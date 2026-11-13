#!/bin/sh
# Start the Intel Arc server from this folder.
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

.venv/bin/python sycl/serve/server_intel.py --engine strata --config "$cfg" --port 8080 --open
status=$?
if [ "$status" -ne 0 ]; then
  printf 'The server stopped (exit %s). Press Enter to close. ' "$status"
  read answer
fi
exit "$status"
