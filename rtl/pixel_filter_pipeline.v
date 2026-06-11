`timescale 1ns/1ps

module pixel_filter_pipeline #(
    parameter WIDTH  = 320,
    parameter HEIGHT = 240,
    parameter INPUT_LUMA = 0,
    parameter SOBEL_LOW_THRESHOLD = 8'd48,
    parameter SOBEL_THRESHOLD = 8'd128,
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
        .window_valid(win_valid),
        .window_x(win_x),
        .window_y(win_y),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .out_valid(sobel_valid),
        .out_x(sobel_x),
        .out_y(sobel_y),
        .magnitude(sobel_mag),
        .is_edge(sobel_is_edge)
    );

    wire [11:0] gaussian_sum =
        {4'd0, p00} + ({4'd0, p01} << 1) + {4'd0, p02} +
        ({4'd0, p10} << 1) + ({4'd0, p11} << 2) + ({4'd0, p12} << 1) +
        {4'd0, p20} + ({4'd0, p21} << 1) + {4'd0, p22};

    wire [7:0] gaussian_pixel = gaussian_sum[11:4];

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

    reg [7:0] gaussian_pixel_d1;
    reg [7:0] gaussian_pixel_d2;
    reg [7:0] gaussian_pixel_d3;
    reg [7:0] gaussian_pixel_d4;

    wire      sobel_soft_edge = (sobel_mag >= SOBEL_LOW_THRESHOLD);
    wire [7:0] sketch_edge_pixel =
        sobel_is_edge ? 8'd0 :
        (sobel_soft_edge ? 8'd160 : 8'd255);
    wire [7:0] cartoon_pixel =
        sobel_is_edge ? 8'd0 :
        (sobel_soft_edge ? (cartoon_tone(gaussian_pixel_d4) >> 1) : cartoon_tone(gaussian_pixel_d4));

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
        sobel_valid && sobel_is_edge &&
        (sobel_x > 9'd2) && (sobel_x < (LAST_X - 9'd2)) &&
        (sobel_y > 8'd2) && (sobel_y < (LAST_Y - 8'd2));
    wire person_region_edge =
        person_active && sobel_is_edge &&
        (sobel_x >= person_x_min) && (sobel_x <= person_x_max) &&
        (sobel_y >= person_y_min) && (sobel_y <= person_y_max);

    always @(posedge clk) begin
        if (reset) begin
            out_valid         <= 1'b0;
            out_x             <= 9'd0;
            out_y             <= 8'd0;
            out_pixel         <= 8'd0;
            out_red_edge      <= 1'b0;
            gaussian_pixel_d1 <= 8'd0;
            gaussian_pixel_d2 <= 8'd0;
            gaussian_pixel_d3 <= 8'd0;
            gaussian_pixel_d4 <= 8'd0;
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
            gaussian_pixel_d1 <= gaussian_pixel;
            gaussian_pixel_d2 <= gaussian_pixel_d1;
            gaussian_pixel_d3 <= gaussian_pixel_d2;
            gaussian_pixel_d4 <= gaussian_pixel_d3;

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
                if (sobel_x < edge_x_min)
                    edge_x_min <= sobel_x;
                if (sobel_x > edge_x_max)
                    edge_x_max <= sobel_x;
                if (sobel_y < edge_y_min)
                    edge_y_min <= sobel_y;
                if (sobel_y > edge_y_max)
                    edge_y_max <= sobel_y;
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
                    out_valid <= sobel_valid;
                    out_x     <= sobel_x;
                    out_y     <= sobel_y;
                    out_pixel <= sketch_edge_pixel;
                    out_red_edge <= person_region_edge;
                end
                default: begin
                    out_valid <= sobel_valid;
                    out_x     <= sobel_x;
                    out_y     <= sobel_y;
                    out_pixel <= cartoon_pixel;
                    out_red_edge <= 1'b0;
                end
            endcase
        end
    end
endmodule
