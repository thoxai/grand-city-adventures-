#!/usr/bin/env bash
# Führt alle automatisierten Tests headless aus. Exit-Code 0 = alles grün.
# Nutzung: GODOT=/pfad/zu/godot tools/run_tests.sh [--suite=name]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Beim ersten Lauf Klassen-Cache erzeugen (class_name-Registrierung)
if [ ! -f .godot/global_script_class_cache.cfg ]; then
  "$GODOT" --headless --editor --quit >/dev/null 2>&1 || true
fi
"$GODOT" --headless --fixed-fps 60 --path . res://tests/test_runner.tscn -- "$@"
