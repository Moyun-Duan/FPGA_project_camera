`timescale 1ns/1ps

module image_window_3x3 #(
    parameter WIDTH  = 320,
    parameter HEIGHT = 240
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       in_valid,
    input  wire [7:0] pixel_in,
    input  wire [8:0] pixel_x,
    input  wire [7:0] pixel_y,
    output reg        window_valid,
    output reg [8:0]  window_x,
    output reg [7:0]  window_y,
    output reg [7:0]  p00,
    output reg [7:0]  p01,
    output reg [7:0]  p02,
    output reg [7:0]  p10,
    output reg [7:0]  p11,
    output reg [7:0]  p12,
    output reg [7:0]  p20,
    output reg [7:0]  p21,
    output reg [7:0]  p22
);
    reg [7:0] line0 [0:WIDTH-1];
    reg [7:0] line1 [0:WIDTH-1];
    reg [7:0] row0_new;
    reg [7:0] row1_new;

    always @(posedge clk) begin
        if (reset) begin
            window_valid <= 1'b0;
            window_x     <= 9'd0;
            window_y     <= 8'd0;
            p00 <= 8'd0; p01 <= 8'd0; p02 <= 8'd0;
            p10 <= 8'd0; p11 <= 8'd0; p12 <= 8'd0;
            p20 <= 8'd0; p21 <= 8'd0; p22 <= 8'd0;
        end else begin
            window_valid <= 1'b0;
            if (in_valid) begin
                row0_new <= line1[pixel_x];
                row1_new <= line0[pixel_x];

                line1[pixel_x] <= line0[pixel_x];
                line0[pixel_x] <= pixel_in;

                p00 <= p01;      p01 <= p02;      p02 <= line1[pixel_x];
                p10 <= p11;      p11 <= p12;      p12 <= line0[pixel_x];
                p20 <= p21;      p21 <= p22;      p22 <= pixel_in;

                if (pixel_x >= 9'd2 && pixel_y >= 8'd2) begin
                    window_valid <= 1'b1;
                    window_x     <= pixel_x - 1'b1;
                    window_y     <= pixel_y - 1'b1;
                end
            end
        end
    end
endmodule
