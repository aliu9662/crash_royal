`timescale 1ns/1ps
module seven_segment (
    input wire clk, reset,
    input wire [7:0] elixir,
    output reg [7:0] an,
    output reg [6:0] segment,
    output reg dp
);
    reg [19:0] refresh;
    reg [3:0] digit;
    reg [7:0] an_next;
    reg [6:0] segment_next;
    always @(posedge clk)
        if (reset) refresh <= 0;
        else refresh <= refresh+1'b1;
    always @* begin
        an_next = 8'hff; digit = 15;
        case (refresh[19:17])
            0: begin an_next[0] = 0; digit = (elixir[(0)*4 +: 4] == 10) ? 0 : elixir[(0)*4 +: 4]; end
            1: begin an_next[1] = 0; digit = (elixir[(0)*4 +: 4] == 10) ? 1 : 0; end
            6: begin an_next[6] = 0; digit = (elixir[(1)*4 +: 4] == 10) ? 0 : elixir[(1)*4 +: 4]; end
            7: begin an_next[7] = 0; digit = (elixir[(1)*4 +: 4] == 10) ? 1 : 0; end
            default: begin end
        endcase
        // Order is {CA,CB,CC,CD,CE,CF,CG}, active low.
        case (digit)
            0: segment_next = 7'b0000001;
            1: segment_next = 7'b1001111;
            2: segment_next = 7'b0010010;
            3: segment_next = 7'b0000110;
            4: segment_next = 7'b1001100;
            5: segment_next = 7'b0100100;
            6: segment_next = 7'b0100000;
            7: segment_next = 7'b0001111;
            8: segment_next = 7'b0000000;
            9: segment_next = 7'b0000100;
            default: segment_next = 7'b1111111;
        endcase
    end
    // Keep anodes and segments aligned while removing the decoder from the
    // direct register-to-pin path. One 100 MHz cycle is invisible to the scan.
    always @(posedge clk) begin
        if (reset) begin
            an <= 8'hff;
            segment <= 7'b1111111;
            dp <= 1;
        end else begin
            an <= an_next;
            segment <= segment_next;
            dp <= 1;
        end
    end
endmodule
