#!/usr/bin/env bash
# Helper condivisi per l'installer macOS-XFCE.

# --- colori/log -------------------------------------------------------------
if [ -t 1 ]; then
  C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'; C_YELL=$'\033[1;33m'
  C_RED=$'\033[1;31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_BLUE=; C_GREEN=; C_YELL=; C_RED=; C_DIM=; C_OFF=
fi
step()  { printf '%s\n' "${C_BLUE}==>${C_OFF} $*"; }
ok()    { printf '%s\n' "  ${C_GREEN}ok${C_OFF} $*"; }
warn()  { printf '%s\n' "  ${C_YELL}!!${C_OFF} $*" >&2; }
err()   { printf '%s\n' "${C_RED}errore:${C_OFF} $*" >&2; }
dim()   { printf '%s\n' "  ${C_DIM}$*${C_OFF}"; }

# --- utility ----------------------------------------------------------------
have()  { command -v "$1" >/dev/null 2>&1; }

# Chiede conferma (rispetta --yes => ASSUME_YES=1)
confirm() {
  [ "${ASSUME_YES:-0}" = "1" ] && return 0
  local ans
  read -r -p "  $1 [s/N] " ans
  [[ "$ans" =~ ^[sSyY]$ ]]
}

# Esegue un comando con sudo se disponibile, altrimenti avverte e ritorna 1
as_root() {
  if [ "$(id -u)" = "0" ]; then "$@"; return $?; fi
  if have sudo; then sudo "$@"; return $?; fi
  warn "serve root per: $*"; return 1
}

# backup di un file/dir prima di sovrascriverlo (una volta sola)
backup_once() {
  local t="$1"
  [ -e "$t" ] || return 0
  [ -e "$t.macos-bak" ] && return 0
  cp -a "$t" "$t.macos-bak" && dim "backup: $t.macos-bak"
}

# imposta una proprietà xfconf (create se manca)
xq() { xfconf-query "$@"; }
