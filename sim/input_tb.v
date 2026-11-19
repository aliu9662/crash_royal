`timescale 1ns/1ps
module input_tb;
    `include "royale_params.vh"
    reg clk = 0;
    always #5 clk = !clk;
    reg reset = 1, clear = 0, enabled = 0, consume = 0;
    reg [1:0] deploy_button = 0;
    reg [1:0] selection_valid = 3;
    wire [1:0] pending;
    reg [5:0] lane = 0;
    wire [5:0] request_lane;
    reg [3:0] card = 0;
    wire [3:0] request_card;
    wire [1:0] request_valid;
    reg [5:0] raw = 0;
    wire [5:0] filtered;
    integer checks = 0;
    command_capture dut(.clk(clk),.reset(reset),.clear(clear),.enabled(enabled),.consume(consume),
        .deploy_button(deploy_button),.lane(lane),.card(card),.selection_valid(selection_valid),
        .pending(pending),.request_lane(request_lane),.request_card(request_card),.request_valid(request_valid));
    input_filter #(.WIDTH(6),.STABLE_CYCLES(4)) filter_dut(.clk(clk),.reset(reset),.raw(raw),.value(filtered));
    task automatic check(input condition, input [1023:0] message);
        begin
        checks = checks+1;
        if (condition !== 1'b1) begin $display("FAIL: %s",message); $finish; end
        end
    endtask
    task automatic cycles(input integer count);
        begin
        repeat (count) @(negedge clk);
        end
    endtask
    initial begin
        cycles(3); reset = 0;
        deploy_button = 3; cycles(2);
        enabled = 1; cycles(2);
        check(pending == 0,"starting with held buttons does not deploy");
        deploy_button = 0; cycles(1);
        lane[(0)*3 +: 3] = 3; card[(0)*2 +: 2] = 3; deploy_button[0] = 1; cycles(1);
        check(pending == 1 && request_lane[(0)*3 +: 3] == 3 && request_card[(0)*2 +: 2] == 3 && request_valid[0],"P1 button captures a valid request");
        lane[(0)*3 +: 3] = 1; card[(0)*2 +: 2] = 0; cycles(2);
        check(request_lane[(0)*3 +: 3] == 3 && request_card[(0)*2 +: 2] == 3,"request retains selection snapshot");
        consume = 1; cycles(1); consume = 0; cycles(2);
        check(pending == 0,"held button cannot repeat deployment");
        lane[(0)*3 +: 3] = 2; card[(0)*2 +: 2] = ICE_GOLEM; deploy_button[0] = 0; cycles(1);
        deploy_button[0] = 1; cycles(1);
        check(pending == 1 && request_lane[(0)*3 +: 3] == 2 && request_card[(0)*2 +: 2] == ICE_GOLEM,"next press captures a request");
        deploy_button = 0; cycles(1); deploy_button = 3; cycles(1);
        check(pending == 3,"both independent controllers capture together");
        consume = 1; deploy_button[0] = 0; cycles(1); deploy_button[0] = 1; lane[(0)*3 +: 3] = 2; cycles(1); consume = 0;
        check(pending == 1 && request_lane[(0)*3 +: 3] == 2,"request at consumption edge survives for next tick");
        enabled = 0; cycles(1);
        check(pending == 0,"idle/game over discards queued deployment");
        raw = 6'b100101; cycles(2); raw = 0; cycles(8);
        check(filtered == 0,"short switch bounce is ignored");
        raw = 6'b100101; cycles(3); raw = 6'b110101; cycles(3);
        check(filtered == 0,"changing selector restarts stability window");
        cycles(8);
        check(filtered == 6'b110101,"stable multi-bit switch vector is accepted");
        $display("PASS input_tb: %0d checks",checks);
        $finish;
    end
    initial begin #100000; begin $display("input test watchdog"); $finish; end end
endmodule
