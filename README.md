# FPGA Royale

First playable hardware prototype for the Nexys A7-100T (`xc7a100tcsg324-1`), written in Verilog-2001. RTL and testbenches use `.v` files, `wire`/`reg`, ordinary `always` blocks, and explicit port connections. Shared constants/functions are included from `rtl/royale_params.vh`.

## Repository contents

- `rtl/`, `sim/`, `scripts/`, and `constraints/`: current Verilog implementation and build/test entry points.
- `instructions/`: all 17 supplied/downloaded course instruction and reference files, including the VGA starter archives and tutorial videos.
- `docs/pitch/`: the saved pitch and earlier presentation versions; the rules below describe the current implementation.
- `docs/design_discussion.txt`: early design discussion, retained as historical context.
- `docs/reference/`: board reference image.
- `docs/verification/`: ModelSim results and the rendered sample screen.
- `docs/materials_manifest.md`: checksums for the imported materials.

Build outputs, installed/downloaded simulator binaries, and cached browser pages are excluded from version control.

## Current checkpoint

The implementation and testbenches are Verilog-2001. ModelSim SE-64 10.6e (`scripts/simulate_questasim.ps1`, `-vlog01compat`) passes gameplay, input, video, and display I/O checks (51/11/22/1,155 checks). The video test checks a complete 800x525 raster, 640x480 visible area, sync timing, one game tick per frame, blanking, and 307,200 rendered pixels; it writes `sample_screen.ppm` in `build/questasim`. A portable preview and results summary are in [docs/verification](docs/verification/simulation_results.md). Icarus scripts remain available but were not used for the November 18 verification.

Vivado 2026.1 synthesis, implementation, timing checks, and bitstream generation passed
for Andy's November 18 timing commit. The merged four-lane, multi-troop sprite build
still requires a fresh Vivado timing run. See the
[implementation results](docs/verification/vivado_build_results.md) for the prior
baseline. Troop balance, physical controls, and monitor operation still need board testing.

## Agreed rules

- Four independent lanes. Each player may have one living copy of each card in each lane
  (up to four friendly troops per lane and 32 fixed troop slots total).
- P1 starts at the bottom end line and advances upward. P2 starts at the top and advances downward.
- Giant walks through opponents and never attacks. Other troops stop and attack the
  nearest opponent in their lane within melee range, including a Giant passing them.
- No lane changes, cross-lane damage, spells, deck cycling, friendly stacking, or special abilities.
- All four cards are directly selectable. A duplicate of the same card in the same
  friendly lane, an invalid one-hot selection, or insufficient elixir rejects deployment
  without spawning a troop or spending elixir. Different card types may share a lane.
- Each tick resolves attacks simultaneously, applies deaths, moves surviving troops, and checks touchdowns. Both players scoring in one tick is a draw. Damage on the scoring tick can kill a unit before it scores.
- Deployment follows the existing-unit update. New troops wait until the next tick before acting. Both players can deploy in the same tick.
- Touchdown means the unit's center reaches the opposing end line. A unit spawns with its center on its own end line.
- Elixir starts at 5, caps at 10, and regenerates every 60 ticks. Spending uses the elixir available at the beginning of the tick; regeneration follows spending.
- A match times out as a draw after 10,800 ticks. Reset returns to the title state.

## Controls

Each player's eight switches form an independent one-hot controller.

| Action | P1 (right side) | P2 (left side) |
| --- | --- | --- |
| Lane 1–4 (exactly one switch on) | SW3:SW0 | SW11:SW8 |
| Giant / Ice Golem / Knight / Mini P.E.K.K.A (exactly one on) | SW7:SW4 | SW15:SW12 |
| Deploy | Right button | Left button |

Set exactly one lane switch and one card switch, then press that player's deploy button. Zero or multiple switches in either group reject deployment.

- Center button: start a match from the title screen.
- Up button: immediately restart the match from any state.
- CPU RESET: return to title. Current deploy-switch positions become the baseline, so resetting/starting cannot deploy a troop accidentally.
- Seven-segment display: P2 elixir on the left pair, P1 elixir on the right pair.
- LEDs 3:0 and 11:8: P1/P2 lanes containing at least one troop. LEDs 4/12:
  rejected deployment. LEDs 5/13: valid lane-and-card selection. LED7: match running.
  LED15: game over.
