#/bin/bash

set -e

PROJECT=Allwinner
ARCH=arm
DEVICE=H6
VDR="yes"
VDR_PREFIX="/usr/local"
DISTRO="VdrELEC"
SUFFIX="VDR"

usage() {
  cat << EOF >&2
Usage: $PROGNAME [-b] [-d]
-b  : Build VdrELEC images. Images will be created which can be written to an SD card. Contains VDR in /usr/local
-d  : Download packages sources
EOF
  exit 1
}

cleanup() {
  rm -rf target/*
}

create_vdr_image() {
  cleanup
  git checkout vdrelec-20-VDR
  PROJECT=${PROJECT} ARCH=${ARCH} DEVICE=${DEVICE} VDR=${VDR} VDR_PREFIX=${VDR_PREFIX} DISTRO=${DISTRO} BUILD_SUFFIX=${SUFFIX} make image
}

get_sources() {
  PROJECT=${PROJECT} ARCH=${ARCH} DEVICE=${DEVICE} VDR=${VDR} VDR_PREFIX=${VDR_PREFIX} DISTRO=${DISTRO} BUILD_SUFFIX=${SUFFIX} tools/download-tool
}

if [ "$#" = "0" ]; then
    usage
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b) create_vdr_image ;;
        -d) get_sources ;;
        *) echo "Unknown parameter passed: $1";  usage; exit 1 ;;
    esac
    shift
done
