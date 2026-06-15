#!/bin/bash
# Finalizzazione al PRIMO login reale (una tantum, poi si auto-rimuove).
#
# Perché serve: l'installer può essere girato in un contesto diverso dalla
# sessione di login reale (via SSH, in headless, o con un altro monitor
# collegato). xfdesktop applica il wallpaper PER-MONITOR e PER-WORKSPACE: se il
# monitor del login differisce da quello presente all'install — o l'utente aveva
# già uno sfondo proprio per-workspace — lo sfondo resta quello vecchio. Qui lo
# ri-applichiamo sul monitor effettivo (tutti i workspace) + spegniamo le icone
# sul desktop, poi rimuoviamo l'autostart così gira una sola volta.
sleep 5

WALL="$(cat "$HOME/.config/macos-xfce/wallpaper" 2>/dev/null)"
[ -f "$WALL" ] || WALL="$(ls "$HOME"/.local/share/wallpapers/gradient-light.jpg 2>/dev/null | head -1)"
[ -f "$WALL" ] && command -v xfconf-query >/dev/null 2>&1 || { rm -f "$HOME/.config/autostart/macos-xfce-firstrun.desktop"; exit 0; }

apply_wallpaper() {
  # tutte le prop last-image / last-single-image già esistenti (qualsiasi monitor/workspace)
  for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E 'last-image$|last-single-image$'); do
    xfconf-query -c xfce4-desktop -p "$p" -s "$WALL" 2>/dev/null
    xfconf-query -c xfce4-desktop -p "${p%/*}/image-style" -t int -s 5 --create 2>/dev/null
  done
  # monitor effettivamente connesso adesso: forza TUTTI i workspace (0-3), anche
  # se l'utente aveva uno sfondo proprio per-workspace.
  mon="$(xrandr 2>/dev/null | awk '/ connected/{print $1; exit}')"
  if [ -n "$mon" ]; then
    for ws in 0 1 2 3; do
      xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor${mon}/workspace${ws}/last-image" -t string -s "$WALL" --create 2>/dev/null
      xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor${mon}/workspace${ws}/image-style" -t int -s 5 --create 2>/dev/null
    done
  fi
  xfconf-query -c xfce4-desktop -p /desktop-icons/style -t int -s 0 --create 2>/dev/null
}

# Ri-applica più volte: xfdesktop crea le prop per-workspace IN RITARDO e può
# riscrivere il proprio valore in memoria -> ripetere copre la race.
apply_wallpaper; sleep 3; apply_wallpaper; sleep 2; apply_wallpaper
command -v xfdesktop >/dev/null 2>&1 && xfdesktop --reload >/dev/null 2>&1

# una tantum: rimuovi l'autostart (lo script può restare, è innocuo)
rm -f "$HOME/.config/autostart/macos-xfce-firstrun.desktop"
