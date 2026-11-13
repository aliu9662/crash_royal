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
    always @(posedge clk)
        if (reset) refresh <= 0;
        else refresh <= refresh+1'b1;
    always @* begin
        an = 8'hff; digit = 15; dp = 1;
        case (refresh[19:17])
            0: begin an[0] = 0; digit = (elixir[(0)*4 +: 4] == 10) ? 0 : elixir[(0)*4 +: 4]; end
            1: begin an[1] = 0; digit = (elixir[(0)*4 +: 4] == 10) ? 1 : 0; end
            6: begin an[6] = 0; digit = (elixir[(1)*4 +: 4] == 10) ? 0 : elixir[(1)*4 +: 4]; end
            7: begin an[7] = 0; digit = (elixir[(1)*4 +: 4] == 10) ? 1 : 0; end
            default: begin end
        endcase
        // Order is {CA,CB,CC,CD,CE,CF,CG}, active low.
        case (digit)
            0: segment = 7'b0000001;
            1: segment = 7'b1001111;
            2: segment = 7'b0010010;
            3: segment = 7'b0000110;
            4: segment = 7'b1001100;
            5: segment = 7'b0100100;
            6: segment = 7'b0100000;
            7: segment = 7'b0001111;
            8: segment = 7'b0000000;
            9: segment = 7'b0000100;
            default: segment = 7'b1111111;
        endcase
    end
endmodule
