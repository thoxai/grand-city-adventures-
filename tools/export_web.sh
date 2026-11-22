#!/usr/bin/env bash
# Baut die Web-Version und packt sie als ZIP zum Hochladen auf einen Webserver.
# Voraussetzung: Godot 4.5.1 + installierte Export-Vorlagen (Web).
# Nutzung: GODOT=/pfad/zu/godot tools/export_web.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=export/web
rm -rf "$OUT" && mkdir -p "$OUT"
if [ ! -f .godot/global_script_class_cache.cfg ]; then
  "$GODOT" --headless --editor --quit >/dev/null 2>&1 || true
fi
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html"
# Apache: korrekte MIME-Typen und Kompression (wird von nginx ignoriert)
cat > "$OUT/.htaccess" <<'HT'
AddType application/wasm .wasm
AddType application/octet-stream .pck
<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE application/wasm application/javascript text/html application/octet-stream
</IfModule>
<IfModule mod_expires.c>
  ExpiresActive On
  ExpiresByType application/wasm "access plus 7 days"
</IfModule>
HT
(cd "$OUT" && zip -q -r -9 ../grand-city-adventures-web.zip . -x '*.import')
echo "Fertig: $OUT/ und export/grand-city-adventures-web.zip"
ls -la export/grand-city-adventures-web.zip
