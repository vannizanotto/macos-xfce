#!/usr/bin/env bash
# Strato di astrazione desktop-environment per il tema macOS.
# Permette allo stesso installer di girare su XFCE (xfconf-query) e Cinnamon
# (gsettings/dconf). Gli ASSET (tema, icone, font, dock, wallpaper) sono
# condivisi; qui si astrae solo l'APPLICAZIONE delle impostazioni.
#
# Uso: dopo aver sourcato lib/common.sh, sourcare anche lib/de.sh, poi chiamare
# le funzioni de_* invece delle xfconf-query dirette.

# --- rilevamento desktop ----------------------------------------------------
# Ritorna: "xfce" | "cinnamon" | "unknown"
de_detect() {
  local d="${XDG_CURRENT_DESKTOP:-}${DESKTOP_SESSION:-}"
  case "${d,,}" in
    *xfce*)     echo xfce;;
    *cinnamon*) echo cinnamon;;
    *)
      # fallback: indovina dagli strumenti presenti
      if have xfconf-query; then echo xfce
      elif have cinnamon; then echo cinnamon
      else echo unknown; fi
      ;;
  esac
}

DE="$(de_detect)"

# helper gsettings tollerante (schema/chiave mancante = no-op con warning soft)
gset() {  # gset SCHEMA KEY VALUE
  have gsettings || return 0
  gsettings writable "$1" "$2" >/dev/null 2>&1 || { dim "gsettings: $1 $2 non scrivibile, salto"; return 0; }
  gsettings set "$1" "$2" "$3" 2>/dev/null || dim "gsettings set $1 $2 fallito"
}

# --- guardia: il DE è gestito? ----------------------------------------------
de_supported() { [ "$DE" = xfce ] || [ "$DE" = cinnamon ]; }
de_require() {
  de_supported && return 0
  err "desktop non supportato (rilevato: '${XDG_CURRENT_DESKTOP:-?}'). Servono XFCE o Cinnamon."
  exit 1
}

# helper interno Cinnamon: forza variante -solid e toglie hdpi
_de_cinnamon_solid() {
  local t="$1"
  t="${t%%-hdpi}"
  t="${t%%-xhdpi}"
  case "$t" in
    *-solid) echo "$t" ;;
    *) echo "${t}-solid" ;;
  esac
}

# --- tema GTK / icone / cursori ---------------------------------------------
de_set_gtk_theme() {  # NAME
  case "$DE" in
    xfce)     xfconf-query -c xsettings -p /Net/ThemeName -t string -s "$1" --create;;
    cinnamon)
      local s; s="$(_de_cinnamon_solid "$1")"
      gset org.cinnamon.desktop.interface gtk-theme "$s"
      gset org.cinnamon.theme name "$s"
      ;;
  esac
}
de_set_icon_theme() {  # NAME
  case "$DE" in
    xfce)     xfconf-query -c xsettings -p /Net/IconThemeName -t string -s "$1" --create;;
    cinnamon) gset org.cinnamon.desktop.interface icon-theme "$1";;
  esac
}
de_set_cursor_theme() {  # NAME
  case "$DE" in
    xfce)     xfconf-query -c xsettings -p /Gtk/CursorThemeName -t string -s "$1" --create;;
    cinnamon) gset org.cinnamon.desktop.interface cursor-theme "$1";;
  esac
}

# --- bottoni finestra a sinistra (stile macOS) ------------------------------
# layout macOS: chiudi,minimizza,massimizza a SINISTRA, niente a destra.
de_set_buttons_mac() {
  case "$DE" in
    xfce)
      xfconf-query -c xsettings -p /Gtk/DecorationLayout -t string -s "close,minimize,maximize:" --create
      xfconf-query -c xfwm4 -p /general/button_layout -t string -s "CHM|" --create
      ;;
    cinnamon)
      gset org.cinnamon.desktop.wm.preferences button-layout "close,minimize,maximize:"
      ;;
  esac
}

# AutoMnemonics off (sottolineature nei menu nascoste) — solo XFCE ha la chiave.
de_set_mnemonics_off() {
  case "$DE" in
    xfce) xfconf-query -c xsettings -p /Gtk/AutoMnemonics -t bool -s true --create;;
    cinnamon) : ;;  # nessun equivalente diretto in Cinnamon
  esac
}

