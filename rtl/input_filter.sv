`timescale 1ns/1ps
module input_filter #(
    parameter int WIDTH = 1,
    parameter int STABLE_CYCLES = 1000000
) (
    input logic clk, reset,
    input logic [WIDTH-1:0] raw,
    output logic [WIDTH-1:0] value
);
    localparam int COUNT_BITS = (STABLE_CYCLES < 2) ? 1 : $clog2(STABLE_CYCLES);
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] meta, synced;
    logic [WIDTH-1:0] candidate;
    logic [COUNT_BITS-1:0] stable_count;
    // Filtering the complete switch vector prevents capturing a mixture of
    // old/new selector bits when a user changes a multi-bit selection.
    always_ff @(posedge clk) begin
        if (reset) begin
            meta <= '0; synced <= '0; candidate <= '0; value <= '0; stable_count <= '0;
        end else begin
            meta <= raw; synced <= meta;
            if (synced != candidate) begin
                candidate <= synced;
                stable_count <= '0;
            end else if (synced == value) stable_count <= '0;
            else if (stable_count == STABLE_CYCLES-1) begin
                value <= synced;
                stable_count <= '0;
            end else stable_count <= stable_count + 1'b1;
        end
    end
endmodule
