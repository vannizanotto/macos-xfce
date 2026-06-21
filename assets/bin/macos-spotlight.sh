#!/bin/bash
# macos-spotlight.sh — lanciatore stile Spotlight (Cmd/Super+Space) basato su rofi.
# Mostra una barra di ricerca centrata in alto da cui avviare app e (se presente
# rofi >= 1.6) cercare file/calcolare. Fallback morbido se rofi non c'è.

if ! command -v rofi >/dev/null 2>&1; then
  command -v notify-send >/dev/null 2>&1 && \
    notify-send "Spotlight" "rofi non è installato: sudo apt install rofi"
  exit 1
fi

# Aspetto "alla Spotlight": finestra stretta ancorata in alto al centro.
exec rofi \
  -show drun \
  -modi drun,run \
  -theme-str 'window { width: 42%; location: north; anchor: north; y-offset: 90px; border-radius: 12px; }
              listview { lines: 8; }
              inputbar { padding: 10px; }' \
  -no-lazy-grab \
  -p ""
