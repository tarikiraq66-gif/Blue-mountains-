#!/usr/bin/env bash
# Assemble clips/01.mp4..10.mp4 into blue_mountain_skiing_broll.mp4 (1080p30, warm grade,
# short cross-dissolves, optional music.mp3 bed with fades).
set -euo pipefail
cd "$(dirname "$0")"

DURS=(4 3 3 3 2.5 3 3 3 2.5 3)   # seconds used from each clip
XF=0.4                           # cross-dissolve length
OUT=blue_mountain_skiing_broll.mp4

inputs=(); filters=""
for i in "${!DURS[@]}"; do
  n=$(printf "%02d" $((i + 1)))
  [[ -f clips/$n.mp4 ]] || { echo "missing clips/$n.mp4" >&2; exit 1; }
  inputs+=(-i "clips/$n.mp4")
  filters+="[$i:v]trim=0:${DURS[$i]},setpts=PTS-STARTPTS,scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,fps=30,format=yuv420p,eq=saturation=1.08:contrast=1.04,colorbalance=rm=0.03:bm=-0.03[v$i];"
done

# Chain cross-dissolves.
prev="v0"; offset=0
for ((i = 1; i < ${#DURS[@]}; i++)); do
  offset=$(python3 -c "print($offset + ${DURS[$((i - 1))]} - $XF)")
  filters+="[$prev][v$i]xfade=transition=fade:duration=$XF:offset=$offset[x$i];"
  prev="x$i"
done
total=$(python3 -c "print($offset + ${DURS[-1]})")
filters+="[$prev]fade=t=in:d=0.5,fade=t=out:st=$(python3 -c "print($total - 0.8)"):d=0.8[vout]"

if [[ -f music.mp3 ]]; then
  ffmpeg -y "${inputs[@]}" -i music.mp3 -filter_complex \
    "$filters;[${#DURS[@]}:a]atrim=0:$total,volume=0.6,afade=t=in:d=1,afade=t=out:st=$(python3 -c "print($total - 2)"):d=2[aout]" \
    -map "[vout]" -map "[aout]" -c:v libx264 -crf 18 -preset slow -c:a aac -b:a 192k "$OUT"
else
  ffmpeg -y "${inputs[@]}" -filter_complex "$filters" -map "[vout]" -an \
    -c:v libx264 -crf 18 -preset slow "$OUT"
fi
echo "Wrote $OUT (${total}s)"
