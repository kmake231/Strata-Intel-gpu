# Connect an agent to Strata on this Intel NUC

This note is for the same computer as the Terminal setup: Ubuntu 24.04, 30 GB of RAM, and an Intel Arc A750 (8 GB), running Qwen3.8-Flash-Next **Gyro-S** at `http://127.0.0.1:8080` with a 32k context.

The chat page on port 8080 is not an agent. It does not browse, and it does not run shell commands. An agent is a separate program. It keeps its own tools and sends the model calls to Strata’s OpenAI-style API at `http://127.0.0.1:8080/v1`. Strata’s own page for the command is [Connect your apps](https://github.com/Niko1221/Strata/blob/main/docs/TERMINAL_LAUNCH.md). This note is what this PC needed.

Start the server first. The agent only talks to a server that is already answering.

## OpenClaw

OpenClaw is the agent to set up first on this PC. Its web page can be opened from a phone on the same Wi-Fi. The copy running here is **2026.11.3**. The Terminal text was checked against OpenClaw 2026.10.4.

### 1. Install Node 24

OpenClaw 2026.11.3 requires Node `>=24.16.0 <25` or `>=26.1.0`.

This PC’s everyday `node` is Linuxbrew **v25.8.0**. That version is outside the range. `npm install -g openclaw` on it does not fail. It installs **2026.6.35**, the newest release that still allows Node 22. Check the version after every install:

```sh
node -v
openclaw --version
```

You want `v24.22.3` (or any 24.16 through 24.x) and `OpenClaw 2026.11.3`.

nvm is already on this machine. Install Node 24.22.3 and put it first on `PATH` for the install:

```sh
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
nvm install 24.22.3
export PATH="$HOME/.nvm/versions/node/v24.22.3/bin:$PATH"
node -v
npm install -g openclaw@2026.11.3 --allow-scripts=openclaw
openclaw --version
```

The npm that ships with that Node has a `#!/usr/bin/env node` first line. If Node 25 is still first on `PATH`, that npm installs into the Linuxbrew tree and the preinstall script refuses 2026.11.3. The `export PATH=...` line above has to come first in the same terminal.

### 2. Keep `openclaw` on Node 24

A later terminal still has Node 25 first, because that is what Linuxbrew puts on `PATH`. A small wrapper in `~/.local/bin` runs the Node 24 copy no matter which `node` comes first. `~/.local/bin` is already on `PATH` from the Terminal install.

```sh
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/openclaw" << 'EOF'
#!/bin/sh
NODE_HOME="$HOME/.nvm/versions/node/v24.22.3"
exec "$NODE_HOME/bin/node" "$NODE_HOME/lib/node_modules/openclaw/openclaw.mjs" "$@"
EOF
chmod +x "$HOME/.local/bin/openclaw"
hash -r
openclaw --version
```

`OpenClaw 2026.11.3` is the line you want, even when `node -v` still prints `v25.8.0`.

### 3. Point OpenClaw at the running server

`strata connect openclaw` writes `~/.openclaw/openclaw.json`. A file it replaces is copied beside it first, with `strata-bak` in the name. The written provider is `strata`, the address is `http://127.0.0.1:8080/v1`, the model id is `strata`, the context window is 32768, `contextTokens` is 23192, and the primary model is `strata/strata`. OpenClaw’s own counter runs about 10–30% above the server, so `contextTokens` is kept under the 32k window on purpose.

**Server started with `strata launch`.** The command can see the address, the key, and the context:

```sh
strata connect openclaw --write --yes --context 32k
strata connect openclaw --check
```

**Server started from this source checkout** (`start-strata.sh` or `sycl/serve/server_intel.py`). `connect` then prints `No running Strata server was found`. With no key of its own it would write the placeholder `strata-local`, and the check fails at once with “The server refused the key.” The real key is `api_key` in `strata-gyro-gyro-s.json` in the checkout. Pass that key and `32k`. Run this from the checkout:

```sh
python3 strata.py connect openclaw --write --yes --context 32k \
  --key "$(python3 -c 'import json; print(json.load(open("strata-gyro-gyro-s.json"))["api_key"])')"

python3 strata.py connect openclaw --check --context 32k \
  --key "$(python3 -c 'import json; print(json.load(open("strata-gyro-gyro-s.json"))["api_key"])')"
```

On this PC the check passed both parts: a prompt that came back `pong` (about 8 s) and a tool call, `get_weather` for Paris (about 10 s). Those two calls are small. A real OpenClaw chat is much larger. That is covered below.

### 4. An OpenClaw that was already installed

This PC already had OpenClaw 2026.3.2, with a user systemd service and an old `~/.openclaw/openclaw.json`. OpenClaw 2026.11.3 will not delete settings retired before July 2026. `openclaw doctor` says so, and tells you to install **2026.9.5**, run doctor, then come back.

Use the same Node 24 `PATH` as the install. If 2026.11.3 has already upgraded the SQLite file, put the pre-update database back before the 2026.9.5 doctor. Doctor prints the backup name.

```sh
export PATH="$HOME/.nvm/versions/node/v24.22.3/bin:$PATH"
npm install -g openclaw@2026.9.5 --allow-scripts=openclaw
openclaw doctor --fix
npm install -g openclaw@2026.11.3 --allow-scripts=openclaw
openclaw doctor --fix --non-interactive --yes
openclaw gateway install --force --port 18789 \
  --runtime-path "$HOME/.nvm/versions/node/v24.22.3/bin/node"
```

Rewrite the wrapper in step 2 after the second install, so `~/.local/bin/openclaw` still points at 2026.11.3.

A fresh install, with no old `~/.openclaw`, skips this step.

### 5. Send one message

The gateway service owns the state folder. While it is running, leave off `--local`. OpenClaw refuses `--local` in that case.

```sh
openclaw agent --agent main --session-id demo --thinking low \
  -m "Reply with the single word pong."
```

### 6. Open the page on a phone

The page is served by the gateway, port **18789**. `gateway.bind` starts as `loopback`, which is only this PC. `lan` listens on every address, including `0.0.0.0`.

```sh
export PATH="$HOME/.nvm/versions/node/v24.22.3/bin:$PATH"
openclaw config set gateway.bind lan
openclaw gateway install --force --port 18789 \
  --runtime-path "$HOME/.nvm/versions/node/v24.22.3/bin/node"
```

On a phone joined to the same Wi-Fi, open `http://<this PC's LAN address>:18789/`. The page asks for the gateway token. Show it on this PC:

```sh
openclaw gateway auth-token --show
```

Anyone on that Wi-Fi who has the token can use the agent. The page can run commands on this PC.

On this PC a phone on the same Wi-Fi opened the page, and a weather question came back from a live lookup.

## OpenCode

OpenCode is the same idea with a smaller prompt. Its system text and tools are about 7.4k tokens. This PC has OpenCode **1.19.5** (`npm i -g opencode-ai`).

Same rule for the key. Use `strata connect` when `strata launch` started the server. Use `python3 strata.py connect` and the key from `strata-gyro-gyro-s.json` when the source server is the one on port 8080.

```sh
strata connect opencode --write --yes --context 32k
strata connect opencode --check
```

```sh
python3 strata.py connect opencode --write --yes --context 32k \
  --key "$(python3 -c 'import json; print(json.load(open("strata-gyro-gyro-s.json"))["api_key"])')"
python3 strata.py connect opencode --check --context 32k \
  --key "$(python3 -c 'import json; print(json.load(open("strata-gyro-gyro-s.json"))["api_key"])')"
```

That writes `~/.config/opencode/opencode.json`. On this PC the check passed the prompt (`pong`, about 15 s) and the Paris weather tool call (about 15 s).

The terminal UI is `opencode`. The web page, on this PC only, is:

```sh
opencode web --hostname 127.0.0.1 --port 4096
```

To open it from a phone on the same Wi-Fi, bind every address and set a password. The username is `opencode` unless `OPENCODE_SERVER_USERNAME` is set.

```sh
OPENCODE_SERVER_PASSWORD='choose-one' opencode web --hostname 0.0.0.0 --port 4096
```

On this PC a weather question in that page got a text reply and no tool call. The request did include tools. The model never emitted a call. Naming the tool worked better: ask it to use the bash tool and run `curl` against `wttr.in`. There is no weather button. A skill is a `SKILL.md` the model is told to follow.

## The other agents

`strata connect` also writes Codex CLI, Claude Code, oh-my-pi (`omp`), pi, Hermes Agent, and the DeepSeek Harness. The names and the one-line install are:

| Name you pass | Install | One message |
| --- | --- | --- |
| `opencode` | `npm i -g opencode-ai` | `opencode run "your task"` |
| `openclaw` | `npm install -g openclaw` on Node 24.16+ | `openclaw agent --agent main --session-id demo --thinking low -m "your task"` |
| `codex` | `npm i -g @openai/codex` | `codex exec --skip-git-repo-check "your task"` |
| `claude-code` | `npm i -g @anthropic-ai/claude-code` | `claude -p "your task"` |
| `omp` | `curl -fsSL https://omp.sh/install \| sh` | `omp -p "your task"` |
| `pi` | `npm install -g @earendil-works/pi-coding-agent` | `pi -p "your task"` |
| `hermes` | (see the Terminal page) | `hermes chat -Q --yolo -q "your task"` |

Write and check one of them the same way as OpenClaw. Add `--context 32k`. Add `--key` from `strata-gyro-gyro-s.json` when the server was not started by `strata launch`.

```sh
strata connect codex --write --yes --context 32k
strata connect codex --check
```

Hermes is built for a 64k window. At 32k the written file uses the lmstudio-shaped workaround, and its prompt plus tools are about 12.9k tokens. Claude Code’s full prompt is about 15.6k tokens. At 32k the connect command sets `CLAUDE_CODE_SIMPLE=1` (about 1.25k tokens, 3 tools). pi has the smallest prompt of the set, about 1.5k tokens.
