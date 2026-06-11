`timescale 1ns/1ps

module victory_gesture_detector #(
    parameter WIDTH              = 320,
    parameter HEIGHT             = 240,
    parameter MIN_SKIN_PIXELS    = 16'd900,
    parameter MIN_BOX_WIDTH      = 9'd45,
    parameter MIN_BOX_HEIGHT     = 8'd60,
    parameter PEAK_GAP           = 8'd18,
    parameter VALLEY_GAP         = 8'd10,
    parameter STABLE_FRAME_COUNT = 4'd5
) (
    input  wire       clk,
    input  wire       reset,

    input  wire       pixel_valid,
    input  wire       skin_mask,
    input  wire [8:0] pixel_x,
    input  wire [7:0] pixel_y,

    output reg        victory,
    output reg [8:0]  bbox_x_min_out,
    output reg [8:0]  bbox_x_max_out,
    output reg [7:0]  bbox_y_min_out,
    output reg [7:0]  bbox_y_max_out
);

    localparam [8:0] X_INIT_MIN = WIDTH - 1;
    localparam [7:0] Y_INIT_MIN = HEIGHT - 1;

    reg [8:0] x_min;
    reg [8:0] x_max;
    reg [7:0] y_min;
    reg [7:0] y_max;
    reg [15:0] skin_count;

    reg [7:0] top0;
    reg [7:0] top1;
    reg [7:0] top2;
    reg [7:0] top3;
    reg [7:0] top4;
    reg [7:0] top5;
    reg [7:0] top6;
    reg [7:0] top7;

    reg [8:0] x_min_l;
    reg [8:0] x_max_l;
    reg [7:0] y_min_l;
    reg [7:0] y_max_l;
    reg [15:0] skin_count_l;

    reg [7:0] top0_l;
    reg [7:0] top1_l;
    reg [7:0] top2_l;
    reg [7:0] top3_l;
    reg [7:0] top4_l;
    reg [7:0] top5_l;
    reg [7:0] top6_l;
    reg [7:0] top7_l;

    reg [7:0] prev_y;
    reg [3:0] stable_count;

    wire frame_wrap = pixel_valid && (pixel_y < prev_y);

    wire [8:0] box_w = (x_max_l >= x_min_l) ? (x_max_l - x_min_l) : 9'd0;
    wire [7:0] box_h = (y_max_l >= y_min_l) ? (y_max_l - y_min_l) : 8'd0;

    wire hand_valid = (skin_count_l > MIN_SKIN_PIXELS) &&
                      (box_w > MIN_BOX_WIDTH) &&
                      (box_h > MIN_BOX_HEIGHT);

    wire [2:0] bin_idx = (pixel_x < 9'd40)  ? 3'd0 :
                         (pixel_x < 9'd80)  ? 3'd1 :
                         (pixel_x < 9'd120) ? 3'd2 :
                         (pixel_x < 9'd160) ? 3'd3 :
                         (pixel_x < 9'd200) ? 3'd4 :
                         (pixel_x < 9'd240) ? 3'd5 :
                         (pixel_x < 9'd280) ? 3'd6 :
                                               3'd7;

    wire [7:0] half_y = y_min_l + (box_h >> 1);

    wire peak1 = hand_valid && (top2_l + PEAK_GAP < half_y);
    wire peak2 = hand_valid && (top3_l + PEAK_GAP < half_y);
    wire peak3 = hand_valid && (top4_l + PEAK_GAP < half_y);
    wire peak4 = hand_valid && (top5_l + PEAK_GAP < half_y);

    wire valley23 = (top3_l > top2_l + VALLEY_GAP) ||
                    (top2_l > top3_l + VALLEY_GAP);

    wire valley34 = (top4_l > top3_l + VALLEY_GAP) ||
                    (top3_l > top4_l + VALLEY_GAP);

    wire valley45 = (top5_l > top4_l + VALLEY_GAP) ||
                    (top4_l > top5_l + VALLEY_GAP);

    wire victory_frame = hand_valid &&
                         (
                            ((peak1 && peak2) && !peak3 && valley34) ||
                            ((peak2 && peak3) && valley23 && valley45) ||
                            ((peak3 && peak4) && !peak2 && valley34)
                         );

    task clear_accumulators;
        begin
            x_min      <= X_INIT_MIN;
            x_max      <= 9'd0;
            y_min      <= Y_INIT_MIN;
            y_max      <= 8'd0;
            skin_count <= 16'd0;

            top0 <= Y_INIT_MIN;
            top1 <= Y_INIT_MIN;
            top2 <= Y_INIT_MIN;
            top3 <= Y_INIT_MIN;
            top4 <= Y_INIT_MIN;
            top5 <= Y_INIT_MIN;
            top6 <= Y_INIT_MIN;
            top7 <= Y_INIT_MIN;
        end
    endtask

    always @(posedge clk) begin
        if (reset) begin
            prev_y <= 8'd0;

            stable_count <= 4'd0;
            victory <= 1'b0;

            bbox_x_min_out <= 9'd0;
            bbox_x_max_out <= 9'd0;
            bbox_y_min_out <= 8'd0;
            bbox_y_max_out <= 8'd0;

            x_min_l <= 9'd0;
            x_max_l <= 9'd0;
            y_min_l <= 8'd0;
            y_max_l <= 8'd0;
            skin_count_l <= 16'd0;

            top0_l <= 8'd0;
            top1_l <= 8'd0;
            top2_l <= 8'd0;
            top3_l <= 8'd0;
            top4_l <= 8'd0;
            top5_l <= 8'd0;
            top6_l <= 8'd0;
            top7_l <= 8'd0;

            clear_accumulators();
        end else begin
            if (pixel_valid) begin
                prev_y <= pixel_y;
            end

            if (frame_wrap) begin
                x_min_l <= x_min;
                x_max_l <= x_max;
                y_min_l <= y_min;
                y_max_l <= y_max;
                skin_count_l <= skin_count;

                top0_l <= top0;
                top1_l <= top1;
                top2_l <= top2;
                top3_l <= top3;
                top4_l <= top4;
                top5_l <= top5;
                top6_l <= top6;
                top7_l <= top7;

                bbox_x_min_out <= x_min;
                bbox_x_max_out <= x_max;
                bbox_y_min_out <= y_min;
                bbox_y_max_out <= y_max;

                if (victory_frame) begin
                    if (stable_count < STABLE_FRAME_COUNT) begin
                        stable_count <= stable_count + 1'b1;
                    end
                end else begin
                    stable_count <= 4'd0;
                end

                victory <= (stable_count >= STABLE_FRAME_COUNT - 1);

                clear_accumulators();
            end else if (pixel_valid && skin_mask) begin
                if (skin_count != 16'hffff) begin
                    skin_count <= skin_count + 1'b1;
                end

                if (pixel_x < x_min) begin
                    x_min <= pixel_x;
                end

                if (pixel_x > x_max) begin
                    x_max <= pixel_x;
                end

                if (pixel_y < y_min) begin
                    y_min <= pixel_y;
                end

                if (pixel_y > y_max) begin
                    y_max <= pixel_y;
                end

                case (bin_idx)
                    3'd0: if (pixel_y < top0) top0 <= pixel_y;
                    3'd1: if (pixel_y < top1) top1 <= pixel_y;
                    3'd2: if (pixel_y < top2) top2 <= pixel_y;
                    3'd3: if (pixel_y < top3) top3 <= pixel_y;
                    3'd4: if (pixel_y < top4) top4 <= pixel_y;
                    3'd5: if (pixel_y < top5) top5 <= pixel_y;
                    3'd6: if (pixel_y < top6) top6 <= pixel_y;
                    default: if (pixel_y < top7) top7 <= pixel_y;
                endcase
            end
        end
    end

endmodule
