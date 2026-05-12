`timescale 1ns/1ps

module sccb_master #(
    parameter CLK_DIV = 500
) (
    input  wire       clk,
    input  wire       reset,
    input  wire       start,
    input  wire [7:0] dev_addr,
    input  wire [7:0] reg_addr,
    input  wire [7:0] reg_data,
    output reg        busy,
    output reg        done,
    output reg        sioc,
    inout  wire       siod
);
    localparam ST_IDLE   = 4'd0;
    localparam ST_START0 = 4'd1;
    localparam ST_START1 = 4'd2;
    localparam ST_BIT0   = 4'd3;
    localparam ST_BIT1   = 4'd4;
    localparam ST_ACK0   = 4'd5;
    localparam ST_ACK1   = 4'd6;
    localparam ST_STOP0  = 4'd7;
    localparam ST_STOP1  = 4'd8;
    localparam ST_STOP2  = 4'd9;

    reg [3:0]  state;
    reg [15:0] div_count;
    reg [7:0]  shift;
    reg [1:0]  byte_index;
    reg [2:0]  bit_index;
    reg        siod_drive_low;

    assign siod = siod_drive_low ? 1'b0 : 1'bz;

    wire tick = (div_count == CLK_DIV - 1);

    always @(posedge clk) begin
        if (reset) begin
            div_count      <= 16'd0;
            state          <= ST_IDLE;
            shift          <= 8'd0;
            byte_index     <= 2'd0;
            bit_index      <= 3'd7;
            busy           <= 1'b0;
            done           <= 1'b0;
            sioc           <= 1'b1;
            siod_drive_low <= 1'b0;
        end else begin
            done <= 1'b0;
            if (busy) begin
                if (tick)
                    div_count <= 16'd0;
                else
                    div_count <= div_count + 1'b1;
            end else begin
                div_count <= 16'd0;
            end

            if (!busy && start) begin
                busy           <= 1'b1;
                state          <= ST_START0;
                byte_index     <= 2'd0;
                bit_index      <= 3'd7;
                shift          <= dev_addr;
                sioc           <= 1'b1;
                siod_drive_low <= 1'b0;
            end else if (busy && tick) begin
                case (state)
                    ST_START0: begin
                        siod_drive_low <= 1'b1;
                        sioc           <= 1'b1;
                        state          <= ST_START1;
                    end
                    ST_START1: begin
                        sioc  <= 1'b0;
                        state <= ST_BIT0;
                    end
                    ST_BIT0: begin
                        sioc           <= 1'b0;
                        siod_drive_low <= ~shift[7];
                        state          <= ST_BIT1;
                    end
                    ST_BIT1: begin
                        sioc <= 1'b1;
                        if (bit_index == 3'd0)
                            state <= ST_ACK0;
                        else begin
                            bit_index <= bit_index - 1'b1;
                            shift     <= {shift[6:0], 1'b0};
                            state     <= ST_BIT0;
                        end
                    end
                    ST_ACK0: begin
                        sioc           <= 1'b0;
                        siod_drive_low <= 1'b0;
                        state          <= ST_ACK1;
                    end
                    ST_ACK1: begin
                        sioc <= 1'b1;
                        if (byte_index == 2'd2) begin
                            state <= ST_STOP0;
                        end else begin
                            byte_index <= byte_index + 1'b1;
                            bit_index  <= 3'd7;
                            if (byte_index == 2'd0)
                                shift <= reg_addr;
                            else
                                shift <= reg_data;
                            state <= ST_BIT0;
                        end
                    end
                    ST_STOP0: begin
                        sioc           <= 1'b0;
                        siod_drive_low <= 1'b1;
                        state          <= ST_STOP1;
                    end
                    ST_STOP1: begin
                        sioc  <= 1'b1;
                        state <= ST_STOP2;
                    end
                    ST_STOP2: begin
                        siod_drive_low <= 1'b0;
                        busy           <= 1'b0;
                        done           <= 1'b1;
                        state          <= ST_IDLE;
                    end
                    default: state <= ST_IDLE;
                endcase
            end
        end
    end
endmodule
