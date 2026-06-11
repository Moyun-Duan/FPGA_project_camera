`timescale 1ns/1ps

module tb_edge_noise_rejection;
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
    integer dark_edge_count;

    always #5 clk = ~clk;

    pixel_filter_pipeline #(
        .WIDTH(24),
        .HEIGHT(18),
        .SOBEL_LOW_THRESHOLD(8'd24),
        .SOBEL_THRESHOLD(8'd64),
        .IMPULSE_DELTA(8'd48)
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

    function is_noise_dot;
        input integer px;
        input integer py;
        begin
            is_noise_dot =
                ((px == 8)  && (py == 7))  ||
                ((px == 15) && (py == 10)) ||
                ((px == 18) && (py == 14));
        end
    endfunction

    always @(posedge clk) begin
        if (out_valid && (out_pixel < 8'd100))
            dark_edge_count <= dark_edge_count + 1;
    end

    initial begin
        dark_edge_count = 0;
        repeat (4) @(negedge clk);
        reset = 1'b0;

        for (y = 0; y < 18; y = y + 1) begin
            for (x = 0; x < 24; x = x + 1) begin
                @(negedge clk);
                pixel_valid = 1'b1;
                pixel_x = x[8:0];
                pixel_y = y[7:0];
                rgb565 = is_noise_dot(x, y) ? 16'h0000 : 16'hffff;
            end
        end

        @(negedge clk);
        pixel_valid = 1'b0;
        rgb565 = 16'd0;
        repeat (64) @(negedge clk);

        if (dark_edge_count > 4) begin
            $fatal(1, "FAIL: isolated impulse noise produced too many dark edge pixels: %0d",
                   dark_edge_count);
        end

        $display("PASS: tb_edge_noise_rejection, dark edges=%0d", dark_edge_count);
        $finish;
    end
endmodule
