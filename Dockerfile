ARG BASE_IMAGE=ubuntu
ARG BASE_TAG=24.04
FROM ${BASE_IMAGE}:${BASE_TAG} AS base

# Cache apt lists for build stages.
FROM base AS build-base
ENV APT_INSTALL="apt-get install -y --no-install-recommends"
RUN apt-get update && ${APT_INSTALL} ca-certificates git
WORKDIR /build

# Build proot.
FROM build-base AS build-proot
RUN apt-get update && ${APT_INSTALL} \
        build-essential \
        libarchive-dev \
        libtalloc-dev \
        uthash-dev
ADD https://github.com/proot-me/proot.git proot/
RUN cd proot/src \
    # Required patch to build with recent version of gcc.
    && sed -i 's|#include "compat.h"|#include "compat.h"\n#include "mem.h"|' tracee/tracee.c \
    && make loader.elf loader-m32.elf build.h \
    && make proot care \
    && make install

# Download toolchain.
FROM build-base AS build-toolchain
RUN apt-get update && ${APT_INSTALL} curl xz-utils
ARG RISCV_TOOLCHAIN_SNAPSHOT=2024.11.22
RUN curl -L https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/${RISCV_TOOLCHAIN_SNAPSHOT}/riscv64-glibc-ubuntu-24.04-llvm-nightly-${RISCV_TOOLCHAIN_SNAPSHOT}-nightly.tar.xz \
        | tar -xJ -C /opt
ENV PATH=/opt/riscv/bin:${PATH}

# Build undocker.
FROM build-base AS build-undocker
RUN apt-get update && ${APT_INSTALL} golang make
ADD https://git.jakstys.lt/motiejus/undocker.git undocker/
RUN make -C undocker undocker

# Target image.
FROM base AS upstream
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        fish \
        git \
        gosu \
        qemu-user \
        skopeo \
        sudo \
        wget \
        # Runtime dependencies for proot.
        libarchive13 \
        libtalloc2 \
        # Runtime dependencies for toolchain.
        libpython3.12 \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    # Remove the default user so that if a user has uid=1000 there is no conflict.
    && userdel ubuntu

# Copy build artifacts to the main image.
COPY --link --from=build-proot /usr/local/bin/proot /usr/local/bin/
COPY --link --from=build-toolchain /opt/riscv/ /opt/riscv/
COPY --link --from=build-undocker /build/undocker/undocker /usr/local/bin/
COPY --link scripts-docker/ /usr/local/bin/

ENV PATH=/opt/riscv/bin:${PATH}
WORKDIR /target
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Add patched gdb build.
FROM build-toolchain AS build-toolchain-gdb
# Dependencies as in https://github.com/riscv-collab/riscv-gnu-toolchain?tab=readme-ov-file#prerequisites
RUN apt-get update && ${APT_INSTALL} \
        autoconf automake autotools-dev curl python3 python3-pip libmpc-dev \
        libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf \
        libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake \
        libglib2.0-dev libslirp-dev
ARG RISCV_TOOLCHAIN_GDB_BRANCH=riscv-disasm-dyn-fix
ADD https://github.com/MarekPikula/binutils-gdb.git#${RISCV_TOOLCHAIN_GDB_BRANCH} \
    binutils-gdb
RUN cd binutils-gdb \
    # Inspired by riscv-gnu-toolchain.
    && ./configure \
        --target=riscv64-unknown-linux-gnu \
        --prefix=/opt/gdb \
        --with-sysroot=/opt/riscv/sysroot \
        --disable-nls \
        --with-expat=yes \
        --enable-gdb \
        --disable-gas \
        --disable-binutils \
        --disable-ld \
        --disable-gold \
        --disable-gprof \
    && make -j`nproc` \
    && make install

FROM upstream AS patched
COPY --link --from=build-toolchain-gdb /opt/gdb/ /opt/gdb/
ENV PATH=/opt/gdb/bin:${PATH}
