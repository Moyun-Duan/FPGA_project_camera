`timescale 1ns/1ps

module ov7670_init #(
    parameter POWERUP_DELAY = 24'd2_000_000
) (
    input  wire clk,
    input  wire reset,
    output wire sioc,
    inout  wire siod,
    output reg  done,
    output reg  busy
);
    localparam DEV_ADDR = 8'h42;

    reg [23:0] delay_count;
    reg [7:0]  rom_index;
    reg        master_start;

    wire [7:0] reg_addr;
    wire [7:0] reg_data;
    wire       rom_valid;
    wire       master_busy;
    wire       master_done;

    ov7670_config_rom u_rom (
        .index(rom_index),
        .reg_addr(reg_addr),
        .reg_data(reg_data),
        .valid(rom_valid)
    );

    sccb_master u_sccb (
        .clk(clk),
        .reset(reset),
        .start(master_start),
        .dev_addr(DEV_ADDR),
        .reg_addr(reg_addr),
        .reg_data(reg_data),
        .busy(master_busy),
        .done(master_done),
        .sioc(sioc),
        .siod(siod)
    );

    always @(posedge clk) begin
        if (reset) begin
            delay_count  <= 24'd0;
            rom_index    <= 8'd0;
            master_start <= 1'b0;
            done         <= 1'b0;
            busy         <= 1'b1;
        end else begin
            master_start <= 1'b0;
            if (done) begin
                busy <= 1'b0;
            end else if (delay_count < POWERUP_DELAY) begin
                delay_count <= delay_count + 1'b1;
                busy        <= 1'b1;
            end else if (rom_valid) begin
                busy <= 1'b1;
                if (!master_busy && !master_start)
                    master_start <= 1'b1;
                if (master_done)
                    rom_index <= rom_index + 1'b1;
            end else begin
                done <= 1'b1;
                busy <= 1'b0;
            end
        end
    end
endmodule
