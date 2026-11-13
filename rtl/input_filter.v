`timescale 1ns/1ps
module input_filter #(
    parameter integer WIDTH = 1,
    parameter integer STABLE_CYCLES = 1000000
) (
    input wire clk, reset,
    input wire [WIDTH-1:0] raw,
    output reg [WIDTH-1:0] value
);
    function integer count_width(input integer count);
        integer remaining;
        begin
            remaining = count-1;
            count_width = 0;
            while (remaining > 0) begin
                count_width = count_width+1;
                remaining = remaining >> 1;
            end
        end
    endfunction
    localparam integer COUNT_BITS = (STABLE_CYCLES < 2) ? 1 : count_width(STABLE_CYCLES);
    (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] meta, synced;
    reg [WIDTH-1:0] candidate;
    reg [COUNT_BITS-1:0] stable_count;
    // Filtering the complete switch vector prevents capturing a mixture of
    // old/new selector bits when a user changes a multi-bit selection.
    always @(posedge clk) begin
        if (reset) begin
            meta <= 0; synced <= 0; candidate <= 0; value <= 0; stable_count <= 0;
        end else begin
            meta <= raw; synced <= meta;
            if (synced != candidate) begin
                candidate <= synced;
                stable_count <= 0;
            end else if (synced == value) stable_count <= 0;
            else if (stable_count == STABLE_CYCLES-1) begin
                value <= synced;
                stable_count <= 0;
            end else stable_count <= stable_count + 1'b1;
        end
    end
endmodule
