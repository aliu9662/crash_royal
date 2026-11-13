`timescale 1ns/1ps
module vga_timing (
    input wire clk, reset,
    output wire pixel_enable, game_tick, visible, hsync, vsync,
    output reg [9:0] x, y
);
    reg [1:0] pixel_divider;
    assign pixel_enable = pixel_divider == 3;
    assign visible = x < 640 && y < 480;
    assign hsync = !(x >= 656 && x < 752);
    assign vsync = !(y >= 490 && y < 492);
    assign game_tick = pixel_enable && x == 0 && y == 480;
    always @(posedge clk) begin
        if (reset) begin
            pixel_divider <= 0; x <= 0; y <= 0;
        end else begin
            pixel_divider <= pixel_divider + 1'b1;
            if (pixel_enable) begin
                if (x == 799) begin
                    x <= 0;
                    if (y == 524) y <= 0;
                    else y <= y + 1'b1;
                end else x <= x + 1'b1;
            end
        end
    end
endmodule