# --- tema del window manager (decorazioni) ----------------------------------
de_set_wm_theme() {  # NAME (es. WhiteSur-Light o variante hdpi su XFCE)
  case "$DE" in
    xfce)     xfconf-query -c xfwm4 -p /general/theme -t string -s "$1" --create;;
    cinnamon)
      local s; s="$(_de_cinnamon_solid "$1")"
      gset org.cinnamon.desktop.wm.preferences theme "$s"
      ;;
  esac
}

# --- font -------------------------------------------------------------------
de_set_interface_font() {  # "SF Pro Text 10"
  case "$DE" in
    xfce)     xfconf-query -c xsettings -p /Gtk/FontName -t string -s "$1" --create;;
    cinnamon) gset org.cinnamon.desktop.interface font-name "$1";;
  esac
}
de_set_title_font() {  # "SF Pro Display Semibold 10"
  case "$DE" in
    xfce)     xfconf-query -c xfwm4 -p /general/title_font -t string -s "$1" --create;;
    cinnamon) gset org.cinnamon.desktop.wm.preferences titlebar-font "$1";;
  esac
}

# --- scala display ----------------------------------------------------------
# NB semantica diversa: XFCE usa Xft.DPI (intero, 96=1x). Cinnamon usa
# text-scaling-factor (float, 1.0=1x). Convertiamo DPI/96.
de_set_scaling() {  # DPI
  [ -n "$1" ] || return 0
  case "$DE" in
    xfce) xfconf-query -c xsettings -p /Xft/DPI -t int -s "$1" --create;;
    cinnamon)
      local f
      f="$(awk "BEGIN{printf \"%.2f\", $1/96}")"
      gset org.cinnamon.desktop.interface text-scaling-factor "$f"
      ;;
  esac
}

# --- wallpaper --------------------------------------------------------------
de_set_wallpaper() {  # PATH
  case "$DE" in
    xfce)
      local p
      local found=0
      for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep last-image || true); do
        xfconf-query -c xfce4-desktop -p "$p" -s "$1" 2>/dev/null || true
        xfconf-query -c xfce4-desktop -p "${p%last-image}image-style" -t int -s 5 --create 2>/dev/null || true
        found=1
      done
      if [ "$found" = 0 ] && [ -n "${DISPLAY:-}" ]; then
        local mon; mon="$(xrandr | grep ' connected' | head -1 | cut -d' ' -f1)"
        if [ -n "$mon" ]; then
          xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor${mon}/workspace0/last-image" -t string -s "$1" --create 2>/dev/null || true
          xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor${mon}/workspace0/image-style" -t int -s 5 --create 2>/dev/null || true
        fi
      fi
      ;;
    cinnamon)
      gset org.cinnamon.desktop.background picture-uri "file://$1"
      gset org.cinnamon.desktop.background picture-options "zoom"
      ;;
  esac
}

# --- notifiche in alto a destra ---------------------------------------------
de_set_notify_topright() {
  case "$DE" in
    xfce)
      xfconf-query -c xfce4-notifyd -p /notify-location -t string -s top-right --create 2>/dev/null || true
      xfconf-query -c xfce4-notifyd -p /theme -t string -s macOS --create 2>/dev/null || true
      ;;
    cinnamon) : ;;  # Cinnamon mostra già le notifiche in alto a destra di default
  esac
}

# --- pannello in alto -------------------------------------------------------
de_set_panel_top() {
  case "$DE" in
    xfce) : ;; # Fatto via XML in install.sh
    cinnamon)
      gset org.cinnamon panels-enabled "['1:0:top']"
      gset org.cinnamon panels-height "['1:28']"
      ;;
  esac
}

# --- hot corners ------------------------------------------------------------
de_set_hot_corners() {
  case "$DE" in
    xfce) : ;; # Fatto via xfdashboard in install.sh
    cinnamon)
      gset org.cinnamon hotcorner-layout "['scale:true:0', 'scale:false:0', 'expo:false:0', 'desktop:true:0']"
      ;;
  esac
}

# --- compositor: serve picom? -----------------------------------------------
# Su Cinnamon c'è già Muffin: picom NON va installato (si pesterebbero i piedi).
de_needs_picom() { [ "$DE" = xfce ]; }
