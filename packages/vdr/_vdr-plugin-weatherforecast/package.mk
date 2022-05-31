# SPDX-License-Identifier: GPL-2.0-or-later

PKG_NAME="_vdr-plugin-weatherforecast"
PKG_VERSION="0.2.0"
PKG_SHA256="c7b1740f096a576171b99bfa1c7ce2a785eed1596e0e510986c98f127cb3312d"
PKG_LICENSE="GPL"
PKG_SITE="https://projects.vdr-developer.org/git/vdr-plugin-weatherforecast.git/"
PKG_URL="https://projects.vdr-developer.org/git/vdr-plugin-weatherforecast.git/snapshot/vdr-plugin-weatherforecast-${PKG_VERSION}.tar.gz"
PKG_SOURCE_DIR="vdr-plugin-weatherforecast-${PKG_VERSION}"
PKG_DEPENDS_TARGET="toolchain _vdr _vdr-plugin-skindesigner"
PKG_NEED_UNPACK="$(get_pkg_directory _vdr)"
PKG_LONGDESC="TODO"
PKG_TOOLCHAIN="manual"

pre_configure_target() {
  # test if prefix is set
  if [ "x${VDR_PREFIX}" = "x" ]; then
      echo "==> VDR_PREFIX is empty, but must be set"
      exit 1
  fi

  export LDFLAGS="$(echo ${LDFLAGS} | sed -e "s|-Wl,--as-needed||") -L${SYSROOT_PREFIX}${VDR_PREFIX}/lib"
}

make_target() {
  VDR_DIR=$(get_build_dir _vdr)
  SKINDESIGNER_DIR=$(get_install_dir _vdr-plugin-skindesigner)

  export PKG_CONFIG_PATH=${VDR_DIR}:${SYSROOT_PREFIX}/${VDR_PREFIX}/lib/pkgconfig:${SKINDESIGNER_DIR}/${VDR_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}
  export CPLUS_INCLUDE_PATH=${VDR_DIR}/include

  make
}

makeinstall_target() {
  LIB_DIR=${INSTALL}/$(pkg-config --variable=locdir vdr)/../../lib/vdr
  make DESTDIR="${INSTALL}" LIBDIR="${LIB_DIR}" install
}

post_makeinstall_target() {
  mkdir -p ${INSTALL}/storage/.config/vdropt-sample/conf.d
  cp -PR ${PKG_DIR}/conf.d/* ${INSTALL}/storage/.config/vdropt-sample/conf.d/

  if find ${INSTALL}/storage/.config/vdropt -mindepth 1 -maxdepth 1 2>/dev/null | read; then
    cp -ar ${INSTALL}/storage/.config/vdropt/* ${INSTALL}/storage/.config/vdropt-sample
    rm -Rf ${INSTALL}/storage/.config/vdropt
  fi

  # create config.zip
  VERSION=$(pkg-config --variable=apiversion vdr)
  cd ${INSTALL}
  mkdir -p ${INSTALL}${VDR_PREFIX}/config/
  zip -qrum9 "${INSTALL}${VDR_PREFIX}/config/weatherforecast-sample-config.zip" storage
}
