#!/usr/bin/env bash
###############################################################################
# macOS-XFCE installer — trasforma un Linux Mint / Ubuntu XFCE in stile macOS.
# Modulare e idempotente. Vedi README.md. Lanciare SENZA sudo (chiede lui dove
# serve). Le parti di sistema (greeter, plymouth, pacchetti) usano sudo.
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$SCRIPT_DIR/assets"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

# --- default ----------------------------------------------------------------
DPI=""                 # vuoto = non toccare la scala; es. 240 per HiDPI 2.5x
ASSUME_YES=0
DO_PACKAGES=1; DO_THEME=1; DO_SFPRO=1; DO_PANEL=1; DO_DOCK=1
DO_SCALING=1; DO_PICOM=1; DO_ANIM=1; DO_POWER=1; DO_CORNERS=1
DO_TOUCHEGG=1; DO_NOTIFY=1; DO_WALLPAPER=1; DO_GREETER=0; DO_PLYMOUTH=0
DO_WHITESUR=1

usage() {
  cat <<EOF
Uso: ./install.sh [opzioni]

  --dpi N            imposta la scala (Xft.DPI). Es: 144 (1.5x), 192 (2x), 240 (2.5x).
                     Default: non cambia la scala.
  --yes              non interattivo (assume "sì").
  --greeter          installa anche il login screen (richiede nody-greeter, sudo).
  --plymouth         installa anche il boot splash ciliegia (sudo, rigenera initramfs).
  --no-sf-pro        non scaricare SF Pro (usa Inter).
  --no-animations    picom senza animazioni (niente build da sorgente).
  --no-whitesur      non clonare/installare WhiteSur (lo dai per già presente).
  --no-packages      salta apt install.
  --only LISTA       esegui solo i componenti elencati (vedi sotto), separati da virgola.
  -h, --help         questo aiuto.

Componenti (per --only): packages,theme,sfpro,panel,dock,scaling,picom,power,
  corners,touchegg,notify,wallpaper,greeter,plymouth
EOF
}

# --- parse argomenti --------------------------------------------------------
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dpi) DPI="$2"; shift 2;;
    --yes|-y) ASSUME_YES=1; shift;;
    --greeter) DO_GREETER=1; shift;;
    --plymouth) DO_PLYMOUTH=1; shift;;
    --no-sf-pro) DO_SFPRO=0; shift;;
    --no-animations) DO_ANIM=0; shift;;
    --no-whitesur) DO_WHITESUR=0; shift;;
    --no-packages) DO_PACKAGES=0; shift;;
    --only) ONLY="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) err "opzione sconosciuta: $1"; usage; exit 2;;
  esac
done
if [ -n "$DPI" ] && ! [[ "$DPI" =~ ^[0-9]+$ ]]; then
  err "--dpi vuole un intero (es. 144, 192, 240), non: $DPI"; exit 2
fi
export ASSUME_YES

if [ -n "$ONLY" ]; then
  DO_PACKAGES=0; DO_THEME=0; DO_SFPRO=0; DO_PANEL=0; DO_DOCK=0; DO_SCALING=0
  DO_PICOM=0; DO_POWER=0; DO_CORNERS=0; DO_TOUCHEGG=0; DO_NOTIFY=0
  DO_WALLPAPER=0; DO_GREETER=0; DO_PLYMOUTH=0
  IFS=',' read -ra _o <<< "$ONLY"
  for c in "${_o[@]}"; do
    case "$c" in
      packages) DO_PACKAGES=1;; theme) DO_THEME=1;; sfpro) DO_SFPRO=1;;
      panel) DO_PANEL=1;; dock) DO_DOCK=1;; scaling) DO_SCALING=1;;
      picom) DO_PICOM=1;; power) DO_POWER=1;; corners) DO_CORNERS=1;;
      touchegg) DO_TOUCHEGG=1;; notify) DO_NOTIFY=1;; wallpaper) DO_WALLPAPER=1;;
      greeter) DO_GREETER=1;; plymouth) DO_PLYMOUTH=1;;
      *) err "componente sconosciuto: $c"; exit 2;;
    esac
  done
