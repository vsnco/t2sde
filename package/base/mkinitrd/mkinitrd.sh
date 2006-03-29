#!/bin/sh
# --- T2-COPYRIGHT-NOTE-BEGIN ---
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# 
# T2 SDE: package/.../mkinitrd/mkinitrd.sh
# Copyright (C) 2005 The T2 SDE Project
# 
# More information can be found in the files COPYING and README.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License. A copy of the
# GNU General Public License can be found in the file COPYING.
# --- T2-COPYRIGHT-NOTE-END ---


set -e

if [ $UID != 0 ]; then
	echo "Non root - exiting ..."
	exit 1
fi

while [ "$1" ]; do
  case $1 in
	[0-9]*) kernelver="$1" ;;
	-R) root="$2" ; shift ;;
	*) echo "Usage: mkinitrd [ -R root ] [ kernelver ]"
	   exit 1 ;;
  esac
  shift
done

[ "$root" ] || root="/"
[ "$kernelver" ] || kernelver=`uname -r`
[ "$moddir" ] || moddir="${root}/lib/modules/$kernelver"

echo "Kernel: $kernelver, module dir: $moddir"

if [ ! -d $moddir ]; then
	echo "Module dir $moddir does not exist!"
	exit 2
fi

sysmap=""
[ -f "${root}/boot/System.map_$kernelver" ] && sysmap="${root}/boot/System.map_$kernelver"

if [ -z "$sysmap" ]; then
	echo "System.map_$kernelver not found!"
	exit 2
fi

echo "System.map: $sysmap"

# check needed tools
for x in cpio gzip ; do
	if ! which -p $x >/dev/null ; then
		echo "$x not found!"
		exit 2
	fi
done

tmpdir=`mktemp`

# create basic structure
#
rm -rf $tmpdir >/dev/null

echo "Create dirtree ..."

mkdir -p $tmpdir/{dev,bin,sbin,proc,sys,lib/modules,etc/hotplug.d/default}
mknod $tmpdir/dev/console c 5 1

# copy the basic / rootfs kernel modules
#
echo "Copying kernel modules ..."

(
  find $moddir/kernel -type f | grep \
	-e reiserfs -e reiser4 -e ext2 -e ext3 -e isofs -e /jfs -e /xfs \
	-e /unionfs -e ntfs -e /dos -e dm-mod \
	-e /ide/ -e /scsi/ -e hci -e usb-storage -e sbp2 |
  while read fn ; do

	for x in $fn `modinfo $fn | grep depends |
	         cut -d : -f 2- | sed -e 's/ //g' -e 's/,/ /g' `
	do
		# expand to full name if it was a depend
		[ $x = ${x##*/} ] &&
		x=`find $moddir/kernel -name "$x.*o"`

		echo -n "${x##*/} "

		# strip $root prefix
		xt=${x##$root}

		mkdir -p `dirname $tmpdir/$xt`
		cp $x $tmpdir/$xt 2>/dev/null
	done
  done
) | fold -s ; echo

# generate map files
#
/sbin/depmod -ae -b $tmpdir -F $sysmap $kernelver

echo "Injecting programs and configuration ..."

# copying config
#
cp -ar ${root}/etc/udev $tmpdir/etc/

# setup programs
#
for x in ${root}/sbin/{hotplug++,udev,udevstart,modprobe,insmod} ${root}/usr/sbin/disktype
do
	# sanity check
	file $x | grep -q "dynamically linked" &&
		echo "Warning: $x is dynamically linked!"
	cp $x $tmpdir/sbin/
done

x=${root}/sbin/insmod.old
if [ ! -e $x ]; then
	echo "Warning: Skipped optional file $x!"
else
        file $x | grep -q "dynamically linked" &&
                echo "Warning: $x is dynamically linked!"
        cp $x $tmpdir/sbin/
	ln -s insmod.old $tmpdir/sbin/modprobe.old
fi

ln -s /sbin/udev $tmpdir/etc/hotplug.d/default/10-udev.hotplug
cp ${root}/bin/pdksh $tmpdir/bin/sh

# static, tiny embutils and friends
#
cp ${root}/usr/embutils/{mount,umount,rm,mv,mkdir,ln,ls,switch_root,sleep,losetup,chmod,cat,sed,mknod} \
   $tmpdir/bin/
ln -s mv $tmpdir/bin/cp

cp ${root}/sbin/initrdinit $tmpdir/init

# create the cpio image
#
echo "Archiving ..."
( cd $tmpdir
  find * | cpio -o -H newc | gzip -c9 > ${root}/boot/initrd-$kernelver.img
)

# display the resulting image
#
du -sh ${root}/boot/initrd-$kernelver.img
rm -rf $tmpdir


