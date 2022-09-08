ExternalProject_Add(libuv
  PREFIX ${DEPS_BUILD_DIR}
  URL ${LIBUV_URL}
  CMAKE_ARGS
    -DCMAKE_INSTALL_PREFIX=${DEPS_INSTALL_DIR}
    -DCMAKE_INSTALL_LIBDIR=lib
    -DBUILD_TESTING=OFF
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    -DLIBUV_BUILD_SHARED=OFF
  CMAKE_CACHE_ARGS
    -DCMAKE_OSX_ARCHITECTURES:STRING=${CMAKE_OSX_ARCHITECTURES}
  DOWNLOAD_DIR ${DEPS_DOWNLOAD_DIR}/libuv
  DOWNLOAD_COMMAND ${CMAKE_COMMAND}
    -DPREFIX=${DEPS_BUILD_DIR}
    -DDOWNLOAD_DIR=${DEPS_DOWNLOAD_DIR}/libuv
    -DURL=${LIBUV_URL}
    -DEXPECTED_SHA256=${LIBUV_SHA256}
    -DTARGET=libuv
    -DUSE_EXISTING_SRC_DIR=${USE_EXISTING_SRC_DIR}
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/DownloadAndExtractFile.cmake
  PATCH_COMMAND
    ${GIT_EXECUTABLE} -C ${DEPS_BUILD_DIR}/src/libuv init
      COMMAND ${GIT_EXECUTABLE} -C ${DEPS_BUILD_DIR}/src/libuv apply --ignore-whitespace
        ${CMAKE_CURRENT_SOURCE_DIR}/patches/libuv-disable-shared.patch)

list(APPEND THIRD_PARTY_DEPS libuv)
