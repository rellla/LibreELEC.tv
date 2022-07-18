#/bin/bash

set -e

PROJECT=Allwinner
ARCH=arm
DEVICE=H6
VDR="yes"
VDR_PREFIX="/usr/local"
DISTRO="VdrELEC"
ADDITIONAL_ADDONS="system-tools locale"

usage() {
  cat << EOF >&2
Usage: $PROGNAME [-t] [-i] [-9] [-0] [-d] [-e] [-x] [-y]
-t  : Build tar (Matrix). Version containing only VDR and is installable in an existing Kodi installation (Deprecated!)
-i  : Build images (Matrix). Images will be created which can be written to an SD card. Contains VDR in /usr/local
-9  : Build images (corelec-19). Images will be created which can be written to an SD card. Contains VDR in /usr/local
-0  : Build images (corelec-20). Images will be created which can be written to an SD card. Contains VDR in /usr/local
-r  : Build images (vdrelec-20). Images will be created which can be written to an SD card. Contains VDR in /usr/local

-dvb-latest   : build dvb-latest device driver addon
-dvb-crazycat : build dvb-crazycat device driver addon
-dvb-all      : build dvb-latest and dvb-crazycat device driver addons

-d  : Enable vdr-plugin-dynamite. Default is disabled.
-e  : Enable vdr-plugin-easyvdr. Default is disabled.
-z  : Enable zapcockpit. Default is disabled.
-s  : Enable softhdodoid test patch. Default is disabled.

-x  : Development only: Build images but don't switch the branch.
-y  : Development only: Build tar but don't switch the branch.
EOF
  exit 1
}

create_vdr_tar() {
  if [ ! "$1" = "x" ]; then
     #### Checkout the correct branch. Only 19.4-Matrix-VDR is supported
     git checkout 19.4-Matrix-VDR
  fi

  #### 1. Pass: build without VDR
  export VDR="no"
  VDR_PREFIX="/opt/vdr" make
  mv target/CoreELEC*.system target/image.pass1

  #### 2. Pass: build with VDR
  export VDR="yes"
  VDR_PREFIX="/opt/vdr" make
  mv target/CoreELEC*.system target/image.pass2

  #### Create Diff
  cd target
  mkdir -p pass1
  mkdir -p pass2
  squashfuse image.pass1 pass1
  squashfuse image.pass2 pass2
  find pass1 | sed -e "s/^pass1//g ; /^\/opt/d" | sort > pass1.filelist
  find pass2 | sed -e "s/^pass2//g ; /^\/opt/d" | sort > pass2.filelist
  diff -u8bBw pass1.filelist pass2.filelist | sed -e '/^\+/!d ; /^\+\/usr\/bin/d ; /^\+\/usr\/share/d ; s/^\+//g ; /^\+\+/d' > libs.diff
  cd ..

  # copy VDR data
  mkdir -p vdr-tar
  cp -a target/pass2/opt vdr-tar

  # copy extra libs from pass1 to vdr-tar
  while read -r line; do
     NEWFILE=`echo $line | sed -e 's/\/usr\/lib/\/opt\/vdr\/lib/g'`
     mkdir -p vdr-tar/`dirname $NEWFILE`
     if [ ! -d target/pass2/$line ]; then
         cp -a target/pass2/$line vdr-tar/$NEWFILE
     fi
  done <target/libs.diff

  # Cleanup
  rm -f vdr-tar/opt/.opt
  rm -f vdr-tar/opt/vdr/bin/{createcats,cxxtools-config,gdk-*,iconv,pango*,rsvg-convert,tntnet-config,update-mime-database}
  rm -Rf vdr-tar/opt/vdr/include
  rm -Rf vdr-tar/opt/vdr/lib/pkgconfig
  rm -Rf vdr-tar/opt/vdr/vdrshare/{doc,mime,pkgconfig,tntnet}
  rm -Rf vdr-tar/usr
  rm -Rf vdr-tar/etc

  find vdr-tar/opt/vdr/vdrshare/locale/ -not -name "vdr*" -and -not -type d -exec rm {} \;
  find vdr-tar -type d -empty -delete

  # build final archive
  tar -czf build-artifacts/coreelec-19-vdr.tar.gz -C vdr-tar .
  rm -Rf vdr-tar

  # umount everything
  umount -q target/pass1 || echo
  umount -q target/pass2 || echo

  echo "======================================================="
  echo "Warnning: This build is deprecated and will be removed!"
  echo "Please use one of the image builds: -0 -9 -i"
  echo "======================================================="
}

