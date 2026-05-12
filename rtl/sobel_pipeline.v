`timescale 1ns/1ps

module sobel_pipeline (
    input  wire       clk,
    input  wire       reset,
    input  wire       window_valid,
    input  wire [8:0] window_x,
    input  wire [7:0] window_y,
    input  wire [7:0] p00,
    input  wire [7:0] p01,
    input  wire [7:0] p02,
    input  wire [7:0] p10,
    input  wire [7:0] p11,
    input  wire [7:0] p12,
    input  wire [7:0] p20,
    input  wire [7:0] p21,
    input  wire [7:0] p22,
    output reg        out_valid,
    output reg [8:0]  out_x,
    output reg [7:0]  out_y,
    output reg [7:0]  magnitude,
    output reg        is_edge
);
    parameter THRESHOLD = 8'd80;

    reg signed [11:0] gx;
    reg signed [11:0] gy;
    reg [11:0] abs_gx;
    reg [11:0] abs_gy;
    reg [12:0] mag_sum;

    always @(posedge clk) begin
        if (reset) begin
            out_valid <= 1'b0;
            out_x     <= 9'd0;
            out_y     <= 8'd0;
            magnitude <= 8'd0;
            is_edge   <= 1'b0;
            gx        <= 12'sd0;
            gy        <= 12'sd0;
            abs_gx    <= 12'd0;
            abs_gy    <= 12'd0;
            mag_sum   <= 13'd0;
        end else begin
            out_valid <= window_valid;
            out_x     <= window_x;
            out_y     <= window_y;

            gx = -$signed({4'd0, p00}) + $signed({4'd0, p02})
                 -($signed({4'd0, p10}) <<< 1) + ($signed({4'd0, p12}) <<< 1)
                 -$signed({4'd0, p20}) + $signed({4'd0, p22});

            gy =  $signed({4'd0, p00}) + ($signed({4'd0, p01}) <<< 1) + $signed({4'd0, p02})
                 -$signed({4'd0, p20}) - ($signed({4'd0, p21}) <<< 1) - $signed({4'd0, p22});

            abs_gx = gx[11] ? (~gx + 1'b1) : gx;
            abs_gy = gy[11] ? (~gy + 1'b1) : gy;
            mag_sum = abs_gx + abs_gy;

            if (mag_sum > 13'd255)
                magnitude <= 8'd255;
            else
                magnitude <= mag_sum[7:0];

            is_edge <= (mag_sum[12:0] > {5'd0, THRESHOLD});
        end
    end
endmodule
