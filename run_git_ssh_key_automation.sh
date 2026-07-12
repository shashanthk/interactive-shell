#!/usr/bin/env bash
set -euo pipefail

REMOTE_BASE_URL="https://raw.githubusercontent.com/shashanthk/interactive-shell/main"
SCRIPT_NAME="generate-ssh-key.sh"
TMP_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/${SCRIPT_NAME}.XXXXXX")"

cleanup() {
  rm -f "$TMP_SCRIPT"
}
trap cleanup EXIT

download() {
  if command -v curl >/dev/null 2>&1; then
    curl --fail --silent --show-error --location "$1" --output "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget --quiet --output-document "$2" "$1"
  else
    echo "ERROR: Missing required command: curl or wget" >&2
    exit 1
  fi
}

echo "Downloading $SCRIPT_NAME..."
download "${REMOTE_BASE_URL}/${SCRIPT_NAME}" "$TMP_SCRIPT"

chmod 700 "$TMP_SCRIPT"

echo "Executing downloaded script..."
bash "$TMP_SCRIPT" "$@"
