#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tools/art-output
preview_dir="$PWD/.tools/art-output"
google-chrome --headless --disable-gpu --no-first-run --hide-scrollbars \
  --disable-background-networking --disable-sync --disable-extensions \
  --user-data-dir="$preview_dir/chrome-profile" \
  --force-device-scale-factor=1 --window-size=1440,1800 \
  --virtual-time-budget=3000 \
  --screenshot="$preview_dir/depot-sprites.png" \
  "file://$PWD/docs/depot-sprite-preview.html" >"$preview_dir/preview.log" 2>&1
tail -n 1 "$preview_dir/preview.log"
