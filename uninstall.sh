#!/usr/bin/env bash
###############################################################################
# Disinstallazione macOS-XFCE. Ripristina i default ragionevoli e rimuove gli
# autostart/script aggiunti. NON rimuove i pacchetti apt né i temi WhiteSur
# (toglili a mano se vuoi). Ripristina i backup .macos-bak dove presenti.
###############################################################################
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

step "Ripristino impostazioni XFCE"
if have xfconf-query; then
  xq -c xsettings -p /Gtk/FontName -s "Sans 10" 2>/dev/null || true
  xq -c xfwm4 -p /general/title_font -s "Sans Bold 9" 2>/dev/null || true
  xq -c xfwm4 -p /general/use_compositing -s true 2>/dev/null || true
  xq -c xfwm4 -p /general/margin_top -s 0 2>/dev/null || true
  xq -c xfwm4 -p /general/button_layout -s "O|HMC" 2>/dev/null || true
  xq -c xfce4-notifyd -p /theme -s Default 2>/dev/null || true
  xq -c xfdashboard -p /theme -s Default 2>/dev/null || true
  xq -c xsettings -p /Xft/DPI -s 96 2>/dev/null || true
  xq -c xsettings -p /Xft/RGBA -s rgb 2>/dev/null || true
fi

# Ripristino Cinnamon: l'installer su Cinnamon applica tema/icone/cursori/wm/
# pannello/scroll/wallpaper via gsettings; qui li riportiamo ai default con
# 'gsettings reset' (reversibile e indipendente dal tema della distro).
if have gsettings; then
  step "Ripristino impostazioni Cinnamon"
  # greset SCHEMA KEY [KEY...] — resetta solo se lo schema è installato e la chiave scrivibile
  greset() {
    local schema="$1"; shift
    gsettings list-schemas 2>/dev/null | grep -qx "$schema" || return 0
    local key
    for key in "$@"; do
      gsettings writable "$schema" "$key" >/dev/null 2>&1 && \
        gsettings reset "$schema" "$key" 2>/dev/null || true
    done
  }
  greset org.cinnamon.desktop.interface gtk-theme icon-theme cursor-theme \
                                        font-name text-scaling-factor scaling-factor
  greset org.cinnamon.theme name
  greset org.cinnamon.desktop.wm.preferences theme titlebar-font button-layout
  greset org.cinnamon.desktop.background picture-uri picture-options
  greset org.cinnamon.desktop.peripherals.touchpad natural-scroll
  greset org.cinnamon.desktop.peripherals.mouse natural-scroll
  greset org.nemo.desktop computer-icon-visible home-icon-visible trash-icon-visible \
                          volumes-visible network-icon-visible
  greset org.cinnamon panels-enabled panels-height panel-zone-icon-sizes \
                      enabled-applets next-applet-id hotcorner-layout
  # Scorciatoie macOS (Spotlight/Emoji): azzera lo schema relocatable e togli i
  # NOSTRI slot da custom-list, lasciando intatti i custom dell'utente.
  _kbschema="org.cinnamon.desktop.keybindings.custom-keybinding"
  for _kb in macos-spotlight macos-emoji; do
    gsettings reset-recursively "$_kbschema:/org/cinnamon/desktop/keybindings/custom-keybindings/$_kb/" 2>/dev/null || true
  done
  if have python3; then
    python3 - <<'PY' 2>/dev/null || true
import subprocess, ast
try:
    cur = subprocess.check_output(['gsettings','get','org.cinnamon.desktop.keybindings','custom-list']).decode().strip()
    lst = ast.literal_eval(cur) if cur and cur != '@as []' else []
    lst = [x for x in lst if x not in ('macos-spotlight','macos-emoji')]
    subprocess.run(['gsettings','set','org.cinnamon.desktop.keybindings','custom-list', str(lst)])
except Exception:
    pass
