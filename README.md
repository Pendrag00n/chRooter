# chRooter

`chRooter` is a simple script that sets up a chrooted user on a Linux system. It allows you to easily specify the path to the chroot environment, the username for the chrooted user, and the binaries to include in the chroot.

## Installation

To use chRooter, simply download the script to your Linux system:  
`$ wget https://raw.githubusercontent.com/Pendrag00n/chRooter/main/chrooter.sh`

Make the script executable:  
`$ chmod +x chRooter.sh`

## Usage

To run `chRooter`, simply modify the following variables and then run the script:

- `$chrootpath`: The path to the new chroot environment.
- `$chrootuser`: The username for the chrooted user.
- `$binaries`: A list of binaries to include in the chroot environment.
- `$corebinaries`: These are basic binaries for the command line to work properly.
