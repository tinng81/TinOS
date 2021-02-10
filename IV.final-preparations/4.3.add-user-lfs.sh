# Usage: ./4.3.add-user-lfs.sh <username>
#!/bin/bash

. ../lfs-env

default_user=lfs

# Create new group and add input user to it 
groupadd "${1:-$default_user}"
useradd -s /bin/bash -g "${1:-$default_user}" -m -k /dev/null "${1:-$default_user}"

# Grant user to root directories
chown -v "${1:-$default_user}" $LFS/{usr,lib,var,etc,bin,sbin,tools,sources}
case $(uname -m) in
  x86_64) chown -v "${1:-$default_user}" $LFS/lib64 ;;
esac

# Add password to created user
passwd "${1:-$default_user}"


