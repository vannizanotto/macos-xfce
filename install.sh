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
# shellcheck source=lib/de.sh
. "$SCRIPT_DIR/lib/de.sh"

# --- default ----------------------------------------------------------------
DPI=""                 # vuoto = AUTO-rileva dallo schermo (--no-scale per non toccare)
NO_SCALE=0             # 1 = non toccare la scala (niente auto-DPI)
WALLPAPER=""           # vuoto = gradiente del pacchetto; altrimenti path a un'immagine tua
ASSUME_YES=0
DO_PACKAGES=1; DO_THEME=1; DO_SFPRO=1; DO_PANEL=1; DO_DOCK=1
DO_SCALING=1; DO_PICOM=1; DO_ANIM=1; DO_POWER=1; DO_CORNERS=1
DO_TOUCHEGG=1; DO_NOTIFY=1; DO_WALLPAPER=1; DO_GREETER=0; DO_PLYMOUTH=0
DO_WHITESUR=1
DO_INPUT=1; DO_FINDER=1; DO_EMOJI=1; DO_DYNWALL=1
# Di default (auto) tematizziamo il desktop ATTUALMENTE in uso (rilevato da
# de_detect in lib/de.sh): così "lancia e basta" funziona sia su Cinnamon sia su
# XFCE, senza lasciare l'utente Cinnamon davanti a un desktop non tematizzato né
# dirottargli a sorpresa la sessione di login.
# --de xfce     = ambiente macOS "pieno": XFCE+picom, l'unico compositor con
#                 glass/blur, angoli arrotondati e ombre (Muffin di Cinnamon NON
#                 fa blur). Se lanciato da Cinnamon installa XFCE e lo imposta
#                 come sessione predefinita (richiede logout/login).
# --de cinnamon = path nativo Cinnamon (tema/dock/pannello, ma SENZA glass).
DE_TARGET="auto"

usage() {
  cat <<EOF
Uso: ./install.sh [opzioni]

  --de TARGET        ambiente macOS: auto (default, tematizza il DE in uso),
                     xfce (glass pieno via picom), cinnamon (nativo, senza glass).
  --dpi N            imposta la scala (Xft.DPI). Es: 144 (1.5x), 192 (2x), 240 (2.5x).
                     Default: AUTO-rilevata dalla densità dello schermo.
  --no-scale         non toccare la scala (disattiva l'auto-DPI).
  --wallpaper PATH   usa la TUA immagine come sfondo (es. un wallpaper macOS).
                     Default: gradiente libero incluso (non si possono redistribuire
                     le immagini Apple).
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
  corners,touchegg,notify,wallpaper,input,finder,emoji,dynwall,greeter,plymouth
EOF
}

# --- parse argomenti --------------------------------------------------------
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --de) DE_TARGET="$2"; shift 2;;
    --dpi) DPI="$2"; shift 2;;
    --no-scale) NO_SCALE=1; shift;;
    --wallpaper) WALLPAPER="$2"; shift 2;;
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

# Applica il target DE scelto (default xfce). lib/de.sh ha già rilevato il DE in
# esecuzione in $DE; qui lo sovrascriviamo col target voluto, così l'installer
# tematizza l'ambiente macOS (XFCE) anche se lanciato da una sessione Cinnamon.
case "$DE_TARGET" in
  xfce|cinnamon) DE="$DE_TARGET";;
  auto)          ;;  # tieni il DE rilevato da de_detect
  *) err "--de: valori validi: xfce, cinnamon, auto (non: $DE_TARGET)"; exit 2;;
esac
export DE

if [ -n "$ONLY" ]; then
  DO_PACKAGES=0; DO_THEME=0; DO_SFPRO=0; DO_PANEL=0; DO_DOCK=0; DO_SCALING=0
  DO_PICOM=0; DO_POWER=0; DO_CORNERS=0; DO_TOUCHEGG=0; DO_NOTIFY=0
  DO_WALLPAPER=0; DO_GREETER=0; DO_PLYMOUTH=0
  DO_INPUT=0; DO_FINDER=0; DO_EMOJI=0; DO_DYNWALL=0
  IFS=',' read -ra _o <<< "$ONLY"
  for c in "${_o[@]}"; do
    case "$c" in
      packages) DO_PACKAGES=1;; theme) DO_THEME=1;; sfpro) DO_SFPRO=1;;
      panel) DO_PANEL=1;; dock) DO_DOCK=1;; scaling) DO_SCALING=1;;
      picom) DO_PICOM=1;; power) DO_POWER=1;; corners) DO_CORNERS=1;;
      touchegg) DO_TOUCHEGG=1;; notify) DO_NOTIFY=1;; wallpaper) DO_WALLPAPER=1;;
      input) DO_INPUT=1;; finder) DO_FINDER=1;; emoji) DO_EMOJI=1;; dynwall) DO_DYNWALL=1;;
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

