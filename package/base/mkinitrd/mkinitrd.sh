#!/bin/bash
# --- T2-COPYRIGHT-NOTE-BEGIN ---
# T2 SDE: package/*/mkinitrd/mkinitrd.sh
# Copyright (C) 2005 - 2022 The T2 SDE Project
# Copyright (C) 2005 - 2021 René Rebe <rene@exactcode.de>
# 
# This Copyright note is generated by scripts/Create-CopyPatch,
# more information can be found in the files COPYING and README.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2.
# --- T2-COPYRIGHT-NOTE-END ---

set -e

map=`mktemp`
firmware=
microcode=
minimal=
network=1
archprefix=
outfile=
compressor="zstd -T0 -19"

declare -A vitalmods
vitalmods[qla1280.ko]=1 # Sgi Octane
vitalmods[qla2xxx.ko]=1 # Sun Blade
vitalmods[tg3.ko]=1 # Sun Fire
vitalmods[xhci-pci.ko]=1 # probably every modern machine

filter="-e ext4 -e isofs -e pata_legacy -e sym53c8xx -e s[rd]_mod"

declare -A added

if [ $UID != 0 ]; then
	echo "Non root - exiting ..."
	exit 1
fi

while [ "$1" ]; do
  case $1 in
	[0-9]*) kernelver="$1" ;;
	-R) root="$2" ; shift ;;
	-a) archprefix="$2" ; shift ;;
	--firmware) firmware=1 ;;
	--minimal) minimal=1 ;;
	--network) network=0 ;;
	--microcode) microcode=1 ;;
	-e) filter="$filter $2" ; shift ;;
	-o) outfile="$2" ; shift ;;
	*) echo "Usage: mkinitrd [ --firmware ] [ --minimal ] [ --network ] [ -R root ] [ -e filter ] [ -o filename ] [ kernelver ]"
	   exit 1 ;;
  esac
  shift
done

if [ ! "$outfile" ]; then
    [ "$minimal" = 1 ] &&
	outfile="$root/boot/minird-$kernelver" ||
	outfile="$root/boot/initrd-$kernelver"
fi

[ "$minimal" != 1 ] && filter="$filter -e reiserfs -e btrfs -e /jfs -e /xfs -e jffs2
-e /udf -e /unionfs -e ntfs -e /fat -e /hfs -e floppy -e efivarfs
-e /ata/ -e /scsi/ -e /fusion/ -e /sdhci/ -e nvme/host -e /mmc/ -e ps3fb -e ps3disk
-e dm-mod -e dm-raid -e md/raid -e dm/mirror -e dm/linear -e dm-crypt -e dm-cache
-e /aes -e /sha -e /blake -e /cbc -e /ecb -e xts
-e cciss -e ips -e virtio -e nls_cp437 -e nls_iso8859-1 -e nls_utf8
-e /.hci -e usb-common -e usb-storage -e sbp2 -e uas
-e usbhid -e i2c-hid -e hid-generic -e hid-multitouch
-e hid-apple -e hid-microsoft -e hyperv-keyboard"

[ "$network" = 1 ] && filter="$filter -e /ipv4/ -e '/ipv6\.' -e ethernet -e nfsv4"

[ "$kernelver" ] || kernelver=`uname -r`
[ "$moddir" ] || moddir="$root/lib/modules/$kernelver"

modinfo="${archprefix}modinfo -b $moddir -k $kernelver"
depmod=${archprefix}depmod

echo "Kernel: $kernelver, module dir: $moddir"

if [ ! -d $moddir ]; then
	echo "Warning: $moddir does not exist!"
	moddir=""
fi

sysmap=""
[ -f "$root/boot/System.map-$kernelver" ] && sysmap="$root/boot/System.map-$kernelver"

if [ -z "$sysmap" ]; then
	echo "System.map-$kernelver not found!"
	exit 2
fi

echo "System.map: $sysmap"

# check needed tools
for x in cpio gzip; do
	if ! type -p $x >/dev/null; then
		echo "$x not found!"
		exit 2
	fi
done

tmpdir="$map.d"
cd ${tmpdir%/*}
mkdir ${tmpdir##*/}
cd $tmpdir

# create basic structure
#
echo "Create dirtree ..."

