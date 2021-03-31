# Usage: ./5.1.build-all-packages.sh 
#!/bin/bash

. ../lfs-env

function build_all_packages() {
  # Aggregated dir for multiple packages
  mkdir -p -v $LFS/sources/gcc

  pushd $LFS/sources
    grep -oP "([^\/]+$)" wget-list > tarball
  
    for tar_name in $(cat tarball); do
      tar_dir=${tar_name%.tar.*}
      tar_script=${tar_dir%-*}

      echo "$tar_dir"
      echo "$tar_script"
  
      # Create and extract to folder
      # NOTE strip parent folder of all tarball
      # FIXME ensure none of the tarball missing a parent folder
      mkdir -v $tar_dir
      tar xvf $tar_name -C $tar_dir --strip 1
  
      # Start compilation for each package
      # NOTE each dir has a matching script with their name
      # TODO might consider strip version in folder/script name
      # NOTE time function reveals Standard Build Unit for each package
      pushd $tar_dir 
        time {
          "$tar_script"
        }
      popd
  
      # FIXME remove after development
      exit
    done
  popd
}


function binutils() {
  mkdir -v build
  cd build

  ../configure --prefix=$LFS/tools       \
             --with-sysroot=$LFS        \
             --target=$LFS_TGT          \
             --disable-nls              \
             --disable-werror
  make
  make install
}

function mpfr() {
  mv -v $PWD ../gcc/mpfr
}

function gmp() {
  mv -v $PWD ../gcc/gmp
}

function mpc() {
  mv -v $PWD ../gcc/mpc
}

function gcc() {
  case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
  esac

  # Migrate from extracted directory to gcc
  cp -r $PWD/* ../gcc
  pushd $LFS/sources/gcc

  mkdir -v build
  cd       build

  ../configure                                     \
    --target=$LFS_TGT                              \
    --prefix=$LFS/tools                            \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --enable-initfini-array                        \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++

  make
  make install

  cd ..
  cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
}

function linux() {
  make mrproper

  make headers
  find usr/include -name '.*' -delete
  rm usr/include/Makefile
  cp -rv usr/include $LFS/usr
}

function glibc() {
  case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
    ;;
  esac

  patch -Np1 -i ../glibc-2.32-fhs-1.patch

  mkdir -v build
  cd build

  ../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2                \
      --with-headers=$LFS/usr/include    \
      libc_cv_slibdir=/lib

  make
  make DESTDIR=$LFS install

  $LFS/tools/libexec/gcc/$LFS_TGT/10.2.0/install-tools/mkheaders
}

function libstdc() {
  pushd $LFS/sources/gcc-10.2.0
    
    # TODO Remove this if not necessary, i.e. built in different subfolder
    rm -rf build
    
    mkdir -v build
    cd build

    ../libstdc++-v3/configure         \
      --host=$LFS_TGT                 \
      --build=$(../config.guess)      \
      --prefix=/usr                   \
      --disable-multilib              \
      --disable-nls                   \
      --disable-libstdcxx-pch         \
      --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/10.2.0

    make
    make DESTDIR=$LFS install
  popd
}

build_all_packages; exit

