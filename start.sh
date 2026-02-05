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

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║ PLACEHOLDER FOR FUTURE SCRIPT FUNCTION                                   ║
# ║                                                                           ║
# ║ Add your custom script function here. Example:                           ║
# ║                                                                           ║
# ║   run_custom_script() {                                                   ║
# ║     /path/to/your/script.sh                                               ║
# ║   }                                                                        ║
# ║                                                                           ║
# ║ Then call it from the menu by replacing the placeholder in case 4 below  ║
# ╚══════════════════════════════════════════════════════════════════════════╝

main_menu() {
  while true; do
    CHOICE=$(whiptail \
      --title "SSD Wipe Station - Main Menu" \
      --menu "Choose an option:" \
      20 70 10 \
      "1" "TRIM/Discard Erase (blkdiscard - fastest)" \
      "2" "ATA Secure Erase (hdparm - SATA drives)" \
      "3" "NVMe Format (nvme - NVMe drives)" \
      "4" "Custom Script (ADD YOUR SCRIPT HERE)" \
      "5" "Exit" \
      3>&1 1>&2 2>&3
    )
    
    case $CHOICE in
      1)
        # Call blkdiscard script
        ssd-wipe-blkdiscard
        ;;
      2)
        # Call hdparm script
        ssd-wipe-hdparm
        ;;
      3)
        # Call nvme script
        ssd-wipe-nvme
        ;;
      4)
        # ╔════════════════════════════════════════════════════════════╗
        # ║ PLACEHOLDER: Replace this with your custom script call    ║
        # ║                                                             ║
        # ║ Example:                                                    ║
        # ║   run_custom_script                                         ║
        # ║   /path/to/your-script.sh                                   ║
        # ║   bash /home/user/my-tool.sh                                ║
        # ╚════════════════════════════════════════════════════════════╝
        
        whiptail --msgbox "Custom script placeholder\n\nAdd your script here!" 10 50
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
