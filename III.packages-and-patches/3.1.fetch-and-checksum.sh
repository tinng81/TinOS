# Usage: ./3.1.fetch-and-checksum.sh 
#!/bin/bash

. ../lfs-env

# Create dir then manually copy wget-list, md5sum to $LFS/sources to fetch
mkdir -v $LFS/sources
chmod -v a+wt $LFS/sources

mv ../tools/wget-list $LFS/sources
mv ../tools/md5sums $LFS/sources

pushd $LFS/sources
  wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
  # verify with checksum
  # md5sums of all packages' sum
  md5sum -c md5sums
popd

