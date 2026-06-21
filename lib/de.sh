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
      # fallback: PRIMA il processo del DE in esecuzione (affidabile anche via
      # SSH/senza XDG_CURRENT_DESKTOP), poi la presenza dei binari. NB: non basta
      # "c'e' xfconf-query -> xfce": su Cinnamon i pacchetti XFCE possono essere
      # installati (es. xfce4-appmenu-plugin) e falsare il rilevamento.
      if   pgrep -x cinnamon >/dev/null 2>&1; then echo cinnamon
      elif pgrep -x xfwm4    >/dev/null 2>&1; then echo xfce
      elif have cinnamon;     then echo cinnamon
      elif have xfconf-query; then echo xfce
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

# Resa font stile Retina: antialiasing grayscale (no subpixel). Il grosso lo fa
# fontconfig (~/.config/fontconfig/fonts.conf, universale); qui allineiamo anche
# le impostazioni Xft di XFCE che altrimenti riaccenderebbero il subpixel.
de_set_font_rendering() {
  case "$DE" in
    xfce)
      xfconf-query -c xsettings -p /Xft/RGBA -t string -s none --create
      xfconf-query -c xsettings -p /Xft/Antialias -t int -s 1 --create
      xfconf-query -c xsettings -p /Xft/Hinting -t int -s 1 --create
      xfconf-query -c xsettings -p /Xft/HintStyle -t string -s hintslight --create
      ;;
    cinnamon) : ;;  # gestito da fontconfig
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
# NB semantica diversa: XFCE usa Xft.DPI (intero, 96=1x). Cinnamon scala l'INTERA
# UI con scaling-factor (uint: 0=auto,1,2), mentre text-scaling-factor ridimensiona
# SOLO i font. Usare solo text-scaling darebbe testo grande ma icone/widget piccoli
# (non un vero "2x"): per l'HiDPI pieno serve scaling-factor=2. Per densità
# intermedie (no fractional pulito via gsettings) ripieghiamo sul testo.
de_set_scaling() {  # DPI
  [ -n "$1" ] || return 0
  case "$DE" in
    xfce) xfconf-query -c xsettings -p /Xft/DPI -t int -s "$1" --create;;
    cinnamon)
      if [ "$1" -ge 192 ]; then
        gset org.cinnamon.desktop.interface scaling-factor 2
        gset org.cinnamon.desktop.interface text-scaling-factor 1.0
      else
        local f; f="$(awk "BEGIN{printf \"%.2f\", $1/96}")"
        gset org.cinnamon.desktop.interface scaling-factor 1
        gset org.cinnamon.desktop.interface text-scaling-factor "$f"
      fi
      ;;
  esac
}

# --- wallpaper --------------------------------------------------------------
de_set_wallpaper() {  # PATH
  case "$DE" in
    xfce)
      local p
      local found=0
      # copre sia last-image (per-workspace) sia last-single-image (modalità a
      # immagine unica di xfdesktop 4.18, default su Mint 22): senza coprire
      # entrambi, su una sessione fresca lo sfondo della distro non viene
      # sostituito (resta il wallpaper Mint -> look "mix").
      for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E 'last-image$|last-single-image$' || true); do
        xfconf-query -c xfce4-desktop -p "$p" -s "$1" 2>/dev/null || true
        xfconf-query -c xfce4-desktop -p "${p%/*}/image-style" -t int -s 5 --create 2>/dev/null || true
        xfconf-query -c xfce4-desktop -p "${p%/*}/image-show" -t bool -s true --create 2>/dev/null || true
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

# --- animazioni finestre stile macOS (solo Cinnamon) ------------------------
# Apertura/chiusura con "scale" (cresce/rimpicciolisce dal centro, come macOS) e
# velocità rapida. La minimizzazione resta "traditional" (verso il dock, l'effetto
# più vicino al genie). Su XFCE gli effetti li fa picom, quindi qui no-op.
# NB: la trasparenza/blur del pannello NON è una chiave gsettings: la decide il
# tema Cinnamon (WhiteSur), non si imposta da qui.
de_set_macos_effects() {
  [ "$DE" = cinnamon ] || return 0
  gset org.cinnamon desktop-effects true
  gset org.cinnamon desktop-effects-map scale
  gset org.cinnamon desktop-effects-close scale
  gset org.cinnamon window-effect-speed 2
}

# --- desktop pulito (niente icone Computer/Home/Cestino, come macOS) ---------
de_set_desktop_icons_off() {
  case "$DE" in
    xfce)
      # style: 0=niente, 1=icone finestre minimizzate, 2=file/launcher.
      # Mettiamo a 0 E spegniamo le singole chiavi show-* (alcune versioni di
      # xfdesktop mostrano Home/Cestino/Filesystem/Volumi anche con style basso).
      xfconf-query -c xfce4-desktop -p /desktop-icons/style -t int -s 0 --create 2>/dev/null || true
      local k
      for k in show-home show-trash show-filesystem show-removable; do
        xfconf-query -c xfce4-desktop -p "/desktop-icons/file-icons/$k" -t bool -s false --create 2>/dev/null || true
      done
      ;;
    cinnamon)
      gset org.nemo.desktop computer-icon-visible false
      gset org.nemo.desktop home-icon-visible false
      gset org.nemo.desktop trash-icon-visible false
      gset org.nemo.desktop volumes-visible false
      gset org.nemo.desktop network-icon-visible false
      ;;
  esac
}

# --- scorciatoie da tastiera personalizzate ---------------------------------
# Su XFCE le scorciatoie sono cablate nello XML (c_panel); qui gestiamo SOLO
# Cinnamon, che usa lo schema relocatable custom-keybinding + la lista custom-list.
# Idempotente: usa uno SLOT fisso (es. "custom90"), quindi ri-eseguire sovrascrive
# la stessa voce invece di duplicarla. Niente conflitti con i custom0..N dell'utente.
# Uso: de_add_keybinding SLOT NAME COMMAND BINDING   (BINDING es. "<Super>space")
de_add_keybinding() {
  [ "$DE" = cinnamon ] || return 0
  have gsettings || return 0
  local slot="$1" name="$2" cmd="$3" bind="$4"
  local schema="org.cinnamon.desktop.keybindings.custom-keybinding"
  local path="/org/cinnamon/desktop/keybindings/custom-keybindings/$slot/"
  gsettings list-schemas 2>/dev/null | grep -qx org.cinnamon.desktop.keybindings || return 0
  gsettings set "$schema:$path" name "$name"     2>/dev/null || true
  gsettings set "$schema:$path" command "$cmd"   2>/dev/null || true
  gsettings set "$schema:$path" binding "['$bind']" 2>/dev/null || true
  # assicura che lo slot sia presente in custom-list (senza duplicarlo)
  local cur; cur="$(gsettings get org.cinnamon.desktop.keybindings custom-list 2>/dev/null)"
  case "$cur" in
    *"'$slot'"*) : ;;                                              # già presente
    "@as []"|"[]"|"['']"|"") gsettings set org.cinnamon.desktop.keybindings custom-list "['$slot']" 2>/dev/null || true ;;
    *) gsettings set org.cinnamon.desktop.keybindings custom-list "${cur%]*}, '$slot']" 2>/dev/null || true ;;
  esac
}

# --- compositor: serve picom? -----------------------------------------------
# Su Cinnamon c'è già Muffin: picom NON va installato (si pesterebbero i piedi).
de_needs_picom() { [ "$DE" = xfce ]; }
