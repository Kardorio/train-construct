#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tools/art-output
render_log="$PWD/.tools/art-output/last-render.log"
if docker run --rm --network none --read-only --cpus 4 --memory 6g \
  --cap-drop ALL --security-opt no-new-privileges \
  --user "$(id -u):$(id -g)" \
  --tmpfs /tmp:rw,nosuid,nodev,size=1g \
  --mount "type=bind,source=$PWD,target=/workspace,readonly" \
  --mount "type=bind,source=$PWD/.tools/art-output,target=/workspace/.tools/art-output" \
  construction-train-art:4.5.15 "$@" >"$render_log" 2>&1; then
  tail -n 1 "$render_log"
else
  tail -n 60 "$render_log"
  exit 1
fi
