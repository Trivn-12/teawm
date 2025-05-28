#!/bin/bash
# Copyright (c) 2015 Oracle and/or its affiliates. All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it would be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# Test creates several zram devices with different filesystems on them.
# It fills each device with zeros and checks that compression works.
#
# Author: Alexey Kodanev <alexey.kodanev@oracle.com>
# Modified: Naresh Kamboju <naresh.kamboju@linaro.org>

TCID="zram01"
ERR_CODE=0

. ./zram_lib.sh

# Test will create the following number of zram devices:
dev_num=1
# This is a list of parameters for zram devices.
# Number of items must be equal to 'dev_num' parameter.
zram_max_streams="2"

# The zram sysfs node 'disksize' value can be either in bytes,
# or you can use mem suffixes. But in some old kernels, mem
# suffixes are not supported, for example, in RHEL6.6GA's kernel
# layer, it uses strict_strtoull() to parse disksize which does
# not support mem suffixes, in some newer kernels, they use
# memparse() which supports mem suffixes. So here we just use
# bytes to make sure everything works correctly.
zram_sizes="2097152" # 2MB
zram_mem_limits="2M"
zram_filesystems="ext4"
zram_algs="lzo"

zram_fill_fs()
{
	for i in $(seq 0 $(($dev_num - 1))); do
		echo "fill zram$i..."
		local b=0
		while [ true ]; do
			dd conv=notrunc if=/dev/zero of=zram${i}/file \
				oflag=append count=1 bs=1024 status=none \
				> /dev/null 2>&1 || break
			b=$(($b + 1))
		done
		echo "zram$i can be filled with '$b' KB"
	done

	# Use mm_stat for accurate memory usage calculation
	local total_orig_size=0
	local total_compr_size=0
	local total_mem_used=0

	for i in $(seq 0 $(($dev_num - 1))); do
		local mm_stat="/sys/block/zram${i}/mm_stat"
		if [ -e "$mm_stat" ]; then
			# mm_stat format: orig_data_size compr_data_size mem_used_total mem_limit_total max_used_total same_pages pages_compacted huge_pages
			local orig_size=$(awk '{print $1}' $mm_stat)
			local compr_size=$(awk '{print $2}' $mm_stat)
			local mem_used=$(awk '{print $3}' $mm_stat)

			total_orig_size=$(($total_orig_size + $orig_size))
			total_compr_size=$(($total_compr_size + $compr_size))
			total_mem_used=$(($total_mem_used + $mem_used))
		fi
	done

	# Convert to MB for display
	local orig_size_mb=$(($total_orig_size / 1024 / 1024))
	local compr_size_mb=$(($total_compr_size / 1024 / 1024))
	local mem_used_mb=$(($total_mem_used / 1024 / 1024))

	echo "zram orig_data: ${orig_size_mb}M, compr_data: ${compr_size_mb}M, mem_used: ${mem_used_mb}M"

	# Calculate compression ratio
	if [ $total_compr_size -gt 0 ]; then
		local ratio=$((($total_orig_size * 100) / $total_compr_size))
		if [ "$ratio" -lt 100 ]; then
			echo "FAIL compression ratio: 0.$ratio:1"
			ERR_CODE=-1
			zram_cleanup
			return
		fi
		echo "zram compression ratio: $(echo "scale=2; $ratio / 100 " | bc):1: OK"
	else
		echo "zram compression ratio: N/A (no compressed data)"
	fi
}

check_prereqs
zram_load
zram_max_streams
zram_compress_alg
zram_set_disksizes
zram_set_memlimit
zram_makefs
zram_mount

zram_fill_fs
zram_cleanup
zram_unload

if [ $ERR_CODE -ne 0 ]; then
	echo "$TCID : [FAIL]"
else
	echo "$TCID : [PASS]"
fi