fi

# variante del tema xfwm4 in base alla scala (i pallini sono PNG a misura fissa)
theme_variant() {
  local v="WhiteSur-Light"
  if [ -n "$DPI" ]; then
    if   [ "$DPI" -ge 216 ]; then v="WhiteSur-Light-xhdpi"
    elif [ "$DPI" -ge 144 ]; then v="WhiteSur-Light-hdpi"; fi
  fi
  echo "$v"
}

need_xfconf() { have xfconf-query || { err "xfconf-query non trovato: sei in XFCE?"; exit 1; }; }

###############################################################################
# COMPONENTI
###############################################################################

c_packages() {
  step "Pacchetti di sistema (apt)"
  local pkgs="plank dconf-cli xfce4-appmenu-plugin appmenu-gtk2-module appmenu-gtk3-module vala-panel-appmenu \
    appmenu-registrar appmenu-gtk-module-common \
    picom xfdashboard touchegg xdotool wmctrl x11-utils \
    fonts-inter fonts-jetbrains-mono python3-gi gir1.2-gtk-3.0 \
    python3-cairo python3-pil git p7zip-full curl"
  as_root apt-get update -y || warn "apt update fallito (continuo)"
  # Pre-filtro: tengo solo i pacchetti realmente disponibili. Senza questo, un
  # singolo nome inesistente fa abortire l'intera transazione apt e NON installa
  # nulla (git/curl inclusi), rompendo a cascata tema, font e build di picom.
  local p avail="" missing=""
  for p in $pkgs; do
    if apt-cache show "$p" >/dev/null 2>&1; then avail="$avail $p"; else missing="$missing $p"; fi
  done
  [ -n "$missing" ] && warn "pacchetti non disponibili, saltati:$missing"
  # shellcheck disable=SC2086
  as_root apt-get install -y $avail || warn "alcuni pacchetti non installati"
  ok "pacchetti"
}

c_theme() {
  step "Tema WhiteSur, font, icone, cursori"
  if [ "$DO_WHITESUR" = 1 ]; then
    local tmp; tmp="$(mktemp -d)"
    if confirm "Clonare e installare WhiteSur (GTK/icone/cursori)?"; then
      # SHELL_VERSION/GNOME_VERSION: senza gnome-shell installato l'installer upstream
      # lascia queste variabili vuote e la compilazione del tema gnome-shell fallisce.
      # NB: NIENTE -l/--libadwaita: quel flag installa SOLO la config gtk-4.0 per
      # libadwaita (app GNOME), non il tema GTK3/xfwm4 che serve a XFCE.
      git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$tmp/gtk" \
        && (cd "$tmp/gtk" && SHELL_VERSION=48 GNOME_VERSION=48-0 ./install.sh -c Light -t default) || warn "WhiteSur GTK ko"
      git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git "$tmp/icon" \
        && (cd "$tmp/icon" && ./install.sh) || warn "WhiteSur icone ko"
      git clone --depth=1 https://github.com/vinceliuice/WhiteSur-cursors.git "$tmp/cur" \
        && (cd "$tmp/cur" && ./install.sh) || warn "WhiteSur cursori ko"
    fi
    rm -rf "$tmp"
    # patch: angoli + batteria (richiedono python3-pil / sed)
    local var; var="$(theme_variant)"
    if [ -d "$HOME/.themes/$var/xfwm4" ] && have python3; then
      python3 "$ASSETS/patches/flatten-corners.py" "$HOME/.themes/$var/xfwm4" || warn "flatten angoli ko"
    fi
    [ -d "$HOME/.local/share/icons/WhiteSur-light" ] && \
      bash "$ASSETS/patches/battery-fix.sh" "$HOME/.local/share/icons/WhiteSur-light" || true
  fi

  # icona limone per il menu (Noto Emoji, sostituisce il logo Apple)
  install -Dm644 "$ASSETS/icons/lemon-logo.svg" "$HOME/.local/share/icons/lemon-logo.svg"
  # temi custom (notifiche + xfdashboard)
  mkdir -p "$HOME/.themes"; cp -r "$ASSETS/themes/macOS" "$HOME/.themes/"
  # gtk overrides (pannello scuro + mnemonics off)
  mkdir -p "$HOME/.config/gtk-3.0"
  backup_once "$HOME/.config/gtk-3.0/gtk.css"
  backup_once "$HOME/.config/gtk-3.0/settings.ini"
  cp "$ASSETS/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
  cp "$ASSETS/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"

  need_xfconf
  local var; var="$(theme_variant)"
  xq -c xsettings -p /Net/ThemeName     -t string -s WhiteSur-Light  --create
  xq -c xsettings -p /Net/IconThemeName -t string -s WhiteSur-light  --create
  xq -c xsettings -p /Gtk/CursorThemeName -t string -s WhiteSur-cursors --create
  xq -c xsettings -p /Gtk/DecorationLayout -t string -s "close,minimize,maximize:" --create
  xq -c xsettings -p /Gtk/AutoMnemonics -t bool -s true --create
  xq -c xfwm4 -p /general/theme -t string -s "$var" --create
  xq -c xfwm4 -p /general/button_layout -t string -s "CHM|" --create
  ok "tema applicato (xfwm4: $var)"
}