create_vdr_image() {
  PROJECT=Allwinner
  ARCH=arm
  DEVICE=H6
  VDR="yes"
  VDR_PREFIX="/usr/local"
  DISTRO="VdrELEC"

  if [ "$1" = "Matrix" ]; then
     git checkout 19.4-Matrix-VDR
     SUFFIX="image-Matrix-VDR"
  elif [ "$1" = "19" ]; then
     git checkout coreelec-19-VDR
     SUFFIX="image-19-VDR"
  elif [ "$1" = "20" ]; then
     git checkout coreelec-20-VDR
     SUFFIX="image-20-VDR"
  elif [ "$1" = "r" ]; then
     git checkout vdrelec-20-VDR
     SUFFIX="image-20-VDR-rellla"
  elif [ "$1" = "x" ]; then
     SUFFIX="devel"
  else
     echo "Unknown image \"$1\". Abort build."
     exit 1
  fi

#  echo "PROJECT=${PROJECT} ARCH=${ARCH} DEVICE=${DEVICE} VDR=${VDR} VDR_PREFIX=${VDR_PREFIX} DISTRO=${DISTRO} BUILD_SUFFIX=${SUFFIX} make image"
#  PROJECT=${PROJECT} ARCH=${ARCH} DEVICE=${DEVICE} VDR=${VDR} VDR_PREFIX=${VDR_PREFIX} DISTRO=${DISTRO} BUILD_SUFFIX=${SUFFIX} make system
#  create_additional_addons ${SUFFIX}
  PROJECT=${PROJECT} ARCH=${ARCH} DEVICE=${DEVICE} VDR=${VDR} VDR_PREFIX=${VDR_PREFIX} DISTRO=${DISTRO} BUILD_SUFFIX=${SUFFIX} make image
}

create_dvb_addons() {
  if [ "$dvb_all" = "1" ]; then
      ADDONS="dvb-latest crazycat"
  elif [ "$dvb_latest" = "1" ]; then
      ADDONS="dvb-latest"
  elif [ "$dvb_crazycat" = "1" ]; then
      ADDONS="dvb-crazycat"
  fi;

  PROJECT=Amlogic-ce ARCH=arm ./scripts/create_addon $ADDONS
}

enable_plugin() {
  # copy the patches and enable plugin
  if [ "$1" = "dynamite" ]; then
    cp packages/vdr/_vdr/optional/vdr-2.4.6-dynamite.patch packages/vdr/_vdr/patches
    sed -i -e "s/^#\(PKG_DEPENDS_TARGET+=\" _vdr-plugin-dynamite\"\)/\1/" packages/virtual/vdr-all/package.mk
  elif [ "$1" = "easyvdr" ]; then
    cp packages/vdr/_vdr/optional/vdr-plugin-easyvdr.patch packages/vdr/_vdr/patches
    sed -i -e "s/^#\(PKG_DEPENDS_TARGET+=\" _vdr-plugin-easyvdr\"\)/\1/" packages/virtual/vdr-all/package.mk
  elif [ "$1" = "zapcockpit" ]; then
    cp packages/vdr/_vdr/optional/vdr-2.4.0_zapcockpit.patch packages/vdr/_vdr/patches
  fi
}

