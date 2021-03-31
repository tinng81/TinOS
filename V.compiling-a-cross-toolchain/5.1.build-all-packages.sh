# Usage: ./5.1.build-all-packages.sh 
#!/bin/bash

. ../lfs-env

function build_all_packages() {
  # Aggregated dir for multiple packages
  # NOTE this might be accidentally deleted by calling packages
  mkdir -p -v $LFS/sources/gcc

  pushd $LFS/sources
    grep -oP "([^\/]+$)" wget-list > tarball
  
    for tar_name in $(cat tarball); do
      tar_dir=${tar_name%.tar.*}
      tar_script=${tar_dir%-*}

      # Additional logic ensures correct (local) func invoked
      case "$tar_script" in 
      grep*|make*|tar*)
        tar_script=_$tar_script
        ;;
      esac

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

  # TODO Add critical interrupt when sanitary check not passed
  echo 'int main(){}' > dummy.c
  $LFS_TGT-gcc dummy.c
  readelf -l a.out | grep '/ld-linux' # Success output [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
  rm -v dummy.c a.out

  $LFS/tools/libexec/gcc/$LFS_TGT/10.2.0/install-tools/mkheaders

  # NOTE chained calling function with already extracted tarball
  # TODO Better practice
  _libstdc
}

# Libstd++ Pass 1
function _libstdc() {
  # NOTE compiled in GCC folder
  pushd $LFS/sources/gcc
      
    mkdir -v build-libstdc
    cd build-libstdc

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

function m4() {
  sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
  echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
  
  ./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

  make
  make DESTDIR=$LFS install
}

function ncurses() {
  sed -i s/mawk// configure

  mkdir -v build
  pushd build
    ../configure
    make -C include
    make -C progs tic
  popd

  ./configure --prefix=/usr                \
              --host=$LFS_TGT              \
              --build=$(./config.guess)    \
              --mandir=/usr/share/man      \
              --with-manpage-format=normal \
              --with-shared                \
              --without-debug              \
              --without-ada                \
              --without-normal             \
              --enable-widec
  
  make
  make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
  echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so

  mv -v $LFS/usr/lib/libncursesw.so.6* $LFS/lib
  ln -sfv ../../lib/$(readlink $LFS/usr/lib/libncursesw.so) $LFS/usr/lib/libncursesw.so
}

function bash() {
  ./configure --prefix=/usr                   \
              --build=$(support/config.guess) \
              --host=$LFS_TGT                 \
              --without-bash-malloc

  make
  make DESTDIR=$LFS install

  mv $LFS/usr/bin/bash $LFS/bin/bash
  ln -sv bash $LFS/bin/sh
}

function coreutils() {
  ./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime
  
  make
  make DESTDIR=$LFS install

  mv -v $LFS/usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} $LFS/bin
  mv -v $LFS/usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm}        $LFS/bin
  mv -v $LFS/usr/bin/{rmdir,stty,sync,true,uname}               $LFS/bin
  mv -v $LFS/usr/bin/{head,nice,sleep,touch}                    $LFS/bin
  mv -v $LFS/usr/bin/chroot                                     $LFS/usr/sbin
  mkdir -pv $LFS/usr/share/man/man8
  mv -v $LFS/usr/share/man/man1/chroot.1                        $LFS/usr/share/man/man8/chroot.8
  sed -i 's/"1"/"8"/'                                           $LFS/usr/share/man/man8/chroot.8
}

function diffutils() {
  ./configure --prefix=/usr --host=$LFS_TGT

  make
  make DESTDIR=$LFS install
}

function file() {
  mkdir build
  pushd build
    ../configure --disable-bzlib      \
                --disable-libseccomp \
                --disable-xzlib      \
                --disable-zlib
    make
  popd

  ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)

  make FILE_COMPILE=$(pwd)/build/src/file
  make DESTDIR=$LFS install
}

function findutils() {
  ./configure --prefix=/usr   \
              --host=$LFS_TGT \
              --build=$(build-aux/config.guess)

  make
  make DESTDIR=$LFS install

  mv -v $LFS/usr/bin/find $LFS/bin
  sed -i 's|find:=${BINDIR}|find:=/bin|' $LFS/usr/bin/updatedb
}

function gawk() {
  sed -i 's/extras//' Makefile.in
  ./configure --prefix=/usr   \
              --host=$LFS_TGT \
              --build=$(./config.guess)

  make
  make DESTDIR=$LFS install
}

# As oppposed to grep on host system
function _grep() {
  ./configure --prefix=/usr   \
              --host=$LFS_TGT \
              --bindir=/bin

  make
  make DESTDIR=$LFS install              
}

function gzip() {
  ./configure --prefix=/usr --host=$LFS_TGT

  make
  make DESTDIR=$LFS install

  mv -v $LFS/usr/bin/gzip $LFS/bin  
}

function _make() {
  ./configure --prefix=/usr   \
              --without-guile \
              --host=$LFS_TGT \
              --build=$(build-aux/config.guess)

  make
  make DESTDIR=$LFS install
}

function patch() {
  ./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)

  make
  make DESTDIR=$LFS install
}

function sed() {
  ./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --bindir=/bin

  make
  make DESTDIR=$LFS install            
}

function _tar() {
  ./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --bindir=/bin

  make
  make DESTDIR=$LFS install
}

function xz() {
  ./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-5.2.5

  make
  make DESTDIR=$LFS install

  mv -v $LFS/usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat}  $LFS/bin
  mv -v $LFS/usr/lib/liblzma.so.*                       $LFS/lib
  ln -svf ../../lib/$(readlink $LFS/usr/lib/liblzma.so) $LFS/usr/lib/liblzma.so

  # NOTE chained calling function with already extracted tarball
  # TODO Better practice
  _binutils-p2
  _gcc-p2
}

function _binutils-p2() {
  # TODO refactor dirname to stripped down version, similar to gcc
  pushd $LFS/sources/binutils-2.35
  mkdir -v build-p2
  cd       build-p2

  ../configure                   \
      --prefix=/usr              \
      --build=$(../config.guess) \
      --host=$LFS_TGT            \
      --disable-nls              \
      --enable-shared            \
      --disable-werror           \
      --enable-64-bit-bfd

  make
  make DESTDIR=$LFS install
  install -vm755 libctf/.libs/libctf.so.0.0.0 $LFS/usr/lib
}

function _gcc-p2() {
  pushd $LFS/sources/gcc
  case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
  ;;
  esac

  mkdir -v build-p2
  cd       build-p2

  mkdir -pv $LFS_TGT/libgcc
  ln -s ../../../libgcc/gthr-posix.h $LFS_TGT/libgcc/gthr-default.h

  ../configure                                       \
    --build=$(../config.guess)                     \
    --host=$LFS_TGT                                \
    --prefix=/usr                                  \
    CC_FOR_TARGET=$LFS_TGT-gcc                     \
    --with-build-sysroot=$LFS                      \
    --enable-initfini-array                        \
    --disable-nls                                  \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++
  
  make
  make DESTDIR=$LFS install
  ln -sv gcc $LFS/usr/bin/cc  
}

build_all_packages; exit

