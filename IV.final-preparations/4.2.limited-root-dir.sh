# Usage: ./4.2.limited-root-dir.sh
#!/bin/bash

. ../lfs-env

# Create limited directories under root
mkdir -pv $LFS/{bin,etc,lib,sbin,usr,var,tools}
case $(uname -m) in
  x86_64) mkdir -pv $LFS/lib64 ;;
esac
