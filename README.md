# Docker environment for RISC-V RVV development

In this repository, you can find a Docker environment set up for RISC-V Vector
(RVV) development.

The main function is ability to debug RVV code with vector register dump
capability, which at the moment (GCC 15.2) is not supported for local
development (only for remote targets, supporting `org.gnu.gdb.riscv.vector`
feature like QEMU).

In addition, it has a recent build of the [RISC-V toolchain][toolchain] with
some (optional) RISC-V-related patches to GDB.

There are two variants of the Docker image:

- `upstream` - base image with all the tools in upstream versions.
- `patched` - same as above but with a patched GDB.

[toolchain]: https://github.com/riscv-collab/riscv-gnu-toolchain

## Quick start

### Quick-quick start

This guide assumes that you are running Ubuntu 24.04 with upstream Docker.

Copy and run the [Pixman example script][example] to prepare environment, build
Pixman, and create a GDB debug session. The expected output can be found in [the
log][example-log].

[example]: example/pixman.sh
[example-log]: example/pixman.log

### Step-by-step start

1. First, you need to have Docker installed. Please follow the guide in the
   [Docker documentation][docker-install]. To ensure you have the recent-enough
   version check if the following command has a similar result:
   ```console
   $ docker version
   Client: Docker Engine - Community
   Version:           27.1.1
   API version:       1.46
   Go version:        go1.21.12
   Git commit:        6312585
   Built:             Tue Jul 23 19:57:01 2024
   OS/Arch:           linux/amd64
   Context:           default

   Server: Docker Engine - Community
   Engine:
   Version:          27.1.1
   API version:      1.46 (minimum version 1.24)
   Go version:       go1.21.12
   Git commit:       cc13f95
   Built:            Tue Jul 23 19:57:01 2024
   OS/Arch:          linux/amd64
   Experimental:     true
   containerd:
   Version:          1.7.19
   GitCommit:        2bf793ef6dc9a18e00cb12efb64355c2c9d5eb41
   runc:
   Version:          1.7.19
   GitCommit:        v1.1.13-0-g58aa920
   docker-init:
   Version:          0.19.0
   GitCommit:        de40ad0
   ```
2. Clone the `rvv-env` repository: `git clone
   https://gitlab.com/riseproject/rvv-env.git`
3. Pull the image with `./docker-pull.sh`.
4. Source the local environment: `source env.sh`
5. Pull and extract the target image: `target-prepare-rootfs`
6. Follow [Using the environment][usage] section.

[docker-install]: https://docs.docker.com/engine/install/ubuntu/
[usage]: #using-the-environment

## Host requirements

As a prerequisite to work with the Docker image in this repo, you need to
install Docker. The image has been tested only on Linux, but it should be
possible to run it also on Windows with Docker Desktop (not tested).

