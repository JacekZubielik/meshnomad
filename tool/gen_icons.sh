#!/usr/bin/env bash
# Regenerate app icon bitmaps from SVG masters (assets/icons/*.svg),
# then fan out to all platforms via flutter_launcher_icons.
# Usage: tool/gen_icons.sh
set -euo pipefail
cd "$(dirname "$0")/.."

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found (pacman -S librsvg)"; exit 1; }

rsvg-convert -w 1024 -h 1024 assets/icons/app_icon.svg            -o assets/icons/app_icon_1024.png
rsvg-convert -w 1024 -h 1024 assets/icons/app_icon_foreground.svg -o assets/icons/app_icon_foreground_1024.png

fvm dart run flutter_launcher_icons
echo "Done. Masters: assets/icons/*.svg  →  platform icons regenerated."
