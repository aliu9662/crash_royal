`timescale 1ns/1ps
module command_capture (
    input logic clk, reset, enabled, consume,
    input logic [1:0] toggle,
    input logic [1:0][2:0] lane,
    input logic [1:0][1:0] card,
    output logic [1:0] pending,
    output logic [1:0][2:0] request_lane,
    output logic [1:0][1:0] request_card
);
    logic [1:0] previous_toggle;
    integer player;
    always_ff @(posedge clk) begin
        if (reset) begin
            previous_toggle <= toggle;
            pending <= 0; request_lane <= '0; request_card <= '0;
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
                        request_lane[player] <= lane[player];
                        request_card[player] <= card[player];
                    end
                end
            end
        end
    end
endmodule
