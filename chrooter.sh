#!/bin/bash

###

chrootpath="/jail/chroot1"
chrootuser="chrootuser"
binaries=(awk bash cat chmod chown cp crontab cut du echo find grep head ls mkdir mount mv nano nc passwd rm rsync sh sleep tail tar touch umount)

###

# Colors!
RED='\033[0;31m'
YEL='\033[1;33m'
BLU='\033[0;34m'
NC='\033[0m' # No Color

# Check if script is being run as root
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo -e "${RED}    ERROR: Please run as root.${NC}"
    echo ""
    exit 1
fi

# Check if the declared binaries are installed
for binary in "${binaries[@]}"; do
    if ! which "$binary" >/dev/null; then
        echo ""
        echo -e "${RED}    ERROR: $binary is not installed. Fix the issue and re-run the script.${NC}"
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

# Create $chrootuser
useradd $chrootuser -c "Chrooted user"
#usermod -a -G $chrootuser $chrootuser
echo "Creating user $chrootuser..."

# If $chrootpath does not exist, create it
if ! [ -d $chrootpath ]; then
    mkdir -p $chrootpath
    echo "Creating $chrootpath..."
fi

# Create /dev/null, /dev/zero, /dev/random, /dev/urandom and /dev/tty
mkdir -p $chrootpath/{dev,etc,lib64,bin,home}
mknod -m 666 $chrootpath/dev/null c 1 3
echo "Creating /dev/null..."
mknod -m 666 $chrootpath/dev/zero c 1 5
echo "Creating /dev/zero..."
mknod -m 666 $chrootpath/dev/random c 1 8
echo "Creating /dev/random..."
mknod -m 666 $chrootpath/dev/urandom c 1 9
echo "Creating /dev/urandom..."
mknod -m 666 $chrootpath/dev/tty c 5 0
echo "Creating /dev/tty..."
echo ""

# Set permissions and ownership for $chrootpath
chown root:root $chrootpath
chmod 0755 $chrootpath
echo "Setting permissions and ownership for $chrootpath..."

# Copy /etc/{passwd,group} to $chrootpath/etc
cp -f /etc/{passwd,group} $chrootpath/etc/
echo "Copying /etc/passwd and /etc/group to $chrootpath/etc..."

# If $chrootpath/home/$chrootuser does not exist, create it
[ -d $chrootpath/home/$chrootuser ] || mkdir -p $chrootpath/home/$chrootuser
chown -R $chrootuser:$chrootuser $chrootpath/home/$chrootuser
chmod -R 0700 $chrootpath/home/$chrootuser

# Add main commands along with their libs to $chrootpath/bin
echo ""
echo "Copying binaries (alongside required libs) to $chrootpath/bin..."
for binary in "${binaries[@]}"; do
    cp /bin/"$binary" $chrootpath/bin/
    echo "Copying /bin/$binary to $chrootpath/bin..."
    ldd /bin/"$binary" | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp '{}' $chrootpath/lib64/ >/dev/null
done

# Set $chrootuser's $PATH variable to include $chrootpath/bin
echo ""
echo "Setting $chrootuser's PATH variable to include $chrootpath/bin..."
echo "export PATH=/bin/" > $chrootpath/home/$chrootuser/.bash_profile

# Ask the user if they want to set $chrootuser's password
echo ""
echo -e "${YEL}Do you want to set a new password for user $chrootuser? (y/n)${NC}"
read -r answer
if ! [ "$answer" = "${answer#[Yy]}" ]; then
    passwd $chrootuser
fi

# Configure SSH to jail $chrootuser
if [ -f "/etc/ssh/sshd_config" ]; then
    echo "Match User $chrootuser" >>/etc/ssh/sshd_config
    echo "    ChrootDirectory $chrootpath" >>/etc/ssh/sshd_config
    sshconfigured=true
else
    echo "${YEL}The SSH config file couldn't be found${NC}"
    sshconfigured=false
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
    echo "  ssh $chrootuser@$(hostname -I)"
    echo ""
fi
exit 0
