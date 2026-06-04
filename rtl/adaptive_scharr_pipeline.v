`timescale 1ns/1ps

module adaptive_scharr_pipeline (
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
    // 计算窗口内平均亮度
    wire [10:0] sum = {3'd0, p00} + {3'd0, p01} + {3'd0, p02} +
                      {3'd0, p10} + {3'd0, p11} + {3'd0, p12} +
                      {3'd0, p20} + {3'd0, p21} + {3'd0, p22};
    wire [7:0] avg_luma = sum[10:3];  // 除以9

    reg [7:0] avg_luma_d;
    always @(posedge clk) avg_luma_d <= avg_luma;

    reg [7:0] adaptive_threshold;
    always @(*) adaptive_threshold = 8'd48 + (avg_luma_d >> 2);  // 阈值随亮度线性增加

    // Scharr算子与方案2相同
    reg signed [12:0] gx, gy;
    reg [12:0] abs_gx, abs_gy;
    reg [13:0] mag_sum;

    always @(posedge clk) begin
        if (reset) begin
            gx <= 13'sd0; gy <= 13'sd0;
            abs_gx <= 13'd0; abs_gy <= 13'd0;
            mag_sum <= 14'd0;
            out_valid <= 1'b0;
            out_x <= 9'd0; out_y <= 8'd0;
            magnitude <= 8'd0;
            is_edge <= 1'b0;
        end else begin
            out_valid <= window_valid;
            out_x <= window_x;
            out_y <= window_y;

            gx = -$signed({5'd0, p00}) * 3
                 + $signed({5'd0, p02}) * 3
                 -$signed({5'd0, p10}) * 10
                 + $signed({5'd0, p12}) * 10
                 -$signed({5'd0, p20}) * 3
                 + $signed({5'd0, p22}) * 3;
            gy =  $signed({5'd0, p00}) * 3
                 + $signed({5'd0, p01}) * 10
                 + $signed({5'd0, p02}) * 3
                 -$signed({5'd0, p20}) * 3
                 -$signed({5'd0, p21}) * 10
                 -$signed({5'd0, p22}) * 3;

            abs_gx = gx[12] ? (~gx + 1'b1) : gx;
            abs_gy = gy[12] ? (~gy + 1'b1) : gy;
            mag_sum = abs_gx + abs_gy;

            magnitude <= (mag_sum > 14'd255) ? 8'd255 : mag_sum[7:0];
            is_edge <= (mag_sum > {6'd0, adaptive_threshold});
        end
    end
endmodule
