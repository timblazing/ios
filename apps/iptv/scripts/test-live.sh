#!/usr/bin/env bash
# End to end on the Mac: relay a live channel, then make ffprobe and ffmpeg read the local HLS playlist.
# usage: scripts/test-live.sh http://<server>:9191/proxy/ts/stream/<uuid>
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# -eq 1 ]] || { echo "usage: $0 <channel stream URL>" >&2; exit 64; }
scripts/build-tests.sh
log=$(mktemp)
Tests/stream-tests serve "$1" 60 > "$log" &
pid=$!
trap 'kill $pid 2>/dev/null || true; rm -f "$log"' EXIT
url=""
for _ in $(seq 1 60); do
  url=$(awk '/^PLAYLIST /{print $2}' "$log")
  [[ -n "$url" ]] && break
  grep -q '^FAILURE' "$log" && { cat "$log"; exit 1; }
  sleep 1
done
[[ -n "$url" ]] || { echo "relay never became ready"; cat "$log"; exit 1; }
echo "ready: $url"
curl -s "$url"
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate -of compact "$url"
ffmpeg -v error -i "$url" -t 8 -f null -
echo "ffprobe + ffmpeg OK"
