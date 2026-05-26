`timescale 1ns/1ps

module vga_only_top (
    input  wire        clk_100m,
    input  wire        reset_n,
    input  wire [1:0]  mode_sw,

    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        test_led
);
    reg [1:0] clk_div;
    always @(posedge clk_100m or negedge reset_n) begin
        if (!reset_n)
            clk_div <= 2'd0;
        else
            clk_div <= clk_div + 1'b1;
    end

    wire pix_clk = clk_div[1];

    reg [2:0] reset_pipe;
    always @(posedge pix_clk or negedge reset_n) begin
        if (!reset_n)
            reset_pipe <= 3'b111;
        else
            reset_pipe <= {reset_pipe[1:0], 1'b0};
    end

    wire reset_pix = reset_pipe[2];

    wire       active;
    wire [9:0] x;
    wire [9:0] y;

    vga_timing u_vga_timing (
        .clk(pix_clk),
        .reset(reset_pix),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .active(active),
        .x(x),
        .y(y)
    );

    reg [25:0] heartbeat;
    always @(posedge clk_100m or negedge reset_n) begin
        if (!reset_n)
            heartbeat <= 26'd0;
        else
            heartbeat <= heartbeat + 1'b1;
    end

    assign test_led = heartbeat[25];

    reg [11:0] rgb;

    always @* begin
        rgb = 12'h000;

        if (active) begin
            case (mode_sw)
                2'b00: begin
                    if (x < 10'd80)
                        rgb = 12'hfff;
                    else if (x < 10'd160)
                        rgb = 12'hff0;
                    else if (x < 10'd240)
                        rgb = 12'h0ff;
                    else if (x < 10'd320)
                        rgb = 12'h0f0;
                    else if (x < 10'd400)
                        rgb = 12'hf0f;
                    else if (x < 10'd480)
                        rgb = 12'hf00;
                    else if (x < 10'd560)
                        rgb = 12'h00f;
                    else
                        rgb = 12'h777;
                end

                2'b01: begin
                    rgb = {x[8:5], x[8:5], x[8:5]};
                end

                2'b10: begin
                    if (x[5] ^ y[5])
                        rgb = 12'hfff;
                    else
                        rgb = 12'h000;
                end

                default: begin
                    if ((x < 10'd8) || (x >= 10'd632) ||
                        (y < 10'd8) || (y >= 10'd472))
                        rgb = 12'hfff;
                    else if ((x >= 10'd318) && (x <= 10'd322))
                        rgb = 12'hf00;
                    else if ((y >= 10'd238) && (y <= 10'd242))
                        rgb = 12'h0f0;
                    else if ((x[7:0] < 8'd16) && (y[7:0] < 8'd16))
                        rgb = 12'h00f;
                    else
                        rgb = 12'h111;
                end
            endcase
        end
    end

    assign vga_r = rgb[11:8];
    assign vga_g = rgb[7:4];
    assign vga_b = rgb[3:0];
endmodule
