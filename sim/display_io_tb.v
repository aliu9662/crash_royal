`timescale 1ns/1ps
module display_io_tb;
    reg clk = 0;
    always #5 clk = !clk;
    reg reset = 1, board_reset_n = 0;
    reg [7:0] elixir = 0;
    wire [7:0] an;
    wire [6:0] segment;
    wire dp;
    wire [15:0] led;
    wire [3:0] red, green, blue;
    wire hs, vs, flash_cs;
    wire [7:0] board_an;
    wire [6:0] board_segment;
    wire board_dp;
    integer checks = 0, value, scan, expected_digit;
    reg [7:0] expected_an;
    reg [6:0] expected_segment;
    reg sample_reset, sample_enable, sample_hs, sample_vs;
    reg [11:0] sample_rgb, previous_rgb;
    reg [1:0] previous_sync;
    reg [325:0] previous_view, sample_live;
    reg [19:0] previous_raster;
    wire [325:0] view_bus = {board.view_state, board.view_winner, board.view_alive,
        board.view_progress, board.view_health, board.view_kind, board.view_elixir,
        board.view_lane, board.view_card, board.view_error};

    seven_segment dut(.clk(clk),.reset(reset),.elixir(elixir),.an(an),.segment(segment),.dp(dp));
    royale_top board(.ClkPort(clk),.BtnCpuReset(board_reset_n),.BtnC(1'b0),.Sw(16'b0),
        .Ld(led),.vgaR(red),.vgaG(green),.vgaB(blue),.hSync(hs),.vSync(vs),
        .An0(board_an[0]),.An1(board_an[1]),.An2(board_an[2]),.An3(board_an[3]),
        .An4(board_an[4]),.An5(board_an[5]),.An6(board_an[6]),.An7(board_an[7]),
        .Ca(board_segment[6]),.Cb(board_segment[5]),.Cc(board_segment[4]),
        .Cd(board_segment[3]),.Ce(board_segment[2]),.Cf(board_segment[1]),.Cg(board_segment[0]),
        .Dp(board_dp),.QuadSpiFlashCS(flash_cs));

    function [6:0] decimal_segments(input integer digit);
        begin
            case (digit)
                0: decimal_segments = 7'b0000001;
                1: decimal_segments = 7'b1001111;
                2: decimal_segments = 7'b0010010;
                3: decimal_segments = 7'b0000110;
                4: decimal_segments = 7'b1001100;
                5: decimal_segments = 7'b0100100;
                6: decimal_segments = 7'b0100000;
                7: decimal_segments = 7'b0001111;
                8: decimal_segments = 7'b0000000;
                9: decimal_segments = 7'b0000100;
                default: decimal_segments = 7'b1111111;
            endcase
        end
    endfunction
    task automatic check(input condition, input [1023:0] message);
        begin
            checks = checks+1;
            if (condition !== 1'b1) begin $display("FAIL: %0s",message); $finish; end
        end
    endtask

    // This is the contract behind the scoped four-cycle pixel constraints:
    // source snapshots, raster, and RGB outputs hold between pixel-enable edges.
    // CE and reset are still checked on every 100 MHz edge.
    always @(posedge clk) begin
        sample_reset = board.reset;
        sample_enable = board.pixel_enable;
        sample_rgb = board.rgb;
        sample_hs = board.raw_hSync; sample_vs = board.raw_vSync;
        previous_rgb = {red,green,blue}; previous_sync = {hs,vs};
        previous_view = view_bus;
        previous_raster = {board.hCount,board.vCount};
        sample_live = {board.state,board.winner,board.alive,board.progress,board.health,
            board.kind,board.elixir,board.lane,board.card,board.error_code};
        #1;
        if (sample_reset) begin
            check({red,green,blue} === 12'd0,"reset blanks VGA immediately");
        end else if (sample_enable) begin
            check({red,green,blue} === sample_rgb,"RGB captures the preceding pixel calculation");
            check({hs,vs} === {sample_hs,sample_vs},"sync and color are captured together");
            check(view_bus === sample_live,"pixel-enable captures a complete renderer snapshot");
        end else begin
            check({red,green,blue,hs,vs} === {previous_rgb,previous_sync},"VGA outputs hold between pixels");
            check(view_bus === previous_view,"renderer snapshot holds between pixels");
            check({board.hCount,board.vCount} === previous_raster,"raster holds between pixels");
        end
    end

    initial begin
        repeat (4) @(negedge clk);
        check(an == 8'hff && segment == 7'h7f && dp,"reset disables all SSD digits");
        reset = 0; board_reset_n = 1;
        repeat (8) @(negedge clk);
        while (!board.pixel_enable) @(negedge clk);
        board.dc.hCount = 100; board.dc.vCount = 250;
        board.game.state = 1; board.game.alive = 10'b1000000001;
        board.game.health[7:0] = 28; board.game.health[79:72] = 16;
        for (value = 0; value <= 10; value = value+1) begin
            elixir = {4'd0,4'd0};
            elixir[3:0] = value; elixir[7:4] = 10-value;
            for (scan = 0; scan < 8; scan = scan+1) begin
                @(negedge clk);
                dut.refresh = scan << 17;
                board.game.progress[8:0] = value*20;
                board.game.elixir = elixir;
                expected_an = 8'hff; expected_digit = 15;
                case (scan)
                    0: begin expected_an[0] = 0; expected_digit = value%10; end
                    1: begin expected_an[1] = 0; expected_digit = value/10; end
                    6: begin expected_an[6] = 0; expected_digit = (10-value)%10; end
                    7: begin expected_an[7] = 0; expected_digit = (10-value)/10; end
                    default: begin end
                endcase
                expected_segment = decimal_segments(expected_digit);
                @(posedge clk); #2;
                check(an === expected_an && segment === expected_segment && dp,
                    "SSD scan selects aligned decimal digits for both players, including ten");
            end
        end
        repeat (256) @(negedge clk);
        board_reset_n = 0;
        repeat (5) @(negedge clk);
        check({red,green,blue} == 0 && flash_cs,"board reset and inactive flash-select are safe");
        $display("PASS display_io_tb: %0d checks",checks);
        $finish;
    end
    initial begin #100000; $display("FAIL display_io_tb: watchdog"); $finish; end
endmodule