disable_plugin() {
  # delete patches and disable plugin
  if [ "$1" = "dynamite" ]; then
    rm -f packages/vdr/_vdr/patches/vdr-2.4.6-dynamite.patch
    sed -i -e "s/^\(PKG_DEPENDS_TARGET+=\" _vdr-plugin-dynamite\"\)/#\1/" packages/virtual/vdr-all/package.mk
  elif [ "$1" = "easyvdr" ]; then
    rm -f packages/vdr/_vdr/patches/vdr-plugin-easyvdr.patch
    sed -i -e "s/^\(PKG_DEPENDS_TARGET+=\" _vdr-plugin-easyvdr\"\)/#\1/" packages/virtual/vdr-all/package.mk
  elif [ "$1" = "zapcockpit" ]; then
    rm -f packages/vdr/_vdr/patches/vdr-2.4.0_zapcockpit.patch
  fi
}

enable_patch() {
  cp packages/vdr/_vdr-plugin-$1/optional/$2 packages/vdr/_vdr-plugin-$1/patches/$2
}

disable_patch() {
  rm -f packages/vdr/_vdr-plugin-$1/patches/$2
}

cleanup() {
  mkdir -p build-artifacts
  rm -f build-artifacts/*

  # umount if still mounted
  if [ -d target/pass1 ]; then
    umount -q target/pass1 || echo
  fi

  if [ -d target/pass2 ]; then
    umount -q target/pass2 || echo
  fi

#  rm -rf target/*
}

if [ "$#" = "0" ]; then
    usage
fi

cleanup

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d) enable_dynamite=1 ;;
        -e) enable_easyvdr=1 ;;
        -z) enable_zapcockpit=1 ;;
        -s) enable_softhdodroid_test=1 ;;
        -t) c_vdr_tar=1 ;;
        -i) c_vdr_image_matrix=1 ;;
        -9) c_vdr_image_19=1 ;;
        -0) c_vdr_image_20=1 ;;
        -r) c_vdr_image_20=r ;;
        -x) dev_vdr_image=1 ;;
        -y) dev_vdr_tar=1 ;;
        -dvb-latest) dvb_latest=1;;
        -dvb-crazycat) dvb_crazycat=1;;
        -dvb-all) dvb_all=1;;
        *) echo "Unknown parameter passed: $1";  usage; exit 1 ;;
    esac
    shift
done

if [ "${enable_dynamite}" = "1" ]; then
  enable_plugin "dynamite"
else
  disable_plugin "dynamite"
fi

if [ "${enable_easyvdr}" = "1" ]; then
  enable_plugin "easyvdr"
else
  disable_plugin "easyvdr"
fi

if [ "${enable_zapcockpit}" = "1" ]; then
  enable_plugin "zapcockpit"
else
  disable_plugin "zapcockpit"
fi

if [ "${enable_softhdodroid_test}" = "1" ]; then
  enable_patch "softhdodroid" "softhdodroid-Test.patch"
else
  disable_patch "softhdodroid" "softhdodroid-Test.patch"
fi

if [ "${c_vdr_tar}" = "1" ]; then
  create_vdr_tar
fi

if [ "${c_vdr_image_matrix}" = "1" ]; then
  create_vdr_image "Matrix"
fi

if [ "${c_vdr_image_19}" = "1" ]; then
  create_vdr_image "19"
fi

if [ "${c_vdr_image_20}" = "1" ]; then
  create_vdr_image "20"
fi

if [ "${c_vdr_image_20}" = "r" ]; then
  create_vdr_image "r"
fi

if [ "${dev_vdr_image}" = "1" ]; then
  create_vdr_image "x"
fi

if [ "${dev_vdr_tar}" = "1" ]; then
  create_vdr_tar "x"
fi

if [ "$dvb_latest" = "1" ] || [ "$dvb_crazycat" = "1" ] || [ "$dvb_all" = "1" ]; then
  create_dvb_addons
fi;

disable_plugin "dynamite"
disable_plugin "easyvdr"
disable_plugin "zapcockpit"
disable_patch "softhdodroid" "softhdodroid-Test.patch"
