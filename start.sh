#!/usr/bin/env bash
export TERM=linux
set -euo pipefail

require_root() {
  [[ $EUID -eq 0 ]] || { echo "Must be run as root"; exit 1; }
}

show_ascii_art() {
  clear
  cat << 'EOF'
################################################################################
#                                                                              #
#                                                                              #
#                           ____________ _____ __   __                         #
#                           | ___ \  ___/  ___|| |  | |                        #
#                           | |_/ / |_  \ `--. | |  | |                        #
#                           |  __/|  _|  `--. \| |/\| |                        #
#                           | |   | |   /\__/ /\  /\  /                        #
#                           \_|   \_|   \____/  \/  \/                         #
#                                                                              #
#                                                                              #
################################################################################


EOF
  sleep 2
}


main_menu() {
  while true; do
    CHOICE=$(whiptail \
      --title "Peanut's Flash Storage Wipe - Select" \
      --menu "Choose an option:" \
      20 70 10 \
      "1" "TRIM/Discard Erase (blkdiscard - Fastest and most compatible)" \
      "2" "ATA Secure Erase (hdparm - SATA drives supporting Secure Erase)" \
      "3" "NVMe Format (nvme-cli - NVMe drives)" \
      "4" "USB Erase (Will slightly damage lifespan)" \
      "5" "Exit" \
      3>&1 1>&2 2>&3
    )
    
    case $CHOICE in
      1)
        # Call blkdiscard script
        blkdis.sh
        ;;
      2)
        # Call hdparm script
        hdpar.sh
        ;;
      3)
        # Call nvme script
        nvme.sh
        ;;
      4)
        #usb stuff
        usbfor.sh
        ;;
      5)
        exit 0
        ;;
      *)
        exit 0
        ;;
    esac
  done
}

# Main execution
require_root
show_ascii_art
main_menu
