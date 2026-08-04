#!/bin/sh
set -e

TOKEN_FILE="/run/secrets/kibana.token"

if [ -f "$TOKEN_FILE" ]; then
  export ELASTICSEARCH_SERVICEACCOUNTTOKEN="$(cat "$TOKEN_FILE")"
else
  echo "ERROR: token file not found at $TOKEN_FILE" >&2
  exit 1
fi

exec /usr/local/bin/kibana-docker