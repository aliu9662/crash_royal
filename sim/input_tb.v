`timescale 1ns/1ps
module input_tb;
    reg clk = 0;
    always #5 clk = !clk;
    reg reset = 1, enabled = 0, consume = 0;
    reg [1:0] toggle = 0;
    wire [1:0] pending;
    reg [5:0] lane = 0;
    wire [5:0] request_lane;
    reg [3:0] card = 0;
    wire [3:0] request_card;
    reg [5:0] raw = 0;
    wire [5:0] filtered;
    integer checks = 0;
    command_capture dut(.clk(clk),.reset(reset),.enabled(enabled),.consume(consume),
        .toggle(toggle),.lane(lane),.card(card),.pending(pending),
        .request_lane(request_lane),.request_card(request_card));
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
        toggle = 3; cycles(2);
        enabled = 1; cycles(2);
        check(pending == 0,"starting with raised switches does not deploy");
        lane[(0)*3 +: 3] = 4; card[(0)*2 +: 2] = 3; toggle[0] = 0; cycles(1);
        check(pending == 1 && request_lane[(0)*3 +: 3] == 4 && request_card[(0)*2 +: 2] == 3,"falling toggle captures a request");
        lane[(0)*3 +: 3] = 1; card[(0)*2 +: 2] = 0; cycles(2);
        check(request_lane[(0)*3 +: 3] == 4 && request_card[(0)*2 +: 2] == 3,"request retains selection snapshot");
        consume = 1; cycles(1); consume = 0; cycles(2);
        check(pending == 0,"held toggle cannot repeat deployment");
        toggle = ~toggle; cycles(1);
        check(pending == 3,"both independent controllers capture together");
        consume = 1; toggle[0] = ~toggle[0]; lane[(0)*3 +: 3] = 2; cycles(1); consume = 0;
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
