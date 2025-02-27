# Containerized Environment for RISC-V Vector (RVV) Development

This repository provides a containerized development environment for debugging
RISC-V Vector (RVV) code. The setup allows RVV code debugging with vector
register dump capability (`info vectors`), which is not supported for local
development in GCC 15.2 (only for remote targets supporting the
`org.gnu.gdb.riscv.vector` feature, like QEMU).

Additionally, it includes a recent build of the [RISC-V toolchain][toolchain],
optionally extended with RISC-V-related GDB patches.

> Originally, the environment was developed internally at Samsung R&D Institute
> Poland by Marek Pikuła.

[toolchain]: https://github.com/riscv-collab/riscv-gnu-toolchain

## Quick Start

### Quick-Quick Start

This guide assumes you are running Ubuntu 24.04 with upstream Docker as the OCI
runner and QEMU with binfmt support.

Copy and run the [Pixman example script][example] to prepare the environment,
build Pixman, and initiate a GDB debug session. The expected output can be found
in [the log][example-log].

[example]: example/pixman.sh
[example-log]: example/pixman.log

### Step-by-Step Quick Start

1. **Install Docker** Follow the [official Docker installation
   guide][docker-install]. Ensure your version is recent enough by running:

   ```console
   $ docker version
   Client: Docker Engine - Community
   Version:           28.0.0
   API version:       1.48
   Go version:        go1.23.6
   Git commit:        f9ced58
   Built:             Wed Feb 19 22:11:38 2025
   OS/Arch:           linux/amd64
   Context:           default

   Server: Docker Engine - Community
   Engine:
   Version:          28.0.0
   API version:      1.48 (minimum version 1.24)
   Go version:       go1.23.6
   Git commit:       af898ab
   Built:            Wed Feb 19 22:09:59 2025
   OS/Arch:          linux/amd64
   Experimental:     false
   containerd:
   Version:          1.7.25
   GitCommit:        bcc810d6b9066471b0b6fa75f557a15a1cbf31bb
   runc:
   Version:          1.2.4
   GitCommit:        v1.2.4-0-g6c52b3f
   docker-init:
   Version:          0.19.0
   GitCommit:        de40ad0
   ```

2. **Install QEMU with binfmt support**

   ```console
   $ apt install qemu-user-binfmt
   $ sudo systemctl enable --now systemd-binfmt.service
   ```

3. **Clone the `rvv-env` repository**

   ```console
   git clone https://gitlab.com/riseproject/rvv-env.git
   ```

4. **Source the environment**

   ```console
   source env.sh
   ```

5. **Pull the images (*host* and *target*)**

   ```console
   ./oci-pull.sh
   ```

6. **Follow the [Using the Environment][usage] section.**

[docker-install]: https://docs.docker.com/engine/install/ubuntu/
[usage]: #using-the-environment

## Host Requirements

### OCI Engine

The primary prerequisite is some kind of OCI engine. The environment is
regularly used on Linux with official Docker CE. It may also work on Windows
with Docker Desktop (not tested) and other OCI engines like Podman.

By default, scripts use `docker` as the OCI engine. To use an alternative, set
the `CONTAINER_CMD` environment variable. Tested with:

- Docker CE 28.0.0
- Podman 5.4.0

