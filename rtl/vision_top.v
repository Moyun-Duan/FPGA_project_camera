`timescale 1ns/1ps

module vision_top (
    input  wire        clk_100m,
    input  wire        reset_n,
    input  wire [1:0]  mode_sw,

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

    ov7670_init u_cam_init (
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
        .HEIGHT(IMG_HEIGHT)
    ) u_capture (
        .pclk(cam_pclk),
        .reset(reset_cam),
        .vsync(cam_vsync),
        .href(cam_href),
        .data(cam_data),
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

    pixel_filter_pipeline #(
        .WIDTH(IMG_WIDTH),
        .HEIGHT(IMG_HEIGHT)
    ) u_filter (
        .clk(cam_pclk),
        .reset(reset_cam),
        .mode(mode_sw),
        .pixel_valid(cap_valid),
        .rgb565(cap_rgb565),
        .pixel_x(cap_x),
        .pixel_y(cap_y),
        .out_valid(filt_valid),
        .out_x(filt_x),
        .out_y(filt_y),
        .out_pixel(filt_pixel)
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
    wire [7:0] fb_pixel;

    frame_buffer_gray #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(8)
    ) u_frame_buffer (
        .wr_clk(cam_pclk),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(filt_pixel),
        .rd_clk(pix_clk),
        .rd_addr(rd_addr),
        .rd_data(fb_pixel)
    );

    reg active_d;
    always @(posedge pix_clk) begin
        if (reset_pix)
            active_d <= 1'b0;
        else
            active_d <= vga_active;
    end

    wire [3:0] gray4 = active_d ? fb_pixel[7:4] : 4'd0;
    assign vga_r = gray4;
    assign vga_g = gray4;
    assign vga_b = gray4;
endmodule
