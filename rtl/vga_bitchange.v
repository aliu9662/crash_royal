`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// File: vga_bitchange.v
// Role: EE354 paint module (skeleton vga_bitchange). Arena/HUD colors + sprite hooks.
//////////////////////////////////////////////////////////////////////////////////
module vga_bitchange (
    input  wire        clk,
    input  wire        bright,
    input  wire [9:0]  hCount,
    input  wire [9:0]  vCount,
    input  wire [1:0]  state,
    input  wire [1:0]  winner,
    input  wire [31:0]  alive,
    input  wire [287:0] progress,
    input  wire [255:0] health,
    input  wire [63:0] kind,
    input  wire [7:0]  elixir,
    input  wire [5:0]  selected_lane,
    input  wire [3:0]  selected_card,
    input  wire [3:0]  error_code,
    input  wire [15:0] elapsed_ticks,
    output reg  [11:0] rgb
);
    `include "royale_params.vh"

    localparam USE_SPRITES = 1;
    localparam SPRITE_W = 20;
    localparam SPRITE_H = 20;

    function automatic [34:0] glyph(input [7:0] c);
        case (c)
            "0": glyph = 35'b01110_10001_10011_10101_11001_10001_01110;
            "1": glyph = 35'b00100_01100_00100_00100_00100_00100_01110;
            "2": glyph = 35'b01110_10001_00001_00010_00100_01000_11111;
            "3": glyph = 35'b11110_00001_00001_01110_00001_00001_11110;
            "4": glyph = 35'b00010_00110_01010_10010_11111_00010_00010;
            "5": glyph = 35'b11111_10000_10000_11110_00001_00001_11110;
            "6": glyph = 35'b01110_10000_10000_11110_10001_10001_01110;
            "7": glyph = 35'b11111_00001_00010_00100_01000_01000_01000;
            "8": glyph = 35'b01110_10001_10001_01110_10001_10001_01110;
            "9": glyph = 35'b01110_10001_10001_01111_00001_00001_01110;
            ":": glyph = 35'b00000_00100_00100_00000_00100_00100_00000;
            "A": glyph = 35'b01110_10001_10001_11111_10001_10001_10001;
            "C": glyph = 35'b01111_10000_10000_10000_10000_10000_01111;
            "D": glyph = 35'b11110_10001_10001_10001_10001_10001_11110;
            "E": glyph = 35'b11111_10000_10000_11110_10000_10000_11111;
            "F": glyph = 35'b11111_10000_10000_11110_10000_10000_10000;
            "G": glyph = 35'b01111_10000_10000_10111_10001_10001_01111;
            "I": glyph = 35'b01110_00100_00100_00100_00100_00100_01110;
            "K": glyph = 35'b10001_10010_10100_11000_10100_10010_10001;
            "L": glyph = 35'b10000_10000_10000_10000_10000_10000_11111;
            "M": glyph = 35'b10001_11011_10101_10101_10001_10001_10001;
            "N": glyph = 35'b10001_11001_10101_10011_10001_10001_10001;
            "O": glyph = 35'b01110_10001_10001_10001_10001_10001_01110;
            "P": glyph = 35'b11110_10001_10001_11110_10000_10000_10000;
            "R": glyph = 35'b11110_10001_10001_11110_10100_10010_10001;
            "S": glyph = 35'b01111_10000_10000_01110_00001_00001_11110;
            "T": glyph = 35'b11111_00100_00100_00100_00100_00100_00100;
            "W": glyph = 35'b10001_10001_10001_10101_10101_10101_01010;
            "Y": glyph = 35'b10001_10001_01010_00100_00100_00100_00100;
            default: glyph = 35'd0;
        endcase
    endfunction

    function automatic [5:0] health_width(input [7:0] hp, input [1:0] card);
        begin
            case (card)
                GIANT: health_width = hp;
                ICE_GOLEM: health_width = (hp * 28) / 12;
                KNIGHT: health_width = (hp * 28) / 16;
                default: health_width = (hp * 28) / 12;
            endcase
        end
    endfunction

    function automatic ink(input integer px, py, left, top, scale, input [7:0] c);
        reg [2:0] col, row;
        reg [4:0] glyph_x, glyph_y;
        reg [5:0] glyph_index;
        reg [34:0] bits;
        begin
            ink = 1'b0;
            col = 0;
            row = 0;
            glyph_x = 0;
            glyph_y = 0;
            glyph_index = 0;
            bits = glyph(c);
            if (px >= left && px < left + 5 * scale && py >= top && py < top + 7 * scale) begin
                // All call sites use scales 1, 2, or 3, so a glyph is at most
                // 15x21 pixels. Clip first, then use bounded unsigned math;
                // signed 32-bit division here creates a very long pixel path.
                glyph_x = px - left;
                glyph_y = py - top;
                case (scale)
                    1: begin col = glyph_x[2:0]; row = glyph_y[2:0]; end
                    2: begin col = glyph_x[3:1]; row = glyph_y[3:1]; end
                    default: begin col = glyph_x / 5'd3; row = glyph_y / 5'd3; end
                endcase
                glyph_index = 6'd34 - (row * 6'd5) - col;
                ink = bits[glyph_index];
            end
        end
    endfunction

    localparam [8*11-1:0] TITLE = "FPGA ROYALE";
    localparam [8*13-1:0] READY = "CENTER: START";
    localparam [8*11-1:0] P1_TEXT = "P1 WINS    ";
    localparam [8*11-1:0] P2_TEXT = "P2 WINS    ";
    localparam [8*11-1:0] DRAW_TEXT = "DRAW       ";

    reg [4:0] sprite_row;
    reg [4:0] sprite_col;
    reg [1:0] sprite_kind;
    reg       sprite_hit;
    wire [11:0] rom_giant;
    wire [11:0] rom_ice;
    wire [11:0] rom_knight;
    wire [11:0] rom_pekka;
    wire [11:0] grass_color;
    wire [3:0] grass_row = vCount[3:0];
    wire [3:0] grass_col = hCount[3:0];
    reg  [11:0] sprite_color;

    giant_rom     u_giant (.clk(clk), .row(sprite_row), .col(sprite_col), .color_data(rom_giant));
    ice_golem_rom u_ice   (.clk(clk), .row(sprite_row), .col(sprite_col), .color_data(rom_ice));
    knight_rom    u_knight(.clk(clk), .row(sprite_row), .col(sprite_col), .color_data(rom_knight));
    mini_pekka_rom u_pekka(.clk(clk), .row(sprite_row), .col(sprite_col), .color_data(rom_pekka));
    grass_tile_rom u_grass(.clk(clk), .row(grass_row), .col(grass_col), .color_data(grass_color));

    always @* begin
        case (sprite_kind)
            GIANT:     sprite_color = rom_giant;
            ICE_GOLEM: sprite_color = rom_ice;
            KNIGHT:    sprite_color = rom_knight;
            default:   sprite_color = rom_pekka;
        endcase
    end

    integer px, py, lane, slot, cx, cy, local_x, local_y;
    reg [3:0] text_index;
    reg [8:0] text_offset;
    integer elapsed_seconds, elapsed_minutes, timer_seconds;
    reg [7:0] text_char;

    always @* begin
        px = hCount;
        py = vCount;
        cx = 0;
        cy = 0;
        text_index = 0;
        text_offset = 0;
        text_char = " ";
        local_x = 0;
        local_y = 0;
        sprite_row = 5'd0;
        sprite_col = 5'd0;
        sprite_kind = 2'd0;
        sprite_hit = 1'b0;
        elapsed_seconds = elapsed_ticks / 60;
        elapsed_minutes = elapsed_seconds / 60;
        timer_seconds = elapsed_seconds % 60;
        rgb = 12'h112;

        if (px >= 80 && px < 560 && py >= 70 && py <= 430) begin
            rgb = grass_color;
            for (lane = 0; lane <= 4; lane = lane + 1)
                if (px >= 80 + lane * 120 && px < 82 + lane * 120)
                    rgb = 12'h667;
            if (py == 250) rgb = 12'h889;
            if (py < 74) rgb = 12'hd45;
            if (py > 426) rgb = 12'h48e;
        end

        for (lane = 0; lane < 4; lane = lane + 1) begin
            if (selected_lane[(1)*3 +: 3] == lane && px >= 83 + lane * 120 && px < 197 + lane * 120 && py >= 62 && py < 68)
                rgb = 12'hfd4;
            if (selected_lane[(0)*3 +: 3] == lane && px >= 83 + lane * 120 && px < 197 + lane * 120 && py >= 433 && py < 439)
                rgb = 12'hfd4;
            if (ink(px, py, 137 + lane * 120, 80, 1, 8'd49 + lane) || ink(px, py, 137 + lane * 120, 413, 1, 8'd49 + lane))
                rgb = 12'h99a;
        end

        for (slot = 0; slot < SLOTS; slot = slot + 1) begin
            lane = (slot % SLOTS_PER_PLAYER) / CARDS;
            cx = 140 + lane * 120 + (slot % CARDS) * 12 - 18 +
                 ((slot < SLOTS_PER_PLAYER) ? -4 : 4);
            cy = (slot < SLOTS_PER_PLAYER) ? 430 - (progress[(slot)*9 +: 9]) :
                                             70 + (progress[(slot)*9 +: 9]);
            if (alive[slot]) begin
                sprite_hit = 1'b0;
                local_x = px - (cx - (SPRITE_W / 2));
                local_y = py - (cy - (SPRITE_H / 2));
                if (local_x >= 0 && local_x < SPRITE_W && local_y >= 0 && local_y < SPRITE_H) begin
                    sprite_hit = 1'b1;
                    sprite_col = local_x[4:0];
                    sprite_row = local_y[4:0];
                    sprite_kind = kind[(slot)*2 +: 2];
                end

                if (!USE_SPRITES && px >= cx - 9 && px <= cx + 9 && py >= cy - 9 && py <= cy + 9)
                    rgb = (slot < SLOTS_PER_PLAYER) ? 12'h38f : 12'hf45;
                if (USE_SPRITES && sprite_hit && (sprite_color != 12'h000))
                    rgb = sprite_color;
                if (USE_SPRITES && px >= cx - 7 && px < cx + 8 && py >= cy + 8 && py < cy + 10)
                    rgb = (slot < SLOTS_PER_PLAYER) ? 12'h38f : 12'hf45;
                if (!USE_SPRITES && ink(px, py, cx - 2, cy - 3, 1, card_letter(kind[(slot)*2 +: 2])))
                    rgb = 12'hfff;
                if (px >= cx - 14 && px < cx + 14 && py >= cy - 14 && py < cy - 11) begin
                    rgb = 12'h333;
                    if (px < cx - 14 + health_width(health[(slot)*8 +: 8], kind[(slot)*2 +: 2]))
                        rgb = 12'h5e6;
                end
            end
        end

        for (slot = 0; slot < 2; slot = slot + 1) begin
            cy = (slot == 0) ? 452 : 38;
            if (ink(px, py, 80, cy, 2, "P") || ink(px, py, 94, cy, 2, 8'd49 + slot))
                rgb = 12'hfff;
            if (px >= 126 && px < 226 && py >= cy && py < cy + 12)
                rgb = (px < 126 + (elixir[(slot)*4 +: 4]) * 10) ? 12'hc5e : 12'h333;
            if (elixir[(slot)*4 +: 4] == 10 && ink(px, py, 228, cy, 2, "1"))
                rgb = 12'hfff;
            if (ink(px, py, 240, cy, 2, 8'd48 + ((elixir[(slot)*4 +: 4] == 10) ? 0 : elixir[(slot)*4 +: 4])))
                rgb = 12'hfff;
            if (ink(px, py, 260, cy, 2, card_letter(selected_card[(slot)*2 +: 2])))
                rgb = 12'hfd4;
            if (error_code[(slot)*2 +: 2] != 0 && ink(px, py, 292, cy, 2, 8'd48 + (error_code[(slot)*2 +: 2])))
                rgb = 12'hf45;
        end

        if (py >= 10 && py < 24 && px >= 254 && px < 386) begin
            text_offset = px - 254;
            text_index = text_offset / 9'd12;
            text_char = TITLE[(10 - text_index) * 8 +: 8];
            if (ink(px, py, 254 + text_index * 12, 10, 2, text_char))
                rgb = 12'hfff;
        end

        if (ink(px, py, 570, 10, 1, 8'd48 + ((elapsed_minutes / 10) % 10)) ||
            ink(px, py, 578, 10, 1, 8'd48 + (elapsed_minutes % 10)) ||
            ink(px, py, 586, 10, 1, ":") ||
            ink(px, py, 594, 10, 1, 8'd48 + (timer_seconds / 10)) ||
            ink(px, py, 602, 10, 1, 8'd48 + (timer_seconds % 10)))
            rgb = 12'hfff;

        if (state != PLAY && px >= 160 && px < 480 && py >= 212 && py < 286) begin
            rgb = 12'h112;
            if (state == IDLE && px >= 190 && px < 450 && py >= 239 && py < 260) begin
                text_offset = px - 190;
                text_index = text_offset / 9'd20;
                text_char = READY[(12 - text_index) * 8 +: 8];
                if (ink(px, py, 190 + text_index * 20, 239, 3, text_char))
                    rgb = 12'hfd4;
            end else if (state == GAME_OVER && px >= 210 && px < 430 && py >= 239 && py < 260) begin
                text_offset = px - 210;
                text_index = text_offset / 9'd20;
                case (winner)
                    P1_WIN:  text_char = P1_TEXT[(10 - text_index) * 8 +: 8];
                    P2_WIN:  text_char = P2_TEXT[(10 - text_index) * 8 +: 8];
                    default: text_char = DRAW_TEXT[(10 - text_index) * 8 +: 8];
                endcase
                if (ink(px, py, 210 + text_index * 20, 239, 3, text_char))
                    rgb = 12'hfd4;
            end
        end

        if (!bright)
            rgb = 12'h000;
    end
endmodule
