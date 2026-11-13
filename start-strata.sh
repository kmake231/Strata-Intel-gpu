#!/bin/sh
# Start the Intel Arc server from this folder.
#
#   ./start-strata.sh              run in the background; the terminal can close
#   ./start-strata.sh --foreground stay in this terminal (the old behaviour)
#   ./start-strata.sh --follow     watch the progress log
#   ./start-strata.sh --log        print the last progress lines
#   ./start-strata.sh --status
#   ./start-strata.sh --stop
#
# The lines that say "reading the prompt", "thinking" and "answering" go to
# logs/strata-server.log. The engine's own log is strata-gyro-gyro-s.log.
cd "$(CDPATH= cd -- "$(dirname "$0")" && pwd)" || exit 1

if [ ! -x .venv/bin/python ]; then
  echo "No setup in this folder yet. From here, run: ./setup.sh --backend sycl"
  printf 'Press Enter to close. '
  read answer
  exit 1
fi

cfg=strata-gyro-gyro-s.json
if [ ! -f "$cfg" ]; then
  echo "No $cfg in this folder. Setup writes it. Run: ./setup.sh --backend sycl"
  printf 'Press Enter to close. '
  read answer
  exit 1
fi

logfile=logs/strata-server.log
pidfile=logs/strata-server.pid
enginelog=strata-gyro-gyro-s.log
py=.venv/bin/python

mkdir -p logs

server_pid() {
  if [ -f "$pidfile" ]; then
    pid=$(cat "$pidfile" 2>/dev/null || true)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      printf '%s\n' "$pid"
      return 0
    fi
  fi
  ps -eo pid=,cmd= | awk '/server_intel.py --engine strata/ && !/awk/ { print $1; exit }'
}

port_open() {
  ss -ltn 2>/dev/null | awk '$4 ~ /:8080$/ { found=1 } END { exit !found }'
}

case "${1:-}" in
  --stop)
    pid=$(server_pid)
    if [ -z "$pid" ]; then
      echo "Strata is not running."
      exit 0
    fi
    kill -TERM "$pid" 2>/dev/null || true
    i=0
    while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 40 ]; do
      sleep 0.5
      i=$((i + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
      echo "Strata is still stopping (pid $pid)."
      exit 1
    fi
    rm -f "$pidfile"
    echo "Strata stopped."
    exit 0
    ;;
  --status)
    pid=$(server_pid)
    if [ -n "$pid" ]; then
      echo "Strata is running (pid $pid)."
    else
      echo "Strata is not running."
    fi
    echo "Progress log: $logfile"
    echo "Engine log:   $enginelog"
    exit 0
    ;;
  --log)
    if [ ! -f "$logfile" ]; then
      echo "No progress log yet. Start the server, then look here: $logfile"
      exit 0
    fi
    tail -n 40 "$logfile"
    exit 0
    ;;
  --follow)
    touch "$logfile"
    echo "Watching $logfile  (Ctrl+C stops watching; the server keeps running)"
    tail -n 20 -f "$logfile"
    exit 0
    ;;
  --foreground)
    exec "$py" sycl/serve/server_intel.py --engine strata --config "$cfg" --port 8080 --open
    ;;
  "")
    ;;
  *)
    echo "Unknown option: $1"
    echo "Use: ./start-strata.sh [--foreground|--follow|--log|--status|--stop]"
    exit 1
    ;;
esac

pid=$(server_pid)
if [ -n "$pid" ] || port_open; then
  echo "Strata is already running${pid:+ (pid $pid)}."
  echo "Progress log: $logfile"
  echo "Watch it:     ./start-strata.sh --follow"
  exit 0
fi

printf '\n===== %s start =====\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$logfile"
# nohup ignores the hangup a closing terminal sends, so the server stays up.
nohup "$py" sycl/serve/server_intel.py --engine strata --config "$cfg" --port 8080 --open \
  >> "$logfile" 2>&1 &
pid=$!
printf '%s\n' "$pid" > "$pidfile"

sleep 0.5
if ! kill -0 "$pid" 2>/dev/null; then
  echo "The server stopped at once. Last lines of $logfile:"
  tail -n 20 "$logfile"
  rm -f "$pidfile"
  exit 1
fi

echo "Strata is running in the background (pid $pid). This terminal can close."
echo "Progress log: $logfile"
echo "Engine log:   $enginelog"
echo "Watch it:     ./start-strata.sh --follow"
echo "Stop it:      ./start-strata.sh --stop"