- VGA shows sprite troops, lane selection, numeric elixir plus bars, normalized unit health bars, elapsed time, a tiled grass arena, and title/winner/draw overlays. Error codes next to each player are 1 = invalid selection, 2 = occupied lane, 3 = insufficient elixir.

## Initial balance values

These are adjustable starting values, not final balance. Stats are centralized in `rtl/royale_params.vh`.

| Card | Cost | HP | Damage | Move every | Attack every |
| --- | --- | --- | --- | --- | --- |
| Giant | 5 | 28 | 0 | 8 ticks | never |
| Ice Golem | 2 | 12 | 1 | 6 ticks | 45 ticks |
| Knight | 3 | 16 | 2 | 4 ticks | 30 ticks |
| Mini P.E.K.K.A | 4 | 12 | 6 | 4 ticks | 24 ticks |

Movement is one pixel per movement interval across a 360-pixel field. Melee range is 18 pixels between centers. Attack cooldowns count down continuously, allowing an immediate attack on first contact when ready. Giant can be attacked from either side while within range.

## Structure and timing

Module interfaces carry flattened vectors: slot `i` occupies `progress[i*9 +: 9]`, `health[i*8 +: 8]`, and `kind[i*2 +: 2]`. Player `p` occupies `elixir[p*4 +: 4]`, lane selection `[p*3 +: 3]`, and card/error selection `[p*2 +: 2]`.

All logic uses the board's 100 MHz clock. A pixel enable every four cycles generates 640x480 VGA with 800x525 total timing at 25 MHz (about 59.52 frames/second). Renderer snapshots, raster counters, and RGB output registers share this enable. Only their pixel data paths receive a four-cycle timing constraint; control, reset, and game logic retain the 10 ns requirement. One game tick at the beginning of vertical blank updates the complete game state before the next visible frame. Consequently 60 game ticks take about 1.008 seconds; the nominal three-minute timeout is about 181.44 seconds. There are no logic-generated clocks or vendor IP dependencies.

`game_core` caches each troop's nearest in-range opponent between updates and requires
at least one idle system-clock edge between game ticks. The board supplies 1,680,000
system clocks per frame. Seven-segment outputs are registered, adding one 10 ns clock
of display latency.

- `game_core.v`: idle/play/game-over controller, 32 card/lane slots, combat, elixir, deployment, scoring.
- `input_filter.v`, `command_capture.v`: synchronizers, stable-input filtering, independent request snapshots.
- `display_controller.v`: 640×480 VGA timing (100 MHz, 1-of-4 pixel enable), `bright`/`hSync`/`vSync`/`hCount`/`vCount`, one `game_tick` per frame.
- `vga_bitchange.v`: arena paint, unit letters, HUD (`localparam USE_SPRITES` sprite hook).
- `seven_segment.v`, `royale_top.v`: board display and integration.
- `constraints/nexys_a7_100t.xdc`: board pin assignments (EE354 port names on `royale_top`), derived from the official [Digilent master constraints](https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc).

`royale_top` ports match the XDC: `ClkPort`, active-low `BtnCpuReset`, `BtnC`, `BtnU`, `BtnL`, `BtnR`, `Sw[15:0]`, `Ld[15:0]`, VGA, seven-segment, and `QuadSpiFlashCS`.

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

Each script builds `rtl/*.v`, `rtl/sprites/*.v`, and `sim/*_tb.v`, then requires a
`PASS <test>:` line for gameplay, input, video, and display I/O. Each player has one
queued request snapshot; the latest filtered deploy-button press replaces an earlier
pending request.

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

Character and grass PNGs are under `rtl/sprites/png`; generated synchronous ROMs are under `rtl/sprites`. Regenerate them with `python3 tools/ee354_optimized_sprite_script.py image.png --output-dir rtl/sprites/png --size 20`. See `rtl/sprites/README.md` for sources and details.

The VGA archive in `instructions/` was reviewed as a reference; this implementation uses a single clock and explicit resets rather than the archive's cascaded clock dividers. Hardware operation and gameplay balance still require a physical-board playtest.
