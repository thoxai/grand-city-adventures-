#!/usr/bin/env bash
# Rendert Screenshots mit Software-Vulkan (lavapipe) in einem virtuellen X-Server.
# Nutzung: GODOT=/pfad/zu/godot tools/run_screenshots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
if [ -f /opt/lavapipe/lvp_icd.json ]; then export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json; fi
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver vulkan --rendering-method mobile --resolution 1280x720 res://tools/screenshot_runner.tscn
