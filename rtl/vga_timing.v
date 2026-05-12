`timescale 1ns/1ps

module vga_timing (
    input  wire       clk,
    input  wire       reset,
    output reg        hsync,
    output reg        vsync,
    output reg        active,
    output reg [9:0]  x,
    output reg [9:0]  y
);
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;

    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge clk) begin
        if (reset) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
            hsync   <= 1'b1;
            vsync   <= 1'b1;
            active  <= 1'b0;
            x       <= 10'd0;
            y       <= 10'd0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 1'b1;
            end else begin
                h_count <= h_count + 1'b1;
            end

            hsync  <= ~((h_count >= H_VISIBLE + H_FRONT) &&
                        (h_count <  H_VISIBLE + H_FRONT + H_SYNC));
            vsync  <= ~((v_count >= V_VISIBLE + V_FRONT) &&
                        (v_count <  V_VISIBLE + V_FRONT + V_SYNC));
            active <= (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
            x      <= h_count;
            y      <= v_count;
        end
    end
endmodule
