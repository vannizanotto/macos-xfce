#!/bin/bash
# Dynamic wallpaper stile macOS Sonoma: chiaro di giorno, scuro di notte.
# Imposta TUTTE le prop last-image di xfce4-desktop (ogni monitor/workspace).
# Usa una coppia chiaro/scuro: prima cerca Sonoma-light/dark (se l'utente le
# possiede), altrimenti i gradienti liberi inclusi nel pacchetto.
WALL_DIR="$HOME/.local/share/wallpapers"

pick() {  # pick BASE_LIGHT_OR_DARK -> stampa il primo file esistente tra i candidati
  local want="$1" c
  for c in "Sonoma-$want.jpg" "gradient-$want.jpg"; do
    [ -f "$WALL_DIR/$c" ] && { echo "$WALL_DIR/$c"; return 0; }
  done
  return 1
}

hour=$(date +%H)
# Giorno = 07:00–18:59 -> chiaro; altrimenti scuro
if [ "$hour" -ge 7 ] && [ "$hour" -lt 19 ]; then
  IMG="$(pick light)"
else
  IMG="$(pick dark)"
fi
[ -n "$IMG" ] && [ -f "$IMG" ] || exit 0

# Applica a ogni prop last-image esistente (live, senza riavvii)
xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'last-image$' | while read -r prop; do
  xfconf-query -c xfce4-desktop -p "$prop" -s "$IMG" 2>/dev/null
done
