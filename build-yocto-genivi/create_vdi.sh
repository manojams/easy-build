#!/bin/bash

# Convert kernel/rootfs images generated by build-yocto-qemux86
# into a .VDI image suitable to be executed from VirtualBox

# BIG FAT WARNING
# A few dangerous commands are executed as sudo and may destroy your host filesystem if buggy.
# USE AT YOUR OWN RISK - YOU HAVE BEEN WARNED!!!

# Prerequisites:
#    qemu-img
#    parted
#    kpartx
#    grub-install
#    sudo

TOPDIR=$PWD/tmp/build-gemini-5.0.2-qemux86

MACHINE=qemux86
FSTYPE=tar.bz2
KERNEL=$TOPDIR/tmp/deploy/images/$MACHINE/bzImage-$MACHINE.bin
ROOTFS=$TOPDIR/tmp/deploy/images/$MACHINE/gemini-image-$MACHINE.$FSTYPE

RAW_IMAGE=test.raw
VDI_IMAGE=test.vdi

MNT_ROOTFS=/tmp/rootfs

set -e
#set -x

# Create QEMU image
# See http://en.wikibooks.org/wiki/QEMU/Images

qemu-img create -f raw $RAW_IMAGE 256M

# Create partition table and partitions on RAW_IMAGE
parted $RAW_IMAGE mklabel msdos
parted $RAW_IMAGE print free
parted $RAW_IMAGE mkpart primary ext3 1 220
parted $RAW_IMAGE set 1 boot on
parted $RAW_IMAGE print free

#echo "DBG: Checking $RAW_IMAGE:"
#sfdisk -l $RAW_IMAGE
#fdisk -l $RAW_IMAGE

TMPFILE1=/tmp/kpartx-$$.tmp

# See http://stackoverflow.com/questions/1419489/loopback-mounting-individual-partitions-from-within-a-file-that-contains-a-parti
sudo kpartx -v -a $RAW_IMAGE >$TMPFILE1

echo "DBG: Contents of $TMPFILE1:"
cat $TMPFILE1

BLOCKDEV=`cut -d' ' -f8 $TMPFILE1`
ROOTPART=/dev/mapper/`cut -d' ' -f3 $TMPFILE1`
echo "DBG: BLOCKDEV=$BLOCKDEV"
echo "DBG: ROOTPART=$ROOTPART"

#echo "DBG: Checking $BLOCKDEV:"
#sudo fdisk -l $BLOCKDEV

sudo mkfs -t ext3 -L "GENIVI" $ROOTPART

mkdir -p $MNT_ROOTFS
#sudo mount -o loop $ROOTPART $MNT_ROOTFS
sudo mount $ROOTPART $MNT_ROOTFS

TMPFILE2=/tmp/losetup-$$.tmp

sudo losetup -av >$TMPFILE2

#echo "DBG: Contents of $TMPFILE2:"
#cat $TMPFILE2

# TODO: Copy kernel to $MNT_ROOTFS/boot
sudo install -m755 -d $MNT_ROOTFS/boot
sudo install -m644 -o 0 -v $KERNEL $MNT_ROOTFS/boot

# Extract rootfs
#sudo tar xvfj $ROOTFS -C $MNT_ROOTFS

#echo "TODO:"
# TODO: Create grub.cfg to MNT_ROOTFS/boot/grub
# grub-mkimage ???

# Create simple /boot/grub/grub.cfg on $ROOTPART
# See http://www.linuxfromscratch.org/lfs/view/development/chapter08/grub.html

TMPFILE3=/tmp/grubcfg-$$.tmp
cat > $TMPFILE3 <<END
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod ext2
set root=(hd0,1)

menuentry "Yocto-GENIVI, Linux" {
        linux   /boot/bzImage-qemux86.bin root=/dev/sda1
}

#menuentry "GNU/Linux, Linux 3.13.6-lfs-SVN-20140404" {
#        linux   /boot/vmlinuz-3.13.6-lfs-SVN-20140404 root=/dev/sda2 ro
#}
END

set -x

sudo install -m755 -d $MNT_ROOTFS/boot/grub
#sudo grub-mkdevicemap -m $MNT_ROOTFS/boot/grub/device.map
#grub-probe $RAW_IMAGE
#sudo install -m644 -o 0 -v $TMPFILE3 $MNT_ROOTFS/boot/grub/grub.cfg
#sudo grub-install --force --root-directory=$MNT_ROOTFS $BLOCKDEV || true
#sudo grub-install --force --boot-directory=$MNT_ROOTFS/boot $BLOCKDEV || true
#sudo grub-install --force --boot-directory=$MNT_ROOTFS/boot $RAW_IMAGE || true
sudo grub-install --force --boot-directory=$MNT_ROOTFS/boot $ROOTPART || true

echo "DBG: Contents of $MNT_ROOTFS:"
ls -la $MNT_ROOTFS

echo "DBG: Contents of $MNT_ROOTFS/boot:"
du -sh $MNT_ROOTFS/boot
#ls -la $MNT_ROOTFS/boot
ls -laR $MNT_ROOTFS/boot

if [ -e $MNT_ROOTFS/boot/grub/device.map ]; then
    echo "DBG: Contents of $MNT_ROOTFS/boot/grub/device.map:"
    cat $MNT_ROOTFS/boot/grub/device.map
fi

echo "DBG: Disk space on $MNT_ROOTFS:"
df -h $MNT_ROOTFS

sudo umount $MNT_ROOTFS

sudo kpartx -d $RAW_IMAGE

sudo losetup -av

rm $TMPFILE1
rm $TMPFILE2
rm $TMPFILE3

echo "DBG: Checking $RAW_IMAGE:"
parted $RAW_IMAGE print free

qemu-img convert -f raw -O vdi $RAW_IMAGE $VDI_IMAGE

# TODO: Test: Run QEMU against VDI_IMAGE
echo "TODO:" qemu-system-i386 -hda $RAW_IMAGE

# TODO: Test: Run VirtualBox against VDI_IMAGE

# TODO: Understand why the following error is shown when starting VM:
#
# error: no such device: d2033abb-85c3-47b2-81b3-59bdd07d7007
# grub rescue>

# See also: http://libguestfs.org/

exit 0;

# EOF