PY
  fi
  # Applet Cinnamenu copiato dall'installer (menu limone). NB: lo rimuove anche se
  # l'utente lo usava da prima — è una disinstallazione del tema.
  rm -rf "$HOME/.local/share/cinnamon/applets/Cinnamenu@json" \
         "$HOME/.config/cinnamon/spices/Cinnamenu@json" 2>/dev/null || true
  # Plank (dconf): ripristina il dump fatto dall'installer prima di toccarlo.
  if have dconf && [ -e "$HOME/.config/plank/dconf-plank.macos-bak" ]; then
    dconf load /net/launchpad/plank/ < "$HOME/.config/plank/dconf-plank.macos-bak" 2>/dev/null \
      && ok "impostazioni Plank ripristinate" || true
  fi
  ok "impostazioni Cinnamon ripristinate (logout/login per applicare il pannello)"
fi

# dynamic wallpaper: disattiva il timer utente
if have systemctl; then
  systemctl --user disable --now macos-dynamic-wallpaper.timer 2>/dev/null || true
fi

step "Rimozione autostart e script utente"
rm -f "$HOME/.config/autostart/picom.desktop" \
      "$HOME/.config/autostart/macos-hot-corners.desktop" \
      "$HOME/.config/autostart/macos-natural-scroll.desktop" \
      "$HOME/.config/autostart/macos-xfce-firstrun.desktop" \
      "$HOME/.config/autostart/plank.desktop"
rm -f "$HOME/.local/bin/macos-power-dialog" "$HOME/.local/bin/macos-hot-corners" \
      "$HOME/.local/bin/macos-natural-scroll.sh" "$HOME/.local/bin/macos-clock-genmon.sh" \
      "$HOME/.local/bin/gsimplecal-toggle.sh" \
      "$HOME/.local/bin/macos-emoji.sh" "$HOME/.local/bin/macos-spotlight.sh" \
      "$HOME/.local/bin/macos-dynamic-wallpaper.sh" \
      "$HOME/.local/bin/macos-xfce-firstrun.sh"
rm -f "$HOME/.config/systemd/user/macos-dynamic-wallpaper.service" \
      "$HOME/.config/systemd/user/macos-dynamic-wallpaper.timer"

# ferma i processi (per PID, niente pkill -f)
for n in picom picom-anim plank xfdashboard; do
  for pid in $(pgrep -x "$n" 2>/dev/null); do kill "$pid" 2>/dev/null || true; done
done
for pid in $(ps -eo pid,args | grep -F "$HOME/.local/bin/macos-hot-corners" | grep -v grep | awk '{print $1}'); do
  kill "$pid" 2>/dev/null || true
done

step "Ripristino XML pannello/scorciatoie dai backup (se presenti)"
X="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
for ch in xfce4-panel xfce4-keyboard-shortcuts; do
  [ -e "$X/$ch.xml.macos-bak" ] && mv -f "$X/$ch.xml.macos-bak" "$X/$ch.xml" && ok "ripristinato $ch.xml"
done

step "Greeter / Plymouth (richiede sudo, opzionale)"
if confirm "Ripristinare il greeter di login di default?"; then
  as_root rm -f /etc/lightdm/lightdm.conf.d/99-nody-greeter.conf && ok "greeter ripristinato"
fi
if confirm "Ripristinare il boot splash di default (mint-logo)?"; then
  if [ -e /usr/share/plymouth/themes/mint-logo/mint-logo.plymouth ]; then
    as_root update-alternatives --set default.plymouth \
      /usr/share/plymouth/themes/mint-logo/mint-logo.plymouth && as_root update-initramfs -u
  else
    warn "tema mint-logo non trovato; scegli un altro default con update-alternatives --config default.plymouth"
  fi
fi

# Su una sessione Cinnamon viva, offri il riavvio della shell per applicare subito
# il ripristino (pannello/applet/scorciatoie si ricaricano all'avvio della shell).
if have gsettings && [ -n "${DISPLAY:-}" ] && pgrep -x cinnamon >/dev/null 2>&1; then
  if confirm "Riavviare Cinnamon ora per applicare subito il ripristino?"; then
    setsid bash -c 'cinnamon --replace' >/dev/null 2>&1 &
    ok "Cinnamon riavviato"
  fi
fi

echo; step "Fatto. Esegui logout/login per completare."
echo "  (rimozione manuale eventuale: temi ~/.themes/WhiteSur*, icone ~/.local/share/icons/WhiteSur*, font ~/.local/share/fonts/SF-Pro)"
