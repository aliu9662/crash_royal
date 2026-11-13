`timescale 1ns/1ps
module game_core #(
    parameter int ELIXIR_TICKS = 60,
    parameter int MATCH_TICKS = 10800
) (
    input logic clk, reset, game_tick, start,
    input logic [1:0] deploy,
    input logic [1:0][2:0] selected_lane,
    input logic [1:0][1:0] selected_card,
    output logic [1:0] state, winner,
    output logic [9:0] alive,
    output logic [9:0][8:0] progress,
    output logic [9:0][7:0] health,
    output logic [9:0][1:0] kind,
    output logic [1:0][3:0] elixir,
    output logic [1:0][1:0] error_code
);
    import royale_pkg::*;
    logic [9:0][5:0] move_left, attack_left;
    logic [31:0] match_age, elixir_age;
    logic [1:0] state_n, winner_n;
    logic [9:0] alive_n;
    logic [9:0][8:0] progress_n;
    logic [9:0][7:0] health_n;
    logic [9:0][1:0] kind_n;
    logic [9:0][5:0] move_left_n, attack_left_n;
    logic [1:0][3:0] elixir_n;
    logic [1:0][1:0] error_n;
    logic [31:0] match_age_n, elixir_age_n;
    logic [9:0][7:0] damage;
    logic [4:0] in_range;
    logic p1_goal, p2_goal;
    integer lane, slot, player, target, separation;

    // Every attack reads the same pre-tick snapshot. Accumulate damage before
    // applying either player's deaths, so a lethal attack cannot erase a reply.
    always_comb begin
        state_n = state; winner_n = winner;
        alive_n = alive; progress_n = progress; health_n = health; kind_n = kind;
        move_left_n = move_left; attack_left_n = attack_left;
        elixir_n = elixir; error_n = error_code;
        match_age_n = match_age; elixir_age_n = elixir_age;
        damage = '0; in_range = '0;
        p1_goal = 0; p2_goal = 0;
        target = 0; separation = 0;
        if (state == IDLE && start) begin
            state_n = PLAY; winner_n = NO_WINNER;
            alive_n = '0; progress_n = '0; health_n = '0; kind_n = '0;
            move_left_n = '0; attack_left_n = '0;
            elixir_n[0] = 5; elixir_n[1] = 5; error_n = '0;
            match_age_n = 0; elixir_age_n = 0;
        end else if (state == PLAY && game_tick) begin
            match_age_n = match_age + 1;
            for (lane = 0; lane < LANES; lane = lane + 1) begin
                separation = FIELD_LENGTH - int'(progress[lane]) - int'(progress[lane+LANES]);
                if (separation < 0) separation = -separation;
                in_range[lane] = alive[lane] && alive[lane+LANES] && separation <= MELEE_RANGE;
            end
            for (slot = 0; slot < SLOTS; slot = slot + 1) begin
                target = (slot < LANES) ? slot + LANES : slot - LANES;
                if (alive[slot]) begin
                    if (attack_left[slot] != 0)
                        attack_left_n[slot] = attack_left[slot] - 1'b1;
                    if (in_range[slot % LANES] && kind[slot] != GIANT && attack_left[slot] == 0) begin
                        damage[target] = card_damage(kind[slot]);
                        attack_left_n[slot] = attack_period(kind[slot]) - 1'b1;
                    end
                end
            end
            for (slot = 0; slot < SLOTS; slot = slot + 1) begin
                if (alive[slot]) begin
                    if (damage[slot] >= health[slot]) begin
                        alive_n[slot] = 0;
                        health_n[slot] = 0;
                    end else begin
                        health_n[slot] = health[slot] - damage[slot];
                        // A Giant ignores blocking; ordinary units wait in range.
                        if (kind[slot] != GIANT && in_range[slot % LANES])
                            move_left_n[slot] = 0;
                        else if (move_left[slot] != 0)
                            move_left_n[slot] = move_left[slot] - 1'b1;
                        else begin
                            if (progress[slot] < FIELD_LENGTH)
                                progress_n[slot] = progress[slot] + 1'b1;
                            move_left_n[slot] = move_period(kind[slot]) - 1'b1;
                        end
                    end
                end
            end
            for (lane = 0; lane < LANES; lane = lane + 1) begin
                p1_goal = p1_goal || (alive_n[lane] && progress_n[lane] >= FIELD_LENGTH);
                p2_goal = p2_goal || (alive_n[lane+LANES] && progress_n[lane+LANES] >= FIELD_LENGTH);
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
                        error_n[player] = OK;
                        if (selected_lane[player] >= LANES)
                            error_n[player] = BAD_LANE;
                        else if (alive[player*LANES + int'(selected_lane[player])])
                            error_n[player] = OCCUPIED;
                        else if (elixir[player] < card_cost(selected_card[player]))
                            error_n[player] = NO_ELIXIR;
                        else begin
                            target = player*LANES + int'(selected_lane[player]);
                            alive_n[target] = 1;
                            kind_n[target] = selected_card[player];
                            health_n[target] = card_health(selected_card[player]);
                            progress_n[target] = 0;
                            move_left_n[target] = 0;
                            attack_left_n[target] = 0;
                            elixir_n[player] = elixir[player] - card_cost(selected_card[player]);
                        end
                    end
                end
                if (elixir_age >= ELIXIR_TICKS-1) begin
                    elixir_age_n = 0;
                    for (player = 0; player < 2; player = player + 1)
                        if (elixir_n[player] < 10) elixir_n[player] = elixir_n[player] + 1'b1;
                end else elixir_age_n = elixir_age + 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE; winner <= NO_WINNER;
            alive <= '0; progress <= '0; health <= '0; kind <= '0;
            move_left <= '0; attack_left <= '0;
            elixir <= '0; error_code <= '0;
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
