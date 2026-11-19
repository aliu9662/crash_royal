# FPGA Royale

First playable hardware prototype for the Nexys A7-100T (`xc7a100tcsg324-1`), written in Verilog-2001. RTL and testbenches use `.v` files, `wire`/`reg`, ordinary `always` blocks, and explicit port connections. Shared constants/functions are included from `rtl/royale_params.vh`.

## Repository contents

- `rtl/`, `sim/`, `scripts/`, and `constraints/`: current Verilog implementation and build/test entry points.
- `instructions/`: all 17 supplied/downloaded course instruction and reference files, including the VGA starter archives and tutorial videos.
- `docs/pitch/`: the saved pitch and earlier presentation versions. These precede the five-lane/four-card decisions; the rules below describe the current implementation.
- `docs/design_discussion.txt`: early design discussion, retained as historical context.
- `docs/reference/`: board reference image.
- `docs/verification/`: ModelSim results and the rendered sample screen.
- `docs/materials_manifest.md`: checksums for the imported materials.

Build outputs, installed/downloaded simulator binaries, and cached browser pages are excluded from version control.

## Current checkpoint

The implementation and testbenches are Verilog-2001. ModelSim SE-64 10.6e (`scripts/simulate_questasim.ps1`, `-vlog01compat`) passes gameplay, input, video, and display I/O checks (51/11/22/1,155 checks). The video test checks a complete 800x525 raster, 640x480 visible area, sync timing, one game tick per frame, blanking, and 307,200 rendered pixels; it writes `sample_screen.ppm` in `build/questasim`. A portable preview and results summary are in [docs/verification](docs/verification/simulation_results.md). Icarus scripts remain available but were not used for the November 18 verification.

Vivado 2026.1 synthesis, implementation, timing checks, and bitstream generation pass with the November 18 timing fixes. Final setup/hold slack is +0.010/+0.050 ns, with zero design-rule violations. See the [implementation results](docs/verification/vivado_build_results.md) for constraints, changes, and reproducibility. Troop balance, physical controls, and monitor operation still need board testing.

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

These are adjustable starting values, not final balance. Stats are centralized in `rtl/royale_params.vh`.

| Card | Cost | HP | Damage | Move every | Attack every |
| --- | --- | --- | --- | --- | --- |
| Giant | 5 | 28 | 0 | 4 ticks | never |
| Ice Golem | 2 | 12 | 1 | 3 ticks | 45 ticks |
| Knight | 3 | 16 | 2 | 2 ticks | 30 ticks |
| Mini P.E.K.K.A | 4 | 12 | 6 | 2 ticks | 24 ticks |

Movement is one pixel per movement interval across a 360-pixel field. Melee range is 18 pixels between centers. Attack cooldowns count down continuously, allowing an immediate attack on first contact when ready. Giant can be attacked from either side while within range.

## Structure and timing

Module interfaces carry flattened vectors: slot `i` occupies `progress[i*9 +: 9]`, `health[i*8 +: 8]`, and `kind[i*2 +: 2]`. Player `p` occupies `elixir[p*4 +: 4]`, lane selection `[p*3 +: 3]`, and card/error selection `[p*2 +: 2]`. These indexed slices are standard Verilog-2001.

All logic uses the board's 100 MHz clock. A pixel enable every four cycles generates 640x480 VGA with 800x525 total timing at 25 MHz (about 59.52 frames/second). Renderer snapshots, raster counters, and RGB output registers share this enable. Only their pixel data paths receive a four-cycle timing constraint; control, reset, and game logic retain the 10 ns requirement. One game tick at the beginning of vertical blank updates the complete game state before the next visible frame. Consequently 60 game ticks take about 1.008 seconds; the nominal three-minute timeout is about 181.44 seconds. There are no logic-generated clocks or vendor IP dependencies.

`game_core` caches lane contact between updates and requires at least one idle system-clock edge between game ticks. The board supplies 1,680,000 system clocks per frame. The cached contact logic matches the original combinational behavior under this interface contract. Seven-segment outputs are registered, adding one 10 ns clock of display latency.

