#!/usr/bin/env bash
set -euo pipefail

REMOTE_BASE_URL="https://raw.githubusercontent.com/shashanthk/interactive-shell/main"
SCRIPT_NAME="generate-ssh-key.sh"
TMP_SCRIPT="$(mktemp /tmp/${SCRIPT_NAME}.XXXXXX)"

cleanup() {
  rm -f "$TMP_SCRIPT"
}
trap cleanup EXIT

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Missing required command: $1" >&2
    exit 1
  }
}

require_cmd curl

echo "Downloading $SCRIPT_NAME..."
curl --fail --silent --show-error --location \
  "${REMOTE_BASE_URL}/${SCRIPT_NAME}" \
  --output "$TMP_SCRIPT"

chmod 700 "$TMP_SCRIPT"

echo "Executing downloaded script..."
exec "$TMP_SCRIPT" "$@"
