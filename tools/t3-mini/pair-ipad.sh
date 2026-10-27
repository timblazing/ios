#!/bin/sh
# Mint a one-time T3 Chat pairing code (read + operate, 10 minutes) and print what to type on the iPad.
set -eu
port=${PORT:-3774}
ip=${LAN_IP:-$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)}
[ -n "$ip" ] || { echo "No LAN address found; set LAN_IP." >&2; exit 1; }
lsof -nP -iTCP@"$ip":"$port" -sTCP:LISTEN >/dev/null 2>&1 ||
  echo "Warning: no LAN adapter on $ip:$port. Start: python3 tools/t3-mini/lan-gateway.py --listen $ip --port $port --allow-chat" >&2
code=$(t3 auth pairing create --scope orchestration:read --scope orchestration:operate --ttl 10m \
  --label "T3 Chat (iPad)" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["credential"])')
printf '\nOn the iPad, open Connection and enter:\n\n  Address  %s:%s\n  Code     %s\n\nThe code works once and expires in 10 minutes.\n' "$ip" "$port" "$code"
