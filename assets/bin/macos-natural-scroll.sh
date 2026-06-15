#!/bin/bash
# Abilita lo scroll naturale (macOS-style) su tutti i pointer libinput.
# Idempotente: rieseguibile a ogni login / hot-plug.
for id in $(xinput list --id-only 2>/dev/null); do
  if xinput list-props "$id" 2>/dev/null | grep -q "libinput Natural Scrolling Enabled ("; then
    xinput set-prop "$id" "libinput Natural Scrolling Enabled" 1 2>/dev/null
  fi
done
