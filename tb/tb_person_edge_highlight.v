`timescale 1ns/1ps

module tb_person_edge_highlight;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg [1:0] mode = 2'b10;
    reg enhance_enable = 1'b0;
    reg pixel_valid = 1'b0;
    reg [15:0] rgb565 = 16'd0;
    reg [8:0] pixel_x = 9'd0;
    reg [7:0] pixel_y = 8'd0;

    wire out_valid;
    wire [8:0] out_x;
    wire [7:0] out_y;
    wire [7:0] out_pixel;
    wire out_red_edge;

    integer x;
    integer y;
    integer red_edge_count;

    always #5 clk = ~clk;

    pixel_filter_pipeline #(
        .WIDTH(16),
        .HEIGHT(16),
        .PERSON_MIN_EDGES(16'd8),
        .PERSON_MIN_WIDTH(9'd2),
        .PERSON_MIN_HEIGHT(8'd6),
        .PERSON_MAX_WIDTH(9'd10)
    ) dut (
        .clk(clk),
        .reset(reset),
        .mode(mode),
        .enhance_enable(enhance_enable),
        .pixel_valid(pixel_valid),
        .rgb565(rgb565),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .out_valid(out_valid),
        .out_x(out_x),
        .out_y(out_y),
        .out_pixel(out_pixel),
        .out_red_edge(out_red_edge)
    );

    always @(posedge clk) begin
        if (out_valid && out_red_edge)
            red_edge_count <= red_edge_count + 1;
    end

    function [15:0] test_pixel;
        input integer px;
        input integer py;
        begin
            if ((px >= 6) && (px <= 9) && (py >= 3) && (py <= 13))
                test_pixel = 16'hffff;
            else
                test_pixel = 16'h0000;
        end
    endfunction

    task send_frame;
        begin
            for (y = 0; y < 16; y = y + 1) begin
                for (x = 0; x < 16; x = x + 1) begin
                    @(negedge clk);
                    pixel_valid = 1'b1;
                    pixel_x = x[8:0];
                    pixel_y = y[7:0];
                    rgb565 = test_pixel(x, y);
                end
            end

            @(negedge clk);
            pixel_valid = 1'b0;
            rgb565 = 16'd0;
            repeat (20) @(negedge clk);
        end
    endtask

    initial begin
        red_edge_count = 0;
        repeat (4) @(negedge clk);
        reset = 1'b0;

        send_frame();

        if (red_edge_count !== 0) begin
            $fatal(1, "FAIL: first frame should only collect edge statistics, red=%0d",
                   red_edge_count);
        end

        send_frame();

        if (red_edge_count < 4) begin
            $fatal(1, "FAIL: expected red person-candidate edges on second frame, red=%0d",
                   red_edge_count);
        end

        $display("PASS: tb_person_edge_highlight, red edges=%0d", red_edge_count);
        $finish;
    end
endmodule
