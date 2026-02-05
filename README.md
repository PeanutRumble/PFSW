# Peanut's Flash Storage Wiper

PFSW is a TUI based flash storage wiper for linux making use of hdparm, blkdiscard, and nvme-cli and simplifies the usage of the tools in a large scale wiping operation allowing multiple drives to be queued.

### Usage:
in the repo directory run "sudo ./start.sh"

### Installation steps:
1. git clone https://github.com/peanutrumble/PFSW
2. cd ssd-wipe
3. chmod +x *.sh

### Dependencies:  (Most of everything is bundled in most linux distros)
1. whiptail
2. Git
3. hdparm
4. blkdiscard
5. nvme-cli (Usualy needs installed)

TODOs 
1. make this a binary for easy installation and usage
2. add a usb wiping feature




