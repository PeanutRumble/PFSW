#!/usr/bin/env bash

export TERM=linux

set -euo pipefail

require_root() {
  [[ $EUID -eq 0 ]] || { echo "Must be run as root"; exit 1; }
}

whiptail --title "SSD Wipe Station" \
  --msgbox "blkdiscard script starts?" \
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

verify_wipe() {
  local dev="$1"
  local drive_bytes
  drive_bytes=$(blockdev --getsize64 "$dev" 2>/dev/null) || return 2

  local offsets=()
  for pct in 0 25 50 75 99; do
    offsets+=( $(( drive_bytes * pct / 100 )) )
  done

  for offset in "${offsets[@]}"; do
    local sample
    sample=$(dd if="$dev" bs=4096 count=1 skip=$(( offset / 4096 )) \
             iflag=direct status=none 2>/dev/null) || return 2
    if echo "$sample" | tr -d '\0' | grep -qP '.'; then
      return 1
    fi
  done
  return 0
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

eval "CHOICES_ARRAY=($CHOICES)"

for dev in "${CHOICES_ARRAY[@]}"; do
  if blkdiscard -f "$dev"; then
    verify_wipe "$dev"
    VERIFY=$?
    if [[ $VERIFY -eq 0 ]]; then
      RESULTS+=("$dev : SUCCESS (verified zeroes)")
    elif [[ $VERIFY -eq 1 ]]; then
      RESULTS+=("$dev : WARNING - blkdiscard reported success but non-zero data found. Drive may have ignored the command.")
      EXIT_CODE=1
    else
      RESULTS+=("$dev : SUCCESS (verification read failed - treat as unconfirmed)")
      EXIT_CODE=1
    fi
  else
    RESULTS+=("$dev : FAILURE - blkdiscard returned an error")
    EXIT_CODE=1
  fi
done

whiptail --title "Erase Results" \
  --msgbox "$(printf '%s\n' "${RESULTS[@]}")" \
  20 70

exit $EXIT_CODE
