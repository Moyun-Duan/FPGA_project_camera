`timescale 1ns/1ps

module tb_pixel_filter_pipeline;
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

    integer x;
    integer y;
    integer dark_edge_count;
    integer bright_background_count;

    always #5 clk = ~clk;

    pixel_filter_pipeline #(
        .WIDTH(8),
        .HEIGHT(6)
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
        .out_pixel(out_pixel)
    );

    always @(posedge clk) begin
        if (out_valid && out_pixel < 8'd100)
            dark_edge_count <= dark_edge_count + 1;
        if (out_valid && out_pixel > 8'd200)
            bright_background_count <= bright_background_count + 1;
    end

    initial begin
        dark_edge_count = 0;
        bright_background_count = 0;
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

        if (dark_edge_count < 4 || bright_background_count < 4) begin
            $display("FAIL: expected dark Sobel edges and bright sketch background, edges=%0d background=%0d",
                     dark_edge_count, bright_background_count);
            $finish(1);
        end

        $display("PASS: tb_pixel_filter_pipeline, dark edges=%0d bright background=%0d",
                 dark_edge_count, bright_background_count);
        $finish;
    end
endmodule
