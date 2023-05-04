#!/bin/bash

###

chrootpath="/jail/chroot1"
chrootuser="chrootuser"
chrootshell="/bin/bash"
binaries=(ls cat echo rm mkdir mount umount du tail passwd cat nano chmod chown cp mv crontab mail rsync tar)

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

# Check if binaries are installed
for binary in $binaries; do
    if ! which $binary >/dev/null; then
        echo ""
        echo -e "${RED}    ERROR: $binary is not installed. Fix the issue and re-run the script.${NC}"
        echo ""
        exit 1
    fi
done

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
chown root:root $chrootpath
chmod 0755 $chrootpath
echo "Setting permissions and ownership for $chrootpath..."

# if $chrootuser does not exist, create it
if ! id -u $chrootuser >/dev/null 2>&1; then
    useradd -M -N -s $chrootshell $chrootuser
    echo "Creating user $chrootuser..."
else
    echo -e "${YEL}User $chrootuser already exists! \n Do you want to go on? (y/n)${NC}"
    read -r answer
    if [ "$answer" = "${answer#[Yy]}" ]; then
        echo "Exiting..."
        exit 0
    fi
    echo "Continuing..."
fi

# copy /etc/{passwd,group} to $chrootpath/etc
cp -vf /etc/{passwd,group} $chrootpath/etc/ > /dev/null
echo "Copying /etc/passwd and /etc/group to $chrootpath/etc..."
cp -v /bin/bash $chrootpath/bin/ > /dev/null
echo "Copying /bin/bash to $chrootpath/bin..."

# if $chrootpath/home/$chrootuser does not exist, create it
[ -d $chrootpath/home/$chrootuser ] || mkdir -p $chrootpath/home/$chrootuser
chown -R $chrootuser:$chrootuser $chrootpath/home/$chrootuser
chmod -R 0700 $chrootpath/home/$chrootuser

# add main commands along with their libs to $chrootpath/bin
echo "Copying binaries to $chrootpath/bin..."
echo ""
for binary in $binaries; do
    cp -v /bin/"$binary" $chrootpath/bin/  > /dev/null
    echo "Copying /bin/$binary to $chrootpath/bin..."
    ldd /bin/"$binary" | grep "=> /" | awk '{print $3}' | xargs -I '{}' cp -v '{}' $chrootpath/lib64/ > /dev/null
done

# Set $chrootuser's $PATH variable to include $chrootpath/bin # FIX !!!
echo "Setting $chrootuser's PATH variable to include $chrootpath/bin..."

echo ""
echo -e "${BLU}  Done! ${NC}"
echo ""
echo "To configure the user to be able to access via SSH do the following:"
echo ""
echo "1. Add the following lines to /etc/ssh/sshd_config:"
echo "   Match User $chrootuser"
echo "   ChrootDirectory $chrootpath"
echo ""
echo "2. Restart sshd:"
echo ""
exit 0
