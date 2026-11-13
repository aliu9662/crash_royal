# FPGA Royale

First playable hardware prototype for the Nexys A7-100T (`xc7a100tcsg324-1`).

## Current checkpoint

Implementation is written for the game engine, independent switch controllers, five-lane VGA renderer, elixir display, and board integration. Vivado and ModelSim accepted all source/testbench files without compilation errors. Icarus completed 50 gameplay checks and 10 input checks successfully. The video simulation was stopped at the user's request; its raster and screen output remain unverified. Synthesis, timing, and bitstream generation remain unverified because both installed commercial tools reported license checkout failures. No board was programmed.

The next session should review the source and decide when to resume video simulation and the Vivado build. Troop balance and physical controls still need board testing.

## Agreed rules

- Five independent lanes, one living unit per player per lane (ten slots total).
- P1 starts at the bottom end line and advances upward. P2 starts at the top and advances downward.
- Giant walks through opponents and never attacks. Other troops stop and attack an opponent within melee range, including a Giant passing them.
- No lane changes, cross-lane damage, spells, deck cycling, friendly stacking, or special abilities.
- All four cards are directly selectable. Invalid lanes, occupied friendly lanes, and insufficient elixir reject deployment without spending elixir.
- Each tick resolves attacks simultaneously, applies deaths, moves surviving troops, and checks touchdowns. Both players scoring in one tick is a draw. Damage on the scoring tick can kill a unit before it scores.
- Deployment follows the existing-unit update. New troops wait until the next tick before acting. Both players can deploy in the same tick.
- Touchdown means the unit's center reaches the opposing end line. A unit spawns with its center on its own end line.
- Elixir starts at 5, caps at 10, and regenerates every 60 ticks. Spending uses the elixir available at the beginning of the tick; regeneration follows spending.
- A match times out as a draw after 10,800 ticks. Reset returns to the title state.

## Controls

Each player's six switches form an independent controller. The button pad is no longer shared for gameplay.

| Action | P1 (right switch group) | P2 (left switch group) |
| --- | --- | --- |
| Lane code, 000 through 100 = lanes 1 through 5 | SW2:SW0 | SW10:SW8 |
| Card code | SW4:SW3 | SW12:SW11 |
| Deploy once on either toggle direction | SW5 | SW13 |

Card codes: `00` Giant, `01` Ice Golem, `10` Knight, `11` Mini P.E.K.K.A. Lane codes 101, 110, and 111 are invalid. Set lane/card first, then toggle deploy. SW6, SW7, SW14, and SW15 are unused.

- Center button: start a match from the title screen. After game over, use CPU RESET, then center to start again.
- CPU RESET: return to title. Current deploy-switch positions become the baseline, so resetting/starting cannot deploy a troop accidentally.
- Seven-segment display: P2 elixir on the left pair, P1 elixir on the right pair.
- LEDs 4:0 and 12:8: P1/P2 occupied lanes. LEDs 5/13: rejected deployment. LEDs 6/14: valid lane selection. LED7: match running. LED15: game over.
- VGA shows lane selection, elixir bars, card letters G/I/K/M, unit health bars, and title/winner/draw overlays. Error codes next to each player are 1 = invalid lane, 2 = occupied lane, 3 = insufficient elixir. An error persists until that player's next deployment request or reset.

## Initial balance values

These are adjustable starting values, not final balance. Stats are centralized in `rtl/royale_pkg.sv`.

| Card | Cost | HP | Damage | Move every | Attack every |
| --- | --- | --- | --- | --- | --- |
| Giant | 5 | 28 | 0 | 4 ticks | never |
| Ice Golem | 2 | 12 | 1 | 3 ticks | 45 ticks |
| Knight | 3 | 16 | 2 | 2 ticks | 30 ticks |
| Mini P.E.K.K.A | 4 | 12 | 6 | 2 ticks | 24 ticks |

Movement is one pixel per movement interval across a 360-pixel field. Melee range is 18 pixels between centers. Attack cooldowns count down continuously, allowing an immediate attack on first contact when ready. Giant can be attacked from either side while within range.

## Structure and timing

All logic uses the board's 100 MHz clock. A pixel enable every four cycles generates 640x480 VGA with 800x525 total timing at 25 MHz (about 59.52 frames/second). One game tick at the beginning of vertical blank updates the complete game state before the next visible frame. Consequently 60 game ticks take about 1.008 seconds; the nominal three-minute timeout is about 181.44 seconds. There are no logic-generated clocks or vendor IP dependencies.

- `game_core.sv`: idle/play/game-over controller, ten unit slots, combat, elixir, deployment, scoring.
- `input_filter.sv`, `command_capture.sv`: synchronizers, stable-input filtering, independent request snapshots.
- `vga_timing.sv`, `arena_renderer.sv`: VGA raster and simple prototype graphics.
- `seven_segment.sv`, `royale_top.sv`: board display and integration.
- `constraints/nexys_a7_100t.xdc`: board pin assignments derived from the official [Digilent master constraints](https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc).

## Build and simulation

With Vivado installed (the scripts also detect this computer's `C:\AMDDesignTools\2026.1\Vivado\bin`):

```powershell
.\scripts\simulate.ps1
.\scripts\build.ps1
```

Alternative simulation entry points are `scripts/simulate_modelsim.ps1` and `scripts/simulate_icarus.ps1`. A portable Icarus package from the official MSYS2 repository was extracted under the ignored `build/tools` directory for this checkpoint; it did not change the system installation or permanent PATH. The Icarus script detects it automatically. It also works with an existing Icarus installation supplied through its `-IcarusBin` option. Each player has one queued request snapshot; if multiple filtered deployment toggles arrive before one game tick, the latest request replaces the earlier pending request.

Simulation runs directed gameplay/input/raster checks and generates a sample screen. The build script synthesizes, places, routes, checks timing, and writes `build/royale_top.bit` plus reports. A failing timing/DRC check fails the build. Neither script programs a board. Load the bitstream through Vivado Hardware Manager when ready to test the physical board.

The VGA archive in `../instructions` was reviewed as a reference; this implementation uses a single clock and explicit resets rather than the archive's cascaded clock dividers. Simple colored units intentionally precede sprite artwork. Hardware operation and gameplay balance still require a physical-board playtest.