To install Docker, follow the guide on [Docker's website][docker-guide].

[docker-guide]: https://www.docker.com/get-started/

> **Note**
> Your user needs to be in the `docker` group.
>
> For machines where you log in with AD credentials, you can force-add to a
> local `docker` group by directly editing `/etc/group` file.

> **Warning**
> If you have Docker already installed, ensure that it's a relatively recent
> version supporting BuildKit.

## Get the Docker image

### Get pre-built images from GitLab Docker Registry

The Docker images are built automatically with the GitLab CI and uploaded to the
GitLab Container Registry (`registry.gitlab.com/riseproject/rvv-env`).

The images are tagged with branch name, with an exception for the default
(`main`) branch, which is `latest`. For example, the default image resides under
`registry.gitlab.com/riseproject/rvv-env/patched:latest` (where `:latest` can be
omitted when pulling manually).

You can pull the image with a convenience script:

```console
$ ./docker-pull.sh
```

### Alternative: building the image manually

To build the image you can execute:

```console
$ git clone https://gitlab.com/riseproject/rvv-env.git
$ cd rvv-env
$ ./docker-build.sh
```

By default, the script uses `latest` tag, but it can be changed for some
experimental images with `DOCKER_TAG` env (e.g., `DOCKER_TAG=test`).

## Using the environment

It's advised to add `target` directory to path so that wrapper scripts work
relative to the `target` directory. This can be achieved by sourcing the
`env.sh` file.

```console
$ source env.sh
```

For the following usage examples it's assumed that you sourced the `env.sh`
file.

> **Note**
> All scripts, either for the Docker environment or the target are executed as
> your user. In order to execute a command as root (e.g., to install additional
> packages), you need to become root on the host first, e.g.:
>
> ```console
> $ sudo su
> $ source env.sh
> $ docker-run whoami
>
> ```

### `docker-run` script

To run something in the Docker environment, you can use `docker-run` convenience
script:

```console
$ docker-run <whatever_command_you_want>
```

The `docker-run` script automatically executes the command with your UID inside
the Docker container.

If you're somewhere in the `target` directory, the script will automatically
translate your current working directory.

### Prepare target rootfs – `target-prepare-rootfs`

In order to run RISC-V binaries, a complete target RISC-V rootfs is required. It
can be acquired, e.g., by extracting Docker images build for `linux/riscv64`
platform.

In case of this repository we use the Pixman CI image as the default base. It is
an image based on Debian Sid, with recent versions of GNU and LLVM toolchains,
as well as Meson. In order to download and extract the image to `target`
directory, run:

```console
$ target-prepare-rootfs
Pulling target image from "registry.freedesktop.org/pixman/pixman/pixman:latest-linux-riscv64"...
Getting image source signatures
Copying blob 3ebfb4722c90 done   |
Copying blob 0a8e14782bf7 done   |
Copying blob 62c9949e92de done   |
Copying blob f93855d29a36 done   |
Copying config 9b2d166331 done   |
Writing manifest to image destination
Getting image source signatures
Copying blob 3ebfb4722c90 done   |
Copying blob 0a8e14782bf7 done   |
Copying blob 62c9949e92de done   |
Copying blob f93855d29a36 done   |
Copying config 9b2d166331 done   |
Writing manifest to image destination
Extracting target image...
Done
$ ls target
bin  boot  dev  etc  home  lib  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var  work
$ cat target/etc/os-release
PRETTY_NAME="Debian GNU/Linux trixie/sid"
NAME="Debian GNU/Linux"
VERSION_CODENAME=trixie
ID=debian
HOME_URL="https://www.debian.org/"
SUPPORT_URL="https://www.debian.org/support"
BUG_REPORT_URL="https://bugs.debian.org/"
```

If you wish to use other target Docker image supply its name as an argument to
`target-prepare-rootfs`.

### Execution in the target environment – `target-run(-rvv)`

`target-run` and `target-run-rvv` are wrapper scripts allowing you to run a
command in the target environment. The only difference between the two commands
is that `target-run` has the RVV extension disabled, whereas `target-run-rvv`
enabled (with option to change the VLEN).

If you're somewhere within the `target` directory, it automatically translates
the working directory, for example:

```console
$ cd target/bin
$ target-run ./uname -a
Linux bf53e4442e98 5.15.0-117-generic #127-Ubuntu SMP Fri Jul 5 20:13:28 UTC 2024 riscv64 GNU/Linux
```

`target-run` uses a `proot` environment with `qemu-riscv64` wrapper to run the
command, so there is no need to have privileged container nor QEMU registered by
`binfmt` on the host.

For `target-run-rvv`, the QEMU wrapper emulates a RISC-V processor with enabled
RVV extension and `VLEN=256`. If you want to change the VLEN set it as
`RVV_VLEN` environment variable.

### Running GDB in the target environment – `target-gdb(-rvv)`

`target-gdb` is a wrapper script instrumenting GDB execution on the virtual
target. Distinction between `target-gdb` and `target-gdb-rvv` is the same as for
`target-run(-rvv)` script.

Example:

```console
$ cd target/work/pixman/build
$ target-gdb-rvv test/stress-test
GNU gdb (GDB) 15.1
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
Type "apropos word" to search for commands related to "word"...
: No such file or directory.
Remote debugging using :1234
Reading symbols from /target/work/pixman/build/test/stress-test...
Reading symbols from /target/lib/ld-linux-riscv64-lp64d.so.1...
(No debugging symbols found in /target/lib/ld-linux-riscv64-lp64d.so.1)
warning: BFD: warning: system-supplied DSO at 0x7fd438097000 has a corrupt string table index
0x00007fd4380a7898 in ?? () from /target/lib/ld-linux-riscv64-lp64d.so.1
(gdb) b rvv_combine_add_ca_float
Breakpoint 1 at 0x55555556c338: file ../pixman/pixman-rvv.c, line 467.
(gdb) c
Continuing.
...
[Switching to Thread 32.55]

Thread 2 hit Breakpoint 1, rvv_combine_add_ca_float (imp=0x5555555c2b90, op=PIXMAN_OP_ADD, dest=0x2aaab1d4e510, src=0x2aaab1d4e370, mask=0x2aaab1d4e440, n_pixels=13)
    at ../pixman/pixman-rvv.c:782
782     RVV_MAKE_PD_COMBINERS (add, ONE, ONE)
(gdb) info vector
v0             {q = {0x0, 0x0}, l = {0x0, 0x0, 0x0, 0x0}, w = {0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0}, s = {0x0 <repeats 16 times>}, b = {0x0 <repeats 32 times>}}
v1             {q = {0x3f8000003f8000003f8000003f800000, 0x3f8000003f8000003f8000003f800000}, l = {0x3f8000003f800000, 0x3f8000003f800000, 0x3f8000003f800000, 0x3f8000003f800000}, w = {0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000, 0x3f800000}, s = {0x0, 0x3f80, 0x0, 0x3f80, 0x0, 0x3f80, 0x0, 0x3f80, 0x0, 0x3f80, 0x0, 0x3f80, 0x0, 0x3f80, 0x0, 0x3f80}, b = {0x0, 0x0, 0x80, 0x3f, 0x0, 0x0, 0x80, 0x3f, 0x0, 0x0, 0x80, 0x3f, 0x0, 0x0, 0x80, 0x3f, 0x0, 0x0, 0x80, 0x3f, 0x0, 0x0, 0x80, 0x3f, 0x0, 0x0, 0x80, 0x3f, 0x0, 0x0, 0x80, 0x3f}}
...
(gdb) disassemble
Dump of assembler code for function rvv_combine_add_ca_float:
=> 0x000055555556c338 <+0>:     beqz    a5,0x55555556c3ca <rvv_combine_add_ca_float+146>
   0x000055555556c33a <+2>:     slliw   a5,a5,0x2
   0x000055555556c33e <+6>:     beqz    a4,0x55555556c3cc <rvv_combine_add_ca_float+148>
   0x000055555556c340 <+8>:     blez    a5,0x55555556c3ca <rvv_combine_add_ca_float+146>
   0x000055555556c344 <+12>:    auipc   a1,0x3c
   0x000055555556c348 <+16>:    flw     fa5,-476(a1) # 0x5555555a8168
   0x000055555556c34c <+20>:    sraiw   a1,a5,0x2
   0x000055555556c350 <+24>:    vsetvli a1,a1,e32,m1,ta,ma
   0x000055555556c354 <+28>:    vlseg4e32.v     v8,(a3)
   0x000055555556c358 <+32>:    vlseg4e32.v     v16,(a4)
   0x000055555556c35c <+36>:    vlseg4e32.v     v4,(a2)
   0x000055555556c360 <+40>:    vfmv.v.f        v1,fa5
(gdb)
```
