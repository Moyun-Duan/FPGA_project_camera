`timescale 1ns/1ps

module frame_buffer_gray #(
    parameter ADDR_WIDTH = 17,
    parameter DATA_WIDTH = 8,
    parameter DEPTH = (1 << ADDR_WIDTH)
) (
    input  wire                  wr_clk,
    input  wire                  wr_en,
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire                  rd_clk,
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  [DATA_WIDTH-1:0] rd_data
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge wr_clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    always @(posedge rd_clk) begin
        rd_data <= mem[rd_addr];
    end
endmodule
