`timescale 1ns/1ps
module command_capture (
    input wire clk, reset, clear, enabled, consume,
    input wire [1:0] deploy_button,
    input wire [5:0] lane,
    input wire [3:0] card,
    input wire [1:0] selection_valid,
    output reg [1:0] pending,
    output reg [5:0] request_lane,
    output reg [3:0] request_card,
    output reg [1:0] request_valid
);
    reg [1:0] previous_button;
    integer player;
    always @(posedge clk) begin
        if (reset || clear) begin
            previous_button <= deploy_button;
            pending <= 0; request_lane <= 0; request_card <= 0; request_valid <= 0;
        end else begin
            previous_button <= deploy_button;
            if (!enabled) pending <= 0;
            else begin
                if (consume) pending <= 0;
                for (player = 0; player < 2; player = player + 1) begin
                    // A press at the consumption edge is a new request for
                    // the next tick, after the old snapshot has been consumed.
                    if (deploy_button[player] && !previous_button[player]) begin
                        pending[player] <= 1;
                        request_lane[(player)*3 +: 3] <= lane[(player)*3 +: 3];
                        request_card[(player)*2 +: 2] <= card[(player)*2 +: 2];
                        request_valid[player] <= selection_valid[player];
                    end
                end
            end
        end
    end
endmodule
