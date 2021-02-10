# Usage: ./2.4.new-partition.sh /dev/sdx
#!/bin/bash

. ../lfs-env

test -z "$1" && echo "Not enough argument! Try 'fdisk -l' to find correct disk" && exit

# FIXME will cause mismatch error if already >3 partitions due to default value skipped
# Create two partitions root 20G and swap 1G
(
echo n    # Add a new partition
echo p    # Primary partition
echo      # Default incrementing partition number
echo      # First sector
echo +20G # Add 20G to partition 
echo n    # Add a new partition
echo p    # Primary partition
echo      # Default incrementing partition number
echo      # First sector
echo +1G  # Add 20G to partition
echo t    # Change partition type
echo      # Default incrementing partition number
echo 82   # Linux Swap Type
echo w    # Write changes
) | fdisk $1

