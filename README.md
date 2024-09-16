# chRooter

`chRooter` is a simple script that manually sets up a chrooted user on a Linux system. It allows you to easily specify the path to the chroot environment, the username for the chrooted user, and the binaries to include in the chroot.

## Installation

To use chRooter, simply download the script to your Linux system:  
`$ wget https://raw.githubusercontent.com/Pendrag00n/chRooter/main/chrooter.sh`

Make the script executable:  
`$ sudo chmod +x chrooter.sh`

Modify the variables to fit your needs and then, run it:  
`$ sudo ./chrooter.sh`

## Usage

To run `chRooter`, simply modify the following variables and then run the script:

- `$chrootpath`: The path to the new chroot environment.
- `$chrootuser`: The username for the chrooted user.
- `$binaries`: A list of binaries to include in the chroot environment.
- `$corebinaries`: These are core binaries that give the envivorement it's basic functionalities.
- `$users`: The rest of users that need to be included into /etc/passwd and /etc/shadow
- `$ulimit`: To limit the number of processes the jailed user can run

Before using this script for anything serious, I recommend giving [Escaping From Jails](https://book.hacktricks.xyz/linux-hardening/privilege-escalation/escaping-from-limited-bash) a quick read and watching [Balázs Bucsay's Conference](https://youtu.be/D1eipd9HbIY) on the matter.
### Bear in mind that a jailed user can still fill up all the partition space if you haven't set up disk quotas