- `game_core.v`: idle/play/game-over controller, ten unit slots, combat, elixir, deployment, scoring.
- `input_filter.v`, `command_capture.v`: synchronizers, stable-input filtering, independent request snapshots.
- `display_controller.v`: 640×480 VGA timing (100 MHz, 1-of-4 pixel enable), `bright`/`hSync`/`vSync`/`hCount`/`vCount`, one `game_tick` per frame.
- `vga_bitchange.v`: arena paint, unit letters, HUD (`localparam USE_SPRITES` sprite hook).
- `seven_segment.v`, `royale_top.v`: board display and integration.
- `constraints/nexys_a7_100t.xdc`: board pin assignments (EE354 port names on `royale_top`), derived from the official [Digilent master constraints](https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc).

`royale_top` ports match the XDC: `ClkPort`, active-low `BtnCpuReset`, `BtnC` (start), `Sw[15:0]`, `Ld[15:0]`, `vgaR`/`vgaG`/`vgaB[3:0]`, `hSync`, `vSync`, `An0`–`An7`, `Ca`–`Cg`, `Dp`, and `QuadSpiFlashCS` (tied high in RTL).

## Simulation

macOS / Linux (Icarus):

```bash
bash scripts/simulate_icarus.sh
```

Windows (Icarus; optional portable tree under `build/tools`, or `-IcarusBin`):

```powershell
.\scripts\simulate_icarus.ps1
```

QuestaSim (`-QuestaBin` if `vsim.exe` is not on PATH):

```powershell
.\scripts\simulate_questasim.ps1
```

Each script builds `rtl/*.v`, `rtl/sprites/*.v` when present, and `sim/*_tb.v`, then requires a `PASS <test>:` line for gameplay, input, video, and display I/O in the respective logs. Each player has one queued request snapshot; if multiple filtered deployment toggles arrive before one game tick, the latest request replaces the earlier pending request.

## Vivado build and program

```powershell
.\scripts\build.ps1
```

Batch-runs `scripts/build.tcl`: synthesis through `write_bitstream`, timing/DRC gates, output `build/royale_top.bit` and reports under `build/`. The script locates Vivado on PATH or under common AMD/Xilinx installation directories; override with `-VivadoBin` if needed. `constraints/pixel_timing.tcl` must be sourced after synthesis, as the build script does, so its scoped register constraints can be resolved. Output propagation is bounded separately for the asynchronous board LEDs, seven-segment display, and VGA interface; these peripherals have no external 100 MHz capture clock.

```powershell
.\scripts\program.ps1
```

Batch-runs `scripts/program.tcl`: Hardware Manager connects to the first target and programs `build/royale_top.bit` into SRAM (lost on power cycle).

For persistent configuration flash, `QuadSpiFlashCS` is held high so gameplay does not drive the quad-SPI device. Store a bitstream in on-board configuration memory separately in Vivado Hardware Manager (*Add Configuration Memory Device*, then program with a `.bin` or `.mcs` from the implemented design—not automated by these scripts).

## Sprite handoff

Default graphics use colored boxes and card letters (`USE_SPRITES = 0` in `vga_bitchange.v`). For EE354 block-RAM ROMs, see `rtl/sprites/README.md`. Convert art with `tools/ee354_optimized_sprite_script.py`: edit the driver to call `generate("giant.png")` or `generate("name.png", rem_x, rem_y)` to mask a background pixel. The script writes `<basename>_12_bit_rom.v` (`module <basename>_rom`); place copies in `rtl/sprites/` (e.g. `giant_rom.v`). Recommended size is 20×20. Set `USE_SPRITES = 1` and instantiate ROMs at the `// SPRITE HOOK`; treat `12'h000` as transparent.

The VGA archive in `instructions/` was reviewed as a reference; this implementation uses a single clock and explicit resets rather than the archive's cascaded clock dividers. Hardware operation and gameplay balance still require a physical-board playtest.