# Siamo in una sessione XFCE VIVA (xfwm4 in esecuzione)? Le azioni "live"
# (restart pannello/plank, xfdashboard, reload del desktop, avvio picom) hanno
# senso solo lì. Se l'installer è lanciato da un'ALTRA sessione (es. Cinnamon,
# default su molti Mint), vanno SALTATE: le config restano scritte e si applicano
# al login XFCE. Altrimenti quei comandi si APPENDONO (xfdesktop --reload e
# xfdashboard avviano un processo in foreground senza una sessione XFCE) e
# creano per giunta un desktop ibrido (pannello XFCE dentro Cinnamon).
xfce_live() { [ -n "${DISPLAY:-}" ] && pgrep -x xfwm4 >/dev/null 2>&1; }

# Sessione VIVA del DE *target* (XFCE o Cinnamon). xfce_live resta per le azioni
# XFCE-specifiche (xfconf/xfdesktop/picom); questo serve alle azioni "live" valide
# su ENTRAMBI i DE — in pratica l'avvio di Plank, che gira anche su Cinnamon.
# Senza, su una sessione Cinnamon viva il dock veniva configurato ma mai avviato
# (xfce_live falso) e compariva solo al login successivo.
de_live() {
  [ -n "${DISPLAY:-}" ] || return 1
  case "$DE" in
    xfce)     pgrep -x xfwm4    >/dev/null 2>&1;;
    cinnamon) pgrep -x cinnamon >/dev/null 2>&1;;
    *) return 1;;
  esac
}

# picom (backend glx) gira in modo AFFIDABILE? NO dentro una VM, con render
# software (llvmpipe) o su GPU deboli (nouveau/NVAF): il glx CONGELA il desktop
# o divora CPU (testato su GeForce 320M/nouveau) -> meglio il compositing interno
# di xfwm4 (vetro senza blur, stabile ovunque). Cache: la detection (glxinfo,
# lenta) gira una sola volta. Ritorna 0 = picom ok, 1 = usa il fallback xfwm4.
# Usata sia da c_picom sia da c_theme (per il flatten degli angoli, che ha senso
# SOLO se picom poi li arrotonda; senza picom lascia gli angoli nativi del tema).
_PICOM_VIABLE=""
picom_viable() {
  if [ -z "$_PICOM_VIABLE" ]; then
    _PICOM_VIABLE=0
    if command -v systemd-detect-virt >/dev/null && systemd-detect-virt -q 2>/dev/null; then _PICOM_VIABLE=1; fi
    if [ "$_PICOM_VIABLE" = 0 ] && have glxinfo && \
       timeout 8 glxinfo 2>/dev/null | grep -qiE 'renderer string.*(llvmpipe|softpipe|swrast|NVAF|nouveau)'; then
      _PICOM_VIABLE=1
    fi
  fi
  return "$_PICOM_VIABLE"
}

# Auto-rileva una scala sensata dalla densità FISICA dello schermo (xrandr:
# pixel + mm), così l'utente generico non deve conoscere il proprio DPI.
# Ritorna un Xft.DPI (144/192/240) o "" se densità normale / non rilevabile.
auto_dpi() {
  have xrandr || { echo ""; return; }
  local line wpx wmm ppi
  line="$(xrandr 2>/dev/null | grep -E ' connected (primary )?[0-9]+x[0-9]+\+' | head -1)"
  [ -n "$line" ] || { echo ""; return; }
  wpx="$(echo "$line" | grep -oE '[0-9]+x[0-9]+\+' | head -1 | cut -dx -f1)"
  wmm="$(echo "$line" | grep -oE '[0-9]+mm x' | head -1 | grep -oE '^[0-9]+')"
  { [ -n "$wpx" ] && [ -n "$wmm" ] && [ "$wmm" -gt 0 ]; } || { echo ""; return; }
  ppi=$(( wpx * 254 / (wmm * 10) ))   # px per pollice (1 inch = 25.4mm)
  if   [ "$ppi" -ge 220 ]; then echo 240
  elif [ "$ppi" -ge 180 ]; then echo 192
  elif [ "$ppi" -ge 140 ]; then echo 144
  else echo ""; fi
}

