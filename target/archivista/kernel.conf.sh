# --- T2-COPYRIGHT-NOTE-BEGIN ---
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# 
# T2 SDE: target/archivista/kernel.conf.sh
# Copyright (C) 2004 - 2006 The T2 SDE Project
# 
# More information can be found in the files COPYING and README.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License. A copy of the
# GNU General Public License can be found in the file COPYING.
# --- T2-COPYRIGHT-NOTE-END ---

echo "disabling oss sound modules ..."

sed -i -e "s/CONFIG_SOUND_OSS=./# CONFIG_SOUND_OSS is not set/" \
       -e "s/CONFIG_SOUND_PRIME=./# CONFIG_SOUND_PRIME is not set/" $1

echo "disableing eth1394 ethernet to not interfere eth0 ..."
sed -i -e "s/CONFIG_IEEE1394_ETH1394./# CONFIG_IEEE1394_ETH1394 is not set/" $1

# preemption is not stable with SANE/Avision user-land libusb USB access
sed -i "s/CONFIG_PREEMPT=y/# CONFIG_PREEMPT is not set/" $1
