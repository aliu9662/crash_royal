`timescale 1ns/1ps
module royale_top (
    input wire CLK100MHZ, CPU_RESETN, BTNC,
    input wire [15:0] SW,
    output reg [15:0] LED,
    output reg [3:0] VGA_R, VGA_G, VGA_B,
    output reg VGA_HS, VGA_VS,
    output wire [7:0] AN,
    output wire CA, CB, CC, CD, CE, CF, CG, DP
);
    `include "royale_defs.vh"
    // Power-on reset, asynchronous assertion, synchronized release.
    (* ASYNC_REG = "TRUE" *) reg [2:0] reset_pipe = 3'b111;
    wire reset;
    always @(posedge CLK100MHZ or negedge CPU_RESETN)
        if (!CPU_RESETN) reset_pipe <= 3'b111;
        else reset_pipe <= {reset_pipe[1:0],1'b0};
    assign reset = reset_pipe[2];

    wire [5:0] p1_switches, p2_switches;
    wire start_button;
    reg previous_start;
    wire [1:0] state, winner, request;
    wire [5:0] lane, request_lane;
    wire [3:0] card, request_card, error_code;
    wire [7:0] elixir;
    wire [9:0] alive;
    wire [89:0] progress;
    wire [79:0] health;
    wire [19:0] kind;
    wire pixel_enable, game_tick, visible, raw_hsync, raw_vsync;
    wire [9:0] x, y;
    wire [11:0] rgb;
    input_filter #(.WIDTH(6)) p1_input(.clk(CLK100MHZ),.reset(reset),.raw(SW[5:0]),.value(p1_switches));
    input_filter #(.WIDTH(6)) p2_input(.clk(CLK100MHZ),.reset(reset),.raw(SW[13:8]),.value(p2_switches));
    input_filter start_input(.clk(CLK100MHZ),.reset(reset),.raw(BTNC),.value(start_button));
    always @(posedge CLK100MHZ)
        if (reset) previous_start <= 0;
        else previous_start <= start_button;
    assign lane[(0)*3 +: 3] = p1_switches[2:0];
    assign lane[(1)*3 +: 3] = p2_switches[2:0];
    assign card[(0)*2 +: 2] = p1_switches[4:3];
    assign card[(1)*2 +: 2] = p2_switches[4:3];
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
    always @(posedge CLK100MHZ) begin
        if (reset) begin
            VGA_R <= 0; VGA_G <= 0; VGA_B <= 0; VGA_HS <= 1; VGA_VS <= 1;
        end else if (pixel_enable) begin
            VGA_R <= rgb[11:8]; VGA_G <= rgb[7:4]; VGA_B <= rgb[3:0];
            VGA_HS <= raw_hsync; VGA_VS <= raw_vsync;
        end
    end
    seven_segment scoreboard(.clk(CLK100MHZ),.reset(reset),.elixir(elixir),.an(AN),
        .segment({CA,CB,CC,CD,CE,CF,CG}),.dp(DP));
    always @* begin
        LED = 0;
        LED[4:0] = alive[4:0]; LED[12:8] = alive[9:5];
        LED[5] = error_code[(0)*2 +: 2] != 0; LED[13] = error_code[(1)*2 +: 2] != 0;
        LED[6] = lane[(0)*3 +: 3] < 5; LED[14] = lane[(1)*3 +: 3] < 5;
        LED[7] = state == PLAY; LED[15] = state == GAME_OVER;
    end
endmodule
