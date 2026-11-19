`timescale 1ns/1ps
module game_core #(
    parameter integer ELIXIR_TICKS = 60,
    parameter integer MATCH_TICKS = 10800
) (
    input wire clk, reset, game_tick, start,
    input wire [1:0] deploy,
    input wire [5:0] selected_lane,
    input wire [3:0] selected_card,
    input wire [1:0] selected_valid,
    output reg [1:0] state, winner,
    output reg [31:0] alive,
    output reg [287:0] progress,
    output reg [255:0] health,
    output reg [63:0] kind,
    output reg [7:0] elixir,
    output reg [3:0] error_code,
    output wire [15:0] elapsed_ticks
);
    `include "royale_params.vh"
    reg [191:0] move_left, attack_left;
    reg [31:0] match_age, elixir_age;
    reg [1:0] state_n, winner_n;
    reg [31:0] alive_n;
    reg [287:0] progress_n;
    reg [255:0] health_n;
    reg [63:0] kind_n;
    reg [191:0] move_left_n, attack_left_n;
    reg [7:0] elixir_n;
    reg [3:0] error_n;
    reg [31:0] match_age_n, elixir_age_n;
    reg [255:0] damage;
    reg [31:0] in_range;
    reg [159:0] target_slot;
    reg p1_goal, p2_goal;
    integer slot, player, target;
    integer contact_slot, contact_card, contact_lane;
    integer contact_candidate, contact_separation, contact_best, contact_target;

    // Cache each troop's nearest in-range opponent between game ticks. This
    // preserves Andy's registered contact path while supporting four cards in
    // every lane instead of one fixed opponent per lane.
    always @(posedge clk) begin
        if (reset) begin
            in_range <= 0;
            target_slot <= 0;
        end else begin
            for (contact_slot = 0; contact_slot < SLOTS; contact_slot = contact_slot + 1) begin
                contact_lane = (contact_slot % SLOTS_PER_PLAYER) / CARDS;
                contact_best = FIELD_LENGTH + 1;
                contact_target = 0;
                in_range[contact_slot] <= 0;
                for (contact_card = 0; contact_card < CARDS; contact_card = contact_card + 1) begin
                    if (contact_slot < SLOTS_PER_PLAYER)
                        contact_candidate = SLOTS_PER_PLAYER + contact_lane*CARDS + contact_card;
                    else
                        contact_candidate = contact_lane*CARDS + contact_card;
                    contact_separation = FIELD_LENGTH -
                        progress[(contact_slot)*9 +: 9] -
                        progress[(contact_candidate)*9 +: 9];
                    if (contact_separation < 0)
                        contact_separation = -contact_separation;
                    if (alive[contact_slot] && alive[contact_candidate] &&
                        contact_separation <= MELEE_RANGE &&
                        contact_separation < contact_best) begin
                        contact_best = contact_separation;
                        contact_target = contact_candidate;
                        in_range[contact_slot] <= 1;
                    end
                end
                target_slot[(contact_slot)*5 +: 5] <= contact_target;
            end
        end
    end

    // Every attack reads the same pre-tick snapshot. Accumulate damage before
    // applying either player's deaths, so a lethal attack cannot erase a reply.
    always @* begin
        state_n = state; winner_n = winner;
        alive_n = alive; progress_n = progress; health_n = health; kind_n = kind;
        move_left_n = move_left; attack_left_n = attack_left;
        elixir_n = elixir; error_n = error_code;
        match_age_n = match_age; elixir_age_n = elixir_age;
        damage = 0;
        p1_goal = 0; p2_goal = 0;
        target = 0;
        if (start) begin
            state_n = PLAY; winner_n = NO_WINNER;
            alive_n = 0; progress_n = 0; health_n = 0; kind_n = 0;
            move_left_n = 0; attack_left_n = 0;
            elixir_n[(0)*4 +: 4] = 5; elixir_n[(1)*4 +: 4] = 5; error_n = 0;
            match_age_n = 0; elixir_age_n = 0;
        end else if (state == PLAY && game_tick) begin
            match_age_n = match_age + 1;
            for (slot = 0; slot < SLOTS; slot = slot + 1) begin
                if (alive[slot]) begin
                    target = target_slot[(slot)*5 +: 5];
                    if (attack_left[(slot)*6 +: 6] != 0)
                        attack_left_n[(slot)*6 +: 6] = attack_left[(slot)*6 +: 6] - 1'b1;
                    if (in_range[slot] && kind[(slot)*2 +: 2] != GIANT && attack_left[(slot)*6 +: 6] == 0) begin
                        damage[(target)*8 +: 8] = damage[(target)*8 +: 8] + card_damage(kind[(slot)*2 +: 2]);
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
                        if (kind[(slot)*2 +: 2] != GIANT && in_range[slot])
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
            for (slot = 0; slot < SLOTS; slot = slot + 1) begin
                if (slot < SLOTS_PER_PLAYER)
                    p1_goal = p1_goal || (alive_n[slot] && progress_n[(slot)*9 +: 9] >= FIELD_LENGTH);
                else
                    p2_goal = p2_goal || (alive_n[slot] && progress_n[(slot)*9 +: 9] >= FIELD_LENGTH);
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
                        if (!selected_valid[player] || selected_lane[(player)*3 +: 3] >= LANES)
                            error_n[(player)*2 +: 2] = BAD_LANE;
                        else if (elixir[(player)*4 +: 4] < card_cost(selected_card[(player)*2 +: 2]))
                            error_n[(player)*2 +: 2] = NO_ELIXIR;
                        else if (alive[player*SLOTS_PER_PLAYER +
                                             (selected_lane[(player)*3 +: 3])*CARDS +
                                             selected_card[(player)*2 +: 2]])
                            error_n[(player)*2 +: 2] = OCCUPIED;
                        else begin
                            target = player*SLOTS_PER_PLAYER +
                                     (selected_lane[(player)*3 +: 3])*CARDS +
                                     selected_card[(player)*2 +: 2];
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

    assign elapsed_ticks = match_age[15:0];

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
