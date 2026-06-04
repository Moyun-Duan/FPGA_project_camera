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
generate
    if ((ADDR_WIDTH >= 13) && (ADDR_WIDTH <= 17) && (DEPTH > 4096) && (DEPTH <= 77824)) begin : gen_banked_4k
        localparam BANK_ADDR_WIDTH = 12;
        localparam BANK_DEPTH      = 4096;
        localparam BANK_COUNT      = (DEPTH + BANK_DEPTH - 1) / BANK_DEPTH;

        wire [4:0] wr_bank = wr_addr[ADDR_WIDTH-1:BANK_ADDR_WIDTH];
        wire [4:0] rd_bank = rd_addr[ADDR_WIDTH-1:BANK_ADDR_WIDTH];
        wire [BANK_COUNT*DATA_WIDTH-1:0] rd_bank_data;

        reg [4:0] rd_bank_d;
        reg       rd_in_range_d;

        always @(posedge rd_clk) begin
            rd_bank_d     <= rd_bank;
            rd_in_range_d <= (rd_addr < DEPTH);
        end

        genvar bank_idx;
        for (bank_idx = 0; bank_idx < BANK_COUNT; bank_idx = bank_idx + 1) begin : bank
            localparam [4:0] BANK_ID = bank_idx[4:0];

            (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:BANK_DEPTH-1];
            reg [DATA_WIDTH-1:0] rd_q;

            wire bank_wr_en = wr_en && (wr_addr < DEPTH) && (wr_bank == BANK_ID);

            always @(posedge wr_clk) begin
                if (bank_wr_en)
                    mem[wr_addr[BANK_ADDR_WIDTH-1:0]] <= wr_data;
            end

            always @(posedge rd_clk) begin
                rd_q <= mem[rd_addr[BANK_ADDR_WIDTH-1:0]];
            end

            assign rd_bank_data[bank_idx*DATA_WIDTH +: DATA_WIDTH] = rd_q;
        end

        integer mux_idx;
        always @* begin
            rd_data = {DATA_WIDTH{1'b0}};
            if (rd_in_range_d) begin
                for (mux_idx = 0; mux_idx < BANK_COUNT; mux_idx = mux_idx + 1) begin
                    if (rd_bank_d == mux_idx[4:0])
                        rd_data = rd_bank_data[mux_idx*DATA_WIDTH +: DATA_WIDTH];
                end
            end
        end
    end else begin : gen_generic
        (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

        always @(posedge wr_clk) begin
            if (wr_en && (wr_addr < DEPTH))
                mem[wr_addr] <= wr_data;
        end

        always @(posedge rd_clk) begin
            if (rd_addr < DEPTH)
                rd_data <= mem[rd_addr];
            else
                rd_data <= {DATA_WIDTH{1'b0}};
        end
    end
endgenerate
endmodule
