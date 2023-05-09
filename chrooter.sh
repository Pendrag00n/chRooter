#!/bin/bash

### Modify the following variables to suit your needs ###

chrootpath="/jail/chroot1"                                                                                               # Path to the chrooted environment
chrootuser="chrootuser"                                                                                                  # Username for the chrooted environment
corebinaries=(bash cat cp echo ls mkdir mv rm rmdir touch)                                                               # Basic binaries for the shell to work
binaries=(awk chmod chown clear crontab cut du find grep head mount nano nc passwd rsync sh sleep tail tar touch umount) # Other binaries that might be useful

###

# Colors!
RED='\033[1;91m'
YEL='\033[1;93m'
BLU='\033[1;94m'
NC='\033[0m' # No Color

# Check if script is being run as root
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo -e "${RED}    ERROR: Please run this script as root.${NC}"
    echo ""
    exit 1
fi

# Check if the declared binaries are installed
for binary in "${binaries[@]}"; do
    if ! which "$binary" >/dev/null; then
        echo ""
        echo -e "${RED}    ERROR: $binary is not installed or is mistyped. Fix the issue and re-run the script.${NC}"
        echo ""
        exit 1
    fi
done
for binary in "${corebinaries[@]}"; do
    if ! which "$binary" >/dev/null; then
        echo ""
        echo -e "${RED}    ERROR: $binary is not installed or is mistyped. Fix the issue and re-run the script.${NC}"
        echo ""
        exit 1
    fi
done

# Check if $chrootuser exists, exit if it does
if id -u $chrootuser >/dev/null 2>&1; then
    echo ""
    echo -e "${RED}    ERROR: User $chrootuser already exists. Fix the issue and re-run the script.${NC}"
    echo ""
    exit 1
fi

# Check if $chrootpath is a valid path
if ! [[ $chrootpath =~ ^/ ]]; then
    echo ""
    echo -e "${RED}    ERROR: $chrootpath is not a valid absolute path. Fix the issue and re-run the script.${NC}"
    echo ""
    exit 1
fi

# If $chrootpath ends with a /, remove it.
if [ ${chrootpath: -1} = "/" ]; then
    chrootpath=${chrootpath::-1}
fi

# If $chrootpath does not exist, create it
if [ -d $chrootpath ]; then
    echo ""
    echo -e "${RED}    ERROR: The directory $chrootpath already exists, please delete it or use another one to prevent stuff from breaking.${NC}"
    echo ""
    exit 1
else
    mkdir -p $chrootpath
    echo "Creating $chrootpath..."
fi

# Create $chrootuser
useradd $chrootuser -c "Chrooted user" -s /bin/bash
echo "Creating user $chrootuser..."

# Create /dev/null, /dev/zero, /dev/random, /dev/urandom and /dev/tty
mkdir -p "$chrootpath"/{dev,etc,lib64,lib,bin,home}
mknod -m 666 "$chrootpath"/dev/null c 1 3
echo "Creating /dev/null..."
mknod -m 666 "$chrootpath"/dev/zero c 1 5
echo "Creating /dev/zero..."
mknod -m 666 "$chrootpath"/dev/random c 1 8
echo "Creating /dev/random..."
mknod -m 666 "$chrootpath"/dev/urandom c 1 9
echo "Creating /dev/urandom..."
mknod -m 666 "$chrootpath"/dev/tty c 5 0
echo "Creating /dev/tty..."
echo ""

# Set permissions and ownership for $chrootpath
chown root:root "$chrootpath"
chmod 0755 "$chrootpath"
echo "Setting permissions and ownership for $chrootpath..."

# Copy /etc/{passwd,group,bashrc} to $chrootpath/etc
cp -f /etc/{passwd,group} "$chrootpath"/etc/
echo "Copying /etc/passwd and /etc/group to $chrootpath/etc..."

# If $chrootpath/home/$chrootuser does not exist, create it
[ -d "$chrootpath"/home/$chrootuser ] || mkdir -p "$chrootpath"/home/$chrootuser
chown -R $chrootuser:$chrootuser "$chrootpath"/home/$chrootuser
chmod -R 0700 "$chrootpath"/home/$chrootuser

# Add main commands along with their libs to $chrootpath/bin
echo ""
echo "Copying core binaries to $chrootpath/bin..."
mainlib=$(ldd /bin/bash | grep -v "=>" | grep "lib" | cut -d " " -f 1 | tr -d '[:blank:]')
libtype=$(echo "$mainlib" | cut -d "/" -f 2)
cp "$mainlib" "$chrootpath"/"$libtype"
for binary in "${corebinaries[@]}"; do
    cp /bin/"$binary" "$chrootpath"/bin/
    echo "Copying /bin/$binary to $chrootpath/bin..."
    ldd /bin/"$binary" | grep "=> /" | awk '{print $3}' | while read -r dep; do
        if [[ $dep == /lib* ]]; then
            cp "$dep" "$chrootpath/lib/"
        elif [[ $dep == /lib64* ]]; then
            cp "$dep" "$chrootpath/lib64/"
        fi
    done
