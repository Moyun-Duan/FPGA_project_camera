`timescale 1ns/1ps

module pixel_filter_pipeline #(
    parameter WIDTH  = 320,
    parameter HEIGHT = 240,
    parameter INPUT_LUMA = 0,
    parameter SOBEL_LOW_THRESHOLD = 8'd24,
    parameter SOBEL_THRESHOLD = 8'd64,
    parameter IMPULSE_DELTA = 8'd40,
    parameter EDGE_STRONG_MIN_SUPPORT = 4'd5,
    parameter EDGE_SOFT_MIN_SUPPORT = 4'd6,
    parameter EDGE_FINAL_STRONG_MIN_SUPPORT = 4'd5,
    parameter EDGE_FINAL_SOFT_MIN_SUPPORT = 4'd6,
    parameter RED_EDGE_ENABLE = 0,
    parameter PERSON_MIN_EDGES = 16'd300,
    parameter PERSON_MIN_WIDTH = 9'd20,
    parameter PERSON_MIN_HEIGHT = 8'd70,
    parameter PERSON_MAX_WIDTH = 9'd220
) (
    input  wire        clk,
    input  wire        reset,
    input  wire [1:0]  mode,
    input  wire        enhance_enable,
    input  wire        pixel_valid,
    input  wire [15:0] rgb565,
    input  wire [8:0]  pixel_x,
    input  wire [7:0]  pixel_y,
    output reg         out_valid,
    output reg [8:0]   out_x,
    output reg [7:0]   out_y,
    output reg [7:0]   out_pixel,
    output reg         out_red_edge
);
    localparam [8:0] LAST_X = WIDTH - 1;
    localparam [7:0] LAST_Y = HEIGHT - 1;

    wire [7:0] rgb_gray;
    rgb565_to_gray u_gray (
        .rgb565(rgb565),
        .gray(rgb_gray)
    );
    wire [7:0] gray = INPUT_LUMA ? rgb565[15:8] : rgb_gray;

    wire       win_valid;
    wire [8:0] win_x;
    wire [7:0] win_y;
    wire [7:0] p00, p01, p02, p10, p11, p12, p20, p21, p22;

    image_window_3x3 #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT)
    ) u_window (
        .clk(clk),
        .reset(reset),
        .in_valid(pixel_valid),
        .pixel_in(gray),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .window_valid(win_valid),
        .window_x(win_x),
        .window_y(win_y),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22)
    );

    wire [7:0] direct_min_a = (p01 < p10) ? p01 : p10;
    wire [7:0] direct_min_b = (p12 < p21) ? p12 : p21;
    wire [7:0] direct_min = (direct_min_a < direct_min_b) ? direct_min_a : direct_min_b;
    wire [7:0] direct_max_a = (p01 > p10) ? p01 : p10;
    wire [7:0] direct_max_b = (p12 > p21) ? p12 : p21;
    wire [7:0] direct_max = (direct_max_a > direct_max_b) ? direct_max_a : direct_max_b;
    wire [9:0] direct_avg_sum = {2'd0, p01} + {2'd0, p10} + {2'd0, p12} + {2'd0, p21};
    wire [7:0] direct_avg = direct_avg_sum[9:2];
    wire [8:0] center_plus_delta = {1'b0, p11} + {1'b0, IMPULSE_DELTA};
    wire [8:0] center_minus_delta = ({1'b0, p11} > {1'b0, IMPULSE_DELTA}) ?
                                    ({1'b0, p11} - {1'b0, IMPULSE_DELTA}) : 9'd0;
    wire dark_like_p00 = ({1'b0, p00} <= center_plus_delta);
    wire dark_like_p01 = ({1'b0, p01} <= center_plus_delta);
    wire dark_like_p02 = ({1'b0, p02} <= center_plus_delta);
    wire dark_like_p10 = ({1'b0, p10} <= center_plus_delta);
    wire dark_like_p12 = ({1'b0, p12} <= center_plus_delta);
    wire dark_like_p20 = ({1'b0, p20} <= center_plus_delta);
    wire dark_like_p21 = ({1'b0, p21} <= center_plus_delta);
    wire dark_like_p22 = ({1'b0, p22} <= center_plus_delta);
    wire bright_like_p00 = ({1'b0, p00} >= center_minus_delta);
    wire bright_like_p01 = ({1'b0, p01} >= center_minus_delta);
    wire bright_like_p02 = ({1'b0, p02} >= center_minus_delta);
    wire bright_like_p10 = ({1'b0, p10} >= center_minus_delta);
    wire bright_like_p12 = ({1'b0, p12} >= center_minus_delta);
    wire bright_like_p20 = ({1'b0, p20} >= center_minus_delta);
    wire bright_like_p21 = ({1'b0, p21} >= center_minus_delta);
    wire bright_like_p22 = ({1'b0, p22} >= center_minus_delta);
    wire [3:0] dark_like_count =
        {3'd0, dark_like_p00} + {3'd0, dark_like_p01} + {3'd0, dark_like_p02} +
        {3'd0, dark_like_p10} + {3'd0, dark_like_p12} +
        {3'd0, dark_like_p20} + {3'd0, dark_like_p21} + {3'd0, dark_like_p22};
    wire [3:0] bright_like_count =
        {3'd0, bright_like_p00} + {3'd0, bright_like_p01} + {3'd0, bright_like_p02} +
        {3'd0, bright_like_p10} + {3'd0, bright_like_p12} +
        {3'd0, bright_like_p20} + {3'd0, bright_like_p21} + {3'd0, bright_like_p22};
    wire center_dark_impulse = (center_plus_delta < {1'b0, direct_avg}) && (dark_like_count < 4'd3);
    wire center_bright_impulse = ({1'b0, p11} > ({1'b0, direct_avg} + {1'b0, IMPULSE_DELTA})) &&
                                  (bright_like_count < 4'd3);
    wire [7:0] denoise_center =
        center_dark_impulse ? direct_max :
        (center_bright_impulse ? direct_min : p11);

    wire [11:0] gaussian_sum =
        {4'd0, p00} + ({4'd0, p01} << 1) + {4'd0, p02} +
        ({4'd0, p10} << 1) + ({4'd0, denoise_center} << 2) + ({4'd0, p12} << 1) +
        {4'd0, p20} + ({4'd0, p21} << 1) + {4'd0, p22};

    wire [7:0] gaussian_pixel = gaussian_sum[11:4];

    wire       edge_win_valid;
    wire [8:0] edge_win_x;
    wire [7:0] edge_win_y;
    wire [7:0] ep00, ep01, ep02, ep10, ep11, ep12, ep20, ep21, ep22;

    image_window_3x3 #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT)
    ) u_edge_window (
        .clk(clk),
        .reset(reset),
        .in_valid(win_valid),
        .pixel_in(denoise_center),
        .pixel_x(win_x),
        .pixel_y(win_y),
        .window_valid(edge_win_valid),
        .window_x(edge_win_x),
        .window_y(edge_win_y),
        .p00(ep00), .p01(ep01), .p02(ep02),
        .p10(ep10), .p11(ep11), .p12(ep12),
        .p20(ep20), .p21(ep21), .p22(ep22)
    );

    wire       sobel_valid;
    wire [8:0] sobel_x;
    wire [7:0] sobel_y;
    wire [7:0] sobel_mag;
    wire       sobel_is_edge;

    canny_pipeline #(
        .LOW_THRESHOLD(SOBEL_LOW_THRESHOLD),
        .HIGH_THRESHOLD(SOBEL_THRESHOLD)
    ) u_sobel (
        .clk(clk),
        .reset(reset),
        .window_valid(edge_win_valid),
        .window_x(edge_win_x),
        .window_y(edge_win_y),
        .p00(ep00), .p01(ep01), .p02(ep02),
        .p10(ep10), .p11(ep11), .p12(ep12),
        .p20(ep20), .p21(ep21), .p22(ep22),
        .out_valid(sobel_valid),
        .out_x(sobel_x),
        .out_y(sobel_y),
        .magnitude(sobel_mag),
        .is_edge(sobel_is_edge)
    );

    wire [8:0] center_ext = {1'b0, p11};
    wire [8:0] blur_ext = {1'b0, gaussian_pixel};
    wire       center_ge_blur = (center_ext >= blur_ext);
    wire [8:0] high_freq =
        center_ge_blur ? (center_ext - blur_ext) : (blur_ext - center_ext);
    wire [8:0] sharpen_step = high_freq >> 1;
    wire [9:0] sharpen_up = {1'b0, center_ext} + {1'b0, sharpen_step};
    wire [8:0] sharpen_down =
        (center_ext > sharpen_step) ? (center_ext - sharpen_step) : 9'd0;
    wire [7:0] sharpen_pixel =
        center_ge_blur ?
            ((sharpen_up > 10'd255) ? 8'd255 : sharpen_up[7:0]) :
            sharpen_down[7:0];

    function [7:0] cartoon_tone;
        input [7:0] value;
        begin
            if (value < 8'd48)
                cartoon_tone = 8'd40;
            else if (value < 8'd96)
                cartoon_tone = 8'd88;
            else if (value < 8'd144)
                cartoon_tone = 8'd136;
            else if (value < 8'd192)
                cartoon_tone = 8'd192;
            else
                cartoon_tone = 8'd240;
        end
    endfunction

    reg [7:0] edge_tone_d1;
    reg [7:0] edge_tone_d2;
    reg [7:0] edge_tone_d3;
    reg [7:0] edge_tone_d4;

    wire      sobel_soft_edge = (sobel_mag >= SOBEL_LOW_THRESHOLD);
    wire [9:0] edge_filter_in = {sobel_is_edge, sobel_soft_edge, edge_tone_d4};

    wire       edge_filter_valid;
    wire [8:0] edge_filter_x;
    wire [7:0] edge_filter_y;
    wire [9:0] ef00, ef01, ef02, ef10, ef11, ef12, ef20, ef21, ef22;

    image_window_3x3 #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .DATA_WIDTH(10)
    ) u_edge_filter_window (
        .clk(clk),
        .reset(reset),
        .in_valid(sobel_valid),
        .pixel_in(edge_filter_in),
        .pixel_x(sobel_x),
        .pixel_y(sobel_y),
        .window_valid(edge_filter_valid),
        .window_x(edge_filter_x),
        .window_y(edge_filter_y),
        .p00(ef00), .p01(ef01), .p02(ef02),
        .p10(ef10), .p11(ef11), .p12(ef12),
        .p20(ef20), .p21(ef21), .p22(ef22)
    );

    wire [3:0] strong_support =
        {3'd0, ef00[9]} + {3'd0, ef01[9]} + {3'd0, ef02[9]} +
        {3'd0, ef10[9]} + {3'd0, ef11[9]} + {3'd0, ef12[9]} +
        {3'd0, ef20[9]} + {3'd0, ef21[9]} + {3'd0, ef22[9]};
    wire [3:0] soft_support =
        {3'd0, ef00[8]} + {3'd0, ef01[8]} + {3'd0, ef02[8]} +
        {3'd0, ef10[8]} + {3'd0, ef11[8]} + {3'd0, ef12[8]} +
        {3'd0, ef20[8]} + {3'd0, ef21[8]} + {3'd0, ef22[8]};
    wire clean_strong_edge = ef11[9] &&
        ((strong_support >= EDGE_STRONG_MIN_SUPPORT) || (soft_support >= EDGE_SOFT_MIN_SUPPORT));
    wire clean_soft_edge = ef11[8] && (soft_support >= EDGE_SOFT_MIN_SUPPORT);
    wire [7:0] edge_tone = ef11[7:0];
    wire [9:0] clean_edge_filter_in = {clean_strong_edge, clean_soft_edge, edge_tone};

    wire       edge_final_valid;
    wire [8:0] edge_final_x;
    wire [7:0] edge_final_y;
    wire [9:0] cf00, cf01, cf02, cf10, cf11, cf12, cf20, cf21, cf22;

    image_window_3x3 #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .DATA_WIDTH(10)
    ) u_edge_final_window (
        .clk(clk),
        .reset(reset),
        .in_valid(edge_filter_valid),
        .pixel_in(clean_edge_filter_in),
        .pixel_x(edge_filter_x),
        .pixel_y(edge_filter_y),
        .window_valid(edge_final_valid),
        .window_x(edge_final_x),
        .window_y(edge_final_y),
        .p00(cf00), .p01(cf01), .p02(cf02),
        .p10(cf10), .p11(cf11), .p12(cf12),
        .p20(cf20), .p21(cf21), .p22(cf22)
    );

    wire [3:0] final_strong_support =
        {3'd0, cf00[9]} + {3'd0, cf01[9]} + {3'd0, cf02[9]} +
        {3'd0, cf10[9]} + {3'd0, cf11[9]} + {3'd0, cf12[9]} +
        {3'd0, cf20[9]} + {3'd0, cf21[9]} + {3'd0, cf22[9]};
    wire [3:0] final_soft_support =
        {3'd0, cf00[8]} + {3'd0, cf01[8]} + {3'd0, cf02[8]} +
        {3'd0, cf10[8]} + {3'd0, cf11[8]} + {3'd0, cf12[8]} +
        {3'd0, cf20[8]} + {3'd0, cf21[8]} + {3'd0, cf22[8]};
    wire final_strong_edge = cf11[9] &&
        ((final_strong_support >= EDGE_FINAL_STRONG_MIN_SUPPORT) ||
         (final_soft_support >= EDGE_FINAL_SOFT_MIN_SUPPORT));
    wire final_soft_edge = cf11[8] && (final_soft_support >= EDGE_FINAL_SOFT_MIN_SUPPORT);
    wire [7:0] final_edge_tone = cf11[7:0];

    wire [7:0] sketch_edge_pixel =
        final_strong_edge ? 8'd0 :
        (final_soft_edge ? 8'd96 : 8'd255);
    wire [7:0] cartoon_pixel =
        final_strong_edge ? 8'd0 :
        (final_soft_edge ? (cartoon_tone(final_edge_tone) >> 1) : cartoon_tone(final_edge_tone));

    reg        person_active;
    reg [8:0]  person_x_min;
    reg [8:0]  person_x_max;
    reg [7:0]  person_y_min;
    reg [7:0]  person_y_max;

    reg [15:0] edge_count;
    reg [8:0]  edge_x_min;
    reg [8:0]  edge_x_max;
    reg [7:0]  edge_y_min;
    reg [7:0]  edge_y_max;

    wire [8:0] edge_width = edge_x_max - edge_x_min + 1'b1;
    wire [7:0] edge_height = edge_y_max - edge_y_min + 1'b1;
    wire       edge_bbox_valid =
        (edge_count >= PERSON_MIN_EDGES) &&
        (edge_x_max > edge_x_min) &&
        (edge_y_max > edge_y_min) &&
        (edge_width >= PERSON_MIN_WIDTH) &&
        (edge_width <= PERSON_MAX_WIDTH) &&
        (edge_height >= PERSON_MIN_HEIGHT) &&
        ({1'b0, edge_height} >= edge_width);

    wire frame_start_sample = pixel_valid && (pixel_x == 9'd0) && (pixel_y == 8'd0);
    wire track_edge =
        edge_final_valid && final_strong_edge &&
        (edge_final_x > 9'd2) && (edge_final_x < (LAST_X - 9'd2)) &&
        (edge_final_y > 8'd2) && (edge_final_y < (LAST_Y - 8'd2));
    wire person_region_edge =
        person_active && final_strong_edge &&
        (edge_final_x >= person_x_min) && (edge_final_x <= person_x_max) &&
        (edge_final_y >= person_y_min) && (edge_final_y <= person_y_max);

    always @(posedge clk) begin
        if (reset) begin
            out_valid         <= 1'b0;
            out_x             <= 9'd0;
            out_y             <= 8'd0;
            out_pixel         <= 8'd0;
            out_red_edge      <= 1'b0;
            edge_tone_d1      <= 8'd0;
            edge_tone_d2      <= 8'd0;
            edge_tone_d3      <= 8'd0;
            edge_tone_d4      <= 8'd0;
            person_active     <= 1'b0;
            person_x_min      <= 9'd0;
            person_x_max      <= 9'd0;
            person_y_min      <= 8'd0;
            person_y_max      <= 8'd0;
            edge_count        <= 16'd0;
            edge_x_min        <= LAST_X;
            edge_x_max        <= 9'd0;
            edge_y_min        <= LAST_Y;
            edge_y_max        <= 8'd0;
        end else begin
            edge_tone_d1 <= ep11;
            edge_tone_d2 <= edge_tone_d1;
            edge_tone_d3 <= edge_tone_d2;
            edge_tone_d4 <= edge_tone_d3;

            if (frame_start_sample) begin
                person_active <= edge_bbox_valid;
                person_x_min  <= edge_x_min;
                person_x_max  <= edge_x_max;
                person_y_min  <= edge_y_min;
                person_y_max  <= edge_y_max;
                edge_count    <= 16'd0;
                edge_x_min    <= LAST_X;
                edge_x_max    <= 9'd0;
                edge_y_min    <= LAST_Y;
                edge_y_max    <= 8'd0;
            end else if (track_edge) begin
                edge_count <= edge_count + 1'b1;
                if (edge_final_x < edge_x_min)
                    edge_x_min <= edge_final_x;
                if (edge_final_x > edge_x_max)
                    edge_x_max <= edge_final_x;
                if (edge_final_y < edge_y_min)
                    edge_y_min <= edge_final_y;
                if (edge_final_y > edge_y_max)
                    edge_y_max <= edge_final_y;
            end

            case (mode)
                2'b00: begin
                    out_valid <= pixel_valid;
                    out_x     <= pixel_x;
                    out_y     <= pixel_y;
                    out_pixel <= gray;
                    out_red_edge <= 1'b0;
                end
                2'b01: begin
                    out_valid <= win_valid;
                    out_x     <= win_x;
                    out_y     <= win_y;
                    out_pixel <= enhance_enable ? sharpen_pixel : gaussian_pixel;
                    out_red_edge <= 1'b0;
                end
                2'b10: begin
                    out_valid <= edge_final_valid;
                    out_x     <= edge_final_x;
                    out_y     <= edge_final_y;
                    out_pixel <= sketch_edge_pixel;
                    out_red_edge <= RED_EDGE_ENABLE && person_region_edge;
                end
                default: begin
                    out_valid <= edge_final_valid;
                    out_x     <= edge_final_x;
                    out_y     <= edge_final_y;
                    out_pixel <= cartoon_pixel;
                    out_red_edge <= 1'b0;
                end
            endcase
        end
    end
endmodule
