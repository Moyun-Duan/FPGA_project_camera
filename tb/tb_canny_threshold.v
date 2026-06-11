`timescale 1ns/1ps

module tb_canny_threshold;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg window_valid = 1'b0;
    reg [8:0] window_x = 9'd0;
    reg [7:0] window_y = 8'd0;
    reg [7:0] p00 = 8'd0;
    reg [7:0] p01 = 8'd0;
    reg [7:0] p02 = 8'd0;
    reg [7:0] p10 = 8'd0;
    reg [7:0] p11 = 8'd0;
    reg [7:0] p12 = 8'd0;
    reg [7:0] p20 = 8'd0;
    reg [7:0] p21 = 8'd0;
    reg [7:0] p22 = 8'd0;

    wire out_valid;
    wire [8:0] out_x;
    wire [7:0] out_y;
    wire [7:0] magnitude;
    wire is_edge;

    integer valid_count;
    reg saw_low_contrast_edge;

    always #5 clk = ~clk;

    canny_pipeline #(
        .LOW_THRESHOLD(8'd24),
        .HIGH_THRESHOLD(8'd64)
    ) dut (
        .clk(clk),
        .reset(reset),
        .window_valid(window_valid),
        .window_x(window_x),
        .window_y(window_y),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .out_valid(out_valid),
        .out_x(out_x),
        .out_y(out_y),
        .magnitude(magnitude),
        .is_edge(is_edge)
    );

    always @(posedge clk) begin
        if (out_valid) begin
            valid_count <= valid_count + 1;
            if ((out_x == 9'd7) && (out_y == 8'd5) && is_edge && (magnitude >= 8'd64))
                saw_low_contrast_edge <= 1'b1;
        end
    end

    initial begin
        valid_count = 0;
        saw_low_contrast_edge = 1'b0;

        repeat (4) @(negedge clk);
        reset = 1'b0;

        @(negedge clk);
        window_valid = 1'b1;
        window_x = 9'd7;
        window_y = 8'd5;
        p00 = 8'd100; p01 = 8'd100; p02 = 8'd124;
        p10 = 8'd100; p11 = 8'd100; p12 = 8'd124;
        p20 = 8'd100; p21 = 8'd100; p22 = 8'd124;

        @(negedge clk);
        window_valid = 1'b0;
        repeat (8) @(negedge clk);

        if (!saw_low_contrast_edge) begin
            $fatal(1, "FAIL: expected 24-level vertical edge to pass threshold, valid=%0d magnitude=%0d edge=%0b",
                   valid_count, magnitude, is_edge);
        end

        $display("PASS: tb_canny_threshold");
        $finish;
    end
endmodule
