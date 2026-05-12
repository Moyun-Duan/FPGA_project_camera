`timescale 1ns/1ps

module tb_pixel_filter_pipeline;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg [1:0] mode = 2'b10;
    reg pixel_valid = 1'b0;
    reg [15:0] rgb565 = 16'd0;
    reg [8:0] pixel_x = 9'd0;
    reg [7:0] pixel_y = 8'd0;

    wire out_valid;
    wire [8:0] out_x;
    wire [7:0] out_y;
    wire [7:0] out_pixel;

    integer x;
    integer y;
    integer edge_like_count;

    always #5 clk = ~clk;

    pixel_filter_pipeline #(
        .WIDTH(8),
        .HEIGHT(6)
    ) dut (
        .clk(clk),
        .reset(reset),
        .mode(mode),
        .pixel_valid(pixel_valid),
        .rgb565(rgb565),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .out_valid(out_valid),
        .out_x(out_x),
        .out_y(out_y),
        .out_pixel(out_pixel)
    );

    always @(posedge clk) begin
        if (out_valid && out_pixel > 8'd100)
            edge_like_count <= edge_like_count + 1;
    end

    initial begin
        edge_like_count = 0;
        repeat (4) @(negedge clk);
        reset = 1'b0;

        for (y = 0; y < 6; y = y + 1) begin
            for (x = 0; x < 8; x = x + 1) begin
                @(negedge clk);
                pixel_valid = 1'b1;
                pixel_x = x[8:0];
                pixel_y = y[7:0];
                rgb565 = (x < 4) ? 16'h0000 : 16'hFFFF;
            end
        end

        @(negedge clk);
        pixel_valid = 1'b0;
        rgb565 = 16'd0;
        repeat (8) @(negedge clk);

        if (edge_like_count < 4) begin
            $display("FAIL: expected Sobel responses around synthetic edge, got %0d", edge_like_count);
            $finish(1);
        end

        $display("PASS: tb_pixel_filter_pipeline, edge responses=%0d", edge_like_count);
        $finish;
    end
endmodule
