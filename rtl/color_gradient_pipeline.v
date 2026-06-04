`timescale 1ns/1ps

module color_gradient_pipeline (
    input  wire           clk,
    input  wire           reset,
    input  wire           window_valid,
    input  wire [8:0]     window_x,
    input  wire [7:0]     window_y,
    input  wire [15:0]    rgb00, rgb01, rgb02,
    input  wire [15:0]    rgb10, rgb11, rgb12,
    input  wire [15:0]    rgb20, rgb21, rgb22,
    output reg            out_valid,
    output reg [8:0]      out_x,
    output reg [7:0]      out_y,
    output reg [7:0]      magnitude,
    output reg            is_edge
);
    parameter THRESHOLD = 8'd80;

    function [7:0] rgb565_to_r8;
        input [15:0] rgb;
        begin
            rgb565_to_r8 = {rgb[15:11], rgb[15:13]};
        end
    endfunction

    function [7:0] rgb565_to_g8;
        input [15:0] rgb;
        begin
            rgb565_to_g8 = {rgb[10:5], rgb[10:9]};
        end
    endfunction

    function [7:0] rgb565_to_b8;
        input [15:0] rgb;
        begin
            rgb565_to_b8 = {rgb[4:0], rgb[4:2]};
        end
    endfunction

    // 计算每个通道的梯度 (Sobel)
    reg signed [11:0] gx_r, gy_r, gx_g, gy_g, gx_b, gy_b;
    reg [11:0] abs_gx_r, abs_gy_r, abs_gx_g, abs_gy_g, abs_gx_b, abs_gy_b;
    reg [12:0] mag_r, mag_g, mag_b;
    reg [12:0] max_mag;

    integer i;
    always @(posedge clk) begin
        if (reset) begin
            gx_r <= 12'sd0; gy_r <= 12'sd0; gx_g <= 12'sd0; gy_g <= 12'sd0; gx_b <= 12'sd0; gy_b <= 12'sd0;
            abs_gx_r <= 12'd0; abs_gy_r <= 12'd0; abs_gx_g <= 12'd0; abs_gy_g <= 12'd0; abs_gx_b <= 12'd0; abs_gy_b <= 12'd0;
            mag_r <= 13'd0; mag_g <= 13'd0; mag_b <= 13'd0;
            max_mag <= 13'd0;
            out_valid <= 1'b0; out_x <= 9'd0; out_y <= 8'd0;
            magnitude <= 8'd0; is_edge <= 1'b0;
        end else begin
            out_valid <= window_valid;
            out_x <= window_x;
            out_y <= window_y;

            // 对R通道计算Sobel梯度
            gx_r = -$signed({4'd0, rgb565_to_r8(rgb00)}) + $signed({4'd0, rgb565_to_r8(rgb02)})
                   -($signed({4'd0, rgb565_to_r8(rgb10)}) << 1) + ($signed({4'd0, rgb565_to_r8(rgb12)}) << 1)
                   -$signed({4'd0, rgb565_to_r8(rgb20)}) + $signed({4'd0, rgb565_to_r8(rgb22)});
            gy_r =  $signed({4'd0, rgb565_to_r8(rgb00)}) + ($signed({4'd0, rgb565_to_r8(rgb01)}) << 1) + $signed({4'd0, rgb565_to_r8(rgb02)})
                   -$signed({4'd0, rgb565_to_r8(rgb20)}) - ($signed({4'd0, rgb565_to_r8(rgb21)}) << 1) - $signed({4'd0, rgb565_to_r8(rgb22)});
            abs_gx_r = gx_r[11] ? (~gx_r + 1'b1) : gx_r;
            abs_gy_r = gy_r[11] ? (~gy_r + 1'b1) : gy_r;
            mag_r = abs_gx_r + abs_gy_r;

            // G通道
            gx_g = -$signed({4'd0, rgb565_to_g8(rgb00)}) + $signed({4'd0, rgb565_to_g8(rgb02)})
                   -($signed({4'd0, rgb565_to_g8(rgb10)}) << 1) + ($signed({4'd0, rgb565_to_g8(rgb12)}) << 1)
                   -$signed({4'd0, rgb565_to_g8(rgb20)}) + $signed({4'd0, rgb565_to_g8(rgb22)});
            gy_g =  $signed({4'd0, rgb565_to_g8(rgb00)}) + ($signed({4'd0, rgb565_to_g8(rgb01)}) << 1) + $signed({4'd0, rgb565_to_g8(rgb02)})
                   -$signed({4'd0, rgb565_to_g8(rgb20)}) - ($signed({4'd0, rgb565_to_g8(rgb21)}) << 1) - $signed({4'd0, rgb565_to_g8(rgb22)});
            abs_gx_g = gx_g[11] ? (~gx_g + 1'b1) : gx_g;
            abs_gy_g = gy_g[11] ? (~gy_g + 1'b1) : gy_g;
            mag_g = abs_gx_g + abs_gy_g;

            // B通道
            gx_b = -$signed({4'd0, rgb565_to_b8(rgb00)}) + $signed({4'd0, rgb565_to_b8(rgb02)})
                   -($signed({4'd0, rgb565_to_b8(rgb10)}) << 1) + ($signed({4'd0, rgb565_to_b8(rgb12)}) << 1)
                   -$signed({4'd0, rgb565_to_b8(rgb20)}) + $signed({4'd0, rgb565_to_b8(rgb22)});
            gy_b =  $signed({4'd0, rgb565_to_b8(rgb00)}) + ($signed({4'd0, rgb565_to_b8(rgb01)}) << 1) + $signed({4'd0, rgb565_to_b8(rgb02)})
                   -$signed({4'd0, rgb565_to_b8(rgb20)}) - ($signed({4'd0, rgb565_to_b8(rgb21)}) << 1) - $signed({4'd0, rgb565_to_b8(rgb22)});
            abs_gx_b = gx_b[11] ? (~gx_b + 1'b1) : gx_b;
            abs_gy_b = gy_b[11] ? (~gy_b + 1'b1) : gy_b;
            mag_b = abs_gx_b + abs_gy_b;

            // 取三个通道梯度的最大值
            max_mag = (mag_r > mag_g) ? mag_r : mag_g;
            max_mag = (max_mag > mag_b) ? max_mag : mag_b;

            magnitude <= (max_mag > 13'd255) ? 8'd255 : max_mag[7:0];
            is_edge <= (max_mag > {5'd0, THRESHOLD});
        end
    end
endmodule
