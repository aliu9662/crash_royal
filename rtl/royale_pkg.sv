`timescale 1ns/1ps
package royale_pkg;
    localparam int LANES = 5;
    localparam int SLOTS = 10;
    localparam int FIELD_LENGTH = 360;
    localparam int MELEE_RANGE = 18;
    localparam logic [1:0] GIANT = 0, ICE_GOLEM = 1, KNIGHT = 2, MINI_PEKKA = 3;
    localparam logic [1:0] IDLE = 0, PLAY = 1, GAME_OVER = 2;
    localparam logic [1:0] NO_WINNER = 0, P1_WIN = 1, P2_WIN = 2, DRAW = 3;
    localparam logic [1:0] OK = 0, BAD_LANE = 1, OCCUPIED = 2, NO_ELIXIR = 3;

    function automatic logic [3:0] card_cost(input logic [1:0] card);
        case (card)
            GIANT: card_cost = 5;
            ICE_GOLEM: card_cost = 2;
            KNIGHT: card_cost = 3;
            default: card_cost = 4;
        endcase
    endfunction
    function automatic logic [7:0] card_health(input logic [1:0] card);
        case (card)
            GIANT: card_health = 28;
            ICE_GOLEM: card_health = 12;
            KNIGHT: card_health = 16;
            default: card_health = 12;
        endcase
    endfunction
    function automatic logic [7:0] card_damage(input logic [1:0] card);
        case (card)
            GIANT: card_damage = 0;
            ICE_GOLEM: card_damage = 1;
            KNIGHT: card_damage = 2;
            default: card_damage = 6;
        endcase
    endfunction
    function automatic logic [5:0] move_period(input logic [1:0] card);
        case (card)
            GIANT: move_period = 4;
            ICE_GOLEM: move_period = 3;
            default: move_period = 2;
        endcase
    endfunction
    function automatic logic [5:0] attack_period(input logic [1:0] card);
        case (card)
            ICE_GOLEM: attack_period = 45;
            KNIGHT: attack_period = 30;
            default: attack_period = 24;
        endcase
    endfunction
    function automatic logic [7:0] card_letter(input logic [1:0] card);
        case (card)
            GIANT: card_letter = "G";
            ICE_GOLEM: card_letter = "I";
            KNIGHT: card_letter = "K";
            default: card_letter = "M";
        endcase
    endfunction
endpackage
