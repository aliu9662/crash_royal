#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
build_dir="$project_root/build/icarus"
rtl_dir="$project_root/rtl"
mkdir -p "$build_dir"
shopt -s nullglob
sources=("$rtl_dir"/*.v)
sprites=("$rtl_dir/sprites"/*.v)
if ((${#sprites[@]})); then
    sources+=("${sprites[@]}")
fi
sources+=("$project_root"/sim/*_tb.v)
for t in game_core_tb input_tb video_tb; do
    iverilog -g2001 -Wall -I "$rtl_dir" -s "$t" -o "$build_dir/$t.vvp" "${sources[@]}"
    vvp "$build_dir/$t.vvp" | tee "$build_dir/$t.log"
    grep -Fq "PASS ${t}:" "$build_dir/$t.log"
done
echo 'All gameplay, input, and video tests passed.'
