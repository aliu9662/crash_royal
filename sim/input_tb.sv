`timescale 1ns/1ps
module input_tb;
    logic clk = 0;
    always #5 clk = !clk;
    logic reset = 1, enabled = 0, consume = 0;
    logic [1:0] toggle = 0, pending;
    logic [1:0][2:0] lane = '0, request_lane;
    logic [1:0][1:0] card = '0, request_card;
    logic [5:0] raw = 0, filtered;
    integer checks = 0;
    command_capture dut(.*);
    input_filter #(.WIDTH(6),.STABLE_CYCLES(4)) filter_dut(.clk(clk),.reset(reset),.raw(raw),.value(filtered));
    task automatic check(input logic condition, input string message);
        checks = checks+1;
        if (condition !== 1'b1) $fatal(1,"FAIL: %s",message);
    endtask
    task automatic cycles(input integer count);
        repeat (count) @(negedge clk);
    endtask
    initial begin
        cycles(3); reset = 0;
        toggle = 3; cycles(2);
        enabled = 1; cycles(2);
        check(pending == 0,"starting with raised switches does not deploy");
        lane[0] = 4; card[0] = 3; toggle[0] = 0; cycles(1);
        check(pending == 1 && request_lane[0] == 4 && request_card[0] == 3,"falling toggle captures a request");
        lane[0] = 1; card[0] = 0; cycles(2);
        check(request_lane[0] == 4 && request_card[0] == 3,"request retains selection snapshot");
        consume = 1; cycles(1); consume = 0; cycles(2);
        check(pending == 0,"held toggle cannot repeat deployment");
        toggle = ~toggle; cycles(1);
        check(pending == 3,"both independent controllers capture together");
        consume = 1; toggle[0] = ~toggle[0]; lane[0] = 2; cycles(1); consume = 0;
        check(pending == 1 && request_lane[0] == 2,"request at consumption edge survives for next tick");
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
    initial begin #100000; $fatal(1,"input test watchdog"); end
endmodule
