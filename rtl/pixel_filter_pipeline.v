`timescale 1ns/1ps

module pixel_filter_pipeline #(
    parameter WIDTH  = 320,
    parameter HEIGHT = 240
) (
    input  wire        clk,
    input  wire        reset,
    input  wire [1:0]  mode,
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

    always @(posedge clk) begin
        if (reset) begin
            out_valid <= 1'b0;
            out_x     <= 9'd0;
            out_y     <= 8'd0;
            out_pixel <= 8'd0;
        end else begin
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
                    out_pixel <= gaussian_pixel;
                end
                2'b10: begin
                    out_valid <= sobel_valid;
                    out_x     <= sobel_x;
                    out_y     <= sobel_y;
                    out_pixel <= sobel_mag;
                end
                default: begin
                    out_valid <= sobel_valid;
                    out_x     <= sobel_x;
                    out_y     <= sobel_y;
                    out_pixel <= sobel_is_edge ? 8'd0 : 8'd255;
                end
            endcase
        end
    end
endmodule
