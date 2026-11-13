`timescale 1ns/1ps
module game_core #(
    parameter integer ELIXIR_TICKS = 60,
    parameter integer MATCH_TICKS = 10800
) (
    input wire clk, reset, game_tick, start,
    input wire [1:0] deploy,
    input wire [5:0] selected_lane,
    input wire [3:0] selected_card,
    output reg [1:0] state, winner,
    output reg [9:0] alive,
    output reg [89:0] progress,
    output reg [79:0] health,
    output reg [19:0] kind,
    output reg [7:0] elixir,
    output reg [3:0] error_code
);
    `include "royale_defs.vh"
    reg [59:0] move_left, attack_left;
    reg [31:0] match_age, elixir_age;
    reg [1:0] state_n, winner_n;
    reg [9:0] alive_n;
    reg [89:0] progress_n;
    reg [79:0] health_n;
    reg [19:0] kind_n;
    reg [59:0] move_left_n, attack_left_n;
    reg [7:0] elixir_n;
    reg [3:0] error_n;
    reg [31:0] match_age_n, elixir_age_n;
    reg [79:0] damage;
    reg [4:0] in_range;
    reg p1_goal, p2_goal;
    integer lane, slot, player, target, separation;

    // Every attack reads the same pre-tick snapshot. Accumulate damage before
    // applying either player's deaths, so a lethal attack cannot erase a reply.
    always @* begin
        state_n = state; winner_n = winner;
        alive_n = alive; progress_n = progress; health_n = health; kind_n = kind;
        move_left_n = move_left; attack_left_n = attack_left;
        elixir_n = elixir; error_n = error_code;
        match_age_n = match_age; elixir_age_n = elixir_age;
        damage = 0; in_range = 0;
        p1_goal = 0; p2_goal = 0;
        target = 0; separation = 0;
        if (state == IDLE && start) begin
            state_n = PLAY; winner_n = NO_WINNER;
            alive_n = 0; progress_n = 0; health_n = 0; kind_n = 0;
            move_left_n = 0; attack_left_n = 0;
            elixir_n[(0)*4 +: 4] = 5; elixir_n[(1)*4 +: 4] = 5; error_n = 0;
            match_age_n = 0; elixir_age_n = 0;
        end else if (state == PLAY && game_tick) begin
            match_age_n = match_age + 1;
            for (lane = 0; lane < LANES; lane = lane + 1) begin
                separation = FIELD_LENGTH - (progress[(lane)*9 +: 9]) - (progress[(lane+LANES)*9 +: 9]);
                if (separation < 0) separation = -separation;
                in_range[lane] = alive[lane] && alive[lane+LANES] && separation <= MELEE_RANGE;
            end
            for (slot = 0; slot < SLOTS; slot = slot + 1) begin
                target = (slot < LANES) ? slot + LANES : slot - LANES;
                if (alive[slot]) begin
                    if (attack_left[(slot)*6 +: 6] != 0)
                        attack_left_n[(slot)*6 +: 6] = attack_left[(slot)*6 +: 6] - 1'b1;
                    if (in_range[slot % LANES] && kind[(slot)*2 +: 2] != GIANT && attack_left[(slot)*6 +: 6] == 0) begin
                        damage[(target)*8 +: 8] = card_damage(kind[(slot)*2 +: 2]);
                        attack_left_n[(slot)*6 +: 6] = attack_period(kind[(slot)*2 +: 2]) - 1'b1;
                    end
                end
            end
            for (slot = 0; slot < SLOTS; slot = slot + 1) begin
                if (alive[slot]) begin
                    if (damage[(slot)*8 +: 8] >= health[(slot)*8 +: 8]) begin
                        alive_n[slot] = 0;
                        health_n[(slot)*8 +: 8] = 0;
                    end else begin
                        health_n[(slot)*8 +: 8] = health[(slot)*8 +: 8] - damage[(slot)*8 +: 8];
                        // A Giant ignores blocking; ordinary units wait in range.
                        if (kind[(slot)*2 +: 2] != GIANT && in_range[slot % LANES])
                            move_left_n[(slot)*6 +: 6] = 0;
                        else if (move_left[(slot)*6 +: 6] != 0)
                            move_left_n[(slot)*6 +: 6] = move_left[(slot)*6 +: 6] - 1'b1;
                        else begin
                            if (progress[(slot)*9 +: 9] < FIELD_LENGTH)
                                progress_n[(slot)*9 +: 9] = progress[(slot)*9 +: 9] + 1'b1;
                            move_left_n[(slot)*6 +: 6] = move_period(kind[(slot)*2 +: 2]) - 1'b1;
                        end
                    end
                end
            end
            for (lane = 0; lane < LANES; lane = lane + 1) begin
                p1_goal = p1_goal || (alive_n[lane] && progress_n[(lane)*9 +: 9] >= FIELD_LENGTH);
                p2_goal = p2_goal || (alive_n[lane+LANES] && progress_n[(lane+LANES)*9 +: 9] >= FIELD_LENGTH);
            end
            if (p1_goal || p2_goal || match_age >= MATCH_TICKS-1) begin
                state_n = GAME_OVER;
                if (p1_goal && !p2_goal) winner_n = P1_WIN;
                else if (p2_goal && !p1_goal) winner_n = P2_WIN;
                else winner_n = DRAW;
            end else begin
                // Validate against pre-tick occupancy and elixir. A slot freed by
                // combat becomes available for deployment on the following tick.
                for (player = 0; player < 2; player = player + 1) begin
                    if (deploy[player]) begin
                        error_n[(player)*2 +: 2] = OK;
                        if (selected_lane[(player)*3 +: 3] >= LANES)
                            error_n[(player)*2 +: 2] = BAD_LANE;
                        else if (alive[player*LANES + (selected_lane[(player)*3 +: 3])])
                            error_n[(player)*2 +: 2] = OCCUPIED;
                        else if (elixir[(player)*4 +: 4] < card_cost(selected_card[(player)*2 +: 2]))
                            error_n[(player)*2 +: 2] = NO_ELIXIR;
                        else begin
                            target = player*LANES + (selected_lane[(player)*3 +: 3]);
                            alive_n[target] = 1;
                            kind_n[(target)*2 +: 2] = selected_card[(player)*2 +: 2];
                            health_n[(target)*8 +: 8] = card_health(selected_card[(player)*2 +: 2]);
                            progress_n[(target)*9 +: 9] = 0;
                            move_left_n[(target)*6 +: 6] = 0;
                            attack_left_n[(target)*6 +: 6] = 0;
                            elixir_n[(player)*4 +: 4] = elixir[(player)*4 +: 4] - card_cost(selected_card[(player)*2 +: 2]);
                        end
                    end
                end
                if (elixir_age >= ELIXIR_TICKS-1) begin
                    elixir_age_n = 0;
                    for (player = 0; player < 2; player = player + 1)
                        if (elixir_n[(player)*4 +: 4] < 10) elixir_n[(player)*4 +: 4] = elixir_n[(player)*4 +: 4] + 1'b1;
                end else elixir_age_n = elixir_age + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE; winner <= NO_WINNER;
            alive <= 0; progress <= 0; health <= 0; kind <= 0;
            move_left <= 0; attack_left <= 0;
            elixir <= 0; error_code <= 0;
            match_age <= 0; elixir_age <= 0;
        end else begin
            state <= state_n; winner <= winner_n;
            alive <= alive_n; progress <= progress_n; health <= health_n; kind <= kind_n;
            move_left <= move_left_n; attack_left <= attack_left_n;
            elixir <= elixir_n; error_code <= error_n;
            match_age <= match_age_n; elixir_age <= elixir_age_n;
        end
    end
endmodule
