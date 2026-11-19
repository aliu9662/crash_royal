"""Convert transparent PNG art into synchronous 12-bit Verilog sprite ROMs."""

import argparse
import math
from pathlib import Path

from PIL import Image


def color_12(pixel):
    red, green, blue, alpha = pixel
    if alpha < 96:
        return 0
    value = ((red >> 4) << 8) | ((green >> 4) << 4) | (blue >> 4)
    # Black is the renderer's transparency key.
    return value if value else 0x111


def prepare(source, size):
    image = Image.open(source).convert("RGBA")
    image.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(image, ((size - image.width) // 2, (size - image.height) // 2))
    return canvas


def write_rom(module_name, image, destination):
    width, height = image.size
    row_width = max(1, math.ceil(math.log2(height)))
    col_width = max(1, math.ceil(math.log2(width)))
    address_width = row_width + col_width
    with destination.open("w", encoding="utf-8") as output:
        output.write(
            f"`timescale 1ns/1ps\n"
            f"module {module_name}_rom (\n"
            f"    input wire clk,\n"
            f"    input wire [{row_width - 1}:0] row,\n"
            f"    input wire [{col_width - 1}:0] col,\n"
            f"    output reg [11:0] color_data\n"
            f");\n"
            f"    (* rom_style = \"block\" *) reg [11:0] sprite_rom [0:{width * height - 1}];\n"
            f"    integer index;\n"
            f"    initial begin\n"
            f"        for (index = 0; index < {width * height}; index = index + 1)\n"
            f"            sprite_rom[index] = 12'h000;\n"
        )
        for y in range(height):
            for x in range(width):
                color = color_12(image.getpixel((x, y)))
                if color:
                    output.write(f"        sprite_rom[{y * width + x}] = 12'h{color:03x};\n")
        output.write(
            "    end\n"
            "    always @(posedge clk)\n"
            f"        if (row < {height} && col < {width})\n"
            f"            color_data <= sprite_rom[row * {width} + col];\n"
            "        else\n"
            "            color_data <= 12'h000;\n"
            "endmodule\n"
        )


def generate(source, output_dir, size=20):
    source = Path(source)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    module_name = source.stem.lower().replace("-", "_").replace(" ", "_")
    image = prepare(source, size)
    image.save(output_dir / f"{module_name}.png")
    write_rom(module_name, image, output_dir.parent / f"{module_name}_rom.v")
    print(f"{source}: {image.width}x{image.height} -> {module_name}_rom.v")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("images", nargs="+")
    parser.add_argument("--output-dir", default="rtl/sprites/png")
    parser.add_argument("--size", type=int, default=20)
    args = parser.parse_args()
    for image in args.images:
        generate(image, args.output_dir, args.size)


if __name__ == "__main__":
    main()
