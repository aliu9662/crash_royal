# ModelSim verification checkpoint

Verified November 12, 2026 using ModelSim SE-64 10.6e.

All RTL and testbenches compiled with `vlog -vlog01compat`, zero compilation errors and warnings. No SystemVerilog mode was enabled.

| Testbench | Result | Coverage |
| --- | --- | --- |
| `game_core_tb` | 50 checks passed | Deployment, elixir, occupied/invalid lanes, simultaneous combat, Giant passing, lane isolation, scoring, draws, timeout, reset |
| `input_tb` | 10 checks passed | Both toggle edges, input filtering, independent requests, selection snapshots, tick-edge requests |
| `video_tb` | 8 checks passed | Full 800x525 raster, 640x480 active area, horizontal/vertical sync, frame tick, blanking, title/draw output |

The video test additionally checked all 307,200 pixels in the sample frame for unknown values. The attached image is a test fixture rendered by the hardware renderer; it is not a physical-board photograph or a recorded play session.

![ModelSim-rendered sample frame](modelsim_sample_screen.png)

Reproduce from the repository root with `./scripts/simulate_modelsim.ps1`, overriding `-ModelSimBin` if needed. ModelSim needs a working license. The generated logs and PPM image go into `build/modelsim/`.

Synthesis, implementation timing, bitstream generation, and physical-board behavior are not covered by these simulation results.
