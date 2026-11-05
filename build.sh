#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
case "${1:-}" in
 package) python3 tools/build.py "$@" ;;
 devlink|link|unlink|clean) python3 tools/build.py "$1" ;;
 test-py) python3 tests/pyanodon.py "${@:2}" ;;
 test-ashes) python3 tests/ashes.py "${@:2}" ;;
 test)
   if [[ $# -eq 3 && $2 == --scenario && $3 == legacy-upgrade ]]; then python3 tests/legacy.py
   elif [[ $# -gt 1 ]]; then python3 tests/engine.py "${@:2}"
   else python3 tests/run.py
   fi
   ;;
 lint) bash -n build.sh tools/art_setup.sh tools/art.sh tools/art_preview.sh; python3 tests/run.py --lint ;;
 art-setup) bash tools/art_setup.sh ;;
 art-experiment) bash tools/art.sh "${@:2}" ;;
 sprites-preview)
   python3 tools/art/make_preview.py
   bash tools/art_preview.sh
   ;;
 sprites-check)
   python3 tools/art/prepare_sprites.py --check
   python3 tests/graphics.py
   ;;
 *) echo 'Usage: ./build.sh {test|test-py|test-ashes|lint|package|devlink|unlink|clean|art-setup|art-experiment|sprites-check|sprites-preview}'; [[ $# -eq 0 ]] ;;
esac
