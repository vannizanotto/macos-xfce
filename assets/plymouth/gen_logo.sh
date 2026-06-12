#!/usr/bin/env bash
# Rigenera logo.png (limone per lo splash) rasterizzando l'SVG del menu con
# Chrome headless (non servono rsvg/inkscape/imagemagick). L'SVG è colorato
# (Noto Emoji), quindi lo si rende così com'è su sfondo trasparente.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVG="$HERE/../icons/lemon-logo.svg"
OUT="$HERE/logo.png"
CHROME="$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)"
[ -n "$CHROME" ] || { echo "Chrome/Chromium non trovato"; exit 1; }

TMP="$(mktemp -d)"
cp "$SVG" "$TMP/logo.svg"
cat > "$TMP/l.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8">
<style>html,body{margin:0;background:transparent}img{display:block;width:220px;height:220px;margin:18px}</style>
</head><body><img src="logo.svg"></body></html>
HTML
"$CHROME" --headless=new --disable-gpu --hide-scrollbars \
  --default-background-color=00000000 --window-size=256,256 \
  --screenshot="$OUT" "file://$TMP/l.html" >/dev/null 2>&1
rm -rf "$TMP"
echo "rigenerato: $OUT"
