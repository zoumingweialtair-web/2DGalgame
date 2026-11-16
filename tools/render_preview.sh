#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
capture_dir="$(mktemp -d /tmp/galgame-render.XXXXXX)"
trap 'rm -rf -- "$capture_dir"' EXIT
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/galgame-cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/galgame-data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/tmp/galgame-config}"
mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$project_dir/previews"

godot_bin="${GODOT_BIN:-godot}"
"$godot_bin" --headless --editor --path "$project_dir" --import > "$capture_dir/import.log" 2>&1

# Movie export needs a real render backend (an Xorg dummy display also works).
"$godot_bin" --path "$project_dir" --rendering-method gl_compatibility \
  --audio-driver Dummy --disable-vsync --fixed-fps 30 --quit-after 360 \
  --write-movie "$capture_dir/snow-night.avi"

ffmpeg -hide_banner -loglevel error -y -i "$capture_dir/snow-night.avi" \
  -an -vf 'pad=ceil(iw/2)*2:ceil(ih/2)*2' \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
  -movflags +faststart "$project_dir/previews/snow-night-loop.mp4"

ffmpeg -hide_banner -loglevel error -y -i "$project_dir/previews/snow-night-loop.mp4" \
  -filter_complex '[0:v]fps=15,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=3' \
  -loop 0 "$project_dir/previews/snow-night-loop.gif"

ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,nb_frames:format=duration \
  -of json "$project_dir/previews/snow-night-loop.mp4"
