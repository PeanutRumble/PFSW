#!/usr/bin/env bash
export TERM=linux
set -euo pipefail

require_root() {
  [[ $EUID -eq 0 ]] || { echo "Must be run as root"; exit 1; }
}

whiptail --title "SSD Wipe Station (hdparm)" \
  --msgbox "Initializing disk subsystem...\n\nPlease wait." \
  10 50

get_ssds() {
  lsblk -ndo NAME,ROTA,TYPE,MOUNTPOINT |
    awk '$2==0 && $3=="disk" && $4=="" {print $1}'
}


check_security_support() {
  local dev=$1
  hdparm -I "$dev" 2>/dev/null | grep -q "supported: enhanced erase"
}

check_frozen() {
  local dev=$1
  hdparm -I "$dev" 2>/dev/null | grep -q "frozen"
}

build_whiptail_list() {
  for d in $(get_ssds); do
    size=$(lsblk -ndo SIZE /dev/"$d")
    # Only include drives that support security erase and aren't NVMe
    if [[ ! "$d" =~ ^nvme ]] && check_security_support "/dev/$d"; then
      echo "/dev/$d" "$size" OFF
    fi
  done
}

require_root

for i in {1..10}; do
  lsblk >/dev/null 2>&1 && break
  sleep 1
done

SSDS=$(get_ssds)
[[ -z "$SSDS" ]] && whiptail --msgbox "No eligible SSDs found." 8 40 && exit 0


DRIVE_LIST=$(build_whiptail_list)
[[ -z "$DRIVE_LIST" ]] && whiptail --msgbox "No SSDs with ATA Secure Erase support found.\n\nNote: NVMe drives are not supported by hdparm." 10 50 && exit 0

CHOICES=$(whiptail \
  --title "SSD Secure Erase (hdparm)" \
  --checklist "Select SSDs to erase (ATA Secure Erase):" \
  20 70 10 \
  $DRIVE_LIST \
  3>&1 1>&2 2>&3
)

[[ -z "$CHOICES" ]] && exit 0

whiptail --yesno \
  "This will PERMANENTLY ERASE using ATA Secure Erase:\n\n$CHOICES\n\nProceed?" \
  15 60 || exit 1

RESULTS=()
EXIT_CODE=0
TEMP_PASS="Erase"

eval "CHOICES_ARRAY=($CHOICES)"

for dev in "${CHOICES_ARRAY[@]}"; do
  ERROR_MSG=""
  
 
  if check_frozen "$dev"; then
    RESULTS+=("$dev : FAILED - Drive is FROZEN")
    RESULTS+=("  Suspend/resume the system or use a different method")
    EXIT_CODE=1
    continue
  fi
  
 
  if ! hdparm --user-master u --security-set-pass "$TEMP_PASS" "$dev" >/dev/null 2>&1; then
    RESULTS+=("$dev : FAILED - Could not set password")
    EXIT_CODE=1
    continue
  fi
  
 
  if hdparm -I "$dev" 2>/dev/null | grep -q "supported: enhanced erase"; then
    ERROR_MSG=$(hdparm --user-master u --security-erase-enhanced "$TEMP_PASS" "$dev" 2>&1)
  else
    ERROR_MSG=$(hdparm --user-master u --security-erase "$TEMP_PASS" "$dev" 2>&1)
  fi
  
  if [[ $? -eq 0 ]]; then
    RESULTS+=("$dev : SUCCESS")
  else
    RESULTS+=("$dev : FAILED")
    RESULTS+=("  Error: $ERROR_MSG")
    EXIT_CODE=1
    
 
    hdparm --user-master u --security-disable "$TEMP_PASS" "$dev" >/dev/null 2>&1 || true
  fi
done

whiptail --title "Erase Results" \
  --msgbox "$(printf '%s\n' "${RESULTS[@]}")" \
  20 70

exit $EXIT_CODE