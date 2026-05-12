`timescale 1ns/1ps

module rgb565_to_gray (
    input  wire [15:0] rgb565,
    output wire [7:0]  gray
);
    wire [7:0] r8 = {rgb565[15:11], rgb565[15:13]};
    wire [7:0] g8 = {rgb565[10:5],  rgb565[10:9]};
    wire [7:0] b8 = {rgb565[4:0],   rgb565[4:2]};

    wire [15:0] y = (r8 * 8'd77) + (g8 * 8'd150) + (b8 * 8'd29);
    assign gray = y[15:8];
endmodule
