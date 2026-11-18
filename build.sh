#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
case "${1:-}" in
 package) python3 tools/build.py "$@" ;;
 devlink|link|unlink|clean) python3 tools/build.py "$1" ;;
 devlink-beta) python3 tools/devlink_beta.py ;;
 test-py) python3 tests/pyanodon.py "${@:2}" ;;
 test-ashes) python3 tests/ashes.py "${@:2}" ;;
 test-tools) python3 tests/train_tools.py ;;
 test-blueprints) python3 tests/depot_settings.py ;;
 test-obstacles) python3 tests/obstacles.py "${@:2}" ;;
 test)
   if [[ $# -eq 3 && $2 == --scenario && $3 == legacy-upgrade ]]; then python3 tests/legacy.py
   elif [[ $# -gt 1 ]]; then python3 tests/engine.py "${@:2}"
   else python3 tests/run.py
   fi
   ;;
 lint) bash -n build.sh; python3 tests/run.py --lint ;;
 sprites-check)
   python3 tools/art/prepare_sprites.py --check
   python3 tests/graphics.py
   python3 tests/train_graphics.py
   ;;
 *)
   if [[ $# -gt 0 && -f tools/local_commands.sh ]]; then
     bash tools/local_commands.sh "$@"
   else
     echo 'Usage: ./build.sh {test|test-py|test-ashes|test-tools|test-blueprints|test-obstacles|lint|package|devlink|devlink-beta|unlink|clean|sprites-check}'
     [[ $# -eq 0 ]]
   fi
   ;;
esac
