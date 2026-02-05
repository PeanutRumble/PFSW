#!/usr/bin/env bash
export TERM=linux
set -euo pipefail

require_root() {
  [[ $EUID -eq 0 ]] || { echo "Must be run as root"; exit 1; }
}

whiptail --title "NVMe Wipe Station" \
  --msgbox "NVME script starts?" \
  10 50

get_nvme_drives() {
  lsblk -ndo NAME,ROTA,TYPE,MOUNTPOINT |
    awk '$2==0 && $3=="disk" && $4=="" {print $1}' |
    grep "^nvme"
}


check_nvme_cli() {
  if ! command -v nvme &>/dev/null; then
    whiptail --msgbox "ERROR: nvme-cli is not installed.\n\nInstall with: apt install nvme-cli" 10 50
    exit 1
  fi
}


check_format_support() {
  local dev=$1
  nvme id-ns "$dev" 2>/dev/null | grep -q "Format "
}

build_whiptail_list() {
  for d in $(get_nvme_drives); do
    size=$(lsblk -ndo SIZE /dev/"$d")
    echo "/dev/$d" "$size" OFF
  done
}

require_root
check_nvme_cli

for i in {1..10}; do
  lsblk >/dev/null 2>&1 && break
  sleep 1
done

NVME_DRIVES=$(get_nvme_drives)
[[ -z "$NVME_DRIVES" ]] && whiptail --msgbox "No eligible NVMe drives found." 8 40 && exit 0

DRIVE_LIST=$(build_whiptail_list)
[[ -z "$DRIVE_LIST" ]] && whiptail --msgbox "No NVMe drives available for formatting." 10 50 && exit 0

CHOICES=$(whiptail \
  --title "NVMe Secure Erase" \
  --checklist "Select NVMe drives to erase (nvme format):" \
  20 70 10 \
  $DRIVE_LIST \
  3>&1 1>&2 2>&3
)

[[ -z "$CHOICES" ]] && exit 0


FORMAT_TYPE=$(whiptail \
  --title "Format Type" \
  --radiolist "Choose erase method:" \
  15 70 3 \
  "1" "Crypto Erase (fastest, if supported)" ON \
  "2" "User Data Erase (thorough)" OFF \
  3>&1 1>&2 2>&3
)

[[ -z "$FORMAT_TYPE" ]] && exit 0

case $FORMAT_TYPE in
  1) SES_VALUE=2; METHOD="Cryptographic Erase" ;;
  2) SES_VALUE=1; METHOD="User Data Erase" ;;
esac

whiptail --yesno \
  "This will PERMANENTLY ERASE using $METHOD:\n\n$CHOICES\n\nProceed?" \
  15 60 || exit 1

RESULTS=()
EXIT_CODE=0

eval "CHOICES_ARRAY=($CHOICES)"

for dev in "${CHOICES_ARRAY[@]}"; do
  ERROR_MSG=""
  
 
  if [[ ! "$dev" =~ nvme[0-9]+n[0-9]+ ]]; then
    RESULTS+=("$dev : FAILED - Invalid NVMe device name")
    EXIT_CODE=1
    continue
  fi
  
 
  ERROR_MSG=$(nvme format "$dev" --ses=$SES_VALUE --force 2>&1)
  
  if [[ $? -eq 0 ]]; then
    RESULTS+=("$dev : SUCCESS ($METHOD)")
  else
    RESULTS+=("$dev : FAILED")
    RESULTS+=("  Error: $ERROR_MSG")
    EXIT_CODE=1
  fi
  
 
  sleep 1
done

whiptail --title "Erase Results" \
  --msgbox "$(printf '%s\n' "${RESULTS[@]}")" \
  20 70

exit $EXIT_CODE
