`timescale 1ns/1ps

module text_overlay_victory #(
    parameter X0 = 10'd112,
    parameter Y0 = 10'd32,
    parameter TEXT_SCALE = 4
) (
    input  wire        active,
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire        enable,
    input  wire [11:0] base_rgb,
    output wire [11:0] out_rgb
);

    localparam CHAR_W = 8;
    localparam CHAR_H = 8;
    localparam NCHAR  = 7;

    localparam TEXT_W = NCHAR * CHAR_W * TEXT_SCALE;
    localparam TEXT_H = CHAR_H * TEXT_SCALE;

    wire in_text = active &&
                   enable &&
                   (x >= X0) &&
                   (x < X0 + TEXT_W) &&
                   (y >= Y0) &&
                   (y < Y0 + TEXT_H);

    wire [9:0] rel_x = x - X0;
    wire [9:0] rel_y = y - Y0;

    wire [9:0] scaled_x = rel_x / TEXT_SCALE;
    wire [9:0] scaled_y = rel_y / TEXT_SCALE;

    wire [9:0] char_idx_full = rel_x / (CHAR_W * TEXT_SCALE);

    wire [2:0] char_col = scaled_x[2:0];
    wire [2:0] row      = scaled_y[2:0];
    wire [2:0] char_idx = char_idx_full[2:0];

    reg [7:0] glyph_row;

    always @* begin
        glyph_row = 8'b00000000;

        case (char_idx)
            3'd0: begin
                case (row)
                    3'd0: glyph_row = 8'b10000001;
                    3'd1: glyph_row = 8'b10000001;
                    3'd2: glyph_row = 8'b01000010;
                    3'd3: glyph_row = 8'b01000010;
                    3'd4: glyph_row = 8'b00100100;
                    3'd5: glyph_row = 8'b00100100;
                    3'd6: glyph_row = 8'b00011000;
                    default: glyph_row = 8'b00011000;
                endcase
            end

            3'd1: begin
                case (row)
                    3'd0: glyph_row = 8'b01111110;
                    3'd1: glyph_row = 8'b00011000;
                    3'd2: glyph_row = 8'b00011000;
                    3'd3: glyph_row = 8'b00011000;
                    3'd4: glyph_row = 8'b00011000;
                    3'd5: glyph_row = 8'b00011000;
                    3'd6: glyph_row = 8'b00011000;
                    default: glyph_row = 8'b01111110;
                endcase
            end

            3'd2: begin
                case (row)
                    3'd0: glyph_row = 8'b00111110;
                    3'd1: glyph_row = 8'b01100000;
                    3'd2: glyph_row = 8'b11000000;
                    3'd3: glyph_row = 8'b11000000;
                    3'd4: glyph_row = 8'b11000000;
                    3'd5: glyph_row = 8'b11000000;
                    3'd6: glyph_row = 8'b01100000;
                    default: glyph_row = 8'b00111110;
                endcase
            end

            3'd3: begin
                case (row)
                    3'd0: glyph_row = 8'b11111111;
                    3'd1: glyph_row = 8'b00011000;
                    3'd2: glyph_row = 8'b00011000;
                    3'd3: glyph_row = 8'b00011000;
                    3'd4: glyph_row = 8'b00011000;
                    3'd5: glyph_row = 8'b00011000;
                    3'd6: glyph_row = 8'b00011000;
                    default: glyph_row = 8'b00011000;
                endcase
            end

            3'd4: begin
                case (row)
                    3'd0: glyph_row = 8'b00111100;
                    3'd1: glyph_row = 8'b01100110;
                    3'd2: glyph_row = 8'b11000011;
                    3'd3: glyph_row = 8'b11000011;
                    3'd4: glyph_row = 8'b11000011;
                    3'd5: glyph_row = 8'b11000011;
                    3'd6: glyph_row = 8'b01100110;
                    default: glyph_row = 8'b00111100;
                endcase
            end

            3'd5: begin
                case (row)
                    3'd0: glyph_row = 8'b11111100;
                    3'd1: glyph_row = 8'b11000110;
                    3'd2: glyph_row = 8'b11000110;
                    3'd3: glyph_row = 8'b11111100;
                    3'd4: glyph_row = 8'b11011000;
                    3'd5: glyph_row = 8'b11001100;
                    3'd6: glyph_row = 8'b11000110;
                    default: glyph_row = 8'b11000011;
                endcase
            end

            default: begin
                case (row)
                    3'd0: glyph_row = 8'b11000011;
                    3'd1: glyph_row = 8'b01100110;
                    3'd2: glyph_row = 8'b00111100;
                    3'd3: glyph_row = 8'b00011000;
                    3'd4: glyph_row = 8'b00011000;
                    3'd5: glyph_row = 8'b00011000;
                    3'd6: glyph_row = 8'b00011000;
                    default: glyph_row = 8'b00011000;
                endcase
            end
        endcase
    end

    wire glyph_pixel = in_text && glyph_row[7 - char_col];
    wire text_bg     = in_text && !glyph_pixel;

    assign out_rgb = glyph_pixel ? 12'h0f0 :
                     text_bg     ? 12'h000 :
                                   base_rgb;

endmodule