mkdir -p {dev,bin,sbin,proc,sys,lib/modules,lib/udev,etc/hotplug.d/default}
mknod dev/null c 1 3
mknod dev/zero c 1 5
mknod dev/tty c 5 0
mknod dev/console c 5 1

# copy the basic / rootfs kernel modules
#

if [ "$moddir" ]; then
 echo "Copying kernel modules ..."
 (
  add_depend() {
     local skipped=
     local x="$1"

     # expand to full name if it was a depend
     [ $x = ${x##*/} ] && x=`sed -n "/\/$x\.ko.*/{p; q}" $map`

     if [ "${added["$x"]}" != 1 ]; then
	added["$x"]=1

	local module=${x##*/}
	echo -n "$module "

	# strip $root prefix
	xt=${x##$root}

	# does it need firmware?
	fw="`$modinfo -F firmware $x`"
	if [ "$fw" ]; then
	     echo -e -n "\nWarning: $module needs firmware"
	     if [ "$firmware" -o "${vitalmods[$module]}" ]; then
		for fn in $fw; do
		    local fn="/lib/firmware/$fn"
		    local dir="./${fn%/*}"
		    if [ ! -e "$root$fn" ]; then
			if [ "${vitalmods[$module]}" ]; then
			    echo ", not found, vital, including anyway"
			else
			    echo ", not found, skipped"
			    skipped=1
			fi
		    else
			mkdir -p "$dir"
			echo -n ", $fn"
			cp -af "$root$fn" "$dir/"
			# TODO: copy source if symlink
			[ -f "$tmpdir$fn" ] && $compressor --rm -f --quiet "$tmpdir$fn"
		    fi
		done
		echo
	     else
		echo ", skipped"
		skipped=1
	     fi
	fi

	if [ -z "$skipped" ]; then
	    mkdir -p `dirname ./$xt` # TODO: use builtin?
	    cp -af $x $tmpdir$xt
	    $compressor --rm -f --quiet $tmpdir$xt

	    # add it's deps, too
	    for fn in `$modinfo -F depends $x | sed 's/,/ /g'`; do
		add_depend "$fn"
	    done
	fi
     else
        #echo "already there"
	:
     fi
  }

  find $moddir/kernel -type f > $map
  grep -v -e /wireless/ -e netfilter $map | grep $filter |
  while read fn; do
	add_depend "$fn"
  done
 ) | fold -s; echo

 # generate map files
 #
 mkdir -p lib/modules/$kernelver
 cp -avf $moddir/modules.{order*,builtin*} lib/modules/$kernelver/
 $depmod -ae -b $tmpdir -F $sysmap $kernelver
 # only keep the .bin-ary files
 rm $tmpdir/lib/modules/$kernelver/modules.{alias,dep,symbols,builtin,order}
fi

echo "Injecting programs and configuration ..."

# copying config
#
cp -ar $root/etc/{group,udev} $tmpdir/etc/

[ -e $root/lib/udev/rules.d ] && cp -ar $root/lib/udev/rules.d $tmpdir/lib/udev/
[ -e $root/etc/mdadm.conf ] && cp -ar $root/etc/mdadm.conf $tmpdir/etc/
cp -ar $root/etc/modprobe.* $root/etc/ld-* $tmpdir/etc/ 2>/dev/null || true

# in theory all, but fat and not all always needed ...
cp -a $root/lib/udev/{ata,scsi,cdrom}_id $tmpdir/lib/udev/

elf_magic () {
	readelf -h "$1" | grep 'Machine\|Class'
}

# copy dynamic libraries, and optional plugins, if any.
#
if [ "$minimal" = 1 ]; then
	extralibs="`ls $root/lib*/{libdl,libncurses.so}* 2>/dev/null || true`"
else
	# glibc only
	extralibs="`ls $root/{lib*/libnss_files,usr/lib*/libgcc_s}.so* 2>/dev/null || true`"
fi

copy_dyn_libs () {
	local magic
	# we can not use ldd(1) as it loads the object, which does not work on cross builds
	for lib in $extralibs `readelf -de $1 |
		sed -n -e 's/.*Shared library.*\[\([^]\]*\)\]/\1/p' \
		       -e 's/.*Requesting program interpreter: \([^]]*\)\]/\1/p'`
	do
		# remove $root prefix from extra libs
		[ "$lib" != "${lib#$root/}" ] && lib="${lib##*/}"

		if [ -z "$magic" ]; then
			magic="$(elf_magic $1)"
			[[ $1 = *bin/* ]] && echo "Warning: $1 is dynamically linked!"
		fi
		for libdir in $root/lib*/ $root/usr/lib*/ "$root"; do
			if [ -e $libdir$lib ]; then
			    [ ! -L $libdir$lib -a "$magic" != "$(elf_magic $libdir$lib)" ] && continue
			    xlibdir=${libdir#$root}
			    echo "	${1#$root} NEEDS $xlibdir$lib"

			    if [ "${added["$xlibdir$lib"]}" != 1 ]; then
				added["$xlibdir$lib"]=1

				mkdir -p ./$xlibdir
				while local x=`readlink $libdir$lib`; [ "$x" ]; do
					echo "	$xlibdir$lib SYMLINKS to $x"
					local y=$tmpdir$xlibdir$lib
					mkdir -p ${y%/*}
					ln -sfv $x $tmpdir$xlibdir$lib
					if [ "${x#/}" == "$x" ]; then # relative?
						# directory to prepend?
						[ ${lib%/*} != "$lib" ] && x="${lib%/*}/$x"
					fi
					lib="$x"
				done
				local y=$tmpdir$xlibdir$lib
				mkdir -p ${y%/*}
				cp -af $libdir$lib $tmpdir$xlibdir$lib

				copy_dyn_libs $libdir$lib
			    fi
			fi
		done
	done
}

# setup programs
#
for x in $root/sbin/{udevd,udevadm} $root/usr/sbin/disktype
do
	cp -av $x $tmpdir/sbin/
	copy_dyn_libs $x
done

# setup optional programs
#
[ "$minimal" != 1 ] &&
for x in $root/sbin/{kmod,modprobe,insmod,blkid,vgchange,lvchange,lvm,mdadm} \
	 $root/usr/sbin/{cryptsetup,ipconfig} $root/usr/embutils/{dmesg,swapon}
do
  if [ ! -e $x ]; then
	echo "Warning: Skipped optional file ${x#$root}!"
  else
	cp -a $x $tmpdir/sbin/
	copy_dyn_libs $x
  fi
done

# copy a small shell
for sh in $root/bin/{pdksh,bash}; do
    if [ -e "$sh" ]; then
	cp $sh $tmpdir/bin/${sh##*/}
	ln -sf ${sh##*/} $tmpdir/bin/sh
	break
    fi
done

# static, tiny embutils and friends
#
cp $root/usr/embutils/{mount,umount,rm,mv,mkdir,ln,ls,switch_root,chroot,sleep,losetup,chmod,cat,sed,mknod} \
   $tmpdir/bin/
ln -s mv $tmpdir/bin/cp

cp $root/sbin/initrdinit $tmpdir/init
chmod +x $tmpdir/init

# Custom ACPI DSDT table
if test -f "$root/boot/DSDT.aml"; then
	echo "Adding local DSDT file: $dsdt"
	cp $root/boot/DSDT.aml $tmpdir/DSDT.aml
fi

# create / truncate
echo -n > "$outfile"

if [ "$microcode" ]; then
    # include cpu microcode, if available, ...
    if [ -d $root/lib/firmware/amd-ucode ]; then
	mkdir -p $tmpdir/kernel/x86/microcode
	cat $root/lib/firmware/amd-ucode/microcode_amd*.bin > $tmpdir/kernel/x86/microcode/AuthenticAMD.bin
    fi

    if [ -d $root/lib/firmware/intel-ucode ]; then
	mkdir -p $tmpdir/kernel/x86/microcode
	cat $root/lib/firmware/intel-ucode/* > $tmpdir/kernel/x86/microcode/GenuineIntel.bin
    fi

    if [ -d $tmpdir/kernel/x86/microcode ]; then
    (
	cd $tmpdir
	find kernel | cpio -o -H newc >> "${outfile:-$root/boot/initrd-$kernelver}"
    )
    fi
    rm -rf $tmpdir/kernel
fi

# create the cpio image
#
echo "Archiving ..."
( cd $tmpdir
  # sorted by priority in case of out-of-memory
  find init proc sys dev *bin usr etc lib* \( -path lib/modules -o -path lib/firmware \) -prune -o -print
  find lib/[mf]*
) | (
  cd $tmpdir
  cpio -o -H newc | $compressor >> "$outfile"
)
rm -rf $tmpdir $map
