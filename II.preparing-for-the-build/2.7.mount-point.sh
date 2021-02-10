# Usage: ./2.7.mount-point.sh /dev/sdx /dev/sdy
#!/bin/bash

. ../lfs-env

test -z "$1" && echo "Not enough argument! Try 'fdisk -l' to find correct disk" && exit

# Mount root partition at $LFS path
mkdir -pv $LFS
mount -v -t ext4 $1 $LFS
/sbin/swapon -v $2
