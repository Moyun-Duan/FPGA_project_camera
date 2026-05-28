`timescale 1ns/1ps

module ov7670_capture #(
    parameter WIDTH  = 320,
    parameter HEIGHT = 240,
    parameter FORMAT = 0
) (
    input  wire        pclk,
    input  wire        reset,
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  data,
    input  wire        yuv_byte_order,
    output reg         pixel_valid,
    output reg [15:0]  rgb565,
    output reg [8:0]   pixel_x,
    output reg [7:0]   pixel_y,
    output reg         frame_start
);
    reg        href_d;
    reg [1:0]  byte_phase;
    reg [7:0]  first_byte;
    reg        row_seen;

    localparam FORMAT_RGB565    = 0;
    localparam FORMAT_YUV_YUYV  = 1;
    localparam FORMAT_YUV_UYVY  = 2;

    function [15:0] gray_to_rgb565;
        input [7:0] y;
        begin
            gray_to_rgb565 = {y[7:3], y[7:2], y[7:3]};
        end
    endfunction

    always @(posedge pclk) begin
        if (reset) begin
            href_d      <= 1'b0;
            byte_phase  <= 2'd0;
            first_byte  <= 8'd0;
            pixel_valid <= 1'b0;
            rgb565      <= 16'd0;
            pixel_x     <= 9'd0;
            pixel_y     <= 8'd0;
            frame_start <= 1'b0;
            row_seen    <= 1'b0;
        end else begin
            href_d      <= href;
            pixel_valid <= 1'b0;
            frame_start <= 1'b0;

            if (vsync) begin
                pixel_x     <= 9'd0;
                pixel_y     <= 8'd0;
                byte_phase  <= 2'd0;
                row_seen    <= 1'b0;
                frame_start <= 1'b1;
            end else if (href) begin
                row_seen <= 1'b1;
                if (!href_d) begin
                    pixel_x    <= 9'd0;
                    byte_phase <= 2'd0;
                end

                case (FORMAT)
                    FORMAT_RGB565: begin
                        if (byte_phase == 2'd0) begin
                            first_byte <= data;
                            byte_phase <= 2'd1;
                        end else begin
                            byte_phase <= 2'd0;
                            if (pixel_x < WIDTH[8:0] && pixel_y < HEIGHT[7:0]) begin
                                rgb565      <= {first_byte, data};
                                pixel_valid <= 1'b1;
                            end
                            if (pixel_x < (WIDTH - 1))
                                pixel_x <= pixel_x + 1'b1;
                        end
                    end

                    FORMAT_YUV_YUYV: begin
                        if ((!yuv_byte_order && ((byte_phase == 2'd0) || (byte_phase == 2'd2))) ||
                            ( yuv_byte_order && ((byte_phase == 2'd1) || (byte_phase == 2'd3)))) begin
                            if (pixel_x < WIDTH[8:0] && pixel_y < HEIGHT[7:0]) begin
                                rgb565      <= gray_to_rgb565(data);
                                pixel_valid <= 1'b1;
                            end
                            if (pixel_x < (WIDTH - 1))
                                pixel_x <= pixel_x + 1'b1;
                        end
                        byte_phase <= byte_phase + 1'b1;
                    end

                    FORMAT_YUV_UYVY: begin
                        if ((!yuv_byte_order && ((byte_phase == 2'd1) || (byte_phase == 2'd3))) ||
                            ( yuv_byte_order && ((byte_phase == 2'd0) || (byte_phase == 2'd2)))) begin
                            if (pixel_x < WIDTH[8:0] && pixel_y < HEIGHT[7:0]) begin
                                rgb565      <= gray_to_rgb565(data);
                                pixel_valid <= 1'b1;
                            end
                            if (pixel_x < (WIDTH - 1))
                                pixel_x <= pixel_x + 1'b1;
                        end
                        byte_phase <= byte_phase + 1'b1;
                    end

                    default: begin
                        byte_phase <= 2'd0;
                    end
                endcase
            end else begin
                byte_phase <= 2'd0;
                if (href_d && row_seen) begin
                    row_seen <= 1'b0;
                    if (pixel_y < (HEIGHT - 1))
                        pixel_y <= pixel_y + 1'b1;
                end
            end
        end
    end
endmodule
