#!/usr/bin/env bash
export TERM=linux
set -euo pipefail

require_root() {
  [[ $EUID -eq 0 ]] || { echo "Must be run as root"; exit 1; }
}

whiptail --title "USB Wipe Station" \
  --msgbox "Initializing USB subsystem...\n\nPlease wait." \
  10 50

get_usb_drives() {
  # Find removable drives that are USB and not mounted
  for dev in /sys/block/sd*; do
    # Check if it's removable (USB)
    if [[ -f "$dev/removable" ]] && [[ $(cat "$dev/removable") -eq 1 ]]; then
      devname=$(basename "$dev")
      # Check if not mounted
      if ! lsblk -ndo MOUNTPOINT /dev/"$devname" | grep -q .; then
        echo "$devname"
      fi
    fi
  done
}

build_whiptail_list() {
  for d in $(get_usb_drives); do
    size=$(lsblk -ndo SIZE /dev/"$d")
    model=$(lsblk -ndo MODEL /dev/"$d" | xargs)
    echo "/dev/$d" "$size - $model" OFF
  done
}

require_root

for i in {1..10}; do
  lsblk >/dev/null 2>&1 && break
  sleep 1
done

USB_DRIVES=$(get_usb_drives)
[[ -z "$USB_DRIVES" ]] && whiptail --msgbox "No eligible USB drives found.\n\nMake sure USB drives are connected and unmounted." 10 50 && exit 0

DRIVE_LIST=$(build_whiptail_list)
[[ -z "$DRIVE_LIST" ]] && whiptail --msgbox "No USB drives available for wiping." 10 50 && exit 0

CHOICES=$(whiptail \
  --title "USB Secure Wipe" \
  --checklist "Select USB drives to wipe:" \
  20 70 10 \
  $DRIVE_LIST \
  3>&1 1>&2 2>&3
)

[[ -z "$CHOICES" ]] && exit 0

# Choose wipe method
METHOD=$(whiptail \
  --title "Wipe Method" \
  --radiolist "Choose wipe method:" \
  18 78 4 \
  "1" "Quick Wipe (zero first/last 10MB - fast, flash-friendly)" ON \
  "2" "Full Wipe (single zero pass - thorough, flash-friendly)" OFF \
  "3" "Partition Table Wipe (zero first 100MB - very fast)" OFF \
  "4" "Full Random Wipe (WARNING: heavy wear on flash!)" OFF \
  3>&1 1>&2 2>&3
)

[[ -z "$METHOD" ]] && exit 0

case $METHOD in
  1) METHOD_NAME="Quick Wipe" ;;
  2) METHOD_NAME="Full Zero Wipe" ;;
  3) METHOD_NAME="Partition Table Wipe" ;;
  4) METHOD_NAME="Full Random Wipe" ;;
esac

whiptail --yesno \
  "This will PERMANENTLY ERASE using $METHOD_NAME:\n\n$CHOICES\n\nProceed?" \
  15 60 || exit 1

RESULTS=()
EXIT_CODE=0

eval "CHOICES_ARRAY=($CHOICES)"

for dev in "${CHOICES_ARRAY[@]}"; do
  ERROR_MSG=""
  
  case $METHOD in
    1)
      # Quick wipe - zero first and last 10MB
      {
        dd if=/dev/zero of="$dev" bs=1M count=10 2>&1 &&
        SIZE=$(blockdev --getsz "$dev") &&
        SKIP=$((SIZE / 512 - 10240)) &&
        dd if=/dev/zero of="$dev" bs=512 seek=$SKIP count=10240 2>&1
      } > /tmp/wipe_output.txt 2>&1
      ;;
    2)
      # Full zero wipe - single pass only (flash-friendly)
      dd if=/dev/zero of="$dev" bs=4M status=progress 2>&1 > /tmp/wipe_output.txt
      ;;
    3)
      # Partition table wipe - zero first 100MB (destroys all partition info)
      dd if=/dev/zero of="$dev" bs=1M count=100 status=progress 2>&1 > /tmp/wipe_output.txt
      ;;
    4)
      # Full random wipe - WARNING: this is harsh on flash!
      # Only use if data sensitivity requires it
      dd if=/dev/urandom of="$dev" bs=4M status=progress 2>&1 > /tmp/wipe_output.txt
      ;;
  esac
  
  if [[ $? -eq 0 ]]; then
    RESULTS+=("$dev : SUCCESS ($METHOD_NAME)")
  else
    ERROR_MSG=$(tail -3 /tmp/wipe_output.txt)
    RESULTS+=("$dev : FAILED")
    RESULTS+=("  Error: $ERROR_MSG")
    EXIT_CODE=1
  fi
  
  # Sync to ensure all writes complete
  sync
done

# Clean up temp file
rm -f /tmp/wipe_output.txt

whiptail --title "Wipe Results" \
  --msgbox "$(printf '%s\n' "${RESULTS[@]}")" \
  20 70

exit $EXIT_CODE
