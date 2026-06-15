#!/bin/bash
# Finalizzazione al PRIMO login reale (una tantum, poi si auto-rimuove).
#
# Perché serve: l'installer può essere girato in un contesto diverso dalla
# sessione di login reale (via SSH, in headless, o con un altro monitor
# collegato). xfdesktop applica il wallpaper PER-MONITOR: se il monitor del
# login differisce da quello presente all'install, lo sfondo resta quello della
# distro. Qui lo ri-applichiamo sul monitor effettivamente presente + spegniamo
# le icone sul desktop, poi rimuoviamo l'autostart così gira una sola volta.
sleep 4

WALL="$(cat "$HOME/.config/macos-xfce/wallpaper" 2>/dev/null)"
[ -f "$WALL" ] || WALL="$(ls "$HOME"/.local/share/wallpapers/gradient-light.jpg 2>/dev/null | head -1)"

if [ -f "$WALL" ] && command -v xfconf-query >/dev/null 2>&1; then
  # tutte le prop last-image / last-single-image già esistenti
  for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E 'last-image$|last-single-image$'); do
    xfconf-query -c xfce4-desktop -p "$p" -s "$WALL" 2>/dev/null
    xfconf-query -c xfce4-desktop -p "${p%/*}/image-style" -t int -s 5 --create 2>/dev/null
  done
  # e il monitor effettivamente connesso adesso (se non aveva già una prop)
  mon="$(xrandr 2>/dev/null | awk '/ connected/{print $1; exit}')"
  if [ -n "$mon" ]; then
    xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor${mon}/workspace0/last-image" -t string -s "$WALL" --create 2>/dev/null
    xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor${mon}/workspace0/image-style" -t int -s 5 --create 2>/dev/null
  fi
  # desktop pulito stile macOS
  xfconf-query -c xfce4-desktop -p /desktop-icons/style -t int -s 0 --create 2>/dev/null
  command -v xfdesktop >/dev/null 2>&1 && xfdesktop --reload >/dev/null 2>&1
fi

# una tantum: rimuovi l'autostart (lo script può restare, è innocuo)
rm -f "$HOME/.config/autostart/macos-xfce-firstrun.desktop"
