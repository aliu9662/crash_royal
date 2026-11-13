`timescale 1ns/1ps
module video_tb;
    `include "royale_defs.vh"
    reg clk = 0;
    always #5 clk = !clk;
    reg reset = 1;
    wire pixel_enable, game_tick, visible, hsync, vsync;
    wire [9:0] x,y;
    vga_timing dut(.clk(clk),.reset(reset),.pixel_enable(pixel_enable),.game_tick(game_tick),
        .visible(visible),.hsync(hsync),.vsync(vsync),.x(x),.y(y));
    reg draw_visible = 1;
    reg [9:0] draw_x = 0, draw_y = 0;
    reg [1:0] state = PLAY, winner = 0;
    reg [9:0] alive = 0;
    reg [89:0] progress = 0;
    reg [79:0] health = 0;
    reg [19:0] kind = 0;
    reg [7:0] elixir = {4'd7,4'd5};
    reg [5:0] selected_lane = {3'd3,3'd1};
    reg [3:0] selected_card = {MINI_PEKKA,GIANT}, error_code = 0;
    wire [11:0] rgb;
    arena_renderer renderer(.visible(draw_visible),.x(draw_x),.y(draw_y),
        .state(state),.winner(winner),.alive(alive),.progress(progress),.health(health),
        .kind(kind),.elixir(elixir),.selected_lane(selected_lane),.selected_card(selected_card),
        .error_code(error_code),.rgb(rgb));
    integer pixels = 0, active_pixels = 0, low_h = 0, low_v = 0, ticks = 0;
    integer cycles_since_pixel = 0, checks = 0, fd, xx, yy;
    task automatic check(input condition, input [1023:0] message);
        begin
        checks = checks+1;
        if (condition !== 1'b1) begin $display("FAIL: %s",message); $finish; end
        end
    endtask
    initial begin
        repeat (3) @(negedge clk);
        reset = 0;
        // Exactly one 800x525 frame, including blanking and sync intervals.
        while (pixels < 800*525) begin
            @(negedge clk);
            cycles_since_pixel = cycles_since_pixel+1;
            if (pixel_enable) begin
                if (pixels != 0 && cycles_since_pixel != 4) begin $display("pixel enable spacing"); $finish; end
                cycles_since_pixel = 0;
                pixels = pixels+1;
                if (visible) active_pixels = active_pixels+1;
                if (!hsync) low_h = low_h+1;
                if (!vsync) low_v = low_v+1;
                if (game_tick) begin
                    ticks = ticks+1;
                    check(!visible && x == 0 && y == 480,"game tick begins vertical blank");
                end
            end else if (game_tick) begin $display("game tick wider than one system clock"); $finish; end
        end
        check(active_pixels == 640*480,"640x480 visible area");
        check(low_h == 96*525,"96 pixel horizontal sync pulse on every line");
        check(low_v == 2*800,"two line vertical sync pulse");
        check(ticks == 1,"one game update per frame");

        alive[0] = 1; kind[(0)*2 +: 2] = GIANT; progress[(0)*9 +: 9] = 160; health[(0)*8 +: 8] = 24;
        alive[5] = 1; kind[(5)*2 +: 2] = KNIGHT; progress[(5)*9 +: 9] = 178; health[(5)*8 +: 8] = 12;
        alive[2] = 1; kind[(2)*2 +: 2] = ICE_GOLEM; progress[(2)*9 +: 9] = 70; health[(2)*8 +: 8] = 12;
        alive[8] = 1; kind[(8)*2 +: 2] = MINI_PEKKA; progress[(8)*9 +: 9] = 95; health[(8)*8 +: 8] = 12;
        draw_visible = 0; #1;
        check(rgb == 0,"blanking always outputs black");
        draw_visible = 1;
        fd = $fopen("sample_screen.ppm","w");
        if (!fd) begin $display("cannot create sample screen"); $finish; end
        $fwrite(fd,"P3\n640 480\n255\n");
        for (yy = 0; yy < 480; yy = yy+1) begin
            for (xx = 0; xx < 640; xx = xx+1) begin
                draw_x = xx; draw_y = yy; #1;
                if ((^rgb === 1'bx)) begin $display("undefined rendered pixel at %0d,%0d",xx,yy); $finish; end
                $fwrite(fd,"%0d %0d %0d\n",rgb[11:8]*17,rgb[7:4]*17,rgb[3:0]*17);
            end
        end
        $fclose(fd);
        state = IDLE; draw_x = 200; draw_y = 245; #1;
        check(!(^rgb === 1'bx),"title overlay renders");
        state = GAME_OVER; winner = DRAW; #1;
        check(!(^rgb === 1'bx),"draw overlay renders");
        $display("PASS video_tb: %0d checks, full raster and 307200 rendered pixels",checks);
        $finish;
    end
    initial begin #20000000; begin $display("video test watchdog"); $finish; end end
endmodule
