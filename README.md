# chRooter

`chrooter.sh` is a simple script that offers a workaround to what the `chroot` command does. It easily sets up a jailed user and custom environment on a Linux system, allowing you to specify the path to the jailed environment, the username for the chrooted user, the users to include in the passwd and shadow files, and the binaries to include in the jail.

The jailed user does not interact with the system through a virtualization layer, avoiding the performance overhead typically associated with virtual machines. The user communicates directly with the kernel using the same system calls as any other user, but their capabilities are restricted by the binaries included in the environment.

It is crucial to understand that importing certain binaries into the chroot may pose a security risk.

## Installation

To use chRooter, simply download the script to your Linux system:  
`$ wget https://raw.githubusercontent.com/Pendrag00n/chRooter/main/chrooter.sh`

Make the script executable:  
`$ sudo chmod +x chrooter.sh`

Modify the variables to fit your needs and then, run it:  
`$ sudo ./chrooter.sh`

## Usage

To run `chrooter.sh`, simply modify the following variables and then run the script:

- `$chrootpath`: The path to the new chroot environment.
- `$chrootuser`: The username for the chrooted user.
- `$binaries`: A list of binaries to include in the chroot environment.
- `$corebinaries`: These are core binaries that give the envivorement it's basic functionalities.
- `$users`: The rest of users that need to be included into /etc/passwd and /etc/shadow
- `$ulimit`: To limit the number of processes the jailed user can run

## Removing a chrooted user

Simply run `$ sudo deluser <username>` and remove the `$chrootpath`

##

Before using this script for anything serious, I recommend giving [Escaping From Jails](https://book.hacktricks.xyz/linux-hardening/privilege-escalation/escaping-from-limited-bash) a quick read and watching [Balázs Bucsay's Conference](https://youtu.be/D1eipd9HbIY) on the matter.
### Bear in mind that a jailed user can still fill up all the partition space if you haven't set up disk quotas
