# Strata on an Intel NUC 11 with an Arc A750

This is a setup log for one computer: Ubuntu 24.04, 30 GB of RAM, and an Intel Arc A750 (8 GB). It uses the Strata Terminal, release 0.2.13, and the Qwen3.8-Flash-Next **Gyro-S** file. The model stays on a separate 2 TB SATA SSD.

The server is up. Gyro-S answers on this computer at `http://127.0.0.1:8080`, and on the local network at the address Strata prints. A phone on the same Wi-Fi opened the web page. The start reused the first saved settings, including the n-gram table in RAM, so only about 2 GB of the 30 GB stays free while it runs.

Strata’s own pages are the source for the product: [install](https://github.com/Niko1221/Strata/blob/main/docs/INSTALL.md), [Intel Arc](https://github.com/Niko1221/Strata/blob/main/docs/INTEL_ARC.md), and [which model fits](https://github.com/Niko1221/Strata/blob/main/docs/MODELS.md). This note only records what this machine needed.

## This computer

| Item | Value |
| --- | --- |
| System | Ubuntu 24.04.4 LTS, x86-64 |
| Machine | Intel NUC 11 |
| CPU | Intel Core i7-11700B, 8 cores / 16 threads, AVX-512 |
| RAM | 30 GB, plus 8 GB swap |
| Graphics | Intel UHD (built in) and Intel Arc A750, 8 GB |
| System disk | NVMe, about 195 GB for the system, about 42 GB free |
| Model disk | 2 TB SATA SSD, NTFS, about 930 GB free |
| Strata | Terminal 0.2.13.1, engine 0.1.59, Linux SYCL package |

The desktop app has no Intel engine. Use the Terminal.

On this amount of memory, Gyro-S is the Qwen3.8-Flash-Next size that fits. Its expert weights need about 26 GB of RAM. DeepSeek V4.1-Flash and Qwen3.6-35B-A3B are for NVIDIA and AMD cards. The full ISTA-DASLab Flash-Next sizes need more RAM than this machine has.

Published speeds of about 30 tokens/s, or prompt speeds near 900 tokens/s, come from an NVIDIA 8 GB laptop. On an Arc A750 the card holds a few hundred experts and the CPU does the rest. A maintainer measurement on an A750 was about 16 tokens/s writing, on a different CPU with 62 GB of RAM. Treat that as a reference, not a promise for this PC.

A phone on the same Wi-Fi uses the local network address. Cursor’s base URL has to be a public address. A typical home PC has no public IP. When you have none, use a Cloudflare quick tunnel (step 10). Steps 10 and 11 are optional and only for Cursor. Do not put an API key, a tunnel address, a home-folder path, or a disk label that identifies you into a public copy of this note.

## Where the files go

Pick the mount point of the 2 TB disk, not a folder of the same name on the system disk:

```sh
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
findmnt -no SOURCE,FSTYPE,TARGET /media/$USER
```

On this machine the real disk came back as a mount whose name ended in `1`, because an empty folder with the old name already existed on the system disk. Use the path that `findmnt` shows on the 2 TB device.

```sh
export MODEL_DIR="/media/$USER/YOUR-SSD-MOUNT/aimodels"
mkdir -p "$MODEL_DIR/gyro-s"
```

The engine itself is small and stays under `~/.local/share/strata`. The 54 GB model and its pack must stay on the large SSD. The system disk does not have room for them.

## 1. Let your user open the Arc card

```sh
sudo apt install intel-opencl-icd libze1 libze-intel-gpu1
sudo usermod -aG render "$USER"
```

Log out of the desktop session and log back in. A new terminal is not enough. Then:

```sh
id
```

The group list must contain `render`.

Ubuntu’s own copies of those packages are too old for this engine. Step 6 replaces them. Installing them here only gets the group and the first libraries in place.

## 2. Install the Terminal

```sh
curl -fsSL --connect-timeout 15 --max-time 120 \
  https://github.com/Niko1221/Strata/releases/latest/download/install.sh \
  -o /tmp/install.sh && sh /tmp/install.sh
```

The installer prints a path like `~/.local/bin/strata`. Add that folder to `~/.bashrc` so every new terminal can find it. The line has to be written into the file. Printing it on screen does nothing:

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

Open a new terminal, then:

```sh
strata --version
strata doctor
```

This machine got `strata 0.2.13.1`. `strata doctor` saying `PROFILE_NOT_SELECTED` is normal before a model is chosen.

## 3. Download Gyro-S onto the large SSD

One file, about 54.4 GiB (58,487,015,808 bytes). The address is the revision Strata pins:

```sh
curl -L --continue-at - \
  -o "$MODEL_DIR/gyro-s/Qwen3.8-Flash-Next-Gyro-S-TQ1_0.gguf" \
  https://huggingface.co/agentionai/Qwen3.8-Flash-Next-Gyro-GGUF/resolve/1ada08422e404aca51ab9df665f089f34c419c6b/Qwen3.8-Flash-Next-Gyro-S-TQ1_0.gguf
```

`--continue-at -` resumes a stopped download. When curl returns to the prompt with `100` and `54.4G` received, check the size:

```sh
stat -c '%s' "$MODEL_DIR/gyro-s/Qwen3.8-Flash-Next-Gyro-S-TQ1_0.gguf"
```

`58487015808` is the complete file.

## 4. Read the plan

This changes nothing:

```sh
strata launch --plan --backend intel --family gyro --model Gyro-S \
  --model-path "$MODEL_DIR/gyro-s" \
  --data-dir "$MODEL_DIR" \
  --context 32k
```

A good plan names Gyro-S, your file, a 32K context, port 8080 on this computer, and the Intel engine. It also says the engine will be downloaded and the pack built from your file. The lines about DFlash2 and pictures are the general defaults. On this Intel engine the first start does not use a draft layer or a picture reader.

## 5. Build the pack, then start

`strata launch` on Terminal 0.1.59.1 did not build the pack for this one-file Gyro model. Build it with the Terminal’s own Python. The version folder matches `strata --version`:

```sh
~/.local/share/strata/terminal/0.1.59.1/python/bin/python3.12 \
  ~/.local/share/strata/terminal/0.1.59.1/setup.py \
  --prepare-pack "$MODEL_DIR/packs/gyro-gyro-s" \
  --gguf-dir "$MODEL_DIR/gyro-s" \
  --family gyro --model Gyro-S
```

Wait until it prints that the model is prepared. That step downloads a small llama.cpp helper once and reads the 54 GB file. It does not download the model again.

Then start the server. Close other heavy programs first. Gyro-S wants about 26 GB of the 30 GB of RAM.

```sh
strata launch --backend intel --family gyro --model Gyro-S \
  --model-path "$MODEL_DIR/gyro-s" \
  --data-dir "$MODEL_DIR" \
  --context 32k --drafting off --vision off --yes --no-tui
```

`--vision off` only hides a warning. This engine package has no picture reader.

## 6. Replace Ubuntu’s old Level Zero library

The first start installed engine `0.1.59` (`linux-x86_64-sycl`, 187 MB) and then crashed. The kernel named `libze_loader.so.1.16.0`, Ubuntu 24.04’s Level Zero from 2024. Intel’s graphics PPA supplies a current stack. This machine installed:

| Package | Version after the upgrade |
| --- | --- |
| libze1 | 1.34.0 |
| libze-intel-gpu1 | 26.40.40196.15 |
| intel-opencl-icd | 26.40.40196.15 |
| libigc2 / libigdfcl2 | 2.42.14 |

```sh
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:kobuk-team/intel-graphics
sudo apt-get install -y libze-intel-gpu1 libze1 intel-opencl-icd clinfo
clinfo | grep "Device Name"
```

Apt may print a dependency note while it removes `libigc1` and unpacks `libigc2`. On this machine that finished cleanly: the new packages were set up, and `clinfo` listed both `Intel(R) Arc(TM) A750 Graphics` and `Intel(R) UHD Graphics`. The A750 name can appear more than once. That is OpenCL and Level Zero each seeing the same card. No reboot was required.

A notice about a Cloudflare apt repo and the `i386` architecture is unrelated. Leave it.

Do not run `apt autoremove` just because apt mentions leftover compiler packages, unless you know you do not need them.

## 7. What the running server actually used

After the graphics upgrade, `strata launch` printed `gyro Gyro-S is already installed with these choices` and started the saved command. It did not write a new one. The engine log shows:

- `--ple-io ram`, so the 26.8 GB n-gram table was read into RAM (about 50 seconds).
- `--vram-reserve-mib 1024`. The card still cached 1,755 experts (about 1.7 GB).
- GPU 0 is the Arc A750. The expert arena is 24.0 GB.
- The engine’s own startup check read 53 tokens at 6.7 tokens/s and wrote 1 token at 1.9 tokens/s. That is one short check during load, not a chat speed.

Strata’s A750 notes prefer a 300 MiB reserve and leaving Gyro’s n-gram table on the SSD. This machine has not been run that way. The process that is serving is the saved command above. A later launch that says “already installed” will keep it. `strata update` can also replace local edits to the Terminal.

The engine log is under `~/.local/state/strata/launch/`. The server log is under `~/.local/state/strata/runtime/`.

While this server is up, about 28 GB of the 30 GB of RAM is in use. Close other heavy programs. To give the memory back, stop the server. Putting the n-gram table back on the SSD means changing the saved command and starting again. That variant is not the one checked here.

## 8. Confirm the server

The launch prompt returned after about two minutes:

```text
The model is loaded and answering.
Ready: http://127.0.0.1:8080
```

Then:

```sh
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/v1/models
```

`/health` returned `"status": "ok"`, `"loaded": true`, `"max_context": 32768`, `"images": false`, and `"api_key": false`. `/v1/models` listed `qwen3.8-flash-next-gyro-gyro-s` as loaded, text in and text out.

| Client | Address |
| --- | --- |
| OpenAI-compatible apps | `http://127.0.0.1:8080/v1` |
| Anthropic-compatible apps | `http://127.0.0.1:8080` (no `/v1` at the end) |

That first check had no API key, because the server answered only on this computer. Step 9 is the later change that shares it on the local network. Stop it with `strata launch --stop`. A finished download is not a running server. `/health` is the check.

## 9. Let another device on the same network use it

`127.0.0.1` is this computer only. To share it with a phone or another PC on the same Wi-Fi, restart with `--access lan`. The model is already loaded, so `--restart` is required. `--yes` alone does not replace a running server. The reload takes about two minutes and keeps the same RAM use.

```sh
strata launch --backend intel --family gyro --model Gyro-S \
  --model-path "$MODEL_DIR/gyro-s" \
  --data-dir "$MODEL_DIR" \
  --context 32k --drafting off --vision off \
  --access lan --restart --yes --no-tui
```

Strata prints two ready addresses: one for this computer, and one for the network. It also creates an API key and shows only a masked value. Read the full key on this computer with `strata launch --show-key`. Do not put the key, or the printed network address, in a public copy of this note.

On the other device:

| Client | Address |
| --- | --- |
| The web page, and OpenAI-compatible apps | `http://<the-printed-lan-address>:8080/v1` |
| The web page in a browser | `http://<the-printed-lan-address>:8080` |
| Anthropic-compatible apps | `http://<the-printed-lan-address>:8080` (no `/v1` at the end) |

The key is a bearer token (`Authorization: Bearer <key>`). On this machine `/health` answers without the key, and `/v1/models` returns `401` until the key is sent. A phone on the same Wi-Fi opened the page. This PC needed no extra firewall rule for that. If another network blocks it, allow TCP port 8080 from the local network only.

## 10. Install Cloudflare’s tunnel program, then open a public address

Cursor’s base URL has to be a public address. `127.0.0.1` and a LAN address such as `192.168.x.x` or `10.x.x.x` are private. Cursor’s servers call that URL from the internet and answer `403` with `Access to private networks is forbidden`.

Skip this step if this PC already has a public IP you can put in Cursor, or if you only want the web page on your own Wi-Fi. This computer had no public IP, so it used Cloudflare. Cloudflare is the way to get a public address when you do not have one. It is not a required part of Strata.

Strata does not download the tunnel program. A new computer does not have it. This PC already had `cloudflared` from other work, which is why the log mentioned another process. Do not expect that line on a new computer.

Check:

```sh
cloudflared --version
```

If the shell says the command is missing, install it. No Cloudflare account is required for the quick tunnel Strata starts. On Ubuntu:

```sh
curl -fsSL -o /tmp/cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i /tmp/cloudflared.deb
cloudflared --version
```

On Windows the install is `winget install --id Cloudflare.cloudflared`. On a Mac it is `brew install cloudflared`. Strata prints the same hint if you start a tunnel before the program is installed.

Then reload the model. This takes about two minutes:

```sh
strata launch --backend intel --family gyro --model Gyro-S \
  --model-path "$MODEL_DIR/gyro-s" \
  --data-dir "$MODEL_DIR" \
  --context 32k --drafting off --vision off \
  --access cloudflare --restart --yes --no-tui
```

When it is ready, the log prints a line like `https://something.trycloudflare.com/v1`. That address is different every time you start a quick tunnel. Copy it from your own terminal. Do not publish it.

Check it from any network:

```sh
curl -fsS https://<the-printed-name>.trycloudflare.com/health
```

`/health` should say `"status": "ok"` and `"api_key": true`. `/v1/models` without the key should return `401`.

The address is on the public internet for as long as this server is running. The API key is what keeps other people out. `strata launch --stop` stops the model and that tunnel. To go back to the Wi-Fi-only server, start again with `--access lan` instead of `--access cloudflare`.

## 11. Use it from Cursor

On this computer a new Cursor chat, with the custom model selected, was asked to reply with the word ready. The answer was `ready`.

In Cursor, open **Settings → Models**:

1. Choose **Add Custom Model** and enter this name exactly: `qwen3.8-flash-next-gyro-gyro-s`
2. Turn that model on. Leave the other model switches off while you are testing this one.
3. Under **OpenAI API Key**, paste the key from `strata launch --show-key`.
4. Turn **Use OpenAI API Key** on. A saved key with the switch off is not enough. Cursor then reports `Model name is not valid`.
5. Turn **Override OpenAI Base URL** on.
6. Set **Base URL** to a public address that ends in `/v1`. On this PC that was the `https://….trycloudflare.com/v1` line from step 10. If you already have a public IP, use that instead, still ending in `/v1`. A private address gets HTTP 403.

Open a new chat, choose `qwen3.8-flash-next-gyro-gyro-s` in the model menu, and send `reply with the word ready`. The first reply can take a while on this Arc card.

Turn **Override OpenAI Base URL** off when you want Cursor’s own models again. The override sends those requests to Strata as well.

The one check on this PC was a short reply. It does not show how a long coding task or a tool call will behave.

## Problems hit on this machine

### `id` has no `render` group

The Arc device nodes are only usable by that group. `sudo usermod -aG render "$USER"`, then log out and back in. Check `id` again before installing models.

### `strata: command not found`

The installer does not always put `~/.local/bin` on `PATH`. Add the `export PATH=...` line to `~/.bashrc`. Do not run `~/.bashrc` as a program, and do not use `sudo` on it. `echo` without `>> ~/.bashrc` only prints the line.

### curl says `Permission denied` on the model folder

The 2 TB disk was not mounted on the path that was typed. That path was an empty root-owned folder on the system disk, created while the SSD was absent. `df` on that path showed the system NVMe, and the folder was mode `755` owned by root.

Find the live mount with `lsblk` and `findmnt`. On this PC the live path’s name ended in `1`. Download to that path. Do not try to store the 54 GB file on the system disk: it only had about 42 GB free.

### Launch says the pack and the tokenizer are missing

The engine install had succeeded. The pack step was skipped. Terminal 0.1.59.1 only builds a pack automatically for shard names like `-00001-of-00002.gguf`. Gyro-S is a single `.gguf`, so the launcher reported a missing pack even though `--model-path` was set.

Build the pack with the `setup.py --prepare-pack` command in step 5, then run `strata launch` again. The engine is already installed, so it is not downloaded twice. Success looks like `model prepared` and a `packs/gyro-gyro-s` folder that contains `index.txt` and `tokenizer/vocab.json`.

### The engine exits in a few seconds with code 1

The server log said `killed by signal 11 (SIGSEGV)`. The engine itself wrote nothing. The kernel line was a fault in `libze_loader.so.1.16.0`.

That is the graphics library, not a bad model file. Replace it from the Intel graphics PPA (step 6) and check `clinfo` before starting again.

### The saved command keeps the n-gram table in RAM

The first launch wrote `--ple-io ram` and `--vram-reserve-mib 1024`. The successful start reused that saved command (`already installed with these choices`). It loaded, and the card cached 1,755 experts. The cost is RAM: the 26.8 GB table plus the 24 GB expert arena leave about 2 GB free on this 30 GB machine.

Strata’s A750 notes for Gyro leave that table on the SSD and use a 300 MiB reserve. This PC has not been restarted with those settings. If a later launch says the model is already installed, it will keep the command that is serving now.

## What is in place now

- The user can open the Arc device (`render`).
- Strata Terminal 0.2.13.1 is installed.
- Gyro-S is on the 2 TB SSD and its byte size matches the published file.
- The pack `packs/gyro-gyro-s` has been built.
- Engine 0.1.59 SYCL is installed.
- Level Zero is 1.34.0 and the compute runtime is 26.40. `clinfo` sees the Arc A750.
- The server is answering on this computer and on the local network. `/health` is `ok`, the model is loaded, the context is 32K, and pictures are off.
- An API key is required for `/v1`. A phone on the same Wi-Fi opened the page.
- Cursor’s chat answered through a Cloudflare quick tunnel after `cloudflared` was installed and **Use OpenAI API Key** was on. The tunnel address and the key stay off this page. A new computer must install `cloudflared` first (step 10).

## Useful CMD

Run these from a terminal where `strata` is on `PATH`. `strata launch --show-key` prints the real key. Do not paste that output into a public note, a chat, or a screenshot.

| Command | What it does |
| --- | --- |
| `strata --version` | Print the Terminal version. |
| `strata doctor` | Check the Terminal. Before a model is chosen it stops at `PROFILE_NOT_SELECTED`. |
| `strata launch --help` | List every launch flag. |
| `strata launch --status` | Show whether a model is serving, and where. |
| `strata launch --show-key` | Print the API key for the running server. |
| `strata launch --stop` | Stop the server and unload the model. |
| `strata logs --follow` | Follow the engine log until you press Ctrl-C. |
| `strata connect` | List app connections (OpenAI-style and Anthropic-style). |
| `strata update --check` | See if a newer Terminal or engine is published. It does not install it. |
| `cloudflared --version` | See if the tunnel program is installed. Strata does not install it. |

Check the server without the key:

```sh
curl -fsS http://127.0.0.1:8080/health
```

Open the monitor on this computer. The key stays in the environment for that one command and is not written into the shell history as a literal value:

```sh
STRATA_API_KEY=$(strata launch --show-key) strata monitor --url http://127.0.0.1:8080 --credential-env STRATA_API_KEY
```

Start again with the same model after a stop. This loads Gyro-S from the SSD, which takes about two minutes:

```sh
strata launch --backend intel --family gyro --model Gyro-S \
  --model-path "$MODEL_DIR/gyro-s" \
  --data-dir "$MODEL_DIR" \
  --context 32k --drafting off --vision off \
  --access lan --yes --no-tui
```

If a server is already running, add `--restart`. That stops the current one first. `--yes` alone does not.
