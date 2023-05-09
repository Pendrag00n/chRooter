#!/bin/bash

### Modify the following variables to suit your needs ###

chrootpath="/jail/chroot1"                                                                                               # Path to the chrooted environment
chrootuser="chrootuser"                                                                                                  # Username for the chrooted environment
corebinaries=(bash cat cp echo ls mkdir mv rm rmdir touch)                                                               # Basic binaries for the shell to work
binaries=(awk chmod chown crontab cut du find grep head mount nano nc passwd rsync sh sleep tail tar touch umount) # Other binaries that might be useful

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

# Set $chrootuser's $PATH variable to include $chrootpath/bin
echo ""
echo "Setting $chrootuser's BASH envivorement..."
echo "export PATH=/bin/" >"$chrootpath"/home/$chrootuser/.bashrc
echo "export PS1=\[\033[01;32m\]\u@\h \[\033[01;34m\]\w\[\033[00m\]$ " >>"$chrootpath"/home/$chrootuser/.bashrc
echo "export LS_COLORS=rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;37;41:su=37;41:sg=30;43:ca=00:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.avif=01;35:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=01;36:*.au=01;36:*.flac=01;36:*.m4a=01;36:*.mid=01;36:*.midi=01;36:*.mka=01;36:*.mp3=01;36:*.mpc=01;36:*.ogg=01;36:*.ra=01;36:*.wav=01;36:*.oga=01;36:*.opus=01;36:*.spx=01;36:*.xspf=01;36:*~=00;90:*#=00;90:*.bak=00;90:*.old=00;90:*.orig=00;90:*.part=00;90:*.rej=00;90:*.swp=00;90:*.tmp=00;90:*.dpkg-dist=00;90:*.dpkg-old=00;90:*.ucf-dist=00;90:*.ucf-new=00;90:*.ucf-old=00;90:*.rpmnew=00;90:*.rpmorig=00;90:*.rpmsave=00;90:" >>"$chrootpath"/home/$chrootuser/.bashrc

# Ask the user if they want to set $chrootuser's password
echo ""
echo -e "
Do you want to set a new password for user $chrootuser? (y/n)${NC}"
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
    echo  -e "   ${BLU}ssh $chrootuser@$(hostname -I)-p $sshport ${NC}"
    echo ""
fi
exit 0
