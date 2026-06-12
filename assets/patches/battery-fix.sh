#!/usr/bin/env bash
# Rende monocrome le icone batteria di WhiteSur (di default verdi).
# GTK ricolora le symbolic in base alla CLASSE css (success/warning/error),
# non al fill: va rimossa la classe, non cambiato il colore.
#
# Uso: battery-fix.sh /percorso/icone/WhiteSur-light
set -euo pipefail
THEME="${1:?uso: battery-fix.sh <dir-tema-icone>}"
SYM="$THEME/status/symbolic"
[ -d "$SYM" ] || { echo "cartella symbolic non trovata in $THEME"; exit 0; }

bak="$THEME/_backup_battery_symbolic"
mkdir -p "$bak"
n=0
shopt -s nullglob
for f in "$SYM"/battery*.svg; do
  [ -e "$bak/$(basename "$f")" ] || cp "$f" "$bak/"
  sed -i -E 's/ class="(success|warning|error)"//g' "$f"
  n=$((n+1))
done
echo "icone batteria rese monocrome: $n (backup in $bak)"
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache "$THEME" 2>/dev/null || true
