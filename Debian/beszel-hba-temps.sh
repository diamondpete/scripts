#!/bin/sh
# Build the sensor folder the Beszel agent reads (SYS_SENSORS=/run/beszel-sys):
# the real sensors, plus the CPU, NVMe drives and Adaptec controllers under names
# that say what they are. Names are worked out here at run time:
#   cpu                             package reading only, not one line per core
#   <owner>_nvme_a, <owner>_nvme_b  mirror pair, one Composite reading per drive
#   <vm>_tank                       Adaptec controller, else hba<number>
# <owner> is the Proxmox VM whose config lists the drive's serial, else this host.
set -eu
ROOT=/run/beszel-sys/class/hwmon
VM_CONFIGS=/etc/pve/qemu-server
mkdir -p "$ROOT"

# vm_of <serial>: print the name of the VM that uses this disk, if any
vm_of() {
  [ -n "$1" ] || return 0
  conf=$(grep -lF -- "$1" "$VM_CONFIGS"/*.conf 2>/dev/null | head -n 1)
  # Stop at the first [section]: snapshots keep their own copy of name:
  [ -z "$conf" ] || sed -n '/^\[/q; s/^name: *//p' "$conf"
}

# has_name <sensor name> <hwmon path>
has_name() {
  grep -qx "$1" "$2/name" 2>/dev/null
}

# Print "<sensor name> <hwmon path>" for each NVMe drive. Sorting by serial keeps
# each drive on the same letter between boots, unlike the nvmeN numbers.
nvme_list() {
  for h in /sys/class/hwmon/hwmon*; do
    has_name nvme "$h" || continue
    serial=$(tr -d ' ' < "$h/device/serial")
    owner=$(vm_of "$serial")
    printf '%s %s %s\n' "${owner:-$(hostname -s)}_nvme" "$serial" "$h"
  done | sort | awk '{
    n = ($1 == prev) ? n + 1 : 0
    prev = $1
    print $1 "_" substr("abcdefghijklmnopqrstuvwxyz", n + 1, 1), $3
  }'
}

# hba_name <controller>: name it after the VM using the disks attached to it
hba_name() {
  arcconf getconfig "$1" PD 2>/dev/null |
    awk -F: 'tolower($1) ~ /serial number/ { gsub(/ /, "", $2); print $2 }' |
    { vm=
      while read -r serial; do
        vm=$(vm_of "$serial")
        [ -z "$vm" ] || break
      done
      echo "${vm:+${vm}_tank}"
    }
}

# Mirror the real sensors so Beszel keeps seeing the NIC/etc.
for h in /sys/class/hwmon/hwmon*; do
  if has_name nvme "$h" || has_name coretemp "$h"; then
    rm -f "$ROOT/${h##*/}"
  else
    ln -sfn "$(readlink -f "$h")" "$ROOT/${h##*/}"
  fi
done

# The CPU package reading, which follows the hottest core, linked so it stays live
for h in /sys/class/hwmon/hwmon*; do
  has_name coretemp "$h" || continue
  label=$(grep -l '^Package id' "$h"/temp*_label 2>/dev/null | head -n 1)
  [ -n "$label" ] || continue
  d="$ROOT/hwmon-cpu"
  mkdir -p "$d"
  [ -s "$d/name" ] || echo cpu > "$d/name"
  ln -sfn "$(readlink -f "${label%_label}_input")" "$d/temp1_input"
done

# Each NVMe drive's Composite reading (temp1), linked so it stays live
nvme_list | while read -r name h; do
  d="$ROOT/hwmon-$name"
  mkdir -p "$d"
  [ -s "$d/name" ] || echo "$name" > "$d/name"
  ln -sfn "$(readlink -f "$h/temp1_input")" "$d/temp1_input"
done

# Add each Adaptec controller's temperature (millidegrees C)
for c in 1 2; do
  t=$(arcconf getconfig $c AD 2>/dev/null | awk -F: '/Temperature/{print $2+0; exit}')
  d="$ROOT/hwmon-hba$c"
  # No reading: drop the old value so Beszel doesn't keep showing it as current
  if [ -z "$t" ] || [ "$t" -le 0 ]; then
    rm -f "$d/temp1_input"
    continue
  fi
  mkdir -p "$d"
  # Listing the disks is slow, so only do it until the controller has a VM name
  if ! [ -s "$d/name" ] || [ "$(cat "$d/name")" = "hba$c" ]; then
    name=$(hba_name "$c")
    echo "${name:-hba$c}" > "$d/name"
  fi
  echo $((t * 1000)) > "$d/temp1_input.tmp" && mv "$d/temp1_input.tmp" "$d/temp1_input"
done
