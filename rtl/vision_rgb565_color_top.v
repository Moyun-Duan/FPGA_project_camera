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
    localparam CAMERA_FORMAT = 0;  // RGB565 camera output
    localparam RGB565_BYTE_SWAP = 1'b0;  // Set to 1 if SW2=1/mode 01 has correct colors.

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
        .RGB565_CONFIG(1'b1)
    ) u_cam_init (
        .clk(clk_100m),
        .reset(reset_sys),
        .sioc(cam_sioc),
        .siod(cam_siod),
        .done(camera_config_done),
        .busy()
    );

    wire        cap_valid;
    wire [15:0] cap_rgb565;
    wire [8:0]  cap_x;
    wire [7:0]  cap_y;

    ov7670_capture #(
        .WIDTH(IMG_WIDTH),
        .HEIGHT(IMG_HEIGHT),
        .FORMAT(CAMERA_FORMAT),
        .YUV_TO_RGB(1'b0)
    ) u_capture (
        .pclk(cam_pclk),
        .reset(reset_cam),
        .vsync(cam_vsync),
        .href(cam_href),
        .data(cam_data),
        .yuv_byte_order(1'b0),
        .pixel_valid(cap_valid),
        .rgb565(cap_rgb565),
        .pixel_x(cap_x),
        .pixel_y(cap_y),
        .frame_start()
    );

    wire        filt_valid;
    wire [8:0]  filt_x;
    wire [7:0]  filt_y;
    wire [7:0]  filt_pixel;
    wire        color_byte_test_cam = style_page_cam && (mode_cam == 2'b01);
    wire        color_style_cam = style_page_cam && mode_cam[1];
    wire        byte_swap_cam = color_byte_test_cam || (color_style_cam && RGB565_BYTE_SWAP);
    wire [15:0] cap_rgb565_swap = {cap_rgb565[7:0], cap_rgb565[15:8]};
    wire [15:0] cap_rgb565_debug = byte_swap_cam ? cap_rgb565_swap : cap_rgb565;
    wire [1:0]  filter_mode_cam = style_page_cam ? (mode_cam[1] ? 2'b10 : 2'b00) : mode_cam;

    pixel_filter_pipeline #(
        .WIDTH(IMG_WIDTH),
        .HEIGHT(IMG_HEIGHT),
        .SOBEL_LOW_THRESHOLD(8'd48),
        .SOBEL_THRESHOLD(8'd128)
    ) u_filter (
        .clk(cam_pclk),
        .reset(reset_cam),
        .mode(filter_mode_cam),
        .enhance_enable(1'b1),
        .pixel_valid(cap_valid),
        .rgb565(cap_rgb565_debug),
        .pixel_x(cap_x),
        .pixel_y(cap_y),
        .out_valid(filt_valid),
        .out_x(filt_x),
        .out_y(filt_y),
        .out_pixel(filt_pixel)
    );

    wire [ADDR_WIDTH-1:0] wr_addr = (filt_y * IMG_WIDTH) + filt_x;
    wire                  wr_en   = filt_valid &&
                                    (filt_x < IMG_WIDTH[8:0]) &&
                                    (filt_y < IMG_HEIGHT[7:0]);
    wire [ADDR_WIDTH-1:0] color_wr_addr = (cap_y * IMG_WIDTH) + cap_x;
    wire                  color_wr_en   = cap_valid &&
                                          (cap_x < IMG_WIDTH[8:0]) &&
                                          (cap_y < IMG_HEIGHT[7:0]);
    wire [8:0] cap_rgb333 = {
        cap_rgb565_debug[15:13],
        cap_rgb565_debug[10:8],
        cap_rgb565_debug[4:2]
    };

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
    wire       color_page = style_page_pix;
    wire       color_raw_mode = color_page && (mode_pix == 2'b00);
    wire       color_byte_test_mode = color_page && (mode_pix == 2'b01);
    wire       color_pixel_mode = color_page && (mode_pix == 2'b10);
    wire       color_anime_mode = color_page && (mode_pix == 2'b11);
    wire [8:0] rd_src_x = color_pixel_mode ? {src_x[8:2], 2'b00} : src_x;
    wire [7:0] rd_src_y = color_pixel_mode ? {src_y[7:2], 2'b00} : src_y;
    wire [ADDR_WIDTH-1:0] rd_addr = (rd_src_y * IMG_WIDTH) + rd_src_x;
    wire [7:0] fb_pixel;
    wire [8:0] fb_rgb333;

    frame_buffer_gray #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(8),
        .DEPTH(FB_DEPTH)
    ) u_frame_buffer (
        .wr_clk(cam_pclk),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(filt_pixel),
        .rd_clk(pix_clk),
        .rd_addr(rd_addr),
        .rd_data(fb_pixel)
    );

    frame_buffer_gray #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(9),
        .DEPTH(FB_DEPTH)
    ) u_color_frame_buffer (
        .wr_clk(cam_pclk),
        .wr_en(color_wr_en),
        .wr_addr(color_wr_addr),
        .wr_data(cap_rgb333),
        .rd_clk(pix_clk),
        .rd_addr(rd_addr),
        .rd_data(fb_rgb333)
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

    reg [3:0] dither_threshold;
    always @* begin
        case ({vga_y_d[0], vga_x_d[0]})
            2'b00: dither_threshold = 4'd0;
            2'b01: dither_threshold = 4'd8;
            2'b10: dither_threshold = 4'd12;
            default: dither_threshold = 4'd4;
        endcase
    end

    wire dither_add = active_d &&
                      (fb_pixel[7:4] != 4'hf) &&
                      (fb_pixel[3:0] > dither_threshold);
    wire [3:0] gray4 = active_d ? (fb_pixel[7:4] + {3'b000, dither_add}) : 4'd0;
    wire [11:0] base_rgb = {gray4, gray4, gray4};

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

    function [3:0] darken4;
        input [3:0] value;
        begin
            darken4 = value >> 1;
        end
    endfunction

    wire [11:0] color_raw_rgb = {
        fb_rgb333[8:6], fb_rgb333[8],
        fb_rgb333[5:3], fb_rgb333[5],
        fb_rgb333[2:0], fb_rgb333[2]
    };
    wire [11:0] color_poster_rgb = {
        posterize4(color_raw_rgb[11:8]),
        posterize4(color_raw_rgb[7:4]),
        posterize4(color_raw_rgb[3:0])
    };
    wire [11:0] color_anime_base = {
        anime_tone4(color_raw_rgb[11:8]),
        anime_tone4(color_raw_rgb[7:4]),
        anime_tone4(color_raw_rgb[3:0])
    };
    wire color_edge_hard = (color_pixel_mode || color_anime_mode) && (fb_pixel < 8'd32);
    wire color_edge_soft = (color_pixel_mode || color_anime_mode) && (fb_pixel < 8'd200);
    wire [11:0] color_pixel_rgb =
        color_edge_hard ? 12'h000 :
        color_edge_soft ? {
            darken4(color_poster_rgb[11:8]),
            darken4(color_poster_rgb[7:4]),
            darken4(color_poster_rgb[3:0])
        } : color_poster_rgb;
    wire [11:0] color_anime_rgb =
        color_edge_hard ? 12'h000 :
        color_edge_soft ? {
            darken4(color_anime_base[11:8]),
            darken4(color_anime_base[7:4]),
            darken4(color_anime_base[3:0])
        } : color_anime_base;
    wire [11:0] image_rgb =
        (color_raw_mode || color_byte_test_mode) ? color_raw_rgb :
        color_pixel_mode ? color_pixel_rgb :
        color_anime_mode ? color_anime_rgb : base_rgb;

    reg [11:0] mode_rgb;
    always @* begin
        case (mode_pix)
            2'b00: mode_rgb = 12'h00f;
            2'b01: mode_rgb = 12'h0f0;
            2'b10: mode_rgb = 12'hf00;
            default: mode_rgb = 12'hfff;
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

    wire [11:0] out_rgb = (mode_mark || border) ? mode_rgb : image_rgb;

    assign vga_r = out_rgb[11:8];
    assign vga_g = out_rgb[7:4];
    assign vga_b = out_rgb[3:0];
endmodule
