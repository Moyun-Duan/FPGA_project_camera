`timescale 1ns/1ps

module reset_sync (
    input  wire clk,
    input  wire reset_n_async,
    output wire reset
);
    reg [2:0] sync;

    always @(posedge clk or negedge reset_n_async) begin
        if (!reset_n_async)
            sync <= 3'b111;
        else
            sync <= {sync[1:0], 1'b0};
    end

    assign reset = sync[2];
endmodule
