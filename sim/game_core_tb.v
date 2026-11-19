`timescale 1ns/1ps
module game_core_tb;
    `include "royale_params.vh"
    reg clk = 0;
    always #5 clk = !clk;
    reg reset = 1, game_tick = 0, start = 0;
    reg [1:0] deploy = 0;
    reg [1:0] selected_valid = 3;
    reg [5:0] selected_lane = 0;
    reg [3:0] selected_card = 0;
    wire [1:0] state, winner;
    wire [31:0] alive;
    wire [287:0] progress;
    wire [255:0] health;
    wire [63:0] kind;
    wire [7:0] elixir;
    wire [3:0] error_code;
    wire [15:0] elapsed_ticks;
    integer checks = 0;
    integer card_case;
    game_core #(.ELIXIR_TICKS(60),.MATCH_TICKS(1000)) dut(
        .clk(clk),.reset(reset),.game_tick(game_tick),.start(start),.deploy(deploy),
        .selected_lane(selected_lane),.selected_card(selected_card),.selected_valid(selected_valid),.state(state),
        .winner(winner),.alive(alive),.progress(progress),.health(health),.kind(kind),
        .elixir(elixir),.error_code(error_code),.elapsed_ticks(elapsed_ticks));
    task automatic check(input condition, input [1023:0] message);
        begin
        checks = checks+1;
        if (condition !== 1'b1) begin $display("FAIL: %s",message); $finish; end
        end
    endtask
    task automatic tick;
        begin
        @(negedge clk); game_tick = 1;
        @(posedge clk); #1;
        @(negedge clk); game_tick = 0;
        end
    endtask
    task automatic new_match;
        begin
        @(negedge clk); reset = 1; deploy = 0; start = 0; game_tick = 0;
        repeat (2) @(negedge clk);
        check(state == IDLE && alive == 0,"reset clears the match");
        reset = 0; start = 1;
        @(negedge clk); start = 0;
        check(state == PLAY && elixir[(0)*4 +: 4] == 5 && elixir[(1)*4 +: 4] == 5,"center starts with equal elixir");
        end
    endtask
    // Direct register fixtures place units near events without hundreds of
    // irrelevant movement ticks. Behavior is then exercised through real ticks.
    task automatic seed(input integer slot, input [1:0] card, input integer distance, hp);
        begin
        dut.alive[slot] = 1;
        dut.kind[(slot)*2 +: 2] = card;
        dut.progress[(slot)*9 +: 9] = distance;
        dut.health[(slot)*8 +: 8] = hp;
        dut.move_left[(slot)*6 +: 6] = 0;
        dut.attack_left[(slot)*6 +: 6] = 0;
        end
    endtask
    initial begin
        new_match();
        selected_lane[(0)*3 +: 3] = 0; selected_lane[(1)*3 +: 3] = 3;
        selected_card[(0)*2 +: 2] = KNIGHT; selected_card[(1)*2 +: 2] = ICE_GOLEM;
        deploy = 3; tick(); deploy = 0;
        check(alive[2] && alive[29],"both players can deploy together in different lanes");
        check(elixir[(0)*4 +: 4] == 2 && elixir[(1)*4 +: 4] == 3,"independent card costs");
        check(progress[(2)*9 +: 9] == 0 && progress[(29)*9 +: 9] == 0,"new units wait until next tick");
        repeat (8) @(negedge clk);
        check(progress[(2)*9 +: 9] == 0,"movement is gated by the game tick");
        tick();
        check(progress[(2)*9 +: 9] == 1 && progress[(29)*9 +: 9] == 1,"battle advances without deployment");
        repeat (3) tick();
        check(progress[(2)*9 +: 9] == 1,"slower movement waits four ticks between Knight steps");
        tick();
        check(progress[(2)*9 +: 9] == 2,"movement resumes after the slower interval");
        selected_card[(0)*2 +: 2] = ICE_GOLEM; deploy = 1; tick(); deploy = 0;
        check(alive[1] && alive[2] && elixir[(0)*4 +: 4] == 0,"different cards can share one lane");
        dut.elixir[(0)*4 +: 4] = 10;
        deploy = 1; tick(); deploy = 0;
        check(error_code[(0)*2 +: 2] == OCCUPIED && elixir[(0)*4 +: 4] == 10,"duplicate card in one lane rejects without spending");
        selected_lane[(0)*3 +: 3] = 7; deploy = 1; tick(); deploy = 0;
        check(error_code[(0)*2 +: 2] == BAD_LANE && alive[1] && alive[2] && alive[29],"invalid lane cannot index a slot");
        selected_lane[(0)*3 +: 3] = 1; selected_valid[0] = 0; deploy = 1; tick(); deploy = 0; selected_valid[0] = 1;
        check(error_code[(0)*2 +: 2] == BAD_LANE && !alive[5],"invalid one-hot selection is rejected");

        for (card_case = 0; card_case < CARDS; card_case = card_case + 1) begin
            new_match();
            selected_lane[(0)*3 +: 3] = 1;
            selected_card[(0)*2 +: 2] = card_case;
            dut.elixir[(0)*4 +: 4] = card_cost(card_case) - 1;
            deploy = 1; tick(); deploy = 0;
            check(error_code[(0)*2 +: 2] == NO_ELIXIR &&
                  !alive[4 + card_case] &&
                  elixir[(0)*4 +: 4] == card_cost(card_case) - 1,
                  "every card rejects without its full elixir cost");
        end

        new_match();
        repeat (59) tick();
        check(elixir[(0)*4 +: 4] == 5 && elixir[(1)*4 +: 4] == 5,"elixir waits until the sixtieth tick");
        tick();
        check(elixir[(0)*4 +: 4] == 6 && elixir[(1)*4 +: 4] == 6,"elixir grows without player input");
        repeat (300) tick();
        check(elixir[(0)*4 +: 4] == 10 && elixir[(1)*4 +: 4] == 10,"elixir caps at ten");
        dut.elixir_age = 59;
        selected_lane[(0)*3 +: 3] = 0; selected_card[(0)*2 +: 2] = GIANT; deploy = 1; tick(); deploy = 0;
        check(elixir[(0)*4 +: 4] == 6,"spending at cap precedes same-tick regeneration");

        new_match();
        seed(2,KNIGHT,175,16); seed(19,MINI_PEKKA,175,12);
        tick();
        check(progress[(2)*9 +: 9] == 175 && progress[(19)*9 +: 9] == 175,"ordinary enemies stop in melee range");
        check(health[(2)*8 +: 8] == 10 && health[(19)*8 +: 8] == 10,"both attacks use the same snapshot");
        tick();
        check(health[(2)*8 +: 8] == 10 && health[(19)*8 +: 8] == 10,"attack cooldown prevents damage every tick");

        new_match();
        seed(1,ICE_GOLEM,175,12); seed(2,KNIGHT,175,16); seed(16,GIANT,175,28);
        tick();
        check(health[(16)*8 +: 8] == 25,"multiple friendly card types combine damage in one lane");
        check(progress[(1)*9 +: 9] == 175 && progress[(2)*9 +: 9] == 175,
              "multiple friendly attackers independently stop in melee range");

        new_match();
        seed(0,GIANT,175,28); seed(18,KNIGHT,175,16);
        tick();
        check(progress[(0)*9 +: 9] == 176 && progress[(18)*9 +: 9] == 175,"Giant walks while defender stops");
        check(health[(0)*8 +: 8] == 26 && health[(18)*8 +: 8] == 16,"Giant takes damage and never attacks");
        dut.progress[(0)*9 +: 9] = 205; dut.move_left[(18)*6 +: 6] = 0;
        tick();
        check(progress[(18)*9 +: 9] == 176,"defender resumes after Giant leaves melee range");

        new_match();
        seed(2,KNIGHT,175,16); seed(23,MINI_PEKKA,175,12);
        tick();
        check(health[(2)*8 +: 8] == 16 && health[(23)*8 +: 8] == 12,"different lanes never interact");
        check(progress[(2)*9 +: 9] == 176 && progress[(23)*9 +: 9] == 176,"different lanes move independently");

        new_match();
        seed(2,KNIGHT,175,2); seed(18,KNIGHT,175,2);
        tick();
        check(!alive[2] && !alive[18],"simultaneous lethal hits kill both units");
        selected_lane[(0)*3 +: 3] = 0; selected_card[(0)*2 +: 2] = ICE_GOLEM; deploy = 1; tick(); deploy = 0;
        check(alive[1] && kind[(1)*2 +: 2] == ICE_GOLEM && health[(1)*8 +: 8] == 12,"card slot can be reused after combat");

        new_match();
        seed(0,GIANT,359,2); seed(18,KNIGHT,0,16);
        tick();
        check(!alive[0] && state == PLAY,"Giant killed on the scoring tick cannot win");

        new_match();
        seed(0,GIANT,359,28);
        tick();
        check(state == GAME_OVER && winner == P1_WIN,"P1 touchdown ends the match");
        deploy = 3;
        repeat (3) tick();
        check(winner == P1_WIN && progress[(0)*9 +: 9] == 360 && elixir[(0)*4 +: 4] == 5,"game over freezes play");

        new_match();
        seed(28,GIANT,359,28);
        tick();
        check(state == GAME_OVER && winner == P2_WIN,"P2 touchdown has equal rules");

        new_match();
        seed(0,GIANT,359,28); seed(20,GIANT,359,28);
        tick();
        check(state == GAME_OVER && winner == DRAW,"simultaneous touchdowns draw");

        new_match();
        dut.match_age = 999;
        tick();
        check(state == GAME_OVER && winner == DRAW,"timeout ends a stalled match");
        start = 1; @(negedge clk); start = 0;
        check(state == PLAY && alive == 0 && elapsed_ticks == 0,"up/start pulse restarts immediately from game over");
        $display("PASS game_core_tb: %0d checks",checks);
        $finish;
    end
    initial begin #1000000; begin $display("gameplay test watchdog"); $finish; end end
endmodule
