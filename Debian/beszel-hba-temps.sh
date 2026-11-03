#!/bin/sh
set -eu
ROOT=/run/beszel-sys/class/hwmon
mkdir -p "$ROOT"
# Mirror the real sensors so Beszel keeps seeing CPU/NVMe/etc.
for h in /sys/class/hwmon/hwmon*; do
  ln -sfn "$(readlink -f "$h")" "$ROOT/$(basename "$h")"
done
# Add each Adaptec controller's temperature (millidegrees C)
for c in 1 2; do
  t=$(arcconf getconfig $c AD 2>/dev/null | awk -F: '/Temperature/{print $2+0; exit}')
  [ -n "$t" ] || continue
  d="$ROOT/hwmon-hba$c"
  mkdir -p "$d"
  echo "hba$c" > "$d/name"
  echo $((t * 1000)) > "$d/temp1_input.tmp" && mv "$d/temp1_input.tmp" "$d/temp1_input"
done
