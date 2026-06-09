`timescale 1ns/1ps

module vision_rgb565_color_top (
    input  wire        clk_100m,
    input  wire        reset_n,
    input  wire [1:0]  mode_sw,
    input  wire        style_page_sw,

    input  wire        cam_pclk,
    input  wire        cam_vsync,
    input  wire        cam_href,
    input  wire [7:0]  cam_data,
    output wire        cam_xclk,
    output wire        cam_reset_n,
    output wire        cam_pwdn,
    output wire        cam_sioc,
    inout  wire        cam_siod,

    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        camera_config_done
);
    localparam IMG_WIDTH  = 320;
    localparam IMG_HEIGHT = 240;
    localparam ADDR_WIDTH = 17;
    localparam FB_DEPTH   = IMG_WIDTH * IMG_HEIGHT;
    localparam CAMERA_FORMAT = 1;  // YUV422 camera output, converted to RGB565 in this color top.
    localparam CAMERA_RGB565_CONFIG = 1'b0;
    localparam COLOR_YUV_BYTE_ORDER = 1'b1;  // Matches the stable vision_top Y-luma phase.

    // Set these after checking SW2=0/channel modes on real hardware.
    localparam COLOR_UV_SWAP = 1'b0;
    localparam COLOR_INVERT_V = 1'b0;
    localparam COLOR_SWAP_RG = 1'b0;
    localparam COLOR_SWAP_RB = 1'b0;

    reg [1:0] clk_div;
    always @(posedge clk_100m or negedge reset_n) begin
        if (!reset_n)
            clk_div <= 2'd0;
        else
            clk_div <= clk_div + 1'b1;
    end

    wire pix_clk = clk_div[1];
    assign cam_xclk    = pix_clk;
    assign cam_reset_n = reset_n;
    assign cam_pwdn    = 1'b0;

    wire reset_sys;
    wire reset_cam;
    wire reset_pix;

    reset_sync u_reset_sys (.clk(clk_100m), .reset_n_async(reset_n), .reset(reset_sys));
    reset_sync u_reset_cam (.clk(cam_pclk), .reset_n_async(reset_n), .reset(reset_cam));
    reset_sync u_reset_pix (.clk(pix_clk),  .reset_n_async(reset_n), .reset(reset_pix));

    reg [1:0] mode_cam_meta;
    reg [1:0] mode_cam;
    reg       style_page_cam_meta;
    reg       style_page_cam;
    always @(posedge cam_pclk) begin
        if (reset_cam) begin
            mode_cam_meta <= 2'b00;
            mode_cam      <= 2'b00;
            style_page_cam_meta <= 1'b0;
            style_page_cam      <= 1'b0;
        end else begin
            mode_cam_meta <= mode_sw;
            mode_cam      <= mode_cam_meta;
            style_page_cam_meta <= style_page_sw;
            style_page_cam      <= style_page_cam_meta;
        end
    end

    reg [1:0] mode_pix_meta;
    reg [1:0] mode_pix;
    reg       style_page_pix_meta;
    reg       style_page_pix;
    always @(posedge pix_clk) begin
        if (reset_pix) begin
            mode_pix_meta <= 2'b00;
            mode_pix      <= 2'b00;
            style_page_pix_meta <= 1'b0;
            style_page_pix      <= 1'b0;
        end else begin
            mode_pix_meta <= mode_sw;
            mode_pix      <= mode_pix_meta;
            style_page_pix_meta <= style_page_sw;
            style_page_pix      <= style_page_pix_meta;
        end
    end

    ov7670_init #(
        .RGB565_CONFIG(CAMERA_RGB565_CONFIG)
    ) u_cam_init (
        .clk(clk_100m),
        .reset(reset_sys),
        .sioc(cam_sioc),
        .siod(cam_siod),
        .done(camera_config_done),
        .busy()
    );

    function [7:0] clamp_u8;
        input signed [17:0] value;
        begin
            if (value < 18'sd0)
                clamp_u8 = 8'd0;
            else if (value > 18'sd255)
                clamp_u8 = 8'd255;
            else
                clamp_u8 = value[7:0];
        end
    endfunction

    function [15:0] yuv_to_rgb565_local;
        input [7:0] y;
        input [7:0] u_in;
        input [7:0] v_in;
        input       uv_swap;
        input       invert_v;
        input       swap_rg;
        input       swap_rb;
        reg [7:0] u_sel;
        reg [7:0] v_sel;
        reg signed [17:0] yy;
        reg signed [17:0] uu;
        reg signed [17:0] vv;
        reg signed [17:0] rr_calc;
        reg signed [17:0] gg_calc;
        reg signed [17:0] bb_calc;
        reg [7:0] r8;
        reg [7:0] g8;
        reg [7:0] b8;
        reg [7:0] tmp8;
        begin
            u_sel = uv_swap ? v_in : u_in;
            v_sel = uv_swap ? u_in : v_in;
            if (invert_v)
                v_sel = 8'd255 - v_sel;

            yy = $signed({10'd0, y});
            uu = ($signed({10'd0, u_sel}) - 18'sd128);
            vv = ($signed({10'd0, v_sel}) - 18'sd128);

            // Boost chroma by 1.5x so the VGA output is visibly colored.
            uu = uu + (uu >>> 1);
            vv = vv + (vv >>> 1);

            rr_calc = yy + ((18'sd90 * vv) >>> 6);
            gg_calc = yy - (((18'sd22 * uu) + (18'sd46 * vv)) >>> 6);
            bb_calc = yy + ((18'sd113 * uu) >>> 6);

            r8 = clamp_u8(rr_calc);
            g8 = clamp_u8(gg_calc);
            b8 = clamp_u8(bb_calc);

            if (swap_rg) begin
                tmp8 = r8;
                r8 = g8;
                g8 = tmp8;
            end
            if (swap_rb) begin
                tmp8 = r8;
                r8 = b8;
                b8 = tmp8;
            end

            yuv_to_rgb565_local = {r8[7:3], g8[7:2], b8[7:3]};
        end
    endfunction

    wire debug_uv_swap = (!style_page_cam) && (mode_cam == 2'b01);
    wire debug_swap_rg = (!style_page_cam) && (mode_cam == 2'b10);
    wire debug_invert_v = (!style_page_cam) && (mode_cam == 2'b11);
    wire use_uv_swap = style_page_cam ? COLOR_UV_SWAP : debug_uv_swap;
    wire use_invert_v = style_page_cam ? COLOR_INVERT_V : debug_invert_v;
    wire use_swap_rg = style_page_cam ? COLOR_SWAP_RG : debug_swap_rg;

    reg        cap_valid;
    reg [15:0] cap_rgb565;
    reg [8:0]  cap_x;
    reg [7:0]  cap_y;
    reg        href_d;
    reg [1:0]  yuv_phase;
    reg [7:0]  y0_byte;
    reg [7:0]  u_byte;
    reg [7:0]  v_byte;
    reg        row_seen;

    always @(posedge cam_pclk) begin
        if (reset_cam) begin
            cap_valid <= 1'b0;
            cap_rgb565 <= 16'd0;
            cap_x <= 9'd0;
            cap_y <= 8'd0;
            href_d <= 1'b0;
            yuv_phase <= 2'd0;
            y0_byte <= 8'd0;
            u_byte <= 8'd128;
            v_byte <= 8'd128;
            row_seen <= 1'b0;
        end else begin
            href_d <= cam_href;
            cap_valid <= 1'b0;

            if (cam_vsync) begin
                cap_x <= 9'd0;
                cap_y <= 8'd0;
                yuv_phase <= 2'd0;
                row_seen <= 1'b0;
            end else if (cam_href) begin
                row_seen <= 1'b1;
                if (!href_d) begin
                    cap_x <= 9'd0;
                    yuv_phase <= 2'd0;
                end

                case (yuv_phase)
                    2'd0: begin
                        if (COLOR_YUV_BYTE_ORDER)
                            u_byte <= cam_data;
                        else
                            y0_byte <= cam_data;
                    end
                    2'd1: begin
                        if (COLOR_YUV_BYTE_ORDER)
                            y0_byte <= cam_data;
                        else
                            u_byte <= cam_data;
                    end
                    2'd2: begin
                        if (COLOR_YUV_BYTE_ORDER) begin
                            v_byte <= cam_data;
                            if (cap_x < IMG_WIDTH[8:0] && cap_y < IMG_HEIGHT[7:0]) begin
                                cap_rgb565 <= yuv_to_rgb565_local(
                                    y0_byte, u_byte, cam_data,
                                    use_uv_swap, use_invert_v, use_swap_rg, COLOR_SWAP_RB
                                );
                                cap_valid <= 1'b1;
                            end
                        end else begin
                            v_byte <= cam_data;
                        end
                        if (COLOR_YUV_BYTE_ORDER && cap_x < (IMG_WIDTH - 1))
                            cap_x <= cap_x + 1'b1;
                    end
                    default: begin
                        if (COLOR_YUV_BYTE_ORDER) begin
                            if (cap_x < IMG_WIDTH[8:0] && cap_y < IMG_HEIGHT[7:0]) begin
                                cap_rgb565 <= yuv_to_rgb565_local(
                                    cam_data, u_byte, v_byte,
                                    use_uv_swap, use_invert_v, use_swap_rg, COLOR_SWAP_RB
                                );
                                cap_valid <= 1'b1;
                            end
                        end else begin
                            if (cap_x < IMG_WIDTH[8:0] && cap_y < IMG_HEIGHT[7:0]) begin
                                cap_rgb565 <= yuv_to_rgb565_local(
                                    y0_byte, u_byte, v_byte,
                                    use_uv_swap, use_invert_v, use_swap_rg, COLOR_SWAP_RB
                                );
                                cap_valid <= 1'b1;
                            end
                        end
                        if (cap_x < (IMG_WIDTH - 1))
                            cap_x <= cap_x + 1'b1;
                    end
                endcase

                yuv_phase <= yuv_phase + 1'b1;
            end else begin
                yuv_phase <= 2'd0;
                if (href_d && row_seen) begin
                    row_seen <= 1'b0;
                    if (cap_y < (IMG_HEIGHT - 1))
                        cap_y <= cap_y + 1'b1;
                end
            end
        end
    end

    wire [ADDR_WIDTH-1:0] wr_addr = (cap_y * IMG_WIDTH) + cap_x;
    wire                  wr_en   = cap_valid &&
                                    (cap_x < IMG_WIDTH[8:0]) &&
                                    (cap_y < IMG_HEIGHT[7:0]);

    wire        vga_active;
    wire [9:0]  vga_x;
    wire [9:0]  vga_y;

    vga_timing u_vga (
        .clk(pix_clk),
        .reset(reset_pix),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .active(vga_active),
        .x(vga_x),
        .y(vga_y)
    );

    wire [8:0] src_x = vga_x[9:1];
    wire [7:0] src_y = vga_y[8:1];
    wire       style_pixel_mode = style_page_pix && (mode_pix == 2'b10);
    wire [8:0] rd_src_x = style_pixel_mode ? {src_x[8:2], 2'b00} : src_x;
    wire [7:0] rd_src_y = style_pixel_mode ? {src_y[7:2], 2'b00} : src_y;
    wire [ADDR_WIDTH-1:0] rd_addr = (rd_src_y * IMG_WIDTH) + rd_src_x;
    wire [15:0] fb_rgb565;

    frame_buffer_gray #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(16),
        .DEPTH(FB_DEPTH)
    ) u_color_frame_buffer (
        .wr_clk(cam_pclk),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(cap_rgb565),
        .rd_clk(pix_clk),
        .rd_addr(rd_addr),
        .rd_data(fb_rgb565)
    );

    reg active_d;
    reg [9:0] vga_x_d;
    reg [9:0] vga_y_d;
    always @(posedge pix_clk) begin
        if (reset_pix) begin
            active_d <= 1'b0;
            vga_x_d  <= 10'd0;
            vga_y_d  <= 10'd0;
        end else begin
            active_d <= vga_active;
            vga_x_d  <= vga_x;
            vga_y_d  <= vga_y;
        end
    end

    function [11:0] rgb565_to_rgb444;
        input [15:0] value;
        input        swap_rb;
        reg [3:0] red4;
        reg [3:0] green4;
        reg [3:0] blue4;
        begin
            red4   = value[15:12];
            green4 = value[10:7];
            blue4  = value[4:1];
            rgb565_to_rgb444 = swap_rb ? {blue4, green4, red4} : {red4, green4, blue4};
        end
    endfunction

    function [3:0] posterize4;
        input [3:0] value;
        begin
            if (value < 4'd4)
                posterize4 = 4'd2;
            else if (value < 4'd8)
                posterize4 = 4'd6;
            else if (value < 4'd12)
                posterize4 = 4'd11;
            else
                posterize4 = 4'd15;
        end
    endfunction

    function [3:0] anime_tone4;
        input [3:0] value;
        begin
            if (value < 4'd3)
                anime_tone4 = 4'd1;
            else if (value < 4'd7)
                anime_tone4 = 4'd5;
            else if (value < 4'd11)
                anime_tone4 = 4'd10;
            else if (value < 4'd14)
                anime_tone4 = 4'd13;
            else
                anime_tone4 = 4'd15;
        end
    endfunction

    wire [11:0] rgb_selected = rgb565_to_rgb444(fb_rgb565, COLOR_SWAP_RB);
    wire [11:0] rgb_swap_rb = rgb565_to_rgb444(fb_rgb565, ~COLOR_SWAP_RB);
    wire [11:0] rgb_boost = {
        rgb_selected[11:8] | (rgb_selected[11:8] >> 1),
        rgb_selected[7:4]  | (rgb_selected[7:4] >> 1),
        rgb_selected[3:0]  | (rgb_selected[3:0] >> 1)
    };

    wire [11:0] poster_rgb = {
        posterize4(rgb_selected[11:8]),
        posterize4(rgb_selected[7:4]),
        posterize4(rgb_selected[3:0])
    };
    wire [11:0] anime_base_rgb = {
        anime_tone4(rgb_selected[11:8]),
        anime_tone4(rgb_selected[7:4]),
        anime_tone4(rgb_selected[3:0])
    };
    wire [5:0] anime_sum = {2'b00, rgb_selected[11:8]} +
                           {2'b00, rgb_selected[7:4]} +
                           {2'b00, rgb_selected[3:0]};
    wire [11:0] anime_rgb = (anime_sum < 6'd8) ? 12'h000 : anime_base_rgb;

    reg [11:0] debug_rgb;
    always @* begin
        case (mode_pix)
            2'b00: debug_rgb = rgb_selected;
            2'b01: debug_rgb = rgb_swap_rb;
            2'b10: debug_rgb = rgb_boost;
            default: begin
                if (vga_y_d < 10'd240)
                    debug_rgb = (vga_x_d < 10'd320) ? rgb_selected : rgb_swap_rb;
                else
                    debug_rgb = (vga_x_d < 10'd320) ? poster_rgb : anime_rgb;
            end
        endcase
    end

    reg [11:0] style_rgb;
    always @* begin
        case (mode_pix)
            2'b00: style_rgb = rgb_selected;
            2'b01: style_rgb = poster_rgb;
            2'b10: style_rgb = poster_rgb;
            default: style_rgb = anime_rgb;
        endcase
    end

    reg [11:0] mode_rgb;
    always @* begin
        case ({style_page_pix, mode_pix})
            3'b000: mode_rgb = 12'h00f;
            3'b001: mode_rgb = 12'h0f0;
            3'b010: mode_rgb = 12'hf00;
            3'b011: mode_rgb = 12'hff0;
            3'b100: mode_rgb = 12'h0ff;
            3'b101: mode_rgb = 12'hf0f;
            3'b110: mode_rgb = 12'hfff;
            default: mode_rgb = 12'hfa0;
        endcase
    end

    wire mode_box = active_d && (vga_x_d < 10'd56) && (vga_y_d < 10'd40);
    wire mode_bar0 = mode_box && (vga_x_d >= 10'd4)  && (vga_x_d < 10'd16) && (vga_y_d >= 10'd4) && (vga_y_d < 10'd36);
    wire mode_bar1 = mode_box && (vga_x_d >= 10'd22) && (vga_x_d < 10'd34) && (vga_y_d >= 10'd4) && (vga_y_d < 10'd36) && mode_pix[0];
    wire mode_bar2 = mode_box && (vga_x_d >= 10'd40) && (vga_x_d < 10'd52) && (vga_y_d >= 10'd4) && (vga_y_d < 10'd36) && mode_pix[1];
    wire mode_mark = mode_bar0 || mode_bar1 || mode_bar2;
    wire border = active_d &&
                  ((vga_x_d < 10'd4) || (vga_x_d >= 10'd636) ||
                   (vga_y_d < 10'd4) || (vga_y_d >= 10'd476));

    wire [11:0] image_rgb = style_page_pix ? style_rgb : debug_rgb;
    wire [11:0] out_rgb = active_d ? ((mode_mark || border) ? mode_rgb : image_rgb) : 12'h000;

    assign vga_r = out_rgb[11:8];
    assign vga_g = out_rgb[7:4];
    assign vga_b = out_rgb[3:0];
endmodule