c_sfpro() {
  step "Font SF Pro (download da Apple)"
  local dest="$HOME/.local/share/fonts/SF-Pro"
  if fc-list 2>/dev/null | grep -qi "SF Pro Text"; then
    ok "SF Pro già installato"
  else
    have curl || { warn "curl mancante, salto SF Pro"; return 0; }
    have 7z || have 7za || { warn "p7zip mancante, salto SF Pro"; return 0; }
    local z; z="$(command -v 7z || command -v 7za)"
    local tmp; tmp="$(mktemp -d)"
    ( cd "$tmp"
      curl -fL -o SF-Pro.dmg https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg \
        && "$z" x -y SF-Pro.dmg >/dev/null \
        && "$z" x -y "SFProFonts/SF Pro Fonts.pkg" >/dev/null \
        && cpio -idmu < "Payload~" 2>/dev/null
    ) || { warn "download/estrazione SF Pro fallito"; rm -rf "$tmp"; return 0; }
    mkdir -p "$dest"
    cp "$tmp"/Library/Fonts/*.otf "$tmp"/Library/Fonts/*.ttf "$dest"/ 2>/dev/null || true
    rm -rf "$tmp"; fc-cache -f "$dest" >/dev/null 2>&1 || true
    ok "SF Pro installato in $dest"
  fi
  need_xfconf
  if fc-list 2>/dev/null | grep -qi "SF Pro Text"; then
    xq -c xsettings -p /Gtk/FontName -t string -s "SF Pro Text 10" --create
    xq -c xfwm4 -p /general/title_font -t string -s "SF Pro Display Semibold 10" --create
  else
    xq -c xsettings -p /Gtk/FontName -t string -s "Inter 10" --create
    xq -c xfwm4 -p /general/title_font -t string -s "Inter Bold 10" --create
  fi
}

c_panel() {
  step "Pannello (menu bar) + scorciatoie"
  local X="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
  mkdir -p "$X" "$HOME/.config/xfce4/panel"
  # icona del logo (limone) + menu Apple stile macOS aperto dal logo nel pannello
  mkdir -p "$HOME/.local/share/icons" "$HOME/.local/bin"
  cp "$ASSETS/icons/lemon-logo.svg" "$HOME/.local/share/icons/" 2>/dev/null || true
  install -Dm755 "$ASSETS/bin/macos-apple-menu" "$HOME/.local/bin/macos-apple-menu" 2>/dev/null || true
  # launcher (menu Apple, spotlight ecc.)
  cp -r "$ASSETS"/panel-launchers/launcher-* "$HOME/.config/xfce4/panel/" 2>/dev/null || true
  for f in "$HOME"/.config/xfce4/panel/launcher-*/*.desktop; do
    [ -e "$f" ] && sed -i "s#@HOME@#$HOME#g" "$f"
  done
  # Dimensioni pannello in base al DPI (i valori HiDPI su lodpi sembrano "2x").
  local psize=28 picon=22
  if [ -n "$DPI" ]; then
    if   [ "$DPI" -ge 216 ]; then psize=50; picon=42
    elif [ "$DPI" -ge 144 ]; then psize=40; picon=32; fi
  fi
  # XML pannello + scorciatoie (sorgente di verità del layout)
  for ch in xfce4-panel xfce4-keyboard-shortcuts; do
    backup_once "$X/$ch.xml"
    sed -e "s#@HOME@#$HOME#g" -e "s#@PANEL_SIZE@#$psize#g" -e "s#@PANEL_ICON@#$picon#g" \
      "$ASSETS/xfconf/$ch.xml" > "$X/$ch.xml"
  done
  # AppMenu registrar: il pannello usa il plugin 'appmenu' (menu globale dell'app
  # nella menu bar). Senza questo servizio in autostart il plugin resta VUOTO e
  # la barra superiore appare rotta. Richiede il pacchetto appmenu-registrar.
  mkdir -p "$HOME/.config/autostart"
  backup_once "$HOME/.config/autostart/appmenu-registrar.desktop"
  cat > "$HOME/.config/autostart/appmenu-registrar.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=AppMenu Registrar
Exec=/usr/libexec/vala-panel/appmenu-registrar
X-GNOME-Autostart-enabled=true
Terminal=false
EOF
  # Il menu globale compare SOLO se le app GTK caricano il modulo appmenu-gtk
  # (via GTK_MODULES) con UBUNTU_MENUPROXY=1. vala-panel-appmenu installa
  # /etc/profile.d/vala-panel-appmenu.sh, ma la sessione XFCE non è sempre una
  # login-shell che lo sourcizza: scriviamo le variabili in /etc/environment
  # (lette da PAM per OGNI sessione). Senza questo il plugin appmenu resta vuoto.
  if ! grep -q 'appmenu-gtk-module' /etc/environment 2>/dev/null; then
    as_root sh -c 'echo "GTK_MODULES=appmenu-gtk-module" >> /etc/environment'
  fi
  if ! grep -q '^UBUNTU_MENUPROXY=' /etc/environment 2>/dev/null; then
    as_root sh -c 'echo "UBUNTU_MENUPROXY=1" >> /etc/environment'
  fi
  # APPLICAZIONE: copiare l'XML non basta. xfconfd tiene la config in RAM e al
  # logout RISCRIVE gli XML coi valori vecchi, vanificando la copia (il pannello
  # non cambia mai). Per applicare davvero: quit del pannello + kill di xfconfd;
  # alla ripartenza xfconfd rilegge gli XML appena scritti. Le impostazioni di
  # xsettings/xfwm4 fatte prima via xfconf-query sono già state scaricate su
  # disco da xfconfd, quindi vengono ricaricate intatte.
  if [ -n "${DISPLAY:-}" ] && have xfce4-panel; then
    sleep 1
    xfce4-panel --quit 2>/dev/null || true
    pkill -x xfconfd 2>/dev/null || true
    sleep 1
    setsid xfce4-panel >/dev/null 2>&1 &
    ok "pannello applicato (menu bar, systray, scorciatoie)"
  else
    warn "nessun DISPLAY: pannello configurato, si applica al prossimo login"
    ok "pannello configurato"
  fi
}