# Imposta la sessione predefinita del display manager a XFCE, così al prossimo
# login l'utente generico entra già nel desktop giusto senza doverlo scegliere.
set_default_session_xfce() {
  [ "$DE" = xfce ] || return 0
  local sess
  for sess in xfce xubuntu xfce4; do
    [ -e "/usr/share/xsessions/$sess.desktop" ] && break
  done
  [ -e "/usr/share/xsessions/$sess.desktop" ] || { dim "nessuna sessione xfce in /usr/share/xsessions"; return 0; }
  # ~/.dmrc (LightDM/altri lo leggono come default utente)
  printf '[Desktop]\nSession=%s\n' "$sess" > "$HOME/.dmrc"
  # AccountsService (LightDM moderno lo preferisce) — richiede root
  local af="/var/lib/AccountsService/users/$USER"
  if as_root test -e "$af" 2>/dev/null; then
    as_root sed -i '/^XSession=/d' "$af" 2>/dev/null || true
    as_root sh -c "printf 'XSession=%s\n' '$sess' >> '$af'" 2>/dev/null || true
  fi
  ok "sessione predefinita = $sess (al prossimo login parte XFCE)"
}

###############################################################################
# COMPONENTI
###############################################################################

c_packages() {
  step "Pacchetti di sistema (apt)"
  local pkgs="plank dconf-cli xfce4-appmenu-plugin appmenu-gtk2-module appmenu-gtk3-module vala-panel-appmenu \
    appmenu-registrar appmenu-gtk-module-common \
    picom xfdashboard touchegg xdotool wmctrl x11-utils xinput \
    xfce4-power-manager xfce4-power-manager-plugins xfce4-pulseaudio-plugin \
    xfce4-genmon-plugin gsimplecal gnome-sushi rofi \
    fonts-inter fonts-jetbrains-mono python3-gi gir1.2-gtk-3.0 \
    python3-cairo python3-pil git p7zip-full curl"
  # Ambiente macOS = XFCE: su una base Cinnamon il desktop XFCE può mancare.
  # Installiamo il core XFCE + xfconf (serve a xfconf-query per tematizzare) così
  # l'utente potrà scegliere la sessione "Xfce" al login e avere il look macOS.
  if [ "$DE" = xfce ]; then
    pkgs="$pkgs xfce4-session xfwm4 xfce4-panel xfce4-settings xfconf \
      thunar xfdesktop4 xfce4-terminal libxfce4ui-utils xinit"
  fi
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
  # L'installer WhiteSur usa setterm/tput per lo spinner: senza un TERM valido
  # (es. lanciato non da terminale / via SSH) ABORTA e il tema GTK non viene
  # installato ("WhiteSur GTK ko" -> tema fantasma). Garantiamo un TERM.
  export TERM="${TERM:-xterm-256color}"
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
    # patch angoli: appiattisce i corner TOP del tema xfwm4 SOLO se picom poi li
    # arrotonda tutti e 4 (GPU ok). Senza picom (VM/nouveau) NON va appiattito,
    # altrimenti le finestre restano coi corner tutti quadri invece dei top
    # arrotondati nativi del tema (Antigravity: "idea geniale"). + batteria.
    local var; var="$(theme_variant)"
    if picom_viable && [ -d "$HOME/.themes/$var/xfwm4" ] && have python3; then
      python3 "$ASSETS/patches/flatten-corners.py" "$HOME/.themes/$var/xfwm4" || warn "flatten angoli ko"
    else
      dim "flatten angoli saltato (niente picom: si tengono i corner nativi del tema)"
    fi
    [ -d "$HOME/.local/share/icons/WhiteSur-light" ] && \
      bash "$ASSETS/patches/battery-fix.sh" "$HOME/.local/share/icons/WhiteSur-light" || true
  fi

  # Cache icone: i varianti WhiteSur (light/dark) usano symlink verso il tema
  # base e il battery-fix riscrive degli SVG -> senza un refresh della cache GTK
  # può mostrare icone mancanti (quadratini vuoti) finché non si rifà il login.
  if have gtk-update-icon-cache; then
    local it
    for it in WhiteSur WhiteSur-light WhiteSur-dark; do
      [ -d "$HOME/.local/share/icons/$it" ] && \
        gtk-update-icon-cache -f -t "$HOME/.local/share/icons/$it" >/dev/null 2>&1 || true
    done
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
  # accent blu Apple per app GTK4 / libadwaita
  mkdir -p "$HOME/.config/gtk-4.0"
  backup_once "$HOME/.config/gtk-4.0/gtk.css"
  cp "$ASSETS/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
  # resa font stile Retina (antialiasing grayscale, no subpixel): fontconfig
  # (universale) + Xft/RGBA su XFCE.
  mkdir -p "$HOME/.config/fontconfig"
  backup_once "$HOME/.config/fontconfig/fonts.conf"
  cp "$ASSETS/fontconfig/fonts.conf" "$HOME/.config/fontconfig/fonts.conf"
  de_set_font_rendering

  local var; var="$(theme_variant)"
  de_set_gtk_theme "WhiteSur-Light"
  de_set_icon_theme "WhiteSur-light"
  de_set_cursor_theme "WhiteSur-cursors"
  de_set_buttons_mac
  de_set_mnemonics_off
  de_set_wm_theme "$var"
  ok "tema applicato (wm: $var)"
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
  # refresh COMPLETO della cache prima del check: con 'fc-cache -f "$dest"' o
  # subito dopo l'installazione la famiglia puo' non essere ancora indicizzata
  # e si ripiega erroneamente su Inter. Accettiamo anche l'esistenza dei .otf.
  fc-cache -f >/dev/null 2>&1 || true
  if ls "$dest"/SF-Pro-Text*.otf >/dev/null 2>&1 || fc-list 2>/dev/null | grep -qi "SF Pro Text"; then
    de_set_interface_font "SF Pro Text 10"
    de_set_title_font "SF Pro Display Semibold 10"
  else
    de_set_interface_font "Inter 10"
    de_set_title_font "Inter Bold 10"
  fi
}

