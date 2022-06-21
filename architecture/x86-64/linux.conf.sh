# --- T2-COPYRIGHT-NOTE-BEGIN ---
# T2 SDE: architecture/x86-64/linux.conf.sh
# Copyright (C) 2004 - 2022 The T2 SDE Project
# 
# This Copyright note is generated by scripts/Create-CopyPatch,
# more information can be found in the files COPYING and README.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2.
# --- T2-COPYRIGHT-NOTE-END ---

{
	cat <<- EOT
		define(`INTEL', `Intel X86 PCs')dnl

		CONFIG_64BIT=y
		
		dnl CPU configuration
		dnl
	EOT

	linux_arch=MK8 # default to orig. AMD
	for x in "generic	GENERIC_CPU"	\
		 "nocona	MPSC"		\
	         "core2		MCORE2"		\
		 "hehalem	MCORE2"		\
		 "westmere	MCORE2"		\
		 "sandybridge	MCORE2"		\
		 "ivybridge	MCORE2"		\
		 "haswell	MCORE2"		\
		 "broadwell	MCORE2"		\
		 "skylake	MCORE2"		\
		 "skylake-avx512	MCORE2"		\
		 "bonnel	ATOM"		\
		 "silvermont	ATOM"
	do
		set $x
		[[ "$SDECFG_X8664_OPT" = $1 ]] && linux_arch=$2
	done

	for x in GENERIC_CPU MK8 MPSC MCORE2 ATOM
	do
		if [ "$linux_arch" != "$x" ]
		then echo "# CONFIG_$x is not set"
		else echo "CONFIG_$x=y" ; fi
	done

	echo
	cat <<- EOT
		CONFIG_NR_CPUS=128

		CONFIG_HZ_1000=y
		CONFIG_HZ=1000

		CONFIG_TRANSPARENT_HUGEPAGE=y
		CONFIG_HUGETLBFS=y

		CONFIG_IA32_EMULATION=y
		CONFIG_X86_X32=y

		dnl Other useful stuff
		dnl
		include(`linux-x86.conf.m4')
		include(`linux-common.conf.m4')
		include(`linux-block.conf.m4')
		include(`linux-net.conf.m4')
		include(`linux-fs.conf.m4')

		# CONFIG_NUMA=y
		# CONFIG_NUMA_BALANCING=y
		CONFIG_PREEMPT_VOLUNTARY=y

		CONFIG_AMD_IOMMU=y
		CONFIG_INTEL_IOMMU=y
		CONFIG_INTEL_IOMMU_SVM=y
		CONFIG_HYPERV_IOMMU_SVM=y
		CONFIG_IOMMU_DEFAULT_PASSTHROUGH=y

		dnl Support for latest low level clocks, gpio, and i2c glue
		dnl
		CONFIG_X86_AMD_PLATFORM_DEVICE=y
		CONFIG_X86_INTEL_LPSS=m
		CONFIG_I2C_DESIGNWARE_BAYTRAIL=y
		CONFIG_PMIC_OPREGION=y
		CONFIG_INTEL_SOC_PMIC=y
	EOT
} | m4 -I $base/architecture/$arch -I $base/architecture/x86 -I $base/architecture/share
