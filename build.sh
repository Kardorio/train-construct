#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
case "${1:-}" in
 package|devlink|link|unlink|clean) python3 tools/build.py "$1" ;;
 test)
   if [[ $# -eq 3 && $2 == --scenario && $3 == legacy-upgrade ]]; then python3 tests/legacy.py
   elif [[ $# -gt 1 ]]; then python3 tests/engine.py "${@:2}"
   else python3 tests/run.py
   fi
   ;;
 lint) bash -n build.sh; python3 tests/run.py --lint ;;
 *) echo 'Usage: ./build.sh {test|lint|package|devlink|unlink|clean}'; [[ $# -eq 0 ]] ;;
esac
