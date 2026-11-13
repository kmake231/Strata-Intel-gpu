# Pictures on an Intel Arc A750

This note is for the same computer as the Terminal setup: Ubuntu 24.04, 30 GB of RAM, and an Intel Arc A750 (8 GB), running Qwen3.8-Flash-Next **Gyro-S**. The Terminal server answers text only. This page is how to turn pictures on.

The released Intel engine has no picture reader. `strata launch --vision on` leaves pictures off. Pictures need a source build: Docker, an engine compiled in that image, and `./setup.sh --backend sycl`. That setup compiles `strata-vision` and downloads the picture file. It starts its own server. It does not add a reader to the Terminal process.

Strata’s own page for this build is [Intel Arc from source](https://github.com/Niko1221/Strata/blob/main/docs/INTEL.md).

On an 8 GB Arc the reader runs on the CPU. A maintainer measurement on an A750, with a different model size, was about 1.7 seconds per picture. That number is not a measurement of Gyro-S on this PC.

## What you already need

- The user is in the `render` group, and a new login has been done since that change. `id` lists `render`.
- Gyro-S is already on the model disk, and its pack has been built. Call that folder `$MODEL_DIR`. The Gyro file is `$MODEL_DIR/gyro-s`.
- The Strata source checkout is on this PC. The commands below are run from that checkout.
- The Terminal server is stopped before the source server starts. Both want the Arc card and port 8080.

```sh
strata launch --stop
```

`Stopped gyro-s-32k` is the line from this PC. Docker’s image build can run while the Terminal server is still up. `./setup.sh` cannot.

## 1. Install Docker

A new computer does not have Docker. This PC already had Docker 29.1.3, and the service was already running. The account was not in the `docker` group, so `docker ps` returned permission denied.

```sh
sudo apt-get update
sudo apt-get install -y docker.io git
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

`usermod` does not change a login that is already open. Log out of the desktop and back in, then open a new terminal. In the terminal you already have, this is enough for that terminal only:

```sh
newgrp docker
docker ps
```

An empty table means the daemon answered and this account may use it. `docker` must not ask for a password. Other terminals stay without the group until you log out and back in.

`git` is in the same install line because the source checkout needs it. This PC already had the checkout.

## 2. Build the compiler image

From the Strata checkout:

```sh
docker build --pull -t strata-sycl-dev sycl/tools
```

`--pull` fetches the current base image. An old cached copy can carry a device compiler that crashes on some Arc builds. The download is about 13 GB. The system disk needs that much free space. On this PC the image finished with:

```text
Successfully built a54b4071300d
Successfully tagged strata-sycl-dev:latest
```

Two lines in that log are normal. Docker says the legacy builder is deprecated. Inside the image, `rsync` prints `policy-rc.d denied execution of start`. The image is still usable.

This image is the compiler. It is not the engine, and it does not read pictures.

## 3. Build the engine for an A750

An A750 is an Alchemist card. Leave `AOT` unset. Battlemage cards (B580, B70, and the rest) use an `AOT=` value. This PC must not.

Stay in the terminal where `docker ps` worked:

```sh
H=$(basename "$PWD")
docker run --rm -u $(id -u):$(id -g) -v "$PWD/..:/work" -e REPO=/work/$H \
  -e BUILD_DIR=/work/$H/build-sycl strata-sycl-dev \
  "cd /work/$H && bash sycl/tools/build.sh strata"
```

The first lines on this PC configured the build and wrote it to `/work/Strata/build-sycl`. These lines are warnings, not a failed build:

- `ccache not found`
- `no python3 with numpy found` (a test is skipped)
- `The ASM compiler identification is IntelLLVM`

Wait until the log prints `BUILD EXIT 0` and `errors: 0`. The binary is `build-sycl/strata` inside the checkout.

On this PC the first attempt printed `/bin/bash: -c: option requires an argument`. The image’s entry point is bash, and that command stopped before the quoted `build.sh` line, so bash had nothing to run. The next command included the quoted line. It linked `strata` as step 137 of 137 and finished:

```text
BUILD EXIT 0
errors: 0
```

## 4. Keep the model folder inside the folder Docker mounts

The engine runs in a container. The container sees one folder of this PC, mounted at `/work`. By default that folder is the parent of the Strata checkout. A model path outside it makes setup stop:

```text
is outside ... which the SYCL engine's container mounts
```

A symlink to the other disk does not work in the container.

Do this when the model files are on a different disk from the source checkout. Docker’s default mount is only the parent of the checkout, so it cannot see that other disk. A model folder that already sits inside the checkout’s parent skips this step.

Set the mount to a directory that contains both the checkout and `$MODEL_DIR`. On this PC that directory is `/`, the top of the disks:

```sh
export STRATA_SYCL_ROOT=/
```

Setup saves that choice. `$MODEL_DIR` is the models folder you pass as `--data-dir`. It is the folder that holds `gyro-s`, not the picture file. With the mount set to `/`, that folder is visible inside the container. Setup downloads `mmproj-Qwen3.8-Flash-Next-BF16.gguf` into it later and writes the path itself.

One more change belongs with this mount. `sycl/serve/strata-sycl.sh` has to enter the checkout at its real path under `/work`. With `STRATA_SYCL_ROOT=/` that path is not `/work/Strata`. The script in this checkout was changed to use the real path. A fresh copy that still enters `/work/Strata` exits at once with `cd: /work/Strata: No such file or directory`.

## 5. Compile the picture reader and start the source server

Pictures stay on when the command does not pass `--vision off`. On this 8 GB card, setup compiles the CPU reader, `strata-vision`, on the PC. It also downloads `mmproj-Qwen3.8-Flash-Next-BF16.gguf`, about 0.9 GB. The engine itself stays the binary from step 3 and runs inside the image.

The reader compile needs CMake, Ninja, and a C++ compiler on the PC. Setup installs CMake and Ninja into its own `.venv` when they are missing. A missing compiler is fixed with:

```sh
sudo apt-get install -y build-essential
```

From the checkout, in the terminal where `STRATA_SYCL_ROOT` is set:

```sh
./setup.sh --backend sycl --family gyro --model Gyro-S \
  --gguf-dir "$MODEL_DIR/gyro-s" \
  --data-dir "$MODEL_DIR" \
  --context 32768
```

Do not run `python3 sycl/setup_intel.py`. Ubuntu’s system Python refuses it. `./setup.sh` uses its own `.venv`.

Setup asks for the KV cache when the context is above 8K. On this PC, press Enter for 8-bit. It then hashes the Gyro file already on disk, downloads the 0.9 GB picture file, reuses the pack, and downloads the draft layer (about 5.2 GB).

It writes `engine-sycl/strata-vision` and `run-gyro-gyro-s.sh`. On this PC the setup text said the machine had 1024 GB of RAM and wrote `--ple-io ram`. That is wrong: this PC has 30 GB. Remove `--ple-io ram` from `strata-gyro-gyro-s.json` before the first start, or the kernel kills the engine (exit 137) after it locks the n-gram table. With that flag removed, the start on this PC reached:

```text
ready: http://127.0.0.1:8080/v1  (OpenAI: /v1/chat/completions, Anthropic: /v1/messages, context 32768 tokens, images on)
```

Experts loaded 24.02 GiB in about 63 seconds. The card cached 1,799 of them, 1.76 GiB of video memory. Drafting stayed off.

Start it with `./start-strata.sh`. The command returns, and the terminal can close. Progress lines (reading the prompt, thinking, answering) go to `logs/strata-server.log`. Watch them with `./start-strata.sh --follow`. `./start-strata.sh --stop` stops the server. `strata-gyro-gyro-s.log` keeps one finished line per request. `./run-gyro-gyro-s.sh` is the script setup writes, and that one still stops when its terminal closes.

`--vision gpu` compiles a second program, `strata-vision-sycl`, and needs Intel’s oneAPI compilers installed on the PC. An 8 GB Arc is not the card that setup uses for that reader. Leave the flag off.

## 6. Cursor and a public address

Stopping the Terminal server also stops the Cloudflare quick tunnel that `strata launch --access cloudflare` started. The source server does not start a tunnel.

Cursor’s base URL still has to be a public address. `127.0.0.1` and a LAN address get HTTP 403. A PC with no public IP needs a tunnel again, pointed at this source server, before Cursor can call it. Phones on the same Wi-Fi can use the address this server prints.

## Where this PC is

- Docker is installed, the service is running, and this account is in the `docker` group. `docker ps` returned an empty list after `newgrp docker`.
- The image `strata-sycl-dev` is built.
- The A750 engine finished with `BUILD EXIT 0` and `errors: 0`. The binary is `build-sycl/strata`.
- `strata-vision` is compiled. The picture file is on the model disk. The source server is answering at `http://127.0.0.1:8080` with images on, 32K context, and the n-gram table left on the SSD.
- The Terminal server `gyro-s-32k` is stopped. Cursor still needs a public address for this source server. `127.0.0.1` is this computer only.
- The 2 TB disk was unmounted once after the engine build. It was mounted again before `./setup.sh`. The empty `aimodels` folder on the system disk is not the model.

## Problems

### `docker ps` says permission denied

Docker is installed and the service is running, but this login is not in the `docker` group. `sudo usermod -aG docker "$USER"`, then log out and back in. `newgrp docker` fixes only the terminal where you run it.

### `docker ps` says the socket does not exist

The service is not running. `sudo systemctl enable --now docker`, then `docker ps` again.

### The image build warns about the legacy builder

Docker 29 prints that the old builder will be removed later. The build on this PC still ended with `Successfully tagged strata-sycl-dev:latest`.

### Setup says the model path is outside the container mount

`$MODEL_DIR` is not inside the folder mounted at `/work`. Export `STRATA_SYCL_ROOT` to a directory that contains both the checkout and the model folder, then run `./setup.sh` again. On this PC that directory is `/`.

### The model folder is empty

The 2 TB disk can be unplugged from the file manager while the system-disk folder of the same name stays. `lsblk` then shows the 1.8 TB disk with no mount point, and `aimodels/gyro-s` on the system disk is empty. Mount the 2 TB disk again, then set `$MODEL_DIR` from `findmnt`, not from the empty folder.

### The engine exits with code 137 while locking the n-gram table

Setup printed `1024 GB of RAM` and wrote `--ple-io ram`. This PC has 30 GB. Docker is allowed to lock that whole table, about 27 GB, and the kernel then kills `strata`. Exit 137 is that kill. Remove `--ple-io ram` from both argument lists in `strata-gyro-gyro-s.json` and run `./start-strata.sh` again. The table stays on the SSD.

### `cd: /work/Strata: No such file or directory`

`STRATA_SYCL_ROOT=/` mounts the whole disk, and the checkout is not a direct child of `/`. The start script in this checkout was changed to use the checkout’s real path under `/work`. A checkout that does not have that change exits here before the model loads.

### `strata launch --vision on` still says there is no picture reader

That command uses the released Intel package. The reader from this page belongs to the source server. The Terminal package stays text only.