done

echo ""
echo "Copying the rest of binaries to $chrootpath/bin..."
mainlib=$(ldd /bin/bash | grep -v "=>" | grep "lib" | cut -d " " -f 1 | tr -d '[:blank:]')
libtype=$(echo "$mainlib" | cut -d "/" -f 2)
cp "$mainlib" "$chrootpath"/"$libtype"
for binary in "${binaries[@]}"; do
    cp /bin/"$binary" "$chrootpath"/bin/
    echo "Copying /bin/$binary to $chrootpath/bin..."
    ldd /bin/"$binary" | grep "=> /" | awk '{print $3}' | while read -r dep; do
        if [[ $dep == /lib* ]]; then
            cp "$dep" "$chrootpath/lib/"
        elif [[ $dep == /lib64* ]]; then
            cp "$dep" "$chrootpath/lib64/"
        fi
    done
done

# Set $chrootuser's BASH envivorement
echo ""
echo "Setting $chrootuser's BASH envivorement..."
echo 'PATH="/bin/"' >"$chrootpath"/home/$chrootuser/.bashrc
echo 'PS1="\[\033[01;32m\]\u@\h \[\033[01;34m\]\w\[\033[00m\]$ "' >>"$chrootpath"/home/$chrootuser/.bashrc
echo "alias ls='ls --color{,=auto,=always}'" >>"$chrootpath"/home/$chrootuser/.bashrc
echo "alias ls -la='ls -la --color{,=auto,=always}'" >>"$chrootpath"/home/$chrootuser/.bashrc
echo "alias ll='ls -la --color{,=auto,=always}'" >>"$chrootpath"/home/$chrootuser/.bashrc
echo " " >>"$chrootpath"/home/$chrootuser/.bashrc
chown $chrootuser:$chrootuser "$chrootpath"/home/$chrootuser/.bashrc
chmod 644 "$chrootpath"/home/$chrootuser/.bashrc

echo 'source ~/.bashrc' >"$chrootpath"/home/$chrootuser/.bash_profile
chown $chrootuser:$chrootuser "$chrootpath"/home/$chrootuser/.bash_profile
chmod 644 "$chrootpath"/home/$chrootuser/.bash_profile

# Ask the user if they want to set $chrootuser's password
echo ""
echo -e "${YEL}Do you want to set a new password for user $chrootuser? (y/n)${NC}"
read -r answer
if ! [ "$answer" = "${answer#[Yy]}" ]; then
    passwd $chrootuser
fi

# Configure SSH to jail $chrootuser
if [ -f "/etc/ssh/sshd_config" ]; then
    sshport=$(grep </etc/ssh/sshd_config "^Port" | cut -d " " -f 2)
    echo "Match User $chrootuser" >>/etc/ssh/sshd_config
    echo "    ChrootDirectory $chrootpath" >>/etc/ssh/sshd_config
    echo ""
    sshconfigured=true
else
    echo -e "${YEL} WARN: The SSH config file couldn't be found! Skipping automatic SSH exception configuration${NC}"
    sshconfigured=false
fi
if [ -z "$sshport" ]; then
    sshport=22
fi

# Determine between ssh or sshd
if systemctl is-active --quiet sshd.service; then
    sshservice_name="sshd.service"
elif systemctl is-active --quiet ssh.service; then
    sshservice_name="ssh.service"
else
    sshservice_name="unknown"
fi

# Ask the user if they want to restart the SSH daemon
if [ "$sshconfigured" = true ] && ! [ "$sshservice_name" = "unknown" ]; then
    echo ""
    echo -e "${YEL}Do you want to restart the SSH daemon? (y/n)${NC}"
    read -r answer
    if ! [ "$answer" = "${answer#[Yy]}" ]; then
        systemctl restart $sshservice_name
    fi
fi

# Done!
echo ""
echo -e "${BLU}  Done! ${NC}"
if [ "$sshconfigured" = false ]; then
    echo ""
    echo "To configure the user to be able to access via SSH do the following:"
    echo ""
    echo "1. Add the following lines to /etc/ssh/sshd_config:"
    echo "   Match User $chrootuser"
    echo "   ChrootDirectory $chrootpath"
    echo ""
    echo "2. Restart sshd:"
    echo "   systemctl restart ssh.service"
    echo ""
else
    echo ""
    echo "The user $chrootuser can now be accessed via SSH by running:"
    echo ""
    echo -e "      $ ${BLU}ssh $chrootuser@$(hostname -I)-p $sshport ${NC}"
    echo ""
fi
exit 0
