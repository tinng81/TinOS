# Usage: ./2.5.make-file-system.sh /dev/sdx /dev/sdy
#!/bin/bash

. ../lfs-env

test -z "$1" && echo "Not enough argument! Try 'fdisk -l' to find correct disk" && exit

# FIXME will cause mismatch error if already >3 partitions due to default value skipped
# Make root partition in ext4 type
mkfs -v -t ext4 $1 	# root partition 
mkswap $2 		# swap partition

