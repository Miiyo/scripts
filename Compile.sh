#!/bin/bash

KERNEL_DEFCONFIG=
CLANG_DIR=
export KBUILD_BUILD_USER=ekkusa
export KBUILD_BUILD_HOST=miyo


make O=out ARCH=arm64 ${KERNEL_DEFCONFIG}
PATH="${CLANG_DIR}/bin:${PATH}" \
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      LD=ld.lld \
                      AR=llvm-ar \
                      NM=llvm-nm \
                      OBJCOPY=llvm-objcopy \
                      OBJDUMP=llvm-objdump \
                      STRIP=llvm-strip \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi-
