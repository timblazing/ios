#!/usr/bin/env bash
# Offline tests: M3U parsing and TS->HLS segmentation, verified with ffprobe.
# Always generates a self-contained 640x360 H.264/AAC fixture with ffmpeg; also runs /tmp/espn.ts if present.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build-tests.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

Tests/stream-tests m3u Tests/fixtures/sample.m3u

ffmpeg -v error -f lavfi -i testsrc=size=640x360:rate=30 -f lavfi -i "sine=frequency=440:sample_rate=48000" \
  -c:v libx264 -preset ultrafast -g 30 -keyint_min 30 -sc_threshold 0 -pix_fmt yuv420p -c:a aac -ac 2 -t 12 \
  -f mpegts "$work/fixture.ts"
inputs=("$work/fixture.ts")
[[ -f /tmp/espn.ts ]] && inputs+=(/tmp/espn.ts) || echo "note: /tmp/espn.ts not found, skipping the real-capture run"

# HEVC (like a 4K channel) must be rejected with a clear codec name rather than spinning forever.
ffmpeg -v error -f lavfi -i testsrc=size=320x180:rate=30 -f lavfi -i "sine=sample_rate=48000" \
  -c:v libx265 -x265-params log-level=error -preset ultrafast -c:a ac3 -t 2 -f mpegts "$work/hevc.ts"
Tests/stream-tests unsupported "$work/hevc.ts" "HEVC (H.265)"

Tests/stream-tests segment "$work/out" "${inputs[@]}"

status=0
checked=0
for seg in "$work"/out/*.ts; do
  codecs=$(ffprobe -v error -show_entries stream=codec_name -of csv=p=0 "$seg" | grep . | sort -u | tr '\n' ' ')
  key=$(ffprobe -v error -select_streams v -show_frames -read_intervals %+#1 -show_entries frame=key_frame -of csv=p=0 "$seg" | head -1 | cut -d, -f1)
  if [[ "$codecs" != "aac h264 " || "$key" != "1" ]]; then
    echo "FAIL $(basename "$seg"): codecs='$codecs' first-frame key_frame='$key'"; status=1
  fi
  checked=$((checked + 1))
done
echo "ffprobe: $checked segments checked (h264+aac, first frame is a keyframe)"
[[ $checked -gt 0 ]] || status=1
exit $status
