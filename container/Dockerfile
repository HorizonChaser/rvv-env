# These arguments are used to select a base image. It could be either host image
# (by default for x86) or target image (for RISC-V).
ARG BASE_IMAGE=ubuntu
ARG BASE_TAG=24.04
FROM ${BASE_IMAGE}:${BASE_TAG} AS base

# `base` target should be BASE_IMAGE-agnostic.
WORKDIR /work
COPY --link entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# It's `base-debian`, as it could be used for all Debian derivatives.
FROM base AS base-debian
ARG ADDITIONAL_PACKAGES=""
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        fish \
        git \
        gosu \
        nano \
        sudo \
        wget \
        ${ADDITIONAL_PACKAGES} \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    # Remove the default user on Ubuntu so that if a user has UID=1000 there is
    # no conflict when bootstrapping the environment.
    && (userdel ubuntu || echo "No user named ubuntu.")

# Use a temporary image to download and extract the toolchain, so that it can be
# cached more efficiently.
FROM ${BASE_IMAGE}:${BASE_TAG} AS host-toolchain-tmp
ARG RISCV_TOOLCHAIN_SNAPSHOT=2025.01.20
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tar \
        xz-utils \
    # Cleanup.
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    # Download and extract RISC-V toolchain.
    && curl -L https://github.com/riscv-collab/riscv-gnu-toolchain/releases/download/${RISCV_TOOLCHAIN_SNAPSHOT}/riscv64-glibc-ubuntu-24.04-llvm-nightly-${RISCV_TOOLCHAIN_SNAPSHOT}-nightly.tar.xz \
        | tar -xJ -C /opt

# Host image with upstream toolchain.
FROM base-debian AS host-upstream
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        # Runtime dependency for toolchain.
        libpython3.12 \
    # Cleanup.
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
COPY --link --from=host-toolchain-tmp /opt/riscv /opt/riscv
ENV PATH=/opt/riscv/bin:${PATH}

# Build patched GDB.
FROM host-upstream AS host-build-toolchain-gdb
WORKDIR /build

# Dependencies as in https://github.com/riscv-collab/riscv-gnu-toolchain?tab=readme-ov-file#prerequisites
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf automake autotools-dev python3 python3-pip libmpc-dev \
        libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf \
        libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake \
        libglib2.0-dev libslirp-dev \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ARG RISCV_TOOLCHAIN_GDB_REPO=https://github.com/MarekPikula/binutils-gdb.git
ARG RISCV_TOOLCHAIN_GDB_BRANCH=riscv-disasm-dyn-fix
ADD --link \
    ${RISCV_TOOLCHAIN_GDB_REPO}#${RISCV_TOOLCHAIN_GDB_BRANCH} \
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

FROM host-upstream AS host-patched
COPY --link --from=host-build-toolchain-gdb /opt/gdb/ /opt/gdb/
ENV PATH=/opt/gdb/bin:${PATH}

# Target images
# By default it just refers to the default `base` image, but you can change the
# base by setting BASE_IMAGE and BASE_TAG build arguments.
FROM base-debian AS target-debian

# You can extend the image by creating a separate `target-...` target or by
# using the ADDITIONAL_PACKAGES argument.
