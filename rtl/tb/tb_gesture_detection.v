`timescale 1ns/1ps

module tb_gesture_detection;

    reg clk;
    reg reset;

    reg        pixel_valid;
    reg [15:0] rgb565;
    reg [8:0]  pixel_x;
    reg [7:0]  pixel_y;

    wire        mask_valid;
    wire        skin_mask;
    wire [8:0]  mask_x;
    wire [7:0]  mask_y;

    wire        victory_detected;
    wire [8:0]  bbox_x_min;
    wire [8:0]  bbox_x_max;
    wire [7:0]  bbox_y_min;
    wire [7:0]  bbox_y_max;

    localparam [15:0] SKIN_RGB565 = 16'hFBEA;
    localparam [15:0] BG_RGB565   = 16'h001F;

    skin_detect_rgb565 u_skin_detect (
        .clk(clk),
        .reset(reset),
        .pixel_valid(pixel_valid),
        .rgb565(rgb565),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .mask_valid(mask_valid),
        .skin_mask(skin_mask),
        .mask_x(mask_x),
        .mask_y(mask_y)
    );

    victory_gesture_detector #(
        .WIDTH(320),
        .HEIGHT(240),
        .MIN_SKIN_PIXELS(16'd900),
        .MIN_BOX_WIDTH(9'd45),
        .MIN_BOX_HEIGHT(8'd60),
        .PEAK_GAP(8'd18),
        .VALLEY_GAP(8'd10),
        .STABLE_FRAME_COUNT(4'd3)
    ) u_victory_detector (
        .clk(clk),
        .reset(reset),
        .pixel_valid(mask_valid),
        .skin_mask(skin_mask),
        .pixel_x(mask_x),
        .pixel_y(mask_y),
        .victory(victory_detected),
        .bbox_x_min_out(bbox_x_min),
        .bbox_x_max_out(bbox_x_max),
        .bbox_y_min_out(bbox_y_min),
        .bbox_y_max_out(bbox_y_max)
    );

    reg        overlay_active;
    reg [9:0]  overlay_x;
    reg [9:0]  overlay_y;
    reg        overlay_enable;
    reg [11:0] overlay_base_rgb;
    wire [11:0] overlay_out_rgb;

    text_overlay_victory #(
        .X0(10'd0),
        .Y0(10'd0),
        .TEXT_SCALE(1)
    ) u_overlay (
        .active(overlay_active),
        .x(overlay_x),
        .y(overlay_y),
        .enable(overlay_enable),
        .base_rgb(overlay_base_rgb),
        .out_rgb(overlay_out_rgb)
    );

    always #5 clk = ~clk;

    function is_victory_shape;
        input integer x;
        input integer y;
        begin
            is_victory_shape =
                ((x >= 80  && x < 240 && y >= 100 && y < 180) ||
                 (x >= 80  && x < 120 && y >= 40  && y < 100) ||
                 (x >= 120 && x < 160 && y >= 40  && y < 100));
        end
    endfunction

    task send_pixel;
        input [8:0] x;
        input [7:0] y;
        input       is_skin;
        begin
            @(posedge clk);
            pixel_valid <= 1'b1;
            pixel_x     <= x;
            pixel_y     <= y;
            rgb565      <= is_skin ? SKIN_RGB565 : BG_RGB565;
        end
    endtask

    task send_idle;
        integer i;
        begin
            for (i = 0; i < 4; i = i + 1) begin
                @(posedge clk);
                pixel_valid <= 1'b0;
                pixel_x     <= 9'd0;
                pixel_y     <= 8'd0;
                rgb565      <= BG_RGB565;
            end
        end
    endtask

    task send_victory_frame;
        integer x;
        integer y;
        begin
            for (y = 0; y < 240; y = y + 1) begin
                for (x = 0; x < 320; x = x + 1) begin
                    send_pixel(x[8:0], y[7:0], is_victory_shape(x, y));
                end
            end
            send_idle();
        end
    endtask

    task send_blank_frame;
        integer x;
        integer y;
        begin
            for (y = 0; y < 240; y = y + 1) begin
                for (x = 0; x < 320; x = x + 1) begin
                    send_pixel(x[8:0], y[7:0], 1'b0);
                end
            end
            send_idle();
        end
    endtask

    task check_overlay;
        begin
            overlay_active   = 1'b1;
            overlay_enable   = 1'b1;
            overlay_base_rgb = 12'h123;

            overlay_x = 10'd0;
            overlay_y = 10'd0;
            #1;

            if (overlay_out_rgb !== 12'h0f0) begin
                $display("ERROR: overlay glyph pixel failed, out = %h", overlay_out_rgb);
                $stop;
            end

            overlay_x = 10'd1;
            overlay_y = 10'd0;
            #1;

            if (overlay_out_rgb !== 12'h000) begin
                $display("ERROR: overlay background pixel failed, out = %h", overlay_out_rgb);
                $stop;
            end

            overlay_enable = 1'b0;
            #1;

            if (overlay_out_rgb !== 12'h123) begin
                $display("ERROR: overlay bypass failed, out = %h", overlay_out_rgb);
                $stop;
            end

            $display("PASS: text overlay check passed.");
        end
    endtask

    integer frame_id;

    initial begin
        $dumpfile("tb_gesture_detection.vcd");
        $dumpvars(0, tb_gesture_detection);

        clk = 1'b0;
        reset = 1'b1;

        pixel_valid = 1'b0;
        rgb565 = BG_RGB565;
        pixel_x = 9'd0;
        pixel_y = 8'd0;

        overlay_active = 1'b0;
        overlay_x = 10'd0;
        overlay_y = 10'd0;
        overlay_enable = 1'b0;
        overlay_base_rgb = 12'h123;

        repeat (10) @(posedge clk);
        reset = 1'b0;

        check_overlay();

        $display("Start sending synthetic victory frames...");

        for (frame_id = 0; frame_id < 8; frame_id = frame_id + 1) begin
            send_victory_frame();
            $display("frame %0d done, victory = %b, bbox = (%0d,%0d)-(%0d,%0d)",
                     frame_id,
                     victory_detected,
                     bbox_x_min,
                     bbox_y_min,
                     bbox_x_max,
                     bbox_y_max);
        end

        if (victory_detected !== 1'b1) begin
            $display("ERROR: victory gesture was not detected.");
            $stop;
        end else begin
            $display("PASS: victory gesture detected.");
        end

        $display("Start sending blank frames...");

        for (frame_id = 0; frame_id < 4; frame_id = frame_id + 1) begin
            send_blank_frame();
            $display("blank frame %0d done, victory = %b", frame_id, victory_detected);
        end

        if (victory_detected !== 1'b0) begin
            $display("ERROR: victory signal did not clear after blank frames.");
            $stop;
        end else begin
            $display("PASS: victory signal cleared after blank frames.");
        end

        $display("ALL TESTS PASSED.");
        $finish;
    end

endmodule
