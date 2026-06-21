#!/bin/bash
# macos-spotlight.sh — lanciatore stile Spotlight (Cmd/Super+Space) basato su rofi.
# Mostra una barra di ricerca centrata in alto da cui avviare app. Usa il tema
# frosted ~/.config/macos-xfce/spotlight.rasi se presente, altrimenti un fallback.

if ! command -v rofi >/dev/null 2>&1; then
  command -v notify-send >/dev/null 2>&1 && \
    notify-send "Spotlight" "rofi non è installato: sudo apt install rofi"
  exit 1
fi

THEME="$HOME/.config/macos-xfce/spotlight.rasi"
if [ -f "$THEME" ]; then
  exec rofi -show drun -modi drun,run -no-lazy-grab -theme "$THEME"
fi

# Fallback senza file di tema: barra stretta ancorata in alto al centro.
exec rofi \
  -show drun -modi drun,run -no-lazy-grab -p "" \
  -theme-str 'window { width: 42%; location: north; anchor: north; y-offset: 120px; border-radius: 12px; }
              listview { lines: 8; } inputbar { padding: 10px; }'
