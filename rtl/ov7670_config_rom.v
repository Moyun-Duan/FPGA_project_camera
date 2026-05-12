`timescale 1ns/1ps

module ov7670_config_rom (
    input  wire [7:0] index,
    output reg  [7:0] reg_addr,
    output reg  [7:0] reg_data,
    output wire       valid
);
    localparam NUM_REGS = 8'd44;

    assign valid = (index < NUM_REGS);

    always @(*) begin
        reg_addr = 8'h00;
        reg_data = 8'h00;
        case (index)
            8'd0:  begin reg_addr = 8'h12; reg_data = 8'h80; end
            8'd1:  begin reg_addr = 8'h11; reg_data = 8'h01; end
            8'd2:  begin reg_addr = 8'h12; reg_data = 8'h14; end
            8'd3:  begin reg_addr = 8'h0C; reg_data = 8'h04; end
            8'd4:  begin reg_addr = 8'h3E; reg_data = 8'h19; end
            8'd5:  begin reg_addr = 8'h40; reg_data = 8'hD0; end
            8'd6:  begin reg_addr = 8'h3A; reg_data = 8'h04; end
            8'd7:  begin reg_addr = 8'h14; reg_data = 8'h38; end
            8'd8:  begin reg_addr = 8'h17; reg_data = 8'h16; end
            8'd9:  begin reg_addr = 8'h18; reg_data = 8'h04; end
            8'd10: begin reg_addr = 8'h32; reg_data = 8'hA4; end
            8'd11: begin reg_addr = 8'h19; reg_data = 8'h02; end
            8'd12: begin reg_addr = 8'h1A; reg_data = 8'h7A; end
            8'd13: begin reg_addr = 8'h03; reg_data = 8'h0A; end
            8'd14: begin reg_addr = 8'h4F; reg_data = 8'hB3; end
            8'd15: begin reg_addr = 8'h50; reg_data = 8'hB3; end
            8'd16: begin reg_addr = 8'h51; reg_data = 8'h00; end
            8'd17: begin reg_addr = 8'h52; reg_data = 8'h3D; end
            8'd18: begin reg_addr = 8'h53; reg_data = 8'hA7; end
            8'd19: begin reg_addr = 8'h54; reg_data = 8'hE4; end
            8'd20: begin reg_addr = 8'h58; reg_data = 8'h9E; end
            8'd21: begin reg_addr = 8'h0E; reg_data = 8'h61; end
            8'd22: begin reg_addr = 8'h0F; reg_data = 8'h4B; end
            8'd23: begin reg_addr = 8'h16; reg_data = 8'h02; end
            8'd24: begin reg_addr = 8'h1E; reg_data = 8'h07; end
            8'd25: begin reg_addr = 8'h21; reg_data = 8'h02; end
            8'd26: begin reg_addr = 8'h22; reg_data = 8'h91; end
            8'd27: begin reg_addr = 8'h29; reg_data = 8'h07; end
            8'd28: begin reg_addr = 8'h33; reg_data = 8'h0B; end
            8'd29: begin reg_addr = 8'h35; reg_data = 8'h0B; end
            8'd30: begin reg_addr = 8'h37; reg_data = 8'h1D; end
            8'd31: begin reg_addr = 8'h38; reg_data = 8'h71; end
            8'd32: begin reg_addr = 8'h39; reg_data = 8'h2A; end
            8'd33: begin reg_addr = 8'h3C; reg_data = 8'h78; end
            8'd34: begin reg_addr = 8'h4D; reg_data = 8'h40; end
            8'd35: begin reg_addr = 8'h4E; reg_data = 8'h20; end
            8'd36: begin reg_addr = 8'h69; reg_data = 8'h00; end
            8'd37: begin reg_addr = 8'h6B; reg_data = 8'h0A; end
            8'd38: begin reg_addr = 8'h74; reg_data = 8'h10; end
            8'd39: begin reg_addr = 8'h8D; reg_data = 8'h4F; end
            8'd40: begin reg_addr = 8'h8E; reg_data = 8'h00; end
            8'd41: begin reg_addr = 8'h8F; reg_data = 8'h00; end
            8'd42: begin reg_addr = 8'hB0; reg_data = 8'h84; end
            8'd43: begin reg_addr = 8'hB8; reg_data = 8'h0A; end
            default: begin reg_addr = 8'h00; reg_data = 8'h00; end
        endcase
    end
endmodule