# Le "welcome" delle distro (mintwelcome, ecc.) partono da /etc/xdg/autostart e
# spuntano ad ogni login rompendo il look macOS. Le silenziamo con un override
# utente Hidden=true (non si toccano i file di sistema).
suppress_distro_welcome() {
  mkdir -p "$HOME/.config/autostart"
  local f base
  for f in /etc/xdg/autostart/*welcome*.desktop; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    cat > "$HOME/.config/autostart/$base" <<EOF
[Desktop Entry]
Type=Application
Name=disabilitato da macOS-XFCE
Hidden=true
X-GNOME-Autostart-enabled=false
EOF
    dim "welcome distro silenziato: $base"
  done
}

c_panel() {
  step "Pannello (menu bar) + scorciatoie"
  suppress_distro_welcome
  de_set_panel_top
  if [ "$DE" = "cinnamon" ]; then
    # Menu-bar macOS su Cinnamon: applet Cinnamenu (menu) + calendario al centro +
    # systray/indicatori a destra, pannello singolo in alto h=28. Spedito come asset.
    mkdir -p "$HOME/.local/share/cinnamon/applets" "$HOME/.config/cinnamon/spices"
    cp -r "$ASSETS/cinnamon/applets/Cinnamenu@json" "$HOME/.local/share/cinnamon/applets/" 2>/dev/null || true
    if [ -d "$ASSETS/cinnamon/spices/Cinnamenu@json" ]; then
      cp -r "$ASSETS/cinnamon/spices/Cinnamenu@json" "$HOME/.config/cinnamon/spices/" 2>/dev/null || true
      # la config Cinnamenu usa @HOME@ per l'icona limone (menu-label vuota,
      # menu-icon-custom=true): sostituisci col path reale.
      for j in "$HOME/.config/cinnamon/spices/Cinnamenu@json"/*.json; do
        [ -e "$j" ] && sed -i "s#@HOME@#$HOME#g" "$j"
      done
    fi
    if have dconf; then
      # applicazione CHIRURGICA (dconf write per-chiave; NON 'dconf load' che
      # azzererebbe le altre chiavi di /org/cinnamon).
      dconf write /org/cinnamon/panels-enabled "['1:0:top']"
      dconf write /org/cinnamon/panels-height "['1:28']"
      dconf write /org/cinnamon/panel-zone-icon-sizes '"[{\"panelId\": 1, \"left\": 0, \"center\": 0, \"right\": 20}]"'
      dconf write /org/cinnamon/enabled-applets "['panel1:left:0:Cinnamenu@json:999', 'panel1:center:0:calendar@cinnamon.org:13', 'panel1:right:0:systray@cinnamon.org:3', 'panel1:right:1:xapp-status@cinnamon.org:4', 'panel1:right:2:notifications@cinnamon.org:5', 'panel1:right:3:removable-drives@cinnamon.org:7', 'panel1:right:4:keyboard@cinnamon.org:8', 'panel1:right:5:network@cinnamon.org:10', 'panel1:right:6:sound@cinnamon.org:11', 'panel1:right:7:power@cinnamon.org:12', 'panel1:right:8:cornerbar@cinnamon.org:14']"
      dconf write /org/cinnamon/next-applet-id 15
    fi
    warn "pannello Cinnamon: si applica al prossimo login (Cinnamon carica applet+tema all'avvio sessione); per applicare subito: cinnamon --replace"
    ok "pannello Cinnamon macOS (Cinnamenu + layout + zone)"
    return 0
  fi
  local X="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
  mkdir -p "$X" "$HOME/.config/xfce4/panel"
  # icona del logo (limone) + menu Apple stile macOS aperto dal logo nel pannello
  mkdir -p "$HOME/.local/share/icons" "$HOME/.local/bin"
  cp "$ASSETS/icons/lemon-logo.svg" "$HOME/.local/share/icons/" 2>/dev/null || true
  install -Dm755 "$ASSETS/bin/macos-apple-menu" "$HOME/.local/bin/macos-apple-menu" 2>/dev/null || true
  # CSS del menu Apple (frosted light); il fallback è dentro lo script.
  install -Dm644 "$ASSETS/apple-menu.css" "$HOME/.config/macos-xfce/apple-menu.css" 2>/dev/null || true
  # Orologio = genmon: data+ora stile macOS + calendario gsimplecal al click.
  # genmon NON usa xfconf: la sua config va in genmon-13.rc (allineato a plugin-13
  # nel panel XML). Lo scriviamo PRIMA del restart del pannello qui sotto.
  install -Dm755 "$ASSETS/bin/macos-clock-genmon.sh" "$HOME/.local/bin/macos-clock-genmon.sh" 2>/dev/null || true
  install -Dm755 "$ASSETS/bin/gsimplecal-toggle.sh" "$HOME/.local/bin/gsimplecal-toggle.sh" 2>/dev/null || true
  sed "s#@HOME@#$HOME#g" "$ASSETS/xfconf/genmon-13.rc" > "$HOME/.config/xfce4/panel/genmon-13.rc"
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
  if xfce_live && have xfce4-panel; then
    sleep 1
    # NB: 'xfce4-panel --quit' può APPENDERSI se il panel non risponde sul bus
    # (visto in sessioni instabili/annidate); il '|| true' non protegge da un
    # hang. timeout + fallback a kill diretto del processo per nome.
    timeout 8 xfce4-panel --quit 2>/dev/null || pkill -x xfce4-panel 2>/dev/null || true
    pkill -x xfconfd 2>/dev/null || true
    sleep 1
    setsid xfce4-panel >/dev/null 2>&1 &
    ok "pannello applicato (menu bar, systray, scorciatoie)"
  else
    warn "non in una sessione XFCE viva: pannello configurato, si applica al login XFCE"
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
Exec=sh -c 'XDG_CURRENT_DESKTOP="\${XDG_CURRENT_DESKTOP:-XFCE}" XDG_SESSION_TYPE="\${XDG_SESSION_TYPE:-x11}" GDK_BACKEND=x11 exec plank'
OnlyShowIn=XFCE;X-Cinnamon;
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
  # restart (non solo "avvia se assente"): un plank già attivo NON rilegge il
  # tema dopo il dconf write -> resterebbe col tema scuro di default.
  if have plank && de_live; then
    # NB: || true obbligatorio — su un'installazione fresca plank NON è in
    # esecuzione, pkill ritorna 1 e con 'set -e' aborterebbe l'installer.
    pkill -x plank 2>/dev/null || true; sleep 1
    setsid plank >/dev/null 2>&1 &
  fi
  ok "plank"
}

c_scaling() {
  [ -z "$DPI" ] && { dim "scala non modificata (nessun --dpi)"; return 0; }
  step "Scala display (HiDPI)"
  de_set_scaling "$DPI"
  ok "Scala = $DPI  (riavvia Chrome/Electron per rileggerlo)"
}

c_picom() {
  de_needs_picom || { dim "picom non necessario per $DE (compositor integrato)"; return 0; }
  step "Compositor / effetto vetro"
  # picom (glx) affidabile? Vedi picom_viable(): no su VM/render software/GPU
  # deboli (nouveau/NVAF) -> compositing interno di xfwm4 (vetro senza blur).
  if ! picom_viable; then
    warn "GPU problematica rilevata (VM/Nouveau): niente picom (freeza), uso compositing xfwm4"
    need_xfconf
    xq -c xfwm4 -p /general/use_compositing -t bool -s true --create
    xq -c xfwm4 -p /general/margin_top -t int -s 52 --create
    rm -f "$HOME/.config/autostart/picom.desktop" 2>/dev/null
    pkill -x picom 2>/dev/null || true; pkill -x picom-anim 2>/dev/null || true
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
  # avvia subito SOLO se siamo in una sessione XFCE viva (altrimenti picom
  # comporrebbe la sessione sbagliata; l'autostart lo lancia al login XFCE).
  if xfce_live; then
    pgrep -x picom >/dev/null || pgrep -x picom-anim >/dev/null || \
      (setsid bash -c "$exec_line" >/dev/null 2>&1 &) || true
    ok "picom attivo"
  else
    ok "picom configurato (parte al login XFCE)"
  fi
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
  [ "$DE" = "cinnamon" ] && { dim "power-dialog nativo in Cinnamon"; return 0; }
  step "Dialogo spegnimento stile macOS"
  install -Dm755 "$ASSETS/bin/macos-power-dialog" "$HOME/.local/bin/macos-power-dialog"
  dim "il wiring (menu + Ctrl+Alt+Fine) è nello XML del pannello/scorciatoie"
  ok "power-dialog installato"
}

c_corners() {
  step "Hot corners + Mission Control"
  de_set_hot_corners
  [ "$DE" = "cinnamon" ] && { ok "hot corners configurati nativamente"; return 0; }
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
  # avvio live SOLO in XFCE: xfdashboard --daemonize si APPENDE in una sessione
  # senza clutter/GL (es. Cinnamon); gli autostart li lanciano al login XFCE.
  if xfce_live; then
    have xfdashboard && (pgrep -f xfdashboard >/dev/null || setsid xfdashboard --daemonize >/dev/null 2>&1 &) || true
    pgrep -f "$HOME/.local/bin/macos-hot-corners" >/dev/null || \
      (setsid "$HOME/.local/bin/macos-hot-corners" >/dev/null 2>&1 &) || true
  fi
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
  de_set_notify_topright
  ok "notifiche"
}

c_wallpaper() {
  mkdir -p "$HOME/.local/share/wallpapers"
  local img
  if [ -n "${WALLPAPER:-}" ]; then
    # wallpaper personalizzato passato con --wallpaper (es. una foto macOS che
    # l'utente possiede ma che non possiamo redistribuire nel repo).
    [ -f "$WALLPAPER" ] || { warn "wallpaper non trovato: $WALLPAPER (salto)"; return 0; }
    step "Wallpaper (personalizzato: $(basename "$WALLPAPER"))"
    cp "$WALLPAPER" "$HOME/.local/share/wallpapers/" || { warn "copia wallpaper fallita"; return 0; }
    img="$HOME/.local/share/wallpapers/$(basename "$WALLPAPER")"
  else
    local wp="gradient-light.jpg"
    [ -f "$ASSETS/wallpapers/$wp" ] || { dim "nessun wallpaper nel pacchetto"; return 0; }
    step "Wallpaper (gradiente libero; usa --wallpaper PATH per la tua immagine)"
    cp "$ASSETS/wallpapers/$wp" "$HOME/.local/share/wallpapers/"
    img="$HOME/.local/share/wallpapers/$wp"
  fi
  de_set_wallpaper "$img"
  # Desktop pulito stile macOS: senza questo restano le icone della distro
  # (Computer/Home/Cestino) sul desktop e il look diventa un "mix" Mint/macOS.
  de_set_desktop_icons_off
  # reload del desktop SOLO in XFCE: 'xfdesktop --reload' senza un xfdesktop in
  # esecuzione (es. lanciato da Cinnamon) avvia un processo in FOREGROUND e si
  # appende -> timeout di sicurezza. Fuori da XFCE si applica al login (firstrun).
  xfce_live && have xfdesktop && timeout 8 xfdesktop --reload >/dev/null 2>&1 || true
  # Autostart "firstrun" (una tantum): se l'install è girato in un contesto
  # diverso dal login reale (SSH/headless/altro monitor), xfdesktop applica il
  # wallpaper sul monitor del LOGIN, che può avere ancora lo sfondo della distro.
  # Questo autostart lo ri-applica sul monitor effettivo al primo login, poi si
  # auto-rimuove. Risolve anche il desktop-icons sul monitor giusto.
  if [ "$DE" = xfce ]; then
    mkdir -p "$HOME/.config/macos-xfce" "$HOME/.local/bin" "$HOME/.config/autostart"
    printf '%s\n' "$img" > "$HOME/.config/macos-xfce/wallpaper"
    install -Dm755 "$ASSETS/bin/macos-xfce-firstrun.sh" "$HOME/.local/bin/macos-xfce-firstrun.sh"
    cat > "$HOME/.config/autostart/macos-xfce-firstrun.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=macOS-XFCE first-run
Comment=Applica wallpaper/desktop sul monitor reale al primo login, poi si rimuove
Exec=$HOME/.local/bin/macos-xfce-firstrun.sh
OnlyShowIn=XFCE;
X-XFCE-Autostart-enabled=true
StartupNotify=false
Terminal=false
EOF
    dim "firstrun: wallpaper/desktop si ri-applicano sul monitor reale al primo login"
  fi
  ok "wallpaper impostato + desktop pulito"
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

c_input() {
  step "Scroll naturale (touchpad + mouse)"
  if [ "$DE" = cinnamon ]; then
    gset org.cinnamon.desktop.peripherals.touchpad natural-scroll true
    gset org.cinnamon.desktop.peripherals.mouse natural-scroll true
    ok "scroll naturale (Cinnamon)"
    return 0
  fi
  install -Dm755 "$ASSETS/bin/macos-natural-scroll.sh" "$HOME/.local/bin/macos-natural-scroll.sh"
  mkdir -p "$HOME/.config/autostart"
  cat > "$HOME/.config/autostart/macos-natural-scroll.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=macOS Natural Scroll
Comment=Abilita scroll naturale su touchpad e mouse
Exec=$HOME/.local/bin/macos-natural-scroll.sh
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
  # applica subito (idempotente; va riapplicato ad ogni login/hot-plug -> autostart)
  [ -n "${DISPLAY:-}" ] && have xinput && "$HOME/.local/bin/macos-natural-scroll.sh" 2>/dev/null || true
  ok "scroll naturale (attivo ad ogni login)"
}

# Inietta l'azione Quick Look (Spazio -> gnome-sushi) in Thunar, preservando le
# azioni esistenti dell'utente. Idempotente.
inject_quicklook_action() {
  local d="$HOME/.config/Thunar"; mkdir -p "$d"
  local uca="$d/uca.xml"
  if [ ! -f "$uca" ]; then
    { echo '<?xml version="1.0" encoding="UTF-8"?>'; echo '<actions>'
      cat "$ASSETS/thunar/uca-quicklook.xml"; echo '</actions>'; } > "$uca"
  elif ! grep -q 'sushi %F' "$uca"; then
    backup_once "$uca"
    if have python3; then
      python3 - "$uca" "$ASSETS/thunar/uca-quicklook.xml" <<'PY' || warn "iniezione Quick Look ko"
import sys
uca, snip = sys.argv[1], sys.argv[2]
s = open(uca).read()
a = open(snip).read().rstrip() + "\n"
if "</actions>" in s:
    s = s.replace("</actions>", a + "</actions>", 1)
    open(uca, "w").write(s)
PY
    else
      warn "python3 mancante: azione Quick Look non iniettata"
    fi
  fi
  # accel: tasto Spazio -> Quick Look (id allineato a uca-quicklook.xml)
  local sc="$d/accels.scm"
  local line='(gtk_accel_path "<Actions>/ThunarActions/uca-action-macosxfce-quicklook-1" "space")'
  if [ -f "$sc" ]; then
    grep -q 'uca-action-macosxfce-quicklook-1' "$sc" || { backup_once "$sc"; printf '%s\n' "$line" >> "$sc"; }
  else
    printf '; thunar GtkAccelMap rc-file\n%s\n' "$line" > "$sc"
  fi
}

c_finder() {
  have thunar || { dim "Thunar non installato, salto Finder/Quick Look"; return 0; }
  [ "$DE" = xfce ] || { dim "Thunar/Quick Look: configurazione solo su XFCE"; return 0; }
  step "Thunar stile Finder + Quick Look"
  if have xfconf-query; then
    xq -c thunar -p /last-view -t string -s ThunarIconView --create
    xq -c thunar -p /last-icon-view-zoom-level -t string -s THUNAR_ZOOM_LEVEL_150_PERCENT --create
    xq -c thunar -p /last-location-bar -t string -s ThunarLocationButtons --create
    xq -c thunar -p /last-side-pane -t string -s ThunarShortcutsPane --create
    xq -c thunar -p /misc-single-click -t bool -s false --create
    xq -c thunar -p /misc-thumbnail-mode -t string -s THUNAR_THUMBNAIL_MODE_ALWAYS --create
  fi
  if have sushi; then
    inject_quicklook_action
  else
    dim "gnome-sushi non installato: niente Quick Look (azione Thunar saltata)"
  fi
  ok "Thunar configurato (icon view, Luoghi, breadcrumb, anteprime)"
}

c_emoji() {
  [ "$DE" = xfce ] || { dim "emoji picker: scorciatoia via xfconf (solo XFCE)"; return 0; }
  step "Emoji picker (Super+Ctrl+Spazio)"
  install -Dm755 "$ASSETS/bin/macos-emoji.sh" "$HOME/.local/bin/macos-emoji.sh"
  have rofi || dim "rofi non installato: il picker non si aprirà finché non lo installi"
  dim "scorciatoia Super+Ctrl+Spazio cablata nello XML delle scorciatoie (c_panel)"
  ok "emoji picker installato"
}

c_dynwall() {
  [ "$DE" = xfce ] || { dim "dynamic wallpaper: solo XFCE"; return 0; }
  if [ -n "${WALLPAPER:-}" ]; then
    dim "wallpaper personalizzato (--wallpaper): salto il dynamic wallpaper per non sovrascriverlo"
    return 0
  fi
  have systemctl || { dim "systemd non disponibile: salto il dynamic wallpaper"; return 0; }
  step "Dynamic wallpaper (chiaro di giorno, scuro di notte)"
  install -Dm755 "$ASSETS/bin/macos-dynamic-wallpaper.sh" "$HOME/.local/bin/macos-dynamic-wallpaper.sh"
  # serve una coppia chiaro/scuro: i gradienti liberi inclusi nel pacchetto
  mkdir -p "$HOME/.local/share/wallpapers"
  local g
  for g in gradient-light.jpg gradient-dark.jpg; do
    [ -f "$ASSETS/wallpapers/$g" ] && cp -n "$ASSETS/wallpapers/$g" "$HOME/.local/share/wallpapers/" 2>/dev/null || true
  done
  mkdir -p "$HOME/.config/systemd/user"
  sed "s#@HOME@#$HOME#g" "$ASSETS/systemd/macos-dynamic-wallpaper.service" \
    > "$HOME/.config/systemd/user/macos-dynamic-wallpaper.service"
  cp "$ASSETS/systemd/macos-dynamic-wallpaper.timer" \
    "$HOME/.config/systemd/user/macos-dynamic-wallpaper.timer"
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now macos-dynamic-wallpaper.timer 2>/dev/null \
    || warn "timer non avviato (sessione senza systemd user?)"
  ok "dynamic wallpaper (timer ogni 30 min)"
}

###############################################################################
# MAIN
###############################################################################
echo "${C_BLUE}macOS-XFCE installer${C_OFF}  (utente: $USER, home: $HOME, ambiente: ${C_GREEN}$DE${C_OFF})"
[ "$(id -u)" = "0" ] && { err "non lanciare come root: usa il tuo utente (chiederà sudo dove serve)"; exit 1; }

# Auto-DPI: se l'utente non ha passato --dpi (né --no-scale), rileva la scala
# adatta dallo schermo, così l'utente generico non deve conoscere il suo DPI.
if [ -z "$DPI" ] && [ "$NO_SCALE" = 0 ] && [ "$DE" = xfce ] && [ -n "${DISPLAY:-}" ]; then
  DPI="$(auto_dpi)"
  [ -n "$DPI" ] && step "Scala auto-rilevata: Xft.DPI=$DPI  (--dpi N o --no-scale per cambiare)"
fi

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
[ "$DO_INPUT"    = 1 ] && c_input
[ "$DO_FINDER"   = 1 ] && c_finder
[ "$DO_EMOJI"    = 1 ] && c_emoji
[ "$DO_DYNWALL"  = 1 ] && c_dynwall
[ "$DO_GREETER"  = 1 ] && c_greeter
[ "$DO_PLYMOUTH" = 1 ] && c_plymouth

# Sessione XFCE come default del DM: al prossimo login l'utente entra già nel
# desktop giusto senza doverla scegliere a mano.
[ "$ONLY" = "" ] && set_default_session_xfce

echo
step "Fatto."
if [ "$DE" = xfce ] && ! pgrep -x xfwm4 >/dev/null 2>&1; then
  echo "  • ${C_GREEN}IMPORTANTE${C_OFF}: il look macOS (glass/blur/angoli/ombre) gira nella sessione ${C_GREEN}Xfce${C_OFF}."
  echo "    L'ho impostata come predefinita: ti basta fare ${C_GREEN}logout/login${C_OFF} (parte già lei)."
fi
echo "  • Esegui un ${C_GREEN}logout/login${C_OFF} per applicare pannello, scorciatoie e autostart."
echo "  • Per il login screen:  ./install.sh --only greeter   (dopo aver installato nody-greeter)"
echo "  • Per il boot splash:   ./install.sh --plymouth"
echo "  • Disinstallazione:     ./uninstall.sh"
