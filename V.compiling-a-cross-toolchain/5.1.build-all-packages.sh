# Usage: ./5.1.build-all-packages.sh 
#!/bin/bash

. ../lfs-env

function build_all_packages(){
  pushd $LFS/sources
    # grep -oP "([^\/]+$)" wget-list | sort -f > tarball
    # ls | sort -f > manifest
  
    for tar_name in *.{bz2,gz,xz}; do
      tar_dir=${tar_name%.tar.*}
  
      # Create and extract to folder
      # NOTE strip parent folder of all tarball
      # FIXME ensure none of the tarball missing a parent folder
      #mkdir -v $tar_dir
      #tar xvf $tar_name -C $tar_dir --strip 1
  
      # Start compilation for each package
      # NOTE each dir has a matching script with their name
      # TODO might consider strip version in folder/script name
      # NOTE time function reveals Standard Build Unit for each package
      pushd $tar_dir 
        time {$tar_dir}
      popd
  
      # FIXME remove after development
      exit
    done
    
  popd
}

function elfutils-0.180()
{
  echo "WD"
}

build_all_packages; exit

