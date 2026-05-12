`timescale 1ns/1ps

module ov7670_capture #(
    parameter WIDTH  = 320,
    parameter HEIGHT = 240
) (
    input  wire        pclk,
    input  wire        reset,
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  data,
    output reg         pixel_valid,
    output reg [15:0]  rgb565,
    output reg [8:0]   pixel_x,
    output reg [7:0]   pixel_y,
    output reg         frame_start
);
    reg        href_d;
    reg        byte_phase;
    reg [7:0]  first_byte;
    reg        row_seen;

    always @(posedge pclk) begin
        if (reset) begin
            href_d      <= 1'b0;
            byte_phase  <= 1'b0;
            first_byte  <= 8'd0;
            pixel_valid <= 1'b0;
            rgb565      <= 16'd0;
            pixel_x     <= 9'd0;
            pixel_y     <= 8'd0;
            frame_start <= 1'b0;
            row_seen    <= 1'b0;
        end else begin
            href_d      <= href;
            pixel_valid <= 1'b0;
            frame_start <= 1'b0;

            if (vsync) begin
                pixel_x     <= 9'd0;
                pixel_y     <= 8'd0;
                byte_phase  <= 1'b0;
                row_seen    <= 1'b0;
                frame_start <= 1'b1;
            end else if (href) begin
                row_seen <= 1'b1;
                if (!href_d) begin
                    pixel_x    <= 9'd0;
                    byte_phase <= 1'b0;
                end

                if (!byte_phase) begin
                    first_byte <= data;
                    byte_phase <= 1'b1;
                end else begin
                    byte_phase <= 1'b0;
                    if (pixel_x < WIDTH[8:0] && pixel_y < HEIGHT[7:0]) begin
                        rgb565      <= {first_byte, data};
                        pixel_valid <= 1'b1;
                    end
                    if (pixel_x < (WIDTH - 1))
                        pixel_x <= pixel_x + 1'b1;
                end
            end else begin
                byte_phase <= 1'b0;
                if (href_d && row_seen) begin
                    row_seen <= 1'b0;
                    if (pixel_y < (HEIGHT - 1))
                        pixel_y <= pixel_y + 1'b1;
                end
            end
        end
    end
endmodule
