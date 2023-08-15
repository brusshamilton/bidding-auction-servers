#!/usr/bin/env bash
#
# A simple server for local testing. It serves bidding scripts out of the
# static directory. Dispatches KV requests to cgi-bin/kv.py

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd "$SCRIPT_DIR"

python3 -m http.server --cgi -b 127.0.0.1 50072 -d "$SCRIPT_DIR"
