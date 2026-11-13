`timescale 1ns/1ps
module royale_top (
    input logic CLK100MHZ, CPU_RESETN, BTNC,
    input logic [15:0] SW,
    output logic [15:0] LED,
    output logic [3:0] VGA_R, VGA_G, VGA_B,
    output logic VGA_HS, VGA_VS,
    output logic [7:0] AN,
    output logic CA, CB, CC, CD, CE, CF, CG, DP
);
    import royale_pkg::*;
    // Power-on reset, asynchronous assertion, synchronized release.
    (* ASYNC_REG = "TRUE" *) logic [2:0] reset_pipe = 3'b111;
    logic reset;
    always_ff @(posedge CLK100MHZ or negedge CPU_RESETN)
        if (!CPU_RESETN) reset_pipe <= 3'b111;
        else reset_pipe <= {reset_pipe[1:0],1'b0};
    assign reset = reset_pipe[2];

    logic [5:0] p1_switches, p2_switches;
    logic start_button, previous_start;
    logic [1:0] state, winner, request;
    logic [1:0][2:0] lane, request_lane;
    logic [1:0][1:0] card, request_card, error_code;
    logic [1:0][3:0] elixir;
    logic [9:0] alive;
    logic [9:0][8:0] progress;
    logic [9:0][7:0] health;
    logic [9:0][1:0] kind;
    logic pixel_enable, game_tick, visible, raw_hsync, raw_vsync;
    logic [9:0] x, y;
    logic [11:0] rgb;
    input_filter #(.WIDTH(6)) p1_input(.clk(CLK100MHZ),.reset(reset),.raw(SW[5:0]),.value(p1_switches));
    input_filter #(.WIDTH(6)) p2_input(.clk(CLK100MHZ),.reset(reset),.raw(SW[13:8]),.value(p2_switches));
    input_filter start_input(.clk(CLK100MHZ),.reset(reset),.raw(BTNC),.value(start_button));
    always_ff @(posedge CLK100MHZ)
        if (reset) previous_start <= 0;
        else previous_start <= start_button;
    assign lane[0] = p1_switches[2:0];
    assign lane[1] = p2_switches[2:0];
    assign card[0] = p1_switches[4:3];
    assign card[1] = p2_switches[4:3];
    command_capture commands(
        .clk(CLK100MHZ),.reset(reset),.enabled(state == PLAY),.consume(game_tick),
        .toggle({p2_switches[5],p1_switches[5]}),.lane(lane),.card(card),
        .pending(request),.request_lane(request_lane),.request_card(request_card));
    game_core game(
        .clk(CLK100MHZ),.reset(reset),.game_tick(game_tick),.start(start_button && !previous_start),
        .deploy(request),.selected_lane(request_lane),.selected_card(request_card),
        .state(state),.winner(winner),.alive(alive),.progress(progress),.health(health),
        .kind(kind),.elixir(elixir),.error_code(error_code));
    vga_timing raster(.clk(CLK100MHZ),.reset(reset),.pixel_enable(pixel_enable),.game_tick(game_tick),
        .visible(visible),.hsync(raw_hsync),.vsync(raw_vsync),.x(x),.y(y));
    arena_renderer renderer(.visible(visible),.x(x),.y(y),.state(state),.winner(winner),
        .alive(alive),.progress(progress),.health(health),.kind(kind),.elixir(elixir),
        .selected_lane(lane),.selected_card(card),.error_code(error_code),.rgb(rgb));
    // Register color and sync together so the displayed pixel stays aligned.
    always_ff @(posedge CLK100MHZ) begin
        if (reset) begin
            VGA_R <= 0; VGA_G <= 0; VGA_B <= 0; VGA_HS <= 1; VGA_VS <= 1;
        end else if (pixel_enable) begin
            VGA_R <= rgb[11:8]; VGA_G <= rgb[7:4]; VGA_B <= rgb[3:0];
            VGA_HS <= raw_hsync; VGA_VS <= raw_vsync;
        end
    end
    seven_segment scoreboard(.clk(CLK100MHZ),.reset(reset),.elixir(elixir),.an(AN),
        .segment({CA,CB,CC,CD,CE,CF,CG}),.dp(DP));
    always_comb begin
        LED = 0;
        LED[4:0] = alive[4:0]; LED[12:8] = alive[9:5];
        LED[5] = error_code[0] != 0; LED[13] = error_code[1] != 0;
        LED[6] = lane[0] < 5; LED[14] = lane[1] < 5;
        LED[7] = state == PLAY; LED[15] = state == GAME_OVER;
    end
endmodule
