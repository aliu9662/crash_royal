`timescale 1ns/1ps
module arena_renderer (
    input wire visible,
    input wire [9:0] x, y,
    input wire [1:0] state, winner,
    input wire [9:0] alive,
    input wire [89:0] progress,
    input wire [79:0] health,
    input wire [19:0] kind,
    input wire [7:0] elixir,
    input wire [5:0] selected_lane,
    input wire [3:0] selected_card, error_code,
    output reg [11:0] rgb
);
    `include "royale_defs.vh"
    // Five-by-seven font, stored as seven rows from top to bottom.
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
            default: glyph = 0;
        endcase
    endfunction
    function automatic ink(input integer px, py, left, top, scale, input [7:0] c);
        integer col, row;
        reg [34:0] bits;
        begin
            ink = 0; col = 0; row = 0; bits = glyph(c);
            if (px >= left && px < left+5*scale && py >= top && py < top+7*scale) begin
                col = (px-left)/scale; row = (py-top)/scale;
                ink = bits[34-row*5-col];
            end
        end
    endfunction
    localparam [8*11-1:0] TITLE = "FPGA ROYALE";
    localparam [8*13-1:0] READY = "CENTER: START";
    localparam [8*11-1:0] P1_TEXT = "P1 WINS    ";
    localparam [8*11-1:0] P2_TEXT = "P2 WINS    ";
    localparam [8*11-1:0] DRAW_TEXT = "DRAW       ";
    integer px, py, lane, slot, cx, cy, text_index;
    reg [7:0] text_char;
    always @* begin
        px = (x); py = (y);
        cx = 0; cy = 0; text_index = 0; text_char = " ";
        rgb = 12'h112;
        if (px >= 80 && px < 560 && py >= 70 && py <= 430) begin
            rgb = (py < 250) ? 12'h322 : 12'h223;
            for (lane = 0; lane <= 5; lane = lane+1)
                if (px >= 80+lane*96 && px < 82+lane*96) rgb = 12'h667;
            if (py == 250) rgb = 12'h889;
            if (py < 74) rgb = 12'hd45;
            if (py > 426) rgb = 12'h48e;
        end
        // Selected lanes and lane numbers remain visible during play.
        for (lane = 0; lane < 5; lane = lane+1) begin
            if (selected_lane[(1)*3 +: 3] == lane && px >= 83+lane*96 && px < 175+lane*96 && py >= 62 && py < 68)
                rgb = 12'hfd4;
            if (selected_lane[(0)*3 +: 3] == lane && px >= 83+lane*96 && px < 175+lane*96 && py >= 433 && py < 439)
                rgb = 12'hfd4;
            if (ink(px,py,124+lane*96,80,1,8'd49+lane) || ink(px,py,124+lane*96,413,1,8'd49+lane))
                rgb = 12'h99a;
        end
        for (slot = 0; slot < 10; slot = slot+1) begin
            // Slight drawing offsets keep both sprites visible during a pass.
            // Collision/range reg uses only progress along the lane.
            cx = 128+(slot%5)*96 + ((slot < 5) ? -10 : 10);
            cy = (slot < 5) ? 430-(progress[(slot)*9 +: 9]) : 70+(progress[(slot)*9 +: 9]);
            if (alive[slot]) begin
                if (px >= cx-9 && px <= cx+9 && py >= cy-9 && py <= cy+9)
                    rgb = (slot < 5) ? 12'h38f : 12'hf45;
                if (ink(px,py,cx-2,cy-3,1,card_letter(kind[(slot)*2 +: 2]))) rgb = 12'hfff;
                if (px >= cx-14 && px < cx+14 && py >= cy-14 && py < cy-11) begin
                    rgb = 12'h333;
                    if (px < cx-14+(health[(slot)*8 +: 8])) rgb = 12'h5e6;
                end
            end
        end
        // P2 HUD at top, P1 HUD at bottom. Bars have ten 10-pixel cells.
        for (slot = 0; slot < 2; slot = slot+1) begin
            cy = (slot == 0) ? 452 : 38;
            if (ink(px,py,80,cy,2,"P") || ink(px,py,94,cy,2,8'd49+slot)) rgb = 12'hfff;
            if (px >= 126 && px < 226 && py >= cy && py < cy+12)
                rgb = (px < 126+(elixir[(slot)*4 +: 4])*10) ? 12'hc5e : 12'h333;
            if (ink(px,py,244,cy,2,card_letter(selected_card[(slot)*2 +: 2]))) rgb = 12'hfd4;
            if (error_code[(slot)*2 +: 2] != 0 && ink(px,py,280,cy,2,8'd48+(error_code[(slot)*2 +: 2]))) rgb = 12'hf45;
        end
        if (py >= 10 && py < 24 && px >= 254 && px < 386) begin
            text_index = (px-254)/12;
            text_char = TITLE[(10-text_index)*8 +: 8];
            if (ink(px,py,254+text_index*12,10,2,text_char)) rgb = 12'hfff;
        end
        if (state != PLAY && px >= 160 && px < 480 && py >= 212 && py < 286) begin
            rgb = 12'h112;
            if (state == IDLE && px >= 190 && px < 450 && py >= 239 && py < 260) begin
                text_index = (px-190)/20;
                text_char = READY[(12-text_index)*8 +: 8];
                if (ink(px,py,190+text_index*20,239,3,text_char)) rgb = 12'hfd4;
            end else if (state == GAME_OVER && px >= 210 && px < 430 && py >= 239 && py < 260) begin
                text_index = (px-210)/20;
                case (winner)
                    P1_WIN: text_char = P1_TEXT[(10-text_index)*8 +: 8];
                    P2_WIN: text_char = P2_TEXT[(10-text_index)*8 +: 8];
                    default: text_char = DRAW_TEXT[(10-text_index)*8 +: 8];
                endcase
                if (ink(px,py,210+text_index*20,239,3,text_char)) rgb = 12'hfd4;
            end
        end
        if (!visible) rgb = 0;
    end
endmodule
