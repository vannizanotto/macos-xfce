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

# dynamic wallpaper: disattiva il timer utente
if have systemctl; then
  systemctl --user disable --now macos-dynamic-wallpaper.timer 2>/dev/null || true
fi

step "Rimozione autostart e script utente"
rm -f "$HOME/.config/autostart/picom.desktop" \
      "$HOME/.config/autostart/macos-hot-corners.desktop" \
      "$HOME/.config/autostart/macos-natural-scroll.desktop" \
      "$HOME/.config/autostart/plank.desktop"
rm -f "$HOME/.local/bin/macos-power-dialog" "$HOME/.local/bin/macos-hot-corners" \
      "$HOME/.local/bin/macos-natural-scroll.sh" "$HOME/.local/bin/macos-clock-genmon.sh" \
      "$HOME/.local/bin/macos-emoji.sh" "$HOME/.local/bin/macos-dynamic-wallpaper.sh"
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

echo; step "Fatto. Esegui logout/login per completare."
echo "  (rimozione manuale eventuale: temi ~/.themes/WhiteSur*, icone ~/.local/share/icons/WhiteSur*, font ~/.local/share/fonts/SF-Pro)"
