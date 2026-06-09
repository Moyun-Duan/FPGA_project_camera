`timescale 1ns/1ps

module tb_ov7670_capture;
    reg clk = 1'b0;
    reg reset = 1'b1;

    reg rgb_vsync = 1'b0;
    reg rgb_href = 1'b0;
    reg [7:0] rgb_data = 8'd0;
    reg rgb_yuv_byte_order = 1'b0;

    wire rgb_pixel_valid;
    wire [15:0] rgb_rgb565;
    wire [8:0] rgb_pixel_x;
    wire [7:0] rgb_pixel_y;
    wire rgb_frame_start;

    reg yuv_vsync = 1'b0;
    reg yuv_href = 1'b0;
    reg [7:0] yuv_data = 8'd0;
    reg yuv_byte_order = 1'b1;

    wire yuv_pixel_valid;
    wire [15:0] yuv_rgb565;
    wire [8:0] yuv_pixel_x;
    wire [7:0] yuv_pixel_y;
    wire yuv_frame_start;

    integer valid_count_rgb;
    integer valid_count_yuv;
    integer yuv_capture_index;

    reg [15:0] yuv_seen0;
    reg [15:0] yuv_seen1;
    reg [15:0] yuv_seen2;
    reg [15:0] yuv_seen3;

    always #10 clk = ~clk;

    ov7670_capture #(
        .WIDTH(4),
        .HEIGHT(2)
    ) dut_rgb (
        .pclk(clk),
        .reset(reset),
        .vsync(rgb_vsync),
        .href(rgb_href),
        .data(rgb_data),
        .yuv_byte_order(rgb_yuv_byte_order),
        .pixel_valid(rgb_pixel_valid),
        .rgb565(rgb_rgb565),
        .pixel_x(rgb_pixel_x),
        .pixel_y(rgb_pixel_y),
        .frame_start(rgb_frame_start)
    );

    ov7670_capture #(
        .WIDTH(4),
        .HEIGHT(1),
        .FORMAT(1),
        .YUV_TO_RGB(1'b0)
    ) dut_yuv_luma (
        .pclk(clk),
        .reset(reset),
        .vsync(yuv_vsync),
        .href(yuv_href),
        .data(yuv_data),
        .yuv_byte_order(yuv_byte_order),
        .pixel_valid(yuv_pixel_valid),
        .rgb565(yuv_rgb565),
        .pixel_x(yuv_pixel_x),
        .pixel_y(yuv_pixel_y),
        .frame_start(yuv_frame_start)
    );

    function [15:0] gray_to_rgb565;
        input [7:0] y;
        begin
            gray_to_rgb565 = {y[7:3], y[7:2], y[7:3]};
        end
    endfunction

    task send_rgb_byte;
        input [7:0] value;
        begin
            rgb_data = value;
            @(negedge clk);
        end
    endtask

    task send_rgb_pixel;
        input [15:0] value;
        begin
            send_rgb_byte(value[15:8]);
            send_rgb_byte(value[7:0]);
        end
    endtask

    task send_yuv_byte;
        input [7:0] value;
        begin
            yuv_data = value;
            @(negedge clk);
        end
    endtask

    always @(posedge clk) begin
        if (rgb_pixel_valid)
            valid_count_rgb <= valid_count_rgb + 1;

        if (yuv_pixel_valid) begin
            case (yuv_capture_index)
                0: yuv_seen0 <= yuv_rgb565;
                1: yuv_seen1 <= yuv_rgb565;
                2: yuv_seen2 <= yuv_rgb565;
                3: yuv_seen3 <= yuv_rgb565;
                default: begin end
            endcase
            yuv_capture_index <= yuv_capture_index + 1;
            valid_count_yuv <= valid_count_yuv + 1;
        end
    end

    initial begin
        valid_count_rgb = 0;
        valid_count_yuv = 0;
        yuv_capture_index = 0;
        yuv_seen0 = 16'd0;
        yuv_seen1 = 16'd0;
        yuv_seen2 = 16'd0;
        yuv_seen3 = 16'd0;

        repeat (3) @(negedge clk);
        reset = 1'b0;

        @(negedge clk);
        rgb_vsync = 1'b1;
        @(negedge clk);
        rgb_vsync = 1'b0;

        rgb_href = 1'b1;
        send_rgb_pixel(16'hF800);
        send_rgb_pixel(16'h07E0);
        rgb_href = 1'b0;
        repeat (2) @(negedge clk);

        rgb_href = 1'b1;
        send_rgb_pixel(16'h001F);
        send_rgb_pixel(16'hFFFF);
        rgb_href = 1'b0;
        repeat (5) @(negedge clk);

        if (valid_count_rgb !== 4) begin
            $fatal(1, "FAIL: expected 4 RGB565 valid pixels, got %0d", valid_count_rgb);
        end

        @(negedge clk);
        yuv_vsync = 1'b1;
        @(negedge clk);
        yuv_vsync = 1'b0;

        yuv_href = 1'b1;
        send_yuv_byte(8'h11);
        send_yuv_byte(8'h20);
        send_yuv_byte(8'h22);
        send_yuv_byte(8'h80);
        send_yuv_byte(8'h33);
        send_yuv_byte(8'hf0);
        send_yuv_byte(8'h44);
        send_yuv_byte(8'h40);
        yuv_href = 1'b0;
        repeat (5) @(negedge clk);

        if (valid_count_yuv !== 4) begin
            $fatal(1, "FAIL: expected 4 YUV luma valid pixels, got %0d", valid_count_yuv);
        end

        if (yuv_seen0 !== gray_to_rgb565(8'h20) ||
            yuv_seen1 !== gray_to_rgb565(8'h80) ||
            yuv_seen2 !== gray_to_rgb565(8'hf0) ||
            yuv_seen3 !== gray_to_rgb565(8'h40)) begin
            $fatal(1, "FAIL: YUV luma bytes were not converted to expected grayscale RGB565 values");
        end

        $display("PASS: tb_ov7670_capture");
        $finish;
    end
endmodule
