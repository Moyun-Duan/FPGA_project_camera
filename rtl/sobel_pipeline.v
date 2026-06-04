`timescale 1ns/1ps

module canny_pipeline (
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
    // 高斯平滑系数 (1/16)
    wire [11:0] smooth_sum =
        {4'd0, p00} + {4'd0, p02} + {4'd0, p20} + {4'd0, p22} +
        ({4'd0, p01} << 1) + ({4'd0, p10} << 1) + ({4'd0, p12} << 1) + ({4'd0, p21} << 1) +
        ({4'd0, p11} << 2);
    wire [7:0] smooth_center = smooth_sum[11:4];

    // 第1级延迟，对齐窗口
    reg [7:0] p11_smooth_d;
    reg window_valid_d1, window_valid_d2;
    reg [8:0] window_x_d1, window_x_d2;
    reg [7:0] window_y_d1, window_y_d2;
    always @(posedge clk) begin
        if (reset) begin
            p11_smooth_d <= 8'd0;
            window_valid_d1 <= 1'b0;
            window_valid_d2 <= 1'b0;
            window_x_d1 <= 9'd0; window_x_d2 <= 9'd0;
            window_y_d1 <= 8'd0; window_y_d2 <= 8'd0;
        end else begin
            p11_smooth_d <= smooth_center;
            window_valid_d1 <= window_valid;
            window_valid_d2 <= window_valid_d1;
            window_x_d1 <= window_x;
            window_x_d2 <= window_x_d1;
            window_y_d1 <= window_y;
            window_y_d2 <= window_y_d1;
        end
    end

    // Sobel梯度计算（基于平滑后的中心像素邻域？为简化，直接使用原始邻域，此处用原始p00~p22计算梯度）
    // 实际更严谨做法需要完整的3x3平滑窗口，但为保持流水线简洁，直接计算梯度（相当于Canny中的梯度步骤）
    reg signed [11:0] gx, gy;
    reg [11:0] abs_gx, abs_gy;
    reg [12:0] mag_sum;
    reg [7:0] direction; // 梯度方向量化: 0~7

    always @(posedge clk) begin
        if (reset) begin
            gx <= 12'sd0; gy <= 12'sd0;
            abs_gx <= 12'd0; abs_gy <= 12'd0;
            mag_sum <= 13'd0;
            direction <= 8'd0;
        end else begin
            gx = -$signed({4'd0, p00}) + $signed({4'd0, p02})
                 -($signed({4'd0, p10}) << 1) + ($signed({4'd0, p12}) << 1)
                 -$signed({4'd0, p20}) + $signed({4'd0, p22});
            gy =  $signed({4'd0, p00}) + ($signed({4'd0, p01}) << 1) + $signed({4'd0, p02})
                 -$signed({4'd0, p20}) - ($signed({4'd0, p21}) << 1) - $signed({4'd0, p22});
            abs_gx = gx[11] ? (~gx + 1'b1) : gx;
            abs_gy = gy[11] ? (~gy + 1'b1) : gy;
            mag_sum = abs_gx + abs_gy;
            // 方向量化 (0~7)
            if (abs_gx > abs_gy) begin
                if (abs_gy * 2 < abs_gx) direction <= 0; // 0度
                else direction <= (gx[11] ^ gy[11]) ? 2 : 6; // 45度或135度
            end else begin
                if (abs_gx * 2 < abs_gy) direction <= 4; // 90度
                else direction <= (gx[11] ^ gy[11]) ? 6 : 2;
            end
        end
    end

    // NMS + 双阈值
    reg [7:0] mag_d1, mag_d2, mag_center;
    reg [7:0] dir_center;
    reg window_valid_d3;
    reg [8:0] out_x_d;
    reg [7:0] out_y_d;

    always @(posedge clk) begin
        if (reset) begin
            mag_d1 <= 8'd0; mag_d2 <= 8'd0; mag_center <= 8'd0;
            dir_center <= 8'd0;
            window_valid_d3 <= 1'b0;
            out_x_d <= 9'd0; out_y_d <= 8'd0;
        end else begin
            mag_d1 <= magnitude;
            mag_d2 <= mag_d1;
            mag_center <= mag_d2;
            dir_center <= direction;
            window_valid_d3 <= window_valid_d2;
            out_x_d <= window_x_d2;
            out_y_d <= window_y_d2;
        end
    end

    wire nms_suppress;
    reg nms_result;
    always @(*) begin
        case (dir_center)
            0: nms_suppress = (mag_center <= mag_d1);
            2: nms_suppress = (mag_center <= mag_d1);
            4: nms_suppress = (mag_center <= mag_d1);
            6: nms_suppress = (mag_center <= mag_d1);
            default: nms_suppress = 1'b0;
        endcase
    end

    reg is_edge_weak, is_edge_strong;
    always @(posedge clk) begin
        if (reset) begin
            is_edge_weak <= 1'b0;
            is_edge_strong <= 1'b0;
        end else if (window_valid_d3) begin
            is_edge_strong <= (mag_center >= 8'd128) && !nms_suppress;
            is_edge_weak   <= (mag_center >= 8'd48) && (mag_center < 8'd128) && !nms_suppress;
        end
    end

    // 滞后连接（简单实现：弱边缘若连接强边缘则保留）
    reg edge_connected;
    always @(posedge clk) begin
        if (reset) edge_connected <= 1'b0;
        else if (window_valid_d3)
            edge_connected <= is_edge_strong | (is_edge_weak & edge_connected);
    end

    always @(posedge clk) begin
        if (reset) begin
            out_valid <= 1'b0;
            out_x <= 9'd0;
            out_y <= 8'd0;
            magnitude <= 8'd0;
            is_edge <= 1'b0;
        end else begin
            out_valid <= window_valid_d3;
            out_x <= out_x_d;
            out_y <= out_y_d;
            magnitude <= mag_center;
            is_edge <= edge_connected;
        end
    end
endmodule
