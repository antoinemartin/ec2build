#!/bin/bash
# 2010 Copyright Yejun Yang (yejunx AT gmail DOT com)
# --> Modified by Elek Marton under the same licence
# --> Modified by Antoine Martin under the same licence
# Creative Commons Attribution-Noncommercial-Share Alike 3.0 United States License.
# http://creativecommons.org/licenses/by-nc-sa/3.0/us/

if [[ `uname -m` == i686 ]]; then
  ARCH=i686
  EC2_ARCH=i386
else
  ARCH=x86_64
  EC2_ARCH=x86_64
fi

BASEDIR=$(dirname $(readlink -f $0))
EBSDEVICE=$1
NEWROOT=/mnt/newroot
ROOT=${NEWROOT}


[ -b $EBSDEVICE ] || { echo;echo "$EBSDEVICE is not a block device";exit 1; }
[ `whoami` == "root" ] || { echo;echo "You must be root to run this script";exit 1; }


# Creating disk
echo;echo "========= > Creating partitions on $EBSDEVICE"
if [ ! -b ${EBSDEVICE}2 ]; then
    fdisk ${EBSDEVICE} <<EOF
n
p


+13G
n
p



t
2
82
w
EOF
fi
sleep 4
umount ${NEWROOT}

# creating swap
echo;echo "========= > Creating swap on ${EBSDEVICE}2"
mkswap ${EBSDEVICE}2 || exit 1

# Creating partition
echo;echo "========= > Creating ext3 partition on ${EBSDEVICE}1"
mkfs.ext3 ${EBSDEVICE}1 || exit 1

# Mounting base partition
echo;echo "========= > Creating mounting ${EBSDEVICE}2 on ${NEWROOT}"
mkdir -p ${NEWROOT}
mount ${EBSDEVICE}1 ${NEWROOT} || exit 1
chmod 755 ${NEWROOT}
mkdir ${NEWROOT}/boot

# Retrieving base packages
PACKS=$(grep -v "^#" "${BASEDIR}/packages")

# building repository 
echo;echo "========= > Rebuilding local repo packages list"
(cd ${BASEDIR}/repo;rm -f ec2.db.tar.gz;repo-add ec2.db.tar.gz *.pkg.*)

# Creating pacman.conf
cat <<EOF > pacman.conf
[options]
HoldPkg     = pacman glibc
SyncFirst   = pacman
Architecture = $ARCH
[ec2]
Server = file://${BASEDIR}/repo
[core]
Include = /etc/pacman.d/mirrorlist
[extra]
Include = /etc/pacman.d/mirrorlist
[community]
Include = /etc/pacman.d/mirrorlist
EOF

# Creating base system
echo;echo "========= > Installing base system"
LC_ALL=C mkarchroot -f -C pacman.conf $ROOT $PACKS

# Copying local pacman mirrorlist
echo;echo "========= > Changing configuration"
mv $ROOT/etc/pacman.d/mirrorlist $ROOT/etc/pacman.d/mirrorlist.pacorig
cp /etc/pacman.d/mirrorlist $ROOT/etc/pacman.d/mirrorlist

# Creating most basing rc.conf
mv $ROOT/etc/rc.conf $ROOT/etc/rc.conf.pacorig
cat <<EOF >$ROOT/etc/rc.conf
LOCALE="en_US.UTF-8"
TIMEZONE="UTC"
MOD_AUTOLOAD="no"
USECOLOR="yes"
USELVM="no"
DAEMONS=(hwclock syslog-ng sshd crond ec2)
EOF

# Creating inittab
mv $ROOT/etc/inittab $ROOT/etc/inittab.pacorig
cat <<EOF >$ROOT/etc/inittab
id:3:initdefault:
rc::sysinit:/etc/rc.sysinit
rs:S1:wait:/etc/rc.single
rm:2345:wait:/etc/rc.multi
rh:06:wait:/etc/rc.shutdown
su:S:wait:/sbin/sulogin -p
ca::ctrlaltdel:/sbin/shutdown -t3 -r now
0:12345:respawn:/sbin/agetty 38400 hvc0 linux
EOF

# Nothing to deny, as everything is managed by virtual AWS firewall
mv $ROOT/etc/hosts.deny $ROOT/etc/hosts.deny.pacorig
cat <<EOF >$ROOT/etc/hosts.deny
#
# /etc/hosts.deny
#
# End of file
EOF

# The grub for the PV-GRUB instance to boot
echo;echo "========= > Creating grub file"
mkdir -p $ROOT/boot/boot/grub
cat <<EOF >$ROOT/boot/boot/grub/menu.lst
default 0
timeout 1

title  Arch Linux
	root   (hd0,0)
	kernel /boot/vmlinuz-linux-ec2 root=/dev/xvda1 ip=dhcp console=hvc0 spinlock=tickless ro
	initrd /boot/initramfs-linux-ec2.img
EOF

cd $ROOT/boot
ln -s boot/grub .
cd ../..

# Modification of ssh daemon to only allow public key authentication
echo;echo "========= > Changing ssh configuration"
cp $ROOT/etc/ssh/sshd_config $ROOT/etc/ssh/sshd_config.pacorig
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/'  $ROOT/etc/ssh/sshd_config
sed -i 's/#UseDNS yes/UseDNS no/' $ROOT/etc/ssh/sshd_config

# Basic root account creation
cp $ROOT/etc/skel/.bash* $ROOT/root
cp $ROOT/etc/skel/.screenrc $ROOT/root
mv $ROOT/etc/fstab $ROOT/etc/fstab.pacorig

# fstab creation
echo;echo "========= > Creating fstab"
cat <<EOF >$ROOT/etc/fstab
$(blkid -c /dev/null -s UUID -o export ${EBSDEVICE}1) / auto    defaults,relatime 0 0
$(blkid -c /dev/null -s UUID -o export ${EBSDEVICE}2) swap  swap   defaults 0 0
none      /proc proc    nodev,noexec,nosuid 0 0
none /dev/pts devpts defaults 0 0
none /dev/shm tmpfs nodev,nosuid 0 0
EOF

# Copy of the local makepkg.conf
echo;echo "========= > Additional configuration"
mv $ROOT/etc/makepkg.conf $ROOT/etc/makepkg.conf.pacorig
cp /etc/makepkg.conf $ROOT/etc/

# Basic sources
mkdir $ROOT/home/{sources,packages,srcpackages}
chmod 1777 $ROOT/home/{sources,packages,srcpackages}

# Allow sudo for all users of the wheel groop
echo;echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> $ROOT/etc/sudoers

# Add the amazon DNS
mv $ROOT/etc/resolv.conf $ROOT/etc/resolv.conf.pacorig
echo;echo "nameserver 172.16.0.23" > $ROOT/etc/resolv.conf

# This file triggers ssh public key installation at first boot
touch $ROOT/root/firstboot

# copy the local packages repository
echo;echo "========= > Copying local repository"
cp -a ${BASEDIR}/repo $ROOT/root/

# replacing /etc/pacman.conf with one that works
echo;echo "========= > Creating pacman.conf"
cat <<EOF > $ROOT/etc/pacman.conf
[options]
HoldPkg     = pacman glibc
SyncFirst   = pacman
Architecture = $ARCH
[ec2]
Server = file:///root/repo
[core]
Include = /etc/pacman.d/mirrorlist
[extra]
Include = /etc/pacman.d/mirrorlist
[community]
Include = /etc/pacman.d/mirrorlist
EOF


# done
echo;echo "========= > Unmounting base system"
cd 
sleep 2
umount ${NEWROOT}

