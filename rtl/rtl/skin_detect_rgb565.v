`timescale 1ns/1ps

module skin_detect_rgb565 #(
    parameter R_MIN          = 8'd80,
    parameter G_MIN          = 8'd30,
    parameter B_MIN          = 8'd15,
    parameter RGB_SPREAD_MIN = 8'd15,
    parameter RG_DIFF_MIN    = 8'd8
) (
    input  wire        clk,
    input  wire        reset,

    input  wire        pixel_valid,
    input  wire [15:0] rgb565,
    input  wire [8:0]  pixel_x,
    input  wire [7:0]  pixel_y,

    output reg         mask_valid,
    output reg         skin_mask,
    output reg  [8:0]  mask_x,
    output reg  [7:0]  mask_y
);

    wire [7:0] r8 = {rgb565[15:11], rgb565[15:13]};
    wire [7:0] g8 = {rgb565[10:5],  rgb565[10:9]};
    wire [7:0] b8 = {rgb565[4:0],   rgb565[4:2]};

    wire [7:0] max_rg  = (r8 > g8) ? r8 : g8;
    wire [7:0] max_rgb = (max_rg > b8) ? max_rg : b8;

    wire [7:0] min_rg  = (r8 < g8) ? r8 : g8;
    wire [7:0] min_rgb = (min_rg < b8) ? min_rg : b8;

    wire [8:0] rg_diff = {1'b0, r8} - {1'b0, g8};
    wire [8:0] spread  = {1'b0, max_rgb} - {1'b0, min_rgb};

    wire skin_now = pixel_valid &&
                    (r8 > R_MIN) &&
                    (g8 > G_MIN) &&
                    (b8 > B_MIN) &&
                    (r8 > g8) &&
                    (g8 > b8) &&
                    (rg_diff > RG_DIFF_MIN) &&
                    (spread > RGB_SPREAD_MIN);

    always @(posedge clk) begin
        if (reset) begin
            mask_valid <= 1'b0;
            skin_mask  <= 1'b0;
            mask_x     <= 9'd0;
            mask_y     <= 8'd0;
        end else begin
            mask_valid <= pixel_valid;
            skin_mask  <= skin_now;
            mask_x     <= pixel_x;
            mask_y     <= pixel_y;
        end
    end

endmodule
