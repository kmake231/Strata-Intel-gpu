# Strata with pictures on an Intel Arc A750

This is one path for one computer: Ubuntu 24.04, 30 GB of RAM, and an Intel Arc A750 (8 GB). It installs Qwen3.8-Flash-Next **Gyro-S** from a source checkout and starts it with pictures on.

The `curl` installer and `strata launch` do not do this. They install the released Intel package, and that package has no picture reader. `strata launch --vision on` leaves pictures off. Pictures need the source engine in Docker and `strata-vision`, which `./setup.sh --backend sycl` compiles. Do not install the Terminal first and then switch. Follow this page from the top.

Strata’s own page for the source build is [Intel Arc from source](https://github.com/Niko1221/Strata/blob/main/docs/INTEL.md). Do not put an API key, a tunnel address, a home-folder path, or a disk label into a public copy of this note.

On an 8 GB Arc the picture reader runs on the CPU. A maintainer measurement on an A750, with a different model size, was about 1.7 seconds per picture. This PC has not timed a picture. The two chats below are text.

## This computer

| Item | Value |
| --- | --- |
| System | Ubuntu 24.04.4 LTS, x86-64 |
| Machine | Intel NUC 11 |
| CPU | Intel Core i7-11700B, 8 cores / 16 threads, AVX-512 |
| RAM | 30 GB, plus 8 GB swap |
| Graphics | Intel UHD (built in) and Intel Arc A750, 8 GB |
| System disk | NVMe, about 195 GB for the system. The Docker image needs about 13 GB free here |
| Model disk | 2 TB SATA SSD, NTFS. Gyro-S is about 54 GB, the picture file about 0.9 GB, the draft layer about 5.2 GB |
| What is serving | The source engine `build-sycl/strata`, with `strata-vision`, images on, context 32K |

Gyro-S is the Qwen3.8-Flash-Next size that fits this RAM. DeepSeek V4.1-Flash and Qwen3.6 do not run on Intel Arc. The full ISTA-DASLab Flash-Next sizes need more RAM than this machine has.

## Where the files go

The model stays on the 2 TB disk. The source checkout can stay on the system disk. Pick the live mount of the 2 TB disk, not an empty folder of the same name on the system disk:

```sh
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
findmnt -no SOURCE,FSTYPE,TARGET /media/$USER
```

On this machine the real disk’s mount name ended in `1`, because an empty folder with the old name already existed on the system disk. Use the path `findmnt` shows on the 2 TB device.

```sh
export MODEL_DIR="/media/$USER/YOUR-SSD-MOUNT/aimodels"
mkdir -p "$MODEL_DIR/gyro-s"
```

## 1. Let your user open the Arc card

```sh
sudo apt-get update
sudo apt-get install -y intel-opencl-icd libze1 libze-intel-gpu1
sudo usermod -aG render "$USER"
```

Log out of the desktop and back in. A new terminal is not enough. `id` must list `render`.

Ubuntu 24.04’s own Level Zero is too old for this engine. The first Terminal start on this PC died in `libze_loader.so.1.16.0`. Replace it before building:

```sh
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:kobuk-team/intel-graphics
sudo apt-get install -y libze-intel-gpu1 libze1 intel-opencl-icd clinfo
clinfo | grep "Device Name"
```

On this PC that moved Level Zero to 1.34.0 and the compute runtime to 26.40. `clinfo` then listed `Intel(R) Arc(TM) A750 Graphics` and `Intel(R) UHD Graphics`. The A750 name can appear more than once. No reboot was required. Apt may warn while it replaces `libigc1`. Leave leftover compiler packages alone. Do not run `apt autoremove` for them.

A C++ compiler is needed later, when setup compiles the picture reader:

```sh
sudo apt-get install -y build-essential git
```

## 2. Get the source checkout

```sh
git clone https://github.com/Niko1221/Strata.git
cd Strata
```

Stay in this folder for every later command. This is not `~/.local/share/strata`. The `curl` installer is a different copy, and it cannot read pictures on this card.

## 3. Install Docker

```sh
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Log out and back in, or, in the terminal you already have:

```sh
newgrp docker
docker ps
```

An empty table, and no password prompt, means this terminal may use Docker. `newgrp` applies only to that terminal.

## 4. Download Gyro-S onto the large SSD

One file, 58,487,015,808 bytes. The address is the revision Strata pins:

```sh
curl -L --continue-at - \
  -o "$MODEL_DIR/gyro-s/Qwen3.8-Flash-Next-Gyro-S-TQ1_0.gguf" \
  https://huggingface.co/agentionai/Qwen3.8-Flash-Next-Gyro-GGUF/resolve/1ada08422e404aca51ab9df665f089f34c419c6b/Qwen3.8-Flash-Next-Gyro-S-TQ1_0.gguf
stat -c '%s' "$MODEL_DIR/gyro-s/Qwen3.8-Flash-Next-Gyro-S-TQ1_0.gguf"
```

`58487015808` is the complete file. `--continue-at -` resumes a stopped download. If the 2 TB disk is not mounted, this write lands in an empty folder on the system disk and fails or fills that disk. Check `findmnt` first.

## 5. Build the compiler image

From the checkout, in the terminal where `docker ps` worked:

```sh
docker build --pull -t strata-sycl-dev sycl/tools
```

`--pull` fetches the current base image. The download is about 13 GB and goes on the system disk. On this PC it ended with `Successfully tagged strata-sycl-dev:latest`.

Two lines are normal. Docker says the legacy builder is deprecated. Inside the image, `rsync` prints `policy-rc.d denied execution of start`. The image is the compiler. It is not the engine.

## 6. Build the A750 engine

An A750 is an Alchemist card. Leave `AOT` unset. Battlemage cards use an `AOT=` value. This PC must not.

The quoted last line is part of the command. Pressing Enter before it makes bash say `option requires an argument`, and nothing is built.

```sh
H=$(basename "$PWD")
docker run --rm -u $(id -u):$(id -g) -v "$PWD/..:/work" -e REPO=/work/$H \
  -e BUILD_DIR=/work/$H/build-sycl strata-sycl-dev \
  "cd /work/$H && bash sycl/tools/build.sh strata"
```

Wait for:

```text
BUILD EXIT 0
errors: 0
```

The binary is `build-sycl/strata` in the checkout. On this PC that was step 137 of 137. `ccache not found` and `no python3 with numpy found` are warnings. The compile still succeeded.

## 7. Let the container see the checkout and the model disk

The engine runs in a container. The container sees one folder of this PC, mounted at `/work`. By default that folder is the parent of the checkout, and the script enters `/work/Strata`.

The Gyro files on this PC are on another disk, so they are outside that parent. A symlink does not work inside the container. Set the mount to `/`, the one folder that contains both the checkout and the model disk:

```sh
export STRATA_SYCL_ROOT=/
```

Upstream’s `sycl/serve/strata-sycl.sh` then tries `cd /work/Strata` and exits, because the checkout is not a direct child of `/`. Before the first start, change the three lines that set `repo_in` to this:

```sh
rel=${here#"$root"}
rel=${rel#/}
repo_in=/work/$rel
```

This checkout already has that change. A fresh `git clone` does not, until you edit the script. A model folder that already sits inside the checkout’s parent does not need `STRATA_SYCL_ROOT` or this edit.

## 8. Compile the picture reader and write the start script

Pictures stay on when the command does not pass `--vision off`. Setup compiles `strata-vision` on the PC and downloads `mmproj-Qwen3.8-Flash-Next-BF16.gguf`, about 0.9 GB. Do not run `python3 sycl/setup_intel.py`. Ubuntu’s system Python refuses it.

```sh
./setup.sh --backend sycl --family gyro --model Gyro-S \
  --gguf-dir "$MODEL_DIR/gyro-s" \
  --data-dir "$MODEL_DIR" \
  --context 32768
```

When it asks `KV cache? [1]`, press Enter. That is 8-bit. Above 8K context, 4-bit is the long-document option. This PC is at 32K.

Setup then hashes the Gyro file, downloads the picture file, prepares the pack, and downloads the draft layer, about 5.2 GB. It writes `engine-sycl/strata-vision` and `run-gyro-gyro-s.sh` in the checkout.

It also prints `1024 GB of RAM` and writes `--ple-io ram`. That number is not this PC. This PC has 30 GB. Docker is allowed to lock the whole n-gram table, about 27 GB, and the kernel then kills the engine. Exit 137 is that kill. Before the first start, open `strata-gyro-gyro-s.json` in the checkout and delete both copies of these two lines:

```text
"--ple-io",
"ram",
```

One copy is in `args`. The other is in `args_written`. The table then stays on the SSD. Leave `--vision` in the file.

`--vision gpu` is a second program and needs Intel’s oneAPI compilers on the PC. An 8 GB card is not the one setup uses for it. Leave that flag off.

## 9. Start it

Close other heavy programs. Gyro-S still puts about 24 GB of experts in RAM.

```sh
./run-gyro-gyro-s.sh
```

Leave that terminal open. Closing it stops the model. On this PC the ready line was:

```text
ready: http://127.0.0.1:8080/v1  (OpenAI: /v1/chat/completions, Anthropic: /v1/messages, context 32768 tokens, images on)
```

Experts loaded 24.02 GiB in about 63 seconds, at 0.48 GiB/s. The card cached 1,799 experts, 1.76 GiB of video memory. The log said drafting was off, so the speeds below do not include the draft layer.

Two text chats on this PC, after that start:

| Chat | Result |
| --- | --- |
| 262 tokens, 37 s | 9.4 tokens/s, expert cache 61.7% hit |
| 434 tokens, 49 s | 10.6 tokens/s, expert cache 56.5% hit |

Open `http://127.0.0.1:8080/` in a browser on this PC and attach a picture there. That address is this computer only. A phone on the same Wi-Fi is step 10. Cursor is steps 11 and 12.

`strata launch --access lan` and `strata launch --access cloudflare` start the released package. That package has pictures off. The picture server is `./run-gyro-gyro-s.sh`. Sharing it means two lines in `strata-gyro-gyro-s.json`, then the same start script again.

## 10. Let another device on the same network use it

This step is optional. Skip it if the page on this PC is enough.

Stop the server first. Closing the terminal that is running `./run-gyro-gyro-s.sh` stops it. In `strata-gyro-gyro-s.json`, next to `"port"`, add:

```json
"host": "0.0.0.0",
"api_key": "choose-a-long-secret"
```

Pick the secret yourself. Do not publish it, and do not put the printed network address in a public copy of this note. The run script does not take `--host`. The server reads these two lines from the JSON. `./setup.sh` already finished, so do not run it again for this. A second setup can write `--ple-io ram` back, and step 8 then has to be done again.

Start it the same way:

```sh
./run-gyro-gyro-s.sh
```

The log prints this PC’s addresses as well as `127.0.0.1`. On the other device:

| Client | Address |
| --- | --- |
| The web page, and OpenAI-compatible apps | `http://<the-printed-lan-address>:8080/v1` |
| The web page in a browser | `http://<the-printed-lan-address>:8080` |
| Anthropic-compatible apps | `http://<the-printed-lan-address>:8080` (no `/v1` at the end) |

The key is a bearer token (`Authorization: Bearer <the-secret-from-the-json>`). With a key set, `/v1/models` without the key returns `401`.

This picture server was only opened on this PC. The phone check in the other note was the Terminal server, which has pictures off. That Terminal server needed no extra firewall rule. If a phone cannot open this one, allow TCP port 8080 from the local network only.

## 11. A public address, when Cursor needs one

Cursor’s base URL has to be a public address. `127.0.0.1` and a LAN address such as `192.168.x.x` or `10.x.x.x` are private. Cursor’s servers call that URL from the internet and answer `403` with `Access to private networks is forbidden`.

Skip this step if this PC already has a public IP you can put in Cursor, or if you only want the web page on your own Wi-Fi. A typical home PC has no public IP. Cloudflare is the way to get a public address when you do not have one. It is not a required part of Strata, and `./setup.sh` does not start a tunnel.

The picture server stays on `127.0.0.1` for the tunnel. Set `"api_key"` as in step 10 before you open it. `"host"` can stay off when you do not want the Wi-Fi page. Restart `./run-gyro-gyro-s.sh` after the JSON change, and leave that terminal open.

Strata does not download the tunnel program. A new computer does not have it. Check:

```sh
cloudflared --version
```

If the shell says the command is missing, install it. No Cloudflare account is required for a quick tunnel. On Ubuntu:

```sh
curl -fsSL -o /tmp/cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i /tmp/cloudflared.deb
cloudflared --version
```

On Windows the install is `winget install --id Cloudflare.cloudflared`. On a Mac it is `brew install cloudflared`.

In a second terminal, leave this running:

```sh
cloudflared tunnel --url http://127.0.0.1:8080
```

`cloudflared` prints an `https://….trycloudflare.com` address. That name is different every time you start a quick tunnel. Copy it from your own terminal. Do not publish it. Closing this terminal closes the public address. Closing the model terminal stops the model.

Check it from any network:

```sh
curl -fsS https://<the-printed-name>.trycloudflare.com/health
```

`/health` should say `"status": "ok"`. `/v1/models` without the key should return `401`.

The browser page through that name needs the printed address in the same JSON, then another restart:

```json
"trusted_origins": ["https://<the-printed-name>.trycloudflare.com"]
```

The name changes on the next tunnel, so that line changes with it. Cursor calls the API with the key and does not need this line.

This picture server was not opened through a tunnel. The earlier tunnel on this PC belonged to the Terminal server, and that tunnel stopped when that server stopped.

## 12. Use it from Cursor

In Cursor, open **Settings → Models**:

1. Choose **Add Custom Model** and enter this name exactly: `qwen3.8-flash-next-gyro-gyro-s`
2. Turn that model on. Leave the other model switches off while you are testing this one.
3. Under **OpenAI API Key**, paste the secret from `"api_key"` in `strata-gyro-gyro-s.json`. `strata launch --show-key` prints the Terminal key, which is a different server.
4. Turn **Use OpenAI API Key** on. A saved key with the switch off is not enough. Cursor then reports `Model name is not valid`.
5. Turn **Override OpenAI Base URL** on.
6. Set **Base URL** to a public address that ends in `/v1`. With the tunnel from step 11, that is `https://<the-printed-name>.trycloudflare.com/v1`. If this PC already has a public IP, use that instead, still ending in `/v1`. A private address gets HTTP 403.

Open a new chat, choose `qwen3.8-flash-next-gyro-gyro-s` in the model menu, and send `reply with the word ready`. The first reply can take a while on this Arc card.

Turn **Override OpenAI Base URL** off when you want Cursor’s own models again. The override sends those requests to Strata as well.

On this PC that short reply was checked against the Terminal server, after its own tunnel. It has not been checked against this picture server. It does not show how a long coding task or a tool call will behave. While no `"api_key"` is set, this source server accepts any key on this computer. After step 10 or 11, Cursor has to send the secret from the JSON.

## What is in place now

- The user can open the Arc device, and Level Zero is 1.34.0. `clinfo` sees the A750.
- The source checkout has `build-sycl/strata` and `engine-sycl/strata-vision`.
- Gyro-S, the picture file, the pack, and the draft layer are on the 2 TB disk.
- `run-gyro-gyro-s.sh` is in the checkout. The n-gram table is left on the SSD.
- The server answered on this PC with images on. Two text chats wrote at 9.4 and 10.6 tokens/s. A picture has not been timed on this PC.
- LAN and a Cloudflare tunnel are steps 10 and 11. They were not started for this picture server. The phone and the Cursor reply on this PC were the Terminal server.

## Problems

### `id` has no `render` group

`sudo usermod -aG render "$USER"`, then log out and back in. A new terminal in the old session is not enough.

### `docker ps` says permission denied, or the socket does not exist

Permission denied means this login is not in the `docker` group yet. Log out and back in, or run `newgrp docker` in that terminal. A missing socket means the service is stopped: `sudo systemctl enable --now docker`.

### The engine build says `option requires an argument`

The `docker run` command was sent before the quoted `build.sh` line. Run the whole command, including the line in quotes.

### The model folder is empty, or setup says the path is outside the container

The 2 TB disk was not mounted, or `$MODEL_DIR` is the empty folder on the system disk. Mount the disk, set `$MODEL_DIR` from `findmnt`, and export `STRATA_SYCL_ROOT=/` when the model disk is not inside the checkout’s parent.

### `cd: /work/Strata: No such file or directory`

`STRATA_SYCL_ROOT=/` is in use, and `sycl/serve/strata-sycl.sh` still enters only `/work/Strata`. Apply the three-line change in step 7, then run `./run-gyro-gyro-s.sh` again.

### Exit code 137 while the log says the n-gram table was locked

`--ple-io ram` locked about 27 GB on a 30 GB PC. Remove that flag from `strata-gyro-gyro-s.json`, as in step 8, and start again.

### `strata launch --vision on` still says there is no picture reader

That command is the released package. The picture server from this page is `./run-gyro-gyro-s.sh`.

### `strata launch --access lan` or `--access cloudflare` comes up with pictures off

Those flags start the released package. For this page, `"host"` and `"api_key"` go in `strata-gyro-gyro-s.json`, and the public address is `cloudflared tunnel --url http://127.0.0.1:8080` in a second terminal.
