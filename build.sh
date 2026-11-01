#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
case "${1:-}" in
 package|devlink|link|unlink|clean) python3 tools/build.py "$1" ;;
 test) python3 tests/run.py ;;
 lint) bash -n build.sh; python3 tests/run.py --lint ;;
 *) echo 'Usage: ./build.sh {test|lint|package|devlink|unlink|clean}'; [[ $# -eq 0 ]] ;;
esac
