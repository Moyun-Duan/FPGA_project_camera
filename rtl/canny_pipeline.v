`timescale 1ns/1ps

module canny_pipeline #(
    parameter LOW_THRESHOLD  = 8'd24,
    parameter HIGH_THRESHOLD = 8'd64
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       window_valid,
    input  wire [8:0] window_x,
    input  wire [7:0] window_y,
    input  wire [7:0] p00, p01, p02,
    input  wire [7:0] p10, p11, p12,
    input  wire [7:0] p20, p21, p22,

    output reg        out_valid,
    output reg [8:0]  out_x,
    output reg [7:0]  out_y,
    output reg [7:0]  magnitude,
    output reg        is_edge
);
    reg        valid_s1;
    reg [8:0]  x_s1;
    reg [7:0]  y_s1;
    reg signed [11:0] gx_s1;
    reg signed [11:0] gy_s1;

    reg        valid_s2;
    reg [8:0]  x_s2;
    reg [7:0]  y_s2;
    reg [11:0] abs_gx_s2;
    reg [11:0] abs_gy_s2;

    reg        valid_s3;
    reg [8:0]  x_s3;
    reg [7:0]  y_s3;
    reg [12:0] mag_sum_s3;

    wire [7:0] mag_clamped = (mag_sum_s3 > 13'd255) ? 8'hff : mag_sum_s3[7:0];

    always @(posedge clk) begin
        if (reset) begin
            valid_s1   <= 1'b0;
            x_s1       <= 9'd0;
            y_s1       <= 8'd0;
            gx_s1      <= 12'sd0;
            gy_s1      <= 12'sd0;
            valid_s2   <= 1'b0;
            x_s2       <= 9'd0;
            y_s2       <= 8'd0;
            abs_gx_s2  <= 12'd0;
            abs_gy_s2  <= 12'd0;
            valid_s3   <= 1'b0;
            x_s3       <= 9'd0;
            y_s3       <= 8'd0;
            mag_sum_s3 <= 13'd0;
            out_valid  <= 1'b0;
            out_x      <= 9'd0;
            out_y      <= 8'd0;
            magnitude  <= 8'd0;
            is_edge    <= 1'b0;
        end else begin
            valid_s1 <= window_valid;
            x_s1     <= window_x;
            y_s1     <= window_y;
            gx_s1    <=
                -$signed({4'd0, p00})
                +$signed({4'd0, p02})
                -($signed({4'd0, p10}) <<< 1)
                +($signed({4'd0, p12}) <<< 1)
                -$signed({4'd0, p20})
                +$signed({4'd0, p22});
            gy_s1    <=
                 $signed({4'd0, p00})
                +($signed({4'd0, p01}) <<< 1)
                + $signed({4'd0, p02})
                - $signed({4'd0, p20})
                -($signed({4'd0, p21}) <<< 1)
                - $signed({4'd0, p22});

            valid_s2  <= valid_s1;
            x_s2      <= x_s1;
            y_s2      <= y_s1;
            abs_gx_s2 <= gx_s1[11] ? -gx_s1 : gx_s1;
            abs_gy_s2 <= gy_s1[11] ? -gy_s1 : gy_s1;

            valid_s3   <= valid_s2;
            x_s3       <= x_s2;
            y_s3       <= y_s2;
            mag_sum_s3 <= {1'b0, abs_gx_s2} + {1'b0, abs_gy_s2};

            out_valid <= valid_s3;
            out_x     <= x_s3;
            out_y     <= y_s3;
            magnitude <= mag_clamped;
            is_edge   <= (mag_clamped >= HIGH_THRESHOLD);
        end
    end
endmodule