To install Docker, follow the guide on [Docker's website][docker-guide].

> **Note**
> Your user needs to be in the `docker` group.
>
> For machines where you log in with AD credentials, you can force-add to a
> local `docker` group by directly editing `/etc/group` file.

> **Warning**
> If you have Docker already installed, and you want to build the image locally,
> ensure that it's a relatively recent version supporting BuildKit.

[docker-guide]: https://www.docker.com/get-started/

### QEMU and binfmt

In order to run the RISC-V image with Docker, you need to have a recent version
of QEMU and binfmt. For Ubuntu and Fedora you need to install `qemu-user-binfmt`
package. If you have an older version of Ubuntu, it's recommended to enable the
[`server-backports` PPA][server-backports] to install a recent version of QEMU
with good support for RVV (recommended version 9.0 or higher).

If you want to use `sudo` in the target image, binfmt needs to have credential
flag enabled. The `oci-run.sh` automatically checks for it, and prints a warning
in case it is not configured properly. If you wish to check it manually,
execute:

```console
$ cat /proc/sys/fs/binfmt_misc/status
enabled
interpreter /usr/bin/qemu-riscv64-static
flags: POCF
offset 0
magic 7f454c460201010000000000000000000200f300
mask ffffffffffffff00fffffffffffffffffeffffff
```

Notice that the `C` flag is active. If it's disabled, you can execute the
following commands:

```console
$ cat /proc/sys/fs/binfmt_misc/qemu-riscv64
enabled
interpreter /usr/bin/qemu-riscv64-static
flags: PF
offset 0
magic 7f454c460201010000000000000000000200f300
mask ffffffffffffff00fffffffffffffffffeffffff
$ sed 's/\(:[^C:]*\)$/\1C/' /usr/lib/binfmt.d/qemu-riscv64-static.conf \
    | sudo tee /etc/binfmt.d/qemu-riscv64-static.conf
$ sudo systemctl restart systemd-binfmt.service
$ cat /proc/sys/fs/binfmt_misc/status
enabled
interpreter /usr/bin/qemu-riscv64-static
flags: POCF
offset 0
magic 7f454c460201010000000000000000000200f300
mask ffffffffffffff00fffffffffffffffffeffffff
```

[server-backports]: https://launchpad.net/~canonical-server/+archive/ubuntu/server-backports/

## Image Types

There are two types of OCI images: *host* and *target*. *Host* images have tools
useful for cross-compilation and debugging on the host x86 machine, while the
*target* images are for the virtual RISC-V target.

### Pre-built Host Images

- `host-upstream`: Upstream tools, including the RISC-V toolchain.
- `host-patched`: Same as above, with patched GDB for better RVV debugging.

### Pre-built Target Images

- `target-debian`: Basic Debian image with development tools.
- `target-ubuntu`: Similar to `target-debian`, but based on Ubuntu.
- `target-pixman`: Based on upstream [Pixman][pixman] CI image, with tools for
  Pixman development.

You can select the image variant by setting the following environment variables:

- `IMAGE_VARIANT_HOST` – to set the *host* image (default: `host-patched`).
- `IMAGE_VARIANT_TARGET` – to set the *target* image (default: `target-debian`).

[pixman]: https://gitlab.freedesktop.org/pixman/pixman

## Pulling Images


The Docker images are built automatically with the GitLab CI and are uploaded to
the GitLab Container Registry (`registry.gitlab.com/riseproject/rvv-env`).

The images are tagged with branch name, with an exception for the default
(`main`) branch, for which `latest` tag is used. For example, the default *host*
image resides under
`registry.gitlab.com/riseproject/rvv-env/host-patched:latest` (where `:latest`
can be omitted).

You can pull the images (both *host* and *target*) with a convenience script:

```console
$ ./oci-pull.sh
```

If you wish to download different image variants, set the `IMAGE_VARIANT_HOST`
and `IMAGE_VARIANT_TARGET` environment variables as specified in the previous
section.

By default, the script uses the `latest` tag, but it can be changed for some
experimental images with `IMAGE_TAG` env variable (e.g., `IMAGE_TAG=test`). You
can also use your fork's image registry by setting `IMAGE_REGISTRY` variable.

### Build images locally

If you want to build the images locally, you can do it with the `oci-build.sh`
script. As the first argument, you should specify the image variant (defined in
`container/variants`). Any additional arguments will be passed to the image
build command.

### Modifying images

All image definitions should be placed in `container/variants` directory. Each
variant image has a name defined by the name of the environment file.

#### Additional packages

If you only wish to install additional packages, it's enough to modify the
`ADDITIONAL_PACKAGES` variable in the env file (like for `target-debian`).

#### Alternative base

If you wish to use a different base image, for example if you already have an
existing RISC-V image you are using in your project, you can change the
`BASE_IMAGE` and `BASE_TAG` variables in the env file (like for
`target-pixman`).

#### Dockerfile modifications

For more extensive modifications you should add another target in the Dockerfile
by extending `base-debian` and adding it as a separate variant configuration.

Example:

1. Add another target to `container/Dockerfile`:

   ```Dockerfile
   FROM base-debian AS target-my-custom-name
   RUN my-custom-command
   ```

2. Add variant file to `container/variants/target-my-custom-name.env`:

   ```env
   IMAGE_TARGET=target-my-custom-name
   PLATFORM=linux/riscv64
   BASE_IMAGE=debian
   BASE_TAG=sid-slim
   ADDITIONAL_PACKAGES=
   ```

3. Build the image:

   ```console
   $ ./oci-build.sh target-my-custom-name
   ```

4. Use the variant in scripts:

   ```console
   $ export IMAGE_VARIANT_TARGET=target-my-custom-name
   $ target-run uname -a
   Linux target-my-custom-name 6.13.5-arch1-1 #1 SMP PREEMPT_DYNAMIC Thu, 27 Feb 2025 18:09:44 +0000 riscv64 GNU/Linux
   ```

## Using the environment

To use the environment, first you need to initialize it:

```console
$ source env.sh
```

All the scripts attach the `rvv-env` directory to `/rvv-env` and the work
directory to `/work` inside the container (both *host* and *target*). By
default, we use `rvv-env/work` for the work directory, but if you have your
project sources elsewhere, you can change the mounted work directory by setting
`WORK_DIR` environment variable. Mind that the path you pass to `WORK_DIR` needs
to be an absolute path.

All the environment commands, transparently translate your current working
directory to the container. In addition to that, they execute the command as
your user inside the container.

For example, if `rvv-env` is in `~/Projects/rvv-env` and the project you're
working on is in `~/Projects/my-project`:

```console
$ source env.sh
$ export WORK_DIR=/home/my-user/Projects/my-project
$ pwd
/home/my-user/Projects/rvv-env
$ target-run pwd
/rvv-env
$ cd ../my-project
$ pwd
/home/my-user/Projects/my-project
$ target-run pwd
/work
$ target-run whoami
my-user
```

All arguments starting with a dash are passed to the run command, until the
first non-dash argument appears, for example:

```console
$ target-run --env=HELLO=WORLD env
LOCAL_USER_ID=1000
HOSTNAME=target-debian
PWD=/rvv-env
HELLO=WORLD
LOCAL_GROUP_ID=1000
LOCAL_USER_NAME=...
TERM=xterm
SHLVL=0
QEMU_CPU=rv64,v=false,vext_spec=v1.0,vlen=256,elen=64
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOME=/home/...
```

### `host-run` script

To run something in the *host* container (e.g., cross-compiler), you can use
`host-run` convenience script:

```console
$ host-run <whatever_command_you_want>
```

### Execution in the target environment – `target-run(-rvv)`

`target-run` and `target-run-rvv` are wrapper scripts allowing you to run a
command in the target environment. The only difference between the two commands
is that `target-run` has the RVV extension disabled (by default), whereas
`target-run-rvv` enabled (with option to change the VLEN and other RVV
parameters).

For `target-run-rvv`, QEMU emulates a RISC-V processor with RVV extension
enabled and `VLEN=256`. Here are the RVV parameters you can modify with
environment variables:

- `RVV_ENABLE` - enable RVV support in QEMU (`true` or `false`).
- `RVV_SPEC` - RVV extension spec (default: `v1.0`).
- `RVV_VLEN` - RVV vector register length (default: `256`).
- `RVV_ELEN` - RVV element length (default: `64`).
- `QEMU_CPU_EXTRA` - any additional `QEMU_CPU` specification.

### Running GDB in the target environment – `target-gdb(-rvv)`, `host-gdb`

`target-gdb` is a wrapper script instrumenting GDB execution on the virtual
target. Distinction between `target-gdb` and `target-gdb-rvv` is the same as for
`target-run(-rvv)` script.

`host-gdb` is a convenience script, which connects a GDB client to the GDB
server created with `target-gdb(-rvv)`.

If you want to run multiple sessions simultaneously, you can set `QEMU_GDB_PORT`
environment variable to some other port than the default 1234.

Example:

```console
$ cd work/pixman/build
$ target-gdb-rvv test/stress-test &
$ host-gdb
GNU gdb (GDB) 16.0.50.20241213-git
Copyright (C) 2024 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
Type "show copying" and "show warranty" for details.
This GDB was configured as "--host=x86_64-pc-linux-gnu --target=riscv64-unknown-linux-gnu".
Type "show configuration" for configuration details.
For bug reporting instructions, please see:
<https://www.gnu.org/software/gdb/bugs/>.
Find the GDB manual and other documentation resources online at:
    <http://www.gnu.org/software/gdb/documentation/>.

For help, type "help".
Type "apropos word" to search for commands related to "word".
Remote debugging using :1234
Reading /work/pixman/build/test/stress-test from remote target...
warning: File transfers from remote targets can be slow. Use "set sysroot" to access files locally instead.
Reading /work/pixman/build/test/stress-test from remote target...
Reading symbols from target:/work/pixman/build/test/stress-test...
Reading /lib/ld-linux-riscv64-lp64d.so.1 from remote target...
Reading /lib/ld-linux-riscv64-lp64d.so.1 from remote target...
Reading symbols from target:/lib/ld-linux-riscv64-lp64d.so.1...
(No debugging symbols found in target:/lib/ld-linux-riscv64-lp64d.so.1)
0x00007dde703e9898 in ?? () from target:/lib/ld-linux-riscv64-lp64d.so.1
(gdb) b rvv_combine_add_ca_float
Function "rvv_combine_add_ca_float" not defined.
Make breakpoint pending on future shared library load? (y or [n]) y
Breakpoint 1 (rvv_combine_add_ca_float) pending.
(gdb) c
Continuing.
Reading /work/pixman/build/test/../pixman/libpixman-1.so.0 from remote target...
Reading /lib/riscv64-linux-gnu/libpng16.so.16 from remote target...
Reading /lib/riscv64-linux-gnu/libm.so.6 from remote target...
Error while mapping shared library sections:
`target:/lib/riscv64-linux-gnu/libm.so.6': not in executable format: file format not recognized
Reading /lib/riscv64-linux-gnu/libgomp.so.1 from remote target...
Error while mapping shared library sections:
`target:/lib/riscv64-linux-gnu/libgomp.so.1': not in executable format: file format not recognized
Reading /lib/riscv64-linux-gnu/libc.so.6 from remote target...
Error while mapping shared library sections:
`target:/lib/riscv64-linux-gnu/libc.so.6': not in executable format: file format not recognized
Reading /lib/riscv64-linux-gnu/libz.so.1 from remote target...
Error while mapping shared library sections:
`target:/lib/riscv64-linux-gnu/libz.so.1': not in executable format: file format not recognized
...
[New Thread 8.150]
[Switching to Thread 8.122]

Thread 2 hit Breakpoint 1, rvv_combine_add_ca_float (imp=0x7dde70005b90, op=PIXMAN_OP_ADD, dest=0x7dde587f1550, src=0x7dde587f1370, mask=0x7dde587f1460, n_pixels=15)
    at ../pixman/pixman-rvv.c:782
782     RVV_MAKE_PD_COMBINERS (add, ONE, ONE)
(gdb) disassemble
Dump of assembler code for function rvv_combine_add_ca_float:
=> 0x00007dde703bba0e <+0>:     beqz    a5,0x7dde703bbaa0 <rvv_combine_add_ca_float+146>
   0x00007dde703bba10 <+2>:     slliw   a5,a5,0x2
   0x00007dde703bba14 <+6>:     beqz    a4,0x7dde703bbaa2 <rvv_combine_add_ca_float+148>
   0x00007dde703bba16 <+8>:     blez    a5,0x7dde703bbaa0 <rvv_combine_add_ca_float+146>
   0x00007dde703bba1a <+12>:    auipc   a1,0x8
   0x00007dde703bba1e <+16>:    flw     fa5,1858(a1) # 0x7dde703c415c
   0x00007dde703bba22 <+20>:    sraiw   a1,a5,0x2
   0x00007dde703bba26 <+24>:    vsetvli a1,a1,e32,m1,ta,ma
   0x00007dde703bba2a <+28>:    vlseg4e32.v     v8,(a3)
   0x00007dde703bba2e <+32>:    vlseg4e32.v     v16,(a4)
   0x00007dde703bba32 <+36>:    vlseg4e32.v     v4,(a2)
   0x00007dde703bba36 <+40>:    vfmv.v.f        v1,fa5
   0x00007dde703bba3a <+44>:    slliw   a0,a1,0x2
--Type <RET> for more, q to quit, c to continue without paging--q
Quit
(gdb) register vector
Undefined command: "register".  Try "help".
(gdb) info vector
v0             {q = {0xff, 0x0}, l = {0xff, 0x0, 0x0, 0x0}, w = {0xff, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0}, s = {0xff, 0x0 <repeats 15 times>}, b = {0xff, 0x0 <repeats 31 times>}}
v1             {q = {0x3f26a6a73f26a6a73f26a6a73f27a7a8, 0x3f27a7a83f27a7a83f27a7a83f27a7a8}, l = {0x3f26a6a73f27a7a8, 0x3f26a6a73f26a6a7, 0x3f27a7a83f27a7a8, 0x3f27a7a83f27a7a8}, w = {0x3f27a7a8, 0x3f26a6a7, 0x3f26a6a7, 0x3f26a6a7, 0x3f27a7a8, 0x3f27a7a8, 0x3f27a7a8, 0x3f27a7a8}, s = {0xa7a8, 0x3f27, 0xa6a7, 0x3f26, 0xa6a7, 0x3f26, 0xa6a7, 0x3f26, 0xa7a8, 0x3f27, 0xa7a8, 0x3f27, 0xa7a8, 0x3f27, 0xa7a8, 0x3f27}, b = {0xa8, 0xa7, 0x27, 0x3f, 0xa7, 0xa6, 0x26, 0x3f, 0xa7, 0xa6, 0x26, 0x3f, 0xa7, 0xa6, 0x26, 0x3f, 0xa8, 0xa7, 0x27, 0x3f, 0xa8, 0xa7, 0x27, 0x3f, 0xa8, 0xa7, 0x27, 0x3f, 0xa8, 0xa7, 0x27, 0x3f}}
--Type <RET> for more, q to quit, c to continue without paging--q
Quit
(gdb) q
A debugging session is active.

        Inferior 1 [process 8] will be killed.

Quit anyway? (y or n) y
$ fg
Send job 1 (target-gdb-rvv test/stress-test &) to foreground
qemu-riscv64-static: QEMU: Terminated via GDBstub
```
