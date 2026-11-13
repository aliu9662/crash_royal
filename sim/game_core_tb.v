`timescale 1ns/1ps
module game_core_tb;
    `include "royale_params.vh"
    reg clk = 0;
    always #5 clk = !clk;
    reg reset = 1, game_tick = 0, start = 0;
    reg [1:0] deploy = 0;
    reg [5:0] selected_lane = 0;
    reg [3:0] selected_card = 0;
    wire [1:0] state, winner;
    wire [9:0] alive;
    wire [89:0] progress;
    wire [79:0] health;
    wire [19:0] kind;
    wire [7:0] elixir;
    wire [3:0] error_code;
    integer checks = 0;
    game_core #(.ELIXIR_TICKS(60),.MATCH_TICKS(1000)) dut(
        .clk(clk),.reset(reset),.game_tick(game_tick),.start(start),.deploy(deploy),
        .selected_lane(selected_lane),.selected_card(selected_card),.state(state),
        .winner(winner),.alive(alive),.progress(progress),.health(health),.kind(kind),
        .elixir(elixir),.error_code(error_code));
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
        selected_lane[(0)*3 +: 3] = 0; selected_lane[(1)*3 +: 3] = 4;
        selected_card[(0)*2 +: 2] = KNIGHT; selected_card[(1)*2 +: 2] = ICE_GOLEM;
        deploy = 3; tick(); deploy = 0;
        check(alive[0] && alive[9],"both players can deploy together in different lanes");
        check(elixir[(0)*4 +: 4] == 2 && elixir[(1)*4 +: 4] == 3,"independent card costs");
        check(progress[(0)*9 +: 9] == 0 && progress[(9)*9 +: 9] == 0,"new units wait until next tick");
        repeat (8) @(negedge clk);
        check(progress[(0)*9 +: 9] == 0,"movement is gated by the game tick");
        tick();
        check(progress[(0)*9 +: 9] == 1 && progress[(9)*9 +: 9] == 1,"battle advances without deployment");
        deploy = 1; tick(); deploy = 0;
        check(error_code[(0)*2 +: 2] == OCCUPIED && elixir[(0)*4 +: 4] == 2,"occupied lane rejects without spending");
        check(progress[(9)*9 +: 9] == 1,"rejected input still observes ordinary movement timers");
        selected_lane[(0)*3 +: 3] = 7; deploy = 1; tick(); deploy = 0;
        check(error_code[(0)*2 +: 2] == BAD_LANE && alive == 10'b1000000001,"invalid lane cannot index a slot");
        selected_lane[(0)*3 +: 3] = 1; selected_card[(0)*2 +: 2] = GIANT; deploy = 1; tick(); deploy = 0;
        check(error_code[(0)*2 +: 2] == NO_ELIXIR && !alive[1] && elixir[(0)*4 +: 4] == 2,"insufficient elixir rejects");

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
        seed(0,KNIGHT,175,16); seed(5,MINI_PEKKA,175,12);
        tick();
        check(progress[(0)*9 +: 9] == 175 && progress[(5)*9 +: 9] == 175,"ordinary enemies stop in melee range");
        check(health[(0)*8 +: 8] == 10 && health[(5)*8 +: 8] == 10,"both attacks use the same snapshot");
        tick();
        check(health[(0)*8 +: 8] == 10 && health[(5)*8 +: 8] == 10,"attack cooldown prevents damage every tick");

        new_match();
        seed(0,GIANT,175,28); seed(5,KNIGHT,175,16);
        tick();
        check(progress[(0)*9 +: 9] == 176 && progress[(5)*9 +: 9] == 175,"Giant walks while defender stops");
        check(health[(0)*8 +: 8] == 26 && health[(5)*8 +: 8] == 16,"Giant takes damage and never attacks");
        dut.progress[(0)*9 +: 9] = 205; dut.move_left[(5)*6 +: 6] = 0;
        tick();
        check(progress[(5)*9 +: 9] == 176,"defender resumes after Giant leaves melee range");

        new_match();
        seed(0,KNIGHT,175,16); seed(6,MINI_PEKKA,175,12);
        tick();
        check(health[(0)*8 +: 8] == 16 && health[(6)*8 +: 8] == 12,"different lanes never interact");
        check(progress[(0)*9 +: 9] == 176 && progress[(6)*9 +: 9] == 176,"different lanes move independently");

        new_match();
        seed(0,KNIGHT,175,2); seed(5,KNIGHT,175,2);
        tick();
        check(!alive[0] && !alive[5],"simultaneous lethal hits kill both units");
        selected_lane[(0)*3 +: 3] = 0; selected_card[(0)*2 +: 2] = ICE_GOLEM; deploy = 1; tick(); deploy = 0;
        check(alive[0] && kind[(0)*2 +: 2] == ICE_GOLEM && health[(0)*8 +: 8] == 12,"dead slot can be reused");

        new_match();
        seed(0,GIANT,359,2); seed(5,KNIGHT,0,16);
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
        seed(7,GIANT,359,28);
        tick();
        check(state == GAME_OVER && winner == P2_WIN,"P2 touchdown has equal rules");

        new_match();
        seed(0,GIANT,359,28); seed(6,GIANT,359,28);
        tick();
        check(state == GAME_OVER && winner == DRAW,"simultaneous touchdowns draw");

        new_match();
        dut.match_age = 999;
        tick();
        check(state == GAME_OVER && winner == DRAW,"timeout ends a stalled match");
        $display("PASS game_core_tb: %0d checks",checks);
        $finish;
    end
    initial begin #1000000; begin $display("gameplay test watchdog"); $finish; end end
endmodule
