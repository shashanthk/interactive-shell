#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible entrypoint retained for older users.
# Prefer using generate-ssh-key.sh directly.

REMOTE_BASE_URL="https://raw.githubusercontent.com/shashanthk/interactive-shell/main"
TARGET_NAME="generate-ssh-key.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
TARGET_SCRIPT="${SCRIPT_DIR}/${TARGET_NAME}"

usage_wrapper() {
  cat >&2 <<'USAGE'
This wrapper is deprecated.
Use one of:
  ./generate-ssh-key.sh --provider github --email you@example.com
  curl -fsSL https://raw.githubusercontent.com/shashanthk/interactive-shell/main/git_ssh_key_automation.sh | bash -s -- --provider github --email you@example.com
USAGE
}

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

run_remote_target() {
  local tmp_script
  tmp_script="$(mktemp "${TMPDIR:-/tmp}/${TARGET_NAME}.XXXXXX")"
  trap 'rm -f "$tmp_script"' EXIT

  echo "Local ${TARGET_NAME} not found; downloading from ${REMOTE_BASE_URL}..." >&2
  download "${REMOTE_BASE_URL}/${TARGET_NAME}" "$tmp_script"

  chmod 700 "$tmp_script"
  bash "$tmp_script" "$@"
}

if [ "$#" -eq 0 ]; then
  usage_wrapper
  exit 2
fi

if [ -n "$SCRIPT_DIR" ] && [ -x "$TARGET_SCRIPT" ]; then
  exec "$TARGET_SCRIPT" "$@"
fi

run_remote_target "$@"
