`timescale 1ns/1ps
module game_core_tb;
    import royale_pkg::*;
    logic clk = 0;
    always #5 clk = !clk;
    logic reset = 1, game_tick = 0, start = 0;
    logic [1:0] deploy = 0;
    logic [1:0][2:0] selected_lane = '0;
    logic [1:0][1:0] selected_card = '0;
    wire [1:0] state, winner;
    wire [9:0] alive;
    wire [9:0][8:0] progress;
    wire [9:0][7:0] health;
    wire [9:0][1:0] kind;
    wire [1:0][3:0] elixir;
    wire [1:0][1:0] error_code;
    integer checks = 0;
    game_core #(.ELIXIR_TICKS(60),.MATCH_TICKS(1000)) dut(.*);
    task automatic check(input logic condition, input string message);
        checks = checks+1;
        if (condition !== 1'b1) $fatal(1,"FAIL: %s",message);
    endtask
    task automatic tick;
        @(negedge clk); game_tick = 1;
        @(posedge clk); #1;
        @(negedge clk); game_tick = 0;
    endtask
    task automatic new_match;
        @(negedge clk); reset = 1; deploy = 0; start = 0; game_tick = 0;
        repeat (2) @(negedge clk);
        check(state == IDLE && alive == 0,"reset clears the match");
        reset = 0; start = 1;
        @(negedge clk); start = 0;
        check(state == PLAY && elixir[0] == 5 && elixir[1] == 5,"center starts with equal elixir");
    endtask
    // Direct register fixtures place units near events without hundreds of
    // irrelevant movement ticks. Behavior is then exercised through real ticks.
    task automatic seed(input integer slot, input logic [1:0] card, input integer distance, hp);
        dut.alive[slot] = 1;
        dut.kind[slot] = card;
        dut.progress[slot] = distance;
        dut.health[slot] = hp;
        dut.move_left[slot] = 0;
        dut.attack_left[slot] = 0;
    endtask
    initial begin
        new_match();
        selected_lane[0] = 0; selected_lane[1] = 4;
        selected_card[0] = KNIGHT; selected_card[1] = ICE_GOLEM;
        deploy = 3; tick(); deploy = 0;
        check(alive[0] && alive[9],"both players can deploy together in different lanes");
        check(elixir[0] == 2 && elixir[1] == 3,"independent card costs");
        check(progress[0] == 0 && progress[9] == 0,"new units wait until next tick");
        repeat (8) @(negedge clk);
        check(progress[0] == 0,"movement is gated by the game tick");
        tick();
        check(progress[0] == 1 && progress[9] == 1,"battle advances without deployment");
        deploy = 1; tick(); deploy = 0;
        check(error_code[0] == OCCUPIED && elixir[0] == 2,"occupied lane rejects without spending");
        check(progress[9] == 1,"rejected input still observes ordinary movement timers");
        selected_lane[0] = 7; deploy = 1; tick(); deploy = 0;
        check(error_code[0] == BAD_LANE && alive == 10'b1000000001,"invalid lane cannot index a slot");
        selected_lane[0] = 1; selected_card[0] = GIANT; deploy = 1; tick(); deploy = 0;
        check(error_code[0] == NO_ELIXIR && !alive[1] && elixir[0] == 2,"insufficient elixir rejects");

        new_match();
        repeat (60) tick();
        check(elixir[0] == 6 && elixir[1] == 6,"elixir grows without player input");
        repeat (300) tick();
        check(elixir[0] == 10 && elixir[1] == 10,"elixir caps at ten");
        dut.elixir_age = 59;
        selected_lane[0] = 0; selected_card[0] = GIANT; deploy = 1; tick(); deploy = 0;
        check(elixir[0] == 6,"spending at cap precedes same-tick regeneration");

        new_match();
        seed(0,KNIGHT,175,16); seed(5,MINI_PEKKA,175,12);
        tick();
        check(progress[0] == 175 && progress[5] == 175,"ordinary enemies stop in melee range");
        check(health[0] == 10 && health[5] == 10,"both attacks use the same snapshot");
        tick();
        check(health[0] == 10 && health[5] == 10,"attack cooldown prevents damage every tick");

        new_match();
        seed(0,GIANT,175,28); seed(5,KNIGHT,175,16);
        tick();
        check(progress[0] == 176 && progress[5] == 175,"Giant walks while defender stops");
        check(health[0] == 26 && health[5] == 16,"Giant takes damage and never attacks");
        dut.progress[0] = 205; dut.move_left[5] = 0;
        tick();
        check(progress[5] == 176,"defender resumes after Giant leaves melee range");

        new_match();
        seed(0,KNIGHT,175,16); seed(6,MINI_PEKKA,175,12);
        tick();
        check(health[0] == 16 && health[6] == 12,"different lanes never interact");
        check(progress[0] == 176 && progress[6] == 176,"different lanes move independently");

        new_match();
        seed(0,KNIGHT,175,2); seed(5,KNIGHT,175,2);
        tick();
        check(!alive[0] && !alive[5],"simultaneous lethal hits kill both units");
        selected_lane[0] = 0; selected_card[0] = ICE_GOLEM; deploy = 1; tick(); deploy = 0;
        check(alive[0] && kind[0] == ICE_GOLEM && health[0] == 12,"dead slot can be reused");

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
        check(winner == P1_WIN && progress[0] == 360 && elixir[0] == 5,"game over freezes play");

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
    initial begin #1000000; $fatal(1,"gameplay test watchdog"); end
endmodule
