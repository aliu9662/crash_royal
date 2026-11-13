`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// File: display_controller.v
// Role: EE354 VGA timing (skeleton display_controller). Single 100 MHz clock
//       with 1-of-4 pixel enable — no cascaded logic clocks.
//////////////////////////////////////////////////////////////////////////////////
module display_controller (
    input  wire       clk,
    input  wire       reset,
    output wire       pixel_enable,
    output wire       game_tick,
    output wire       bright,
    output wire       hSync,
    output wire       vSync,
    output reg  [9:0] hCount,
    output reg  [9:0] vCount
);
    reg [1:0] pixel_divider;

    assign pixel_enable = (pixel_divider == 2'd3);
    assign bright = (hCount < 10'd640) && (vCount < 10'd480);
    assign hSync = !(hCount >= 10'd656 && hCount < 10'd752);
    assign vSync = !(vCount >= 10'd490 && vCount < 10'd492);
    assign game_tick = pixel_enable && (hCount == 10'd0) && (vCount == 10'd480);

    always @(posedge clk) begin
        if (reset) begin
            pixel_divider <= 2'd0;
            hCount <= 10'd0;
            vCount <= 10'd0;
        end else begin
            pixel_divider <= pixel_divider + 2'd1;
            if (pixel_enable) begin
                if (hCount == 10'd799) begin
                    hCount <= 10'd0;
                    if (vCount == 10'd524)
                        vCount <= 10'd0;
                    else
                        vCount <= vCount + 10'd1;
                end else begin
                    hCount <= hCount + 10'd1;
                end
            end
        end
    end
endmodule