c_dock() {
  step "Dock (Plank)"
  mkdir -p "$HOME/.config/autostart"
  backup_once "$HOME/.config/autostart/plank.desktop"
  cat > "$HOME/.config/autostart/plank.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Plank
Exec=plank
OnlyShowIn=XFCE;
X-XFCE-Autostart-enabled=true
StartupNotify=false
Terminal=false
EOF
  # Tema Plank "WhiteSur" (asset utente: a livello di sistema esistono solo
  # Default/Matte/Transparent; WhiteSur va installato in ~/.local).
  mkdir -p "$HOME/.local/share/plank/themes/WhiteSur"
  cp "$ASSETS/plank/themes/WhiteSur/dock.theme" "$HOME/.local/share/plank/themes/WhiteSur/"

  # Launchpad: .desktop custom + icona (primo item del dock).
  mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons"
  cp "$ASSETS/icons/launchpad.svg" "$HOME/.local/share/icons/" 2>/dev/null || true
  sed "s#@HOME@#$HOME#g" "$ASSETS/applications/launchpad.desktop" > "$HOME/.local/share/applications/launchpad.desktop"

  # Voci del dock (dockitem) — ordine stile macOS, con templating @HOME@.
  mkdir -p "$HOME/.config/plank/dock1/launchers"
  for f in "$ASSETS"/plank/launchers/*.dockitem; do
    sed "s#@HOME@#$HOME#g" "$f" > "$HOME/.config/plank/dock1/launchers/$(basename "$f")"
  done

  if have dconf; then
    # backup delle impostazioni dconf attuali (ripristino: dconf load /net/launchpad/plank/ < file)
    local dbak="$HOME/.config/plank/dconf-plank.macos-bak"
    mkdir -p "$HOME/.config/plank"
    [ -e "$dbak" ] || dconf dump /net/launchpad/plank/ > "$dbak" 2>/dev/null || true
    # icona del dock in base al DPI (80 su HiDPI sembra enorme su lodpi)
    local dksz=48
    if [ -n "$DPI" ]; then
      if   [ "$DPI" -ge 216 ]; then dksz=80
      elif [ "$DPI" -ge 144 ]; then dksz=64; fi
    fi
    dconf write /net/launchpad/plank/docks/dock1/theme "'WhiteSur'" 2>/dev/null || true
    dconf write /net/launchpad/plank/docks/dock1/position "'bottom'" 2>/dev/null || true
    dconf write /net/launchpad/plank/docks/dock1/icon-size "$dksz" 2>/dev/null || true
    dconf write /net/launchpad/plank/docks/dock1/zoom-enabled true 2>/dev/null || true
    dconf write /net/launchpad/plank/docks/dock1/zoom-percent 150 2>/dev/null || true
    dconf write /net/launchpad/plank/docks/dock1/dock-items \
      "['launchpad.dockitem', 'google-chrome.dockitem', 'thunar.dockitem', 'libreoffice-writer.dockitem', 'libreoffice-calc.dockitem', 'xfce4-terminal.dockitem', 'trash.dockitem']" 2>/dev/null || true
  fi
  have plank && (pgrep -x plank >/dev/null || setsid plank >/dev/null 2>&1 &) || true
  ok "plank"
}

c_scaling() {
  [ -z "$DPI" ] && { dim "scala non modificata (nessun --dpi)"; return 0; }
  step "Scala display (HiDPI)"
  need_xfconf
  xq -c xsettings -p /Xft/DPI -t int -s "$DPI" --create
  ok "Xft.DPI = $DPI  (riavvia Chrome/Electron per rileggerlo)"
}

c_picom() {
  step "Compositor / effetto vetro"
  # Rilevamento accelerazione GPU: con render software (llvmpipe) o dentro una VM,
  # il backend glx di picom CONGELA il desktop (display bloccato). In quel caso si
  # usa il compositing interno di xfwm4 (Xrender): dà la trasparenza del pannello
  # (effetto vetro SENZA blur) ed è stabile ovunque. Con GPU vera -> picom pieno.
  local gpu=1
  if command -v systemd-detect-virt >/dev/null && systemd-detect-virt -q 2>/dev/null; then gpu=0; fi
  if have glxinfo && glxinfo 2>/dev/null | grep -qiE 'renderer string.*(llvmpipe|softpipe|swrast)'; then gpu=0; fi
  if [ "$gpu" = 0 ]; then
    warn "nessuna accelerazione GPU (VM/render software): niente picom (freeza), uso compositing xfwm4"
    need_xfconf
    xq -c xfwm4 -p /general/use_compositing -t bool -s true --create
    xq -c xfwm4 -p /general/margin_top -t int -s 52 --create
    rm -f "$HOME/.config/autostart/picom.desktop" 2>/dev/null
    pkill -x picom 2>/dev/null; pkill -x picom-anim 2>/dev/null || true
    ok "compositing xfwm4 attivo (vetro senza blur, stabile su VM/no-GPU)"
    return 0
  fi
  mkdir -p "$HOME/.config/picom" "$HOME/.config/autostart"
  cp "$ASSETS/picom/picom.conf" "$HOME/.config/picom/picom.conf"
  cp "$ASSETS/picom/picom-anim.conf" "$HOME/.config/picom/picom-anim.conf"
  local exec_line="picom --config $HOME/.config/picom/picom.conf"

  if [ "$DO_ANIM" = 1 ]; then
    if have picom-anim; then
      exec_line="picom-anim --config $HOME/.config/picom/picom-anim.conf"
    elif confirm "Compilare picom-anim (FT-Labs) da sorgente per le animazioni? (lungo)"; then
      if build_picom_anim; then
        exec_line="picom-anim --config $HOME/.config/picom/picom-anim.conf"
      else
        warn "build fallita: uso picom standard senza animazioni"
      fi
    fi
  fi

  cat > "$HOME/.config/autostart/picom.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=picom
Exec=$exec_line
OnlyShowIn=XFCE;
X-XFCE-Autostart-enabled=true
StartupNotify=false
Terminal=false
EOF

  need_xfconf
  xq -c xfwm4 -p /general/use_compositing -t bool -s false --create
  # margine = altezza del pannello superiore (default 52; adatta se diverso)
  xq -c xfwm4 -p /general/margin_top -t int -s 52 --create
  # avvia subito
  pgrep -x picom >/dev/null || pgrep -x picom-anim >/dev/null || \
    (setsid bash -c "$exec_line" >/dev/null 2>&1 &) || true
  ok "picom attivo"
}

build_picom_anim() {
  have git && have meson && have ninja || \
    as_root apt-get install -y meson ninja-build libconfig-dev libdbus-1-dev libegl-dev \
      libev-dev libgl-dev libepoxy-dev libpcre2-dev libpixman-1-dev libx11-xcb-dev libxext-dev \
      libxcb1-dev libxcb-composite0-dev libxcb-damage0-dev libxcb-dpms0-dev \
      libxcb-glx0-dev libxcb-xinerama0-dev \
      libxcb-image0-dev libxcb-present-dev libxcb-randr0-dev libxcb-render0-dev \
      libxcb-render-util0-dev libxcb-shape0-dev libxcb-util-dev libxcb-xfixes0-dev \
      uthash-dev || return 1
  local tmp; tmp="$(mktemp -d)"
  git clone --depth=1 https://github.com/FT-Labs/picom.git "$tmp" || return 1
  ( cd "$tmp" && meson setup --buildtype=release build && ninja -C build ) || return 1
  as_root install -Dm755 "$tmp/build/src/picom" /usr/local/bin/picom-anim || return 1
  rm -rf "$tmp"; have picom-anim
}

c_power() {
  step "Dialogo spegnimento stile macOS"
  install -Dm755 "$ASSETS/bin/macos-power-dialog" "$HOME/.local/bin/macos-power-dialog"
  dim "il wiring (menu + Ctrl+Alt+Fine) è nello XML del pannello/scorciatoie"
  ok "power-dialog installato"
}

c_corners() {
  step "Hot corners + Mission Control (xfdashboard)"
  install -Dm755 "$ASSETS/bin/macos-hot-corners" "$HOME/.local/bin/macos-hot-corners"
  cat > "$HOME/.config/autostart/macos-hot-corners.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=macOS Hot Corners
Exec=$HOME/.local/bin/macos-hot-corners
OnlyShowIn=XFCE;
X-XFCE-Autostart-enabled=true
StartupNotify=false
Terminal=false
EOF
  if have xfconf-query; then
    xq -c xfdashboard -p /theme -t string -s macOS --create 2>/dev/null || true
  fi
  have xfdashboard && (pgrep -f xfdashboard >/dev/null || setsid xfdashboard --daemonize >/dev/null 2>&1 &) || true
  pgrep -f "$HOME/.local/bin/macos-hot-corners" >/dev/null || \
    (setsid "$HOME/.local/bin/macos-hot-corners" >/dev/null 2>&1 &) || true
  ok "hot corners + xfdashboard"
}

c_touchegg() {
  have touchegg || { dim "touchegg non installato, salto le gesture"; return 0; }
  step "Gesture touchpad (touchégg)"
  mkdir -p "$HOME/.config/touchegg"
  cp "$ASSETS/touchegg/touchegg.conf" "$HOME/.config/touchegg/touchegg.conf"
  as_root systemctl enable --now touchegg.service 2>/dev/null || warn "servizio touchegg non avviato"
  ok "gesture configurate"
}

c_notify() {
  step "Notifiche stile macOS"
  need_xfconf
  xq -c xfce4-notifyd -p /notify-location -t string -s top-right --create 2>/dev/null || true
  xq -c xfce4-notifyd -p /theme -t string -s macOS --create 2>/dev/null || true
  ok "notifiche"
}

c_wallpaper() {
  local wp="gradient-light.jpg"
  [ -f "$ASSETS/wallpapers/$wp" ] || { dim "nessun wallpaper nel pacchetto"; return 0; }
  step "Wallpaper (gradiente libero, colorato in alto per il blur)"
  mkdir -p "$HOME/.local/share/wallpapers"
  cp "$ASSETS/wallpapers/$wp" "$HOME/.local/share/wallpapers/"
  local img="$HOME/.local/share/wallpapers/$wp"
  need_xfconf
  # NB: serve ANCHE image-style (5=scaled): con la sola last-image l'immagine
  # non viene disegnata e il desktop resta nero.
  local p found=0
  for p in $(xq -c xfce4-desktop -l 2>/dev/null | grep 'last-image$' || true); do
    xq -c xfce4-desktop -p "$p" -t string -s "$img" --create 2>/dev/null || true
    xq -c xfce4-desktop -p "${p%last-image}image-style" -t int -s 5 --create 2>/dev/null || true
    found=1
  done
  # sistema vergine: nessuna proprietà backdrop ancora -> creala per i monitor attivi
  if [ "$found" = 0 ] && [ -n "${DISPLAY:-}" ] && have xrandr; then
    local mon
    for mon in $(xrandr 2>/dev/null | awk '/ connected/{print $1}'); do
      xq -c xfce4-desktop -p "/backdrop/screen0/monitor$mon/workspace0/last-image"  -t string -s "$img" --create 2>/dev/null || true
      xq -c xfce4-desktop -p "/backdrop/screen0/monitor$mon/workspace0/image-style" -t int    -s 5    --create 2>/dev/null || true
    done
  fi
  [ -n "${DISPLAY:-}" ] && have xfdesktop && xfdesktop --reload >/dev/null 2>&1 || true
  ok "wallpaper impostato"
}

c_greeter() {
  step "Login screen (nody-greeter)"
  if ! have nody-greeter; then
    warn "nody-greeter non installato."
    dim "scarica il .deb da https://github.com/JezerM/nody-greeter/releases e:"
    dim "  sudo apt install ./nody-greeter-*.deb   poi rilancia: ./install.sh --only greeter"
    return 0
  fi
  # font SF Pro dentro il tema (lightdm non legge ~/.local)
  local SRC="$ASSETS/greeter"
  local fd="$SRC/macos/resources/font"
  local sf="$HOME/.local/share/fonts/SF-Pro"
  if [ -d "$sf" ]; then
    for f in SF-Pro-Display-Light SF-Pro-Display-Regular SF-Pro-Display-Medium \
             SF-Pro-Display-Semibold SF-Pro-Text-Regular; do
      [ -f "$sf/$f.otf" ] && cp "$sf/$f.otf" "$fd/"
    done
  else
    warn "SF Pro non presente: il greeter userà Inter (fallback)"
  fi
  # deploy script generalizzato
  local deploy; deploy="$(mktemp)"
  sed "s#@SRC@#$SRC#g" "$SRC/macos-theme-deploy" > "$deploy"
  as_root install -Dm755 "$deploy" /usr/local/sbin/macos-theme-deploy
  rm -f "$deploy"
  as_root /usr/local/sbin/macos-theme-deploy || { warn "deploy greeter fallito"; return 0; }
  # Ubuntu 24.04+: AppArmor blocca gli unprivileged user namespaces, e il sandbox
  # di Chromium (nody-greeter è Electron) fallisce -> il greeter CRASHA all'avvio
  # ("FATAL:credentials.cc Check failed: Permission denied"). Permettiamo gli
  # userns non privilegiati via sysctl drop-in.
  if [ -e /proc/sys/kernel/apparmor_restrict_unprivileged_userns ]; then
    echo 'kernel.apparmor_restrict_unprivileged_userns=0' | \
      as_root tee /etc/sysctl.d/60-nody-greeter-userns.conf >/dev/null
    as_root sysctl --system >/dev/null 2>&1 || true
  fi
  ok "greeter installato (test: nody-greeter --mode debug --theme macos)"
}

c_plymouth() {
  step "Boot splash (Plymouth, logo limone)"
  as_root mkdir -p /usr/share/plymouth/themes/lemon
  # solo i file runtime del tema (no generatore/preview)
  as_root cp "$ASSETS"/plymouth/lemon.plymouth "$ASSETS"/plymouth/lemon.script \
            "$ASSETS"/plymouth/logo.png "$ASSETS"/plymouth/track.png \
            "$ASSETS"/plymouth/fill.png /usr/share/plymouth/themes/lemon/ \
    || { warn "copia plymouth ko"; return 0; }
  as_root update-alternatives --install /usr/share/plymouth/themes/default.plymouth \
    default.plymouth /usr/share/plymouth/themes/lemon/lemon.plymouth 200 || true
  as_root update-alternatives --set default.plymouth \
    /usr/share/plymouth/themes/lemon/lemon.plymouth || true
  as_root update-initramfs -u || warn "update-initramfs fallito"
  ok "boot splash installato (visibile al riavvio)"
}

###############################################################################
# MAIN
###############################################################################
echo "${C_BLUE}macOS-XFCE installer${C_OFF}  (utente: $USER, home: $HOME)"
[ "$(id -u)" = "0" ] && { err "non lanciare come root: usa il tuo utente (chiederà sudo dove serve)"; exit 1; }

[ "$DO_PACKAGES" = 1 ] && c_packages
[ "$DO_THEME"    = 1 ] && c_theme
[ "$DO_SFPRO"    = 1 ] && c_sfpro
[ "$DO_PANEL"    = 1 ] && c_panel
[ "$DO_DOCK"     = 1 ] && c_dock
[ "$DO_SCALING"  = 1 ] && c_scaling
[ "$DO_PICOM"    = 1 ] && c_picom
[ "$DO_POWER"    = 1 ] && c_power
[ "$DO_CORNERS"  = 1 ] && c_corners
[ "$DO_TOUCHEGG" = 1 ] && c_touchegg
[ "$DO_NOTIFY"   = 1 ] && c_notify
[ "$DO_WALLPAPER" = 1 ] && c_wallpaper
[ "$DO_GREETER"  = 1 ] && c_greeter
[ "$DO_PLYMOUTH" = 1 ] && c_plymouth

echo
step "Fatto."
echo "  • Esegui un ${C_GREEN}logout/login${C_OFF} per applicare pannello, scorciatoie e autostart."
echo "  • Per il login screen:  ./install.sh --only greeter   (dopo aver installato nody-greeter)"
echo "  • Per il boot splash:   ./install.sh --plymouth"
echo "  • Disinstallazione:     ./uninstall.sh"
