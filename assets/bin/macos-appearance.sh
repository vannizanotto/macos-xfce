#!/bin/bash
# macos-appearance.sh [auto|light|dark|toggle] — commuta l'aspetto chiaro/scuro
# stile macOS ("Appearance"): tema GTK/WM/shell + icone + wallpaper, in modo
# DE-aware (Cinnamon via gsettings, XFCE via xfconf-query).
#   auto   (default) sceglie chiaro/scuro in base all'ora (giorno 07–19 = chiaro)
#   toggle inverte lo stato attuale (per scorciatoia, es. Super+Shift+D)
#   light/dark forzano lo stato
# Se la variante WhiteSur-Dark NON è installata, resta sul tema chiaro (non rompe).
set -u
WALL_DIR="$HOME/.local/share/wallpapers"
mode="${1:-auto}"

detect_de() {
  case "${XDG_CURRENT_DESKTOP:-}${DESKTOP_SESSION:-}" in
    *[Xx]fce*)     echo xfce; return;;
    *[Cc]innamon*) echo cinnamon; return;;
  esac
  if   pgrep -x cinnamon >/dev/null 2>&1; then echo cinnamon
  elif pgrep -x xfwm4    >/dev/null 2>&1; then echo xfce
  else echo unknown; fi
}
DE="$(detect_de)"

current_is_dark() {
  case "$DE" in
    cinnamon) gsettings get org.cinnamon.desktop.interface gtk-theme 2>/dev/null | grep -qi dark;;
    xfce)     xfconf-query -c xsettings -p /Net/ThemeName 2>/dev/null | grep -qi dark;;
    *) return 1;;
  esac
}

case "$mode" in
  light)  want=light;;
  dark)   want=dark;;
  toggle) current_is_dark && want=light || want=dark;;
  auto|*) h=$(date +%H); { [ "$h" -ge 7 ] && [ "$h" -lt 19 ]; } && want=light || want=dark;;
esac

theme_exists() { [ -d "$HOME/.themes/$1" ] || [ -d "/usr/share/themes/$1" ]; }

pick_wall() {  # pick_wall light|dark -> stampa il primo wallpaper esistente
  local w="$1" c
  for c in "Sonoma-$w.jpg" "gradient-$w.jpg"; do
    [ -f "$WALL_DIR/$c" ] && { echo "$WALL_DIR/$c"; return 0; }
  done
  return 1
}

if [ "$want" = dark ]; then GTK="WhiteSur-Dark"; ICON="WhiteSur-dark"
else                        GTK="WhiteSur-Light"; ICON="WhiteSur-light"; fi
# fallback: niente variante Dark installata -> non spezzare il tema
theme_exists "$GTK" || { GTK="WhiteSur-Light"; ICON="WhiteSur-light"; }
IMG="$(pick_wall "$want" || true)"

case "$DE" in
  cinnamon)
    # Cinnamon preferisce la variante -solid (pannello opaco)
    solid="$GTK-solid"; theme_exists "$solid" || solid="$GTK"
    gsettings set org.cinnamon.desktop.interface gtk-theme "$solid"
    gsettings set org.cinnamon.theme name "$solid"
    gsettings set org.cinnamon.desktop.wm.preferences theme "$solid"
    gsettings set org.cinnamon.desktop.interface icon-theme "$ICON"
    [ -n "$IMG" ] && gsettings set org.cinnamon.desktop.background picture-uri "file://$IMG"
    ;;
  xfce)
    xfconf-query -c xsettings -p /Net/ThemeName     -s "$GTK"  2>/dev/null || true
    xfconf-query -c xfwm4     -p /general/theme      -s "$GTK"  2>/dev/null || true
    xfconf-query -c xsettings -p /Net/IconThemeName -s "$ICON" 2>/dev/null || true
    if [ -n "$IMG" ]; then
      xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'last-image$' | while read -r p; do
        xfconf-query -c xfce4-desktop -p "$p" -s "$IMG" 2>/dev/null || true
      done
    fi
    ;;
esac
