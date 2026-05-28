`timescale 1ns/1ps

module tb_ov7670_capture;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg vsync = 1'b0;
    reg href = 1'b0;
    reg [7:0] data = 8'd0;
    reg yuv_byte_order = 1'b0;

    wire pixel_valid;
    wire [15:0] rgb565;
    wire [8:0] pixel_x;
    wire [7:0] pixel_y;
    wire frame_start;

    integer valid_count;

    always #10 clk = ~clk;

    ov7670_capture #(
        .WIDTH(4),
        .HEIGHT(2)
    ) dut (
        .pclk(clk),
        .reset(reset),
        .vsync(vsync),
        .href(href),
        .data(data),
        .yuv_byte_order(yuv_byte_order),
        .pixel_valid(pixel_valid),
        .rgb565(rgb565),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .frame_start(frame_start)
    );

    task send_byte;
        input [7:0] value;
        begin
            @(negedge clk);
            data = value;
        end
    endtask

    task send_pixel;
        input [15:0] value;
        begin
            send_byte(value[15:8]);
            send_byte(value[7:0]);
        end
    endtask

    always @(posedge clk) begin
        if (pixel_valid)
            valid_count <= valid_count + 1;
    end

    initial begin
        valid_count = 0;
        repeat (3) @(negedge clk);
        reset = 1'b0;

        @(negedge clk);
        vsync = 1'b1;
        @(negedge clk);
        vsync = 1'b0;

        href = 1'b1;
        send_pixel(16'hF800);
        send_pixel(16'h07E0);
        href = 1'b0;
        repeat (2) @(negedge clk);

        href = 1'b1;
        send_pixel(16'h001F);
        send_pixel(16'hFFFF);
        href = 1'b0;
        repeat (5) @(negedge clk);

        if (valid_count !== 4) begin
            $display("FAIL: expected 4 valid pixels, got %0d", valid_count);
            $finish(1);
        end

        $display("PASS: tb_ov7670_capture");
        $finish;
    end
endmodule
