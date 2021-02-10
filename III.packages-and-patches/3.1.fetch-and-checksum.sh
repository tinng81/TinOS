# Usage: ./3.1.fetch-and-checksum.fs 
#!/bin/bash

. ../lfs-env

# Create dir then manually copy wget-list, md5sum to $LFS/sources to fetch
mkdir -v $LFS/sources
chmod -v a+wt $LFS/sources
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources

# verify with checksum
pushd $LFS/sources
  md5sum -c md5sums
popd

