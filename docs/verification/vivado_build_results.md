# Vivado implementation checkpoint — November 18, 2026

Reviewed partner commit `02b08d7` (`V1`) and implemented the timing/build fixes described below. The bitstream includes these fixes in addition to V1; its exact source hashes are recorded in the local build manifest.

## Tool and target

- Vivado Enterprise 2026.1, build 6511674, Windows 64-bit.
- Nexys A7-100T, `xc7a100tcsg324-1`.
- Verilog-2001 sources; no SystemVerilog conversion or vendor IP required.
- The licensed installation is `C:/AMDDesignTools/2026.1/Vivado`.

## Final results

| Check | Result |
| --- | --- |
| Synthesis | Passed; zero errors and zero critical warnings |
| Placement and routing | Completed |
| Post-route physical optimization | Completed with `AggressiveExplore` |
| Worst setup slack | +0.010 ns |
| Total negative setup slack | 0.000 ns; zero failing endpoints |
| Worst hold slack | +0.050 ns |
| Total negative hold slack | 0.000 ns; zero failing endpoints |
| Worst pulse-width slack | +4.500 ns; zero failing endpoints |
| Unconstrained internal endpoints | Zero |
| Registers without a clock | Zero |
| Design-rule violations | Zero in the final default-ruledeck report |
| Slice LUTs | 2,914 / 63,400 (4.60%) |
| Slice registers | 800 / 126,800 (0.63%) |
| Latches, block RAM, DSPs | Zero |

The setup margin is small. Repeat implementation after any RTL or constraint change rather than reusing this result. Physical-board programming, monitor compatibility, controls, and gameplay balance remain untested.

## Changes required

1. **Build entry points:** detect installed Vivado instead of assuming a 2024.1 installation. Capture launcher/license output. Pass the include directory to `synth_design`, which supports it, rather than `read_verilog`.
2. **Renderer arithmetic:** replace signed 32-bit glyph/text division with bounded unsigned arithmetic for the actual scales and screen ranges. A ModelSim comparison against V1 produced identical output for 1,536,000 pixels across five full screens.
3. **Combat timing:** calculate each lane's bounded progress sum and cache contact between game updates. The core requires at least one idle system-clock edge between game ticks; the board supplies one tick per 1,680,000 clocks. ModelSim matched V1 for 20,000 comparisons, including randomized combat fixtures and sequential play at the minimum supported spacing.
4. **Display registers:** register seven-segment outputs and capture renderer inputs on the same pixel enable as the raster and RGB registers. Seven-segment latency increases by one 10 ns clock; renderer snapshots add at most one 40 ns pixel interval.
5. **Timing constraints:** apply the pixel-only multicycle constraints after synthesis, when the mapped registers exist. Correct the output constraints for asynchronous board peripherals. Keep game logic and pixel control paths at 100 MHz.
6. **Final implementation:** the initial route missed setup by 0.163 ns. Post-route physical optimization closed that miss. `scripts/finish_build.tcl` performs this optimization when needed, writes reports, and retains setup, hold, and DRC gates before `write_bitstream`.

The reviewed synthesis warnings concern deliberately unused switches, the constant inactive flash-select output, and the currently unused renderer clock port. No latches were inferred. The 14 asynchronous button/switch input paths are intentionally excluded up to the synchronizer entry/reset boundary; subsequent synchronous paths are timed.

## Timing assumptions

The primary clock is 100 MHz (10 ns). Raster counters, renderer snapshot registers, and RGB output registers share the one-in-four pixel enable. Only paths from these source registers' clock pins to RGB data pins use setup multicycle 4 and hold multicycle 3. Their enable/reset paths retain the ordinary 10 ns requirement. Other register paths are not covered by that exception.

LEDs, seven-segment outputs, and analog VGA have no external 100 MHz capture clock. Their constraint limits register-to-pad propagation plus a 2 ns external allowance to 10 ns, using `set_max_delay -datapath_only` from `ClkPort` to output ports. This excludes clock-tree insertion and synchronous hold analysis for those asynchronous peripherals. RGB and sync are held for 40 ns. This is a design propagation budget, not a measured monitor setup/hold specification.

The pixel exception follows AMD's [common-enable multicycle guidance](https://docs.amd.com/r/2026.1-English/ug949-vivado-design-methodology/Relaxing-the-Setup-Requirement-While-Keeping-Hold-Unchanged). AMD documents the removal of clock skew and hold checking for [`set_max_delay -datapath_only`](https://docs.amd.com/r/en-US/ug903-vivado-using-constraints/List-of-Nodes-for-the-through-Option), and supports [post-route physical optimization](https://docs.amd.com/r/2026.1-English/ug904-vivado-implementation/phys_opt_design?contentId=esUUddQBWaTTp_~qd4AgEg).

## Simulation and artifacts

ModelSim SE-64 10.6e compiled the current RTL/testbenches using `-vlog01compat`, with zero compilation errors or warnings. Gameplay/input/video/display I/O passed 51/11/22/1,155 checks. See [simulation results](simulation_results.md) for scope and reference comparisons.

Generated artifacts are local and excluded from Git:

- `build/royale_top.bit`: programming bitstream.
- `build/build_manifest.json`: base commit, local source-file hashes, and bitstream hash. This bitstream is 3,825,990 bytes, SHA-256 `8501122c8e81d5ee50840aaa3f4e8aeaf0312c00e36c6bf04d4db9d27c8157c1`.
- `build/routed.dcp`: final optimized routed checkpoint.
- `build/timing.rpt`, `critical_paths.rpt`, `utilization.rpt`, `drc.rpt`: final reports.
- `build/build.log`: synthesis through initial routing; its final timing error precedes the successful post-route optimization.
- `build/finish_build.log`: resumed routed checkpoint, final optimization, reports, gates, and bitstream generation.
- `build/questasim/`: four regression logs and sample frame.
- `build/core_equivalence/`, `build/renderer_equivalence/`: one-time reference-comparison logs.

Reproduce the complete flow from the repository root with `./scripts/build.ps1`. The build automatically sources `constraints/pixel_timing.tcl` after synthesis and `scripts/finish_build.tcl` after routing. A valid Vivado license is required.
