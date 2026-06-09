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

    //--------------------------------------------------
    // 坐标同步
    //--------------------------------------------------

    reg        valid_d1;
    reg [8:0]  x_d1;
    reg [7:0]  y_d1;

    always @(posedge clk) begin
        if(reset) begin
            valid_d1 <= 1'b0;
            x_d1 <= 9'd0;
            y_d1 <= 8'd0;
        end
        else begin
            valid_d1 <= window_valid;
            x_d1 <= window_x;
            y_d1 <= window_y;
        end
    end

    //--------------------------------------------------
    // Sobel
    //--------------------------------------------------

    reg signed [11:0] gx;
    reg signed [11:0] gy;

    reg [11:0] abs_gx;
    reg [11:0] abs_gy;

    reg [12:0] mag_sum;

    always @(posedge clk) begin

        if(reset) begin

            gx <= 0;
            gy <= 0;

            abs_gx <= 0;
            abs_gy <= 0;

            mag_sum <= 0;

        end
        else begin

            gx <=
                -$signed({4'd0,p00})
                +$signed({4'd0,p02})
                -($signed({4'd0,p10}) <<< 1)
                +($signed({4'd0,p12}) <<< 1)
                -$signed({4'd0,p20})
                +$signed({4'd0,p22});

            gy <=
                 $signed({4'd0,p00})
                +($signed({4'd0,p01}) <<< 1)
                + $signed({4'd0,p02})
                - $signed({4'd0,p20})
                -($signed({4'd0,p21}) <<< 1)
                - $signed({4'd0,p22});

            abs_gx <= gx[11] ? (-gx) : gx;
            abs_gy <= gy[11] ? (-gy) : gy;

            mag_sum <= abs_gx + abs_gy;

        end
    end

    //--------------------------------------------------
    // 输出梯度幅值
    //--------------------------------------------------

    reg [7:0] mag_out;

    always @(posedge clk) begin

        if(reset)
            mag_out <= 8'd0;

        else begin

            if(mag_sum > 13'd255)
                mag_out <= 8'hFF;
            else
                mag_out <= mag_sum[7:0];

        end

    end

    //--------------------------------------------------
    // 阈值判断
    //--------------------------------------------------
    // 可以调整这个参数
    //--------------------------------------------------

    localparam EDGE_THRESHOLD = 13'd180;

    reg edge_flag;

    always @(posedge clk) begin

        if(reset)
            edge_flag <= 1'b0;
        else
            edge_flag <= (mag_sum > EDGE_THRESHOLD);

    end

    //--------------------------------------------------
    // 输出
    //--------------------------------------------------

    always @(posedge clk) begin

        if(reset) begin

            out_valid  <= 1'b0;
            out_x      <= 9'd0;
            out_y      <= 8'd0;

            magnitude  <= 8'd0;
            is_edge    <= 1'b0;

        end
        else begin

            out_valid  <= valid_d1;
            out_x      <= x_d1;
            out_y      <= y_d1;

            magnitude  <= mag_out;
            is_edge    <= edge_flag;

        end

    end

endmodule
