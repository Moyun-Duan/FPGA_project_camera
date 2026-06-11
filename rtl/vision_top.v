`timescale 1ns/1ps

module vision_top (
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
    localparam CAMERA_FORMAT = 1;  // YUV422, direct Y-luma capture for stable grayscale
    localparam CAMERA_LUMA_OUTPUT = 1;

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
    always @(posedge cam_pclk) begin
        if (reset_cam) begin
            mode_cam_meta <= 2'b00;
            mode_cam      <= 2'b00;
        end else begin
            mode_cam_meta <= mode_sw;
            mode_cam      <= mode_cam_meta;
        end
    end

    reg [1:0] mode_pix_meta;
    reg [1:0] mode_pix;
    always @(posedge pix_clk) begin
        if (reset_pix) begin
            mode_pix_meta <= 2'b00;
            mode_pix      <= 2'b00;
        end else begin
            mode_pix_meta <= mode_sw;
            mode_pix      <= mode_pix_meta;
        end
    end

    ov7670_init #(
        .RGB565_CONFIG(1'b0)
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
        .YUV_TO_RGB(1'b0),
        .LUMA_OUTPUT(CAMERA_LUMA_OUTPUT)
    ) u_capture (
        .pclk(cam_pclk),
        .reset(reset_cam),
        .vsync(cam_vsync),
        .href(cam_href),
        .data(cam_data),
        .yuv_byte_order(1'b1),
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
    wire        filt_red_edge;

    pixel_filter_pipeline #(
        .WIDTH(IMG_WIDTH),
        .HEIGHT(IMG_HEIGHT),
        .INPUT_LUMA(CAMERA_LUMA_OUTPUT),
        .SOBEL_LOW_THRESHOLD(8'd48),
        .SOBEL_THRESHOLD(8'd128)
    ) u_filter (
        .clk(cam_pclk),
        .reset(reset_cam),
        .mode(mode_cam),
        .enhance_enable(1'b1),
        .pixel_valid(cap_valid),
        .rgb565(cap_rgb565),
        .pixel_x(cap_x),
        .pixel_y(cap_y),
        .out_valid(filt_valid),
        .out_x(filt_x),
        .out_y(filt_y),
        .out_pixel(filt_pixel),
        .out_red_edge(filt_red_edge)
    );

    wire [ADDR_WIDTH-1:0] wr_addr = (filt_y * IMG_WIDTH) + filt_x;
    wire                 wr_en   = filt_valid &&
                                   (filt_x < IMG_WIDTH[8:0]) &&
                                   (filt_y < IMG_HEIGHT[7:0]);

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
    wire [ADDR_WIDTH-1:0] rd_addr = (src_y * IMG_WIDTH) + src_x;
    wire [8:0] fb_data;
    wire       fb_red_edge = fb_data[8];
    wire [7:0] fb_pixel    = fb_data[7:0];

    frame_buffer_gray #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(9),
        .DEPTH(FB_DEPTH)
    ) u_frame_buffer (
        .wr_clk(cam_pclk),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data({filt_red_edge, filt_pixel}),
        .rd_clk(pix_clk),
        .rd_addr(rd_addr),
        .rd_data(fb_data)
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

    wire red_edge_overlay = active_d && (mode_pix == 2'b10) && fb_red_edge;
    wire [11:0] out_rgb = (mode_mark || border) ? mode_rgb :
                           (red_edge_overlay ? 12'hf00 : base_rgb);

    assign vga_r = out_rgb[11:8];
    assign vga_g = out_rgb[7:4];
    assign vga_b = out_rgb[3:0];
endmodule
