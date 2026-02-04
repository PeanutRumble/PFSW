#!/usr/bin/env bash

export TERM=linux

set -euo pipefail

require_root() {
  [[ $EUID -eq 0 ]] || { echo "Must be run as root"; exit 1; }
}

whiptail --title "SSD Wipe Station" \
  --msgbox "Initializing disk subsystem...\n\nPlease wait." \
  10 50

get_ssds() {
  lsblk -ndo NAME,ROTA,TYPE,MOUNTPOINT |
    awk '$2==0 && $3=="disk" && $4=="" {print $1}'
}

build_whiptail_list() {
  for d in $(get_ssds); do
    size=$(lsblk -ndo SIZE /dev/"$d")
    echo "/dev/$d" "$size" OFF
  done
}

require_root

for i in {1..10}; do
  lsblk >/dev/null 2>&1 && break
  sleep 1
done

SSDS=$(get_ssds)
[[ -z "$SSDS" ]] && whiptail --msgbox "No eligible SSDs found." 8 40 && exit 0

CHOICES=$(whiptail \
  --title "SSD Secure Erase" \
  --checklist "Select SSDs to erase (blkdiscard):" \
  20 70 10 \
  $(build_whiptail_list) \
  3>&1 1>&2 2>&3
)

[[ -z "$CHOICES" ]] && exit 0

whiptail --yesno \
  "This will PERMANENTLY ERASE:\n\n$CHOICES\n\nProceed?" \
  15 60 || exit 1

RESULTS=()
EXIT_CODE=0

for dev in $CHOICES; do
  if blkdiscard -f "$dev"; then
    RESULTS+=("$dev : SUCCESS")
  else
    RESULTS+=("$dev : FAILURE")
    EXIT_CODE=1
  fi
done

whiptail --title "Erase Results" \
  --msgbox "$(printf '%s\n' "${RESULTS[@]}")" \
  20 70

exit $EXIT_CODE


