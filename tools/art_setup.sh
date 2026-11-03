#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker build --tag construction-train-art:4.5.15 tools/art
