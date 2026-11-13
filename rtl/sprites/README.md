# Sprite ROMs (EE354 flow)

PNG art is turned into block-RAM ROM modules with `tools/ee354_optimized_sprite_script.py`
(from the course optimized sprite script). Edit the driver at the bottom of that file to
call `generate("your.png")` or import `generate` from another driver.

Expected unit PNGs in this folder (or repo root while generating):

- `giant.png`, `ice_golem.png`, `knight.png`, `mini_pekka.png`

The script writes `<basename>_12_bit_rom.v` in the current working directory.
Rename or copy those files here as `giant_rom.v`, `ice_golem_rom.v`, etc. if you prefer
shorter names. Each module is named `<basename>_rom`, for example `giant_rom`.

## ROM interface

From the script, address widths are:

```
row_width = ceil(log2(height - 1))
col_width = ceil(log2(width - 1))
```

(height/width are image row and column counts). The port list is:

```verilog
module giant_rom (
    input wire clk,
    input wire [row_width-1:0] row,
    input wire [col_width-1:0] col,
    output reg [11:0] color_data
);
```

`row` and `col` are registered inside the ROM, so `color_data` is valid one clock after
the address inputs change. Pixels equal to the mask color are stored as `12'h000`
(transparent). Do not use pure black for visible pixels if you rely on transparency.

Recommended size is **20×20** pixels (5-bit `row` and 5-bit `col`), close to the 19×19
unit box in `vga_bitchange.v`.

## Build and simulation

Place generated `.v` files in `rtl/sprites/`. The repo build and sim scripts already
include `rtl/sprites/*.v` when present:

- `scripts/build.tcl`
- `scripts/simulate_icarus.ps1`, `scripts/simulate_icarus.sh`
- `scripts/simulate_questasim.ps1`

In `vga_bitchange.v`, set `localparam USE_SPRITES = 1` and instantiate each `*_rom` at
the `// SPRITE HOOK` comment, wiring VGA pixel coordinates into `row`/`col` and blending
`color_data` when it is not `12'h000`.
