`timescale 1ns/1ps
module royale_top (
    input  wire        ClkPort,
    input  wire        BtnCpuReset,
    input  wire        BtnC,
    input  wire [15:0] Sw,
    output reg  [15:0] Ld,
    output reg  [3:0]  vgaR,
    output reg  [3:0]  vgaG,
    output reg  [3:0]  vgaB,
    output reg         hSync,
    output reg         vSync,
    output wire        An0,
    output wire        An1,
    output wire        An2,
    output wire        An3,
    output wire        An4,
    output wire        An5,
    output wire        An6,
    output wire        An7,
    output wire        Ca,
    output wire        Cb,
    output wire        Cc,
    output wire        Cd,
    output wire        Ce,
    output wire        Cf,
    output wire        Cg,
    output wire        Dp,
    output wire        QuadSpiFlashCS
);
    `include "royale_params.vh"
    // Power-on reset, asynchronous assertion, synchronized release.
    (* ASYNC_REG = "TRUE" *) reg [2:0] reset_pipe = 3'b111;
    wire reset;
    always @(posedge ClkPort or negedge BtnCpuReset)
        if (!BtnCpuReset) reset_pipe <= 3'b111;
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
    wire pixel_enable, game_tick, bright, raw_hSync, raw_vSync;
    wire [9:0] hCount, vCount;
    wire [11:0] rgb;
    // Renderer inputs change only on pixel-enable edges, like the raster and
    // RGB output registers. This gives the pixel logic its full 40 ns period.
    reg [1:0] view_state, view_winner;
    reg [9:0] view_alive;
    reg [89:0] view_progress;
    reg [79:0] view_health;
    reg [19:0] view_kind;
    reg [7:0] view_elixir;
    reg [5:0] view_lane;
    reg [3:0] view_card, view_error;
    wire [7:0] an;
    wire [6:0] segment;
    wire dp_seg;

    input_filter #(.WIDTH(6)) p1_input(.clk(ClkPort),.reset(reset),.raw(Sw[5:0]),.value(p1_switches));
    input_filter #(.WIDTH(6)) p2_input(.clk(ClkPort),.reset(reset),.raw(Sw[13:8]),.value(p2_switches));
    input_filter start_input(.clk(ClkPort),.reset(reset),.raw(BtnC),.value(start_button));
    always @(posedge ClkPort)
        if (reset) previous_start <= 0;
        else previous_start <= start_button;
    assign lane[(0)*3 +: 3] = p1_switches[2:0];
    assign lane[(1)*3 +: 3] = p2_switches[2:0];
    assign card[(0)*2 +: 2] = p1_switches[4:3];
    assign card[(1)*2 +: 2] = p2_switches[4:3];
    command_capture commands(
        .clk(ClkPort),.reset(reset),.enabled(state == PLAY),.consume(game_tick),
        .toggle({p2_switches[5],p1_switches[5]}),.lane(lane),.card(card),
        .pending(request),.request_lane(request_lane),.request_card(request_card));
    game_core game(
        .clk(ClkPort),.reset(reset),.game_tick(game_tick),.start(start_button && !previous_start),
        .deploy(request),.selected_lane(request_lane),.selected_card(request_card),
        .state(state),.winner(winner),.alive(alive),.progress(progress),.health(health),
        .kind(kind),.elixir(elixir),.error_code(error_code));
    display_controller dc(
        .clk(ClkPort),.reset(reset),.pixel_enable(pixel_enable),.game_tick(game_tick),
        .bright(bright),.hSync(raw_hSync),.vSync(raw_vSync),.hCount(hCount),.vCount(vCount));
    always @(posedge ClkPort) begin
        if (reset) begin
            view_state <= IDLE; view_winner <= NO_WINNER;
            view_alive <= 0; view_progress <= 0; view_health <= 0;
            view_kind <= 0; view_elixir <= 0; view_lane <= 0;
            view_card <= 0; view_error <= 0;
        end else if (pixel_enable) begin
            view_state <= state; view_winner <= winner;
            view_alive <= alive; view_progress <= progress; view_health <= health;
            view_kind <= kind; view_elixir <= elixir; view_lane <= lane;
            view_card <= card; view_error <= error_code;
        end
    end
    vga_bitchange vbc(
        .clk(ClkPort),.bright(bright),.hCount(hCount),.vCount(vCount),.state(view_state),.winner(view_winner),
        .alive(view_alive),.progress(view_progress),.health(view_health),.kind(view_kind),.elixir(view_elixir),
        .selected_lane(view_lane),.selected_card(view_card),.error_code(view_error),.rgb(rgb));
    // Register color and sync together so the displayed pixel stays aligned.
    always @(posedge ClkPort) begin
        if (reset) begin
            vgaR <= 0; vgaG <= 0; vgaB <= 0; hSync <= 1; vSync <= 1;
        end else if (pixel_enable) begin
            vgaR <= rgb[11:8]; vgaG <= rgb[7:4]; vgaB <= rgb[3:0];
            hSync <= raw_hSync; vSync <= raw_vSync;
        end
    end
    assign {An7, An6, An5, An4, An3, An2, An1, An0} = an;
    assign {Ca, Cb, Cc, Cd, Ce, Cf, Cg} = segment;
    assign Dp = dp_seg;
    assign QuadSpiFlashCS = 1'b1;
    seven_segment scoreboard(.clk(ClkPort),.reset(reset),.elixir(elixir),.an(an),
        .segment(segment),.dp(dp_seg));
    always @* begin
        Ld = 0;
        Ld[4:0] = alive[4:0]; Ld[12:8] = alive[9:5];
        Ld[5] = error_code[(0)*2 +: 2] != 0; Ld[13] = error_code[(1)*2 +: 2] != 0;
        Ld[6] = lane[(0)*3 +: 3] < 5; Ld[14] = lane[(1)*3 +: 3] < 5;
        Ld[7] = state == PLAY; Ld[15] = state == GAME_OVER;
    end
endmodule
