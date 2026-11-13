`timescale 1ns/1ps
module command_capture (
    input wire clk, reset, enabled, consume,
    input wire [1:0] toggle,
    input wire [5:0] lane,
    input wire [3:0] card,
    output reg [1:0] pending,
    output reg [5:0] request_lane,
    output reg [3:0] request_card
);
    reg [1:0] previous_toggle;
    integer player;
    always @(posedge clk) begin
        if (reset) begin
            previous_toggle <= toggle;
            pending <= 0; request_lane <= 0; request_card <= 0;
        end else begin
            previous_toggle <= toggle;
            if (!enabled) pending <= 0;
            else begin
                if (consume) pending <= 0;
                for (player = 0; player < 2; player = player + 1) begin
                    // A transition at the consumption edge is a new request for
                    // the next tick, after the old snapshot has been consumed.
                    if (toggle[player] != previous_toggle[player]) begin
                        pending[player] <= 1;
                        request_lane[(player)*3 +: 3] <= lane[(player)*3 +: 3];
                        request_card[(player)*2 +: 2] <= card[(player)*2 +: 2];
                    end
                end
            end
        end
    end
endmodule
