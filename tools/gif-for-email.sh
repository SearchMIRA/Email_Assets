#!/usr/bin/env bash
# Compress a GIF until it is small enough to animate in Gmail.
#
#   tools/gif-for-email.sh videos/ui.gif [output.gif]
#
# Env overrides:
#   TARGET_MB=2      size to aim for
#   TRIM=8           only keep the first N seconds (biggest lever by far)
#   WIDTH=800        starting width; the ladder steps down from here
#
# Gmail serves only the first frame of oversized animated GIFs, so an
# uncompressed screen recording silently turns into a still image.
set -euo pipefail

SRC="${1:?usage: gif-for-email.sh <input.gif> [output.gif]}"
DST="${2:-${SRC%.gif}-email.gif}"
TARGET_MB="${TARGET_MB:-2}"
WIDTH="${WIDTH:-800}"
TRIM="${TRIM:-}"

for tool in ffmpeg gifsicle; do
  command -v "$tool" >/dev/null || { echo "missing $tool (brew install $tool)" >&2; exit 1; }
done

target_bytes=$(awk "BEGIN{printf \"%d\", $TARGET_MB * 1048576}")
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mb() { awk "BEGIN{printf \"%.2f\", $1/1048576}"; }

# Quality ladder: give up resolution and frame rate before giving up detail.
# Each rung is "width fps colors lossy".
ladder=(
  "$WIDTH 12.5 64 60"
  "$WIDTH 12.5 64 100"
  "$WIDTH 10 64 100"
  "$((WIDTH * 8 / 10)) 10 64 100"
  "$((WIDTH * 8 / 10)) 10 48 140"
  "$((WIDTH * 64 / 100)) 10 48 140"
)

best=""
for rung in "${ladder[@]}"; do
  read -r w fps colors lossy <<<"$rung"
  raw="$tmp/raw.gif"
  out="$tmp/out.gif"

  # dither=none is deliberate: dithering adds high-frequency noise that
  # defeats both LZW and gifsicle's lossy pass, inflating the file 40%+.
  ffmpeg -v error -y ${TRIM:+-t "$TRIM"} -i "$SRC" \
    -filter_complex "fps=${fps},scale=${w}:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=${colors}:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" \
    "$raw"
  gifsicle -O3 --lossy="$lossy" "$raw" -o "$out" 2>/dev/null

  size=$(stat -f%z "$out" 2>/dev/null || stat -c%s "$out")
  echo "  ${w}px ${fps}fps ${colors}c lossy=${lossy} -> $(mb "$size") MB"
  best="$out"
  cp "$out" "$tmp/best.gif"

  if [ "$size" -le "$target_bytes" ]; then
    cp "$tmp/best.gif" "$DST"
    echo "OK  $DST  $(mb "$size") MB (target ${TARGET_MB} MB)"
    exit 0
  fi
done

cp "$tmp/best.gif" "$DST"
final=$(stat -f%z "$DST" 2>/dev/null || stat -c%s "$DST")
echo "WARN $DST  $(mb "$final") MB — still over ${TARGET_MB} MB." >&2
echo "     Duration is the dominant factor (~0.3 MB per second of UI motion)." >&2
echo "     Re-run with TRIM=8 to keep only the first 8 seconds." >&2
exit 1
