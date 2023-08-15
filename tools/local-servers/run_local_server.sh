#!/usr/bin/env bash
#
# A simple server for local testing. It serves bidding scripts out of the
# static directory. Dispatches KV requests to cgi-bin/kv.py

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd "$SCRIPT_DIR"

openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem \
            -sha256 -days 3650 -nodes \
            -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"
python3 ./local_server.py cert.pem key.pem
