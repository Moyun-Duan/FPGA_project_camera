`timescale 1ns/1ps

module pixel_filter_pipeline #(
    parameter WIDTH  = 320,
    parameter HEIGHT = 240,
    parameter SOBEL_LOW_THRESHOLD = 8'd48,
    parameter SOBEL_THRESHOLD = 8'd128
) (
    input  wire        clk,
    input  wire        reset,
    input  wire [1:0]  mode,
    input  wire        enhance_enable,
    input  wire        pixel_valid,
    input  wire [15:0] rgb565,
    input  wire [8:0]  pixel_x,
    input  wire [7:0]  pixel_y,
    output reg         out_valid,
    output reg [8:0]   out_x,
    output reg [7:0]   out_y,
    output reg [7:0]   out_pixel
);
    wire [7:0] gray;
    rgb565_to_gray u_gray (
        .rgb565(rgb565),
        .gray(gray)
    );

    wire       win_valid;
    wire [8:0] win_x;
    wire [7:0] win_y;
    wire [7:0] p00, p01, p02, p10, p11, p12, p20, p21, p22;

    image_window_3x3 #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT)
    ) u_window (
        .clk(clk),
        .reset(reset),
        .in_valid(pixel_valid),
        .pixel_in(gray),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .window_valid(win_valid),
        .window_x(win_x),
        .window_y(win_y),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22)
    );

    wire       sobel_valid;
    wire [8:0] sobel_x;
    wire [7:0] sobel_y;
    wire [7:0] sobel_mag;
    wire       sobel_is_edge;

    sobel_pipeline u_sobel (
        .clk(clk),
        .reset(reset),
        .window_valid(win_valid),
        .window_x(win_x),
        .window_y(win_y),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .out_valid(sobel_valid),
        .out_x(sobel_x),
        .out_y(sobel_y),
        .magnitude(sobel_mag),
        .is_edge(sobel_is_edge)
    );

    wire [11:0] gaussian_sum =
        {4'd0, p00} + ({4'd0, p01} << 1) + {4'd0, p02} +
        ({4'd0, p10} << 1) + ({4'd0, p11} << 2) + ({4'd0, p12} << 1) +
        {4'd0, p20} + ({4'd0, p21} << 1) + {4'd0, p22};

    wire [7:0] gaussian_pixel = gaussian_sum[11:4];

    wire [8:0] center_ext = {1'b0, p11};
    wire [8:0] blur_ext = {1'b0, gaussian_pixel};
    wire       center_ge_blur = (center_ext >= blur_ext);
    wire [8:0] high_freq =
        center_ge_blur ? (center_ext - blur_ext) : (blur_ext - center_ext);
    wire [8:0] sharpen_step = high_freq >> 1;
    wire [9:0] sharpen_up = {1'b0, center_ext} + {1'b0, sharpen_step};
    wire [8:0] sharpen_down =
        (center_ext > sharpen_step) ? (center_ext - sharpen_step) : 9'd0;
    wire [7:0] sharpen_pixel =
        center_ge_blur ?
            ((sharpen_up > 10'd255) ? 8'd255 : sharpen_up[7:0]) :
            sharpen_down[7:0];

    function [7:0] cartoon_tone;
        input [7:0] value;
        begin
            if (value < 8'd48)
                cartoon_tone = 8'd40;
            else if (value < 8'd96)
                cartoon_tone = 8'd88;
            else if (value < 8'd144)
                cartoon_tone = 8'd136;
            else if (value < 8'd192)
                cartoon_tone = 8'd192;
            else
                cartoon_tone = 8'd240;
        end
    endfunction

    reg [7:0] gaussian_pixel_d;
    wire      sobel_soft_edge = (sobel_mag >= SOBEL_LOW_THRESHOLD);
    wire [7:0] sketch_edge_pixel =
        sobel_is_edge ? 8'd0 :
        (sobel_soft_edge ? 8'd160 : 8'd255);
    wire [7:0] cartoon_pixel =
        sobel_is_edge ? 8'd0 :
        (sobel_soft_edge ? (cartoon_tone(gaussian_pixel_d) >> 1) : cartoon_tone(gaussian_pixel_d));

    always @(posedge clk) begin
        if (reset) begin
            out_valid <= 1'b0;
            out_x     <= 9'd0;
            out_y     <= 8'd0;
            out_pixel <= 8'd0;
            gaussian_pixel_d <= 8'd0;
        end else begin
            gaussian_pixel_d <= gaussian_pixel;

            case (mode)
                2'b00: begin
                    out_valid <= pixel_valid;
                    out_x     <= pixel_x;
                    out_y     <= pixel_y;
                    out_pixel <= gray;
                end
                2'b01: begin
                    out_valid <= win_valid;
                    out_x     <= win_x;
                    out_y     <= win_y;
                    out_pixel <= enhance_enable ? sharpen_pixel : gaussian_pixel;
                end
                2'b10: begin
                    out_valid <= sobel_valid;
                    out_x     <= sobel_x;
                    out_y     <= sobel_y;
                    out_pixel <= sketch_edge_pixel;
                end
                default: begin
                    out_valid <= sobel_valid;
                    out_x     <= sobel_x;
                    out_y     <= sobel_y;
                    out_pixel <= cartoon_pixel;
                end
            endcase
        end
    end
endmodule
