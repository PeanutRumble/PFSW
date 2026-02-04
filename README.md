This is a bare(ish) bones TUI ssd wipe tool made for linux based around the blkdiscard tool

Usage: With the SATA SSDs installed navigate to the repo directory and run "sudo ./ssdwipe.sh" it should then go through a user freindly wiping interface

Installation & setup: 
1. git clone https://github.com/peanutrumble/ssd-wipe
2. cd ssd-wipe
3. chmod +x ssdwipe.sh

Dependencies:
whiptail
git
blkdiscard
