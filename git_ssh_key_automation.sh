#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible entrypoint retained for older users.
# Prefer using generate-ssh-key.sh directly.

REMOTE_BASE_URL="https://raw.githubusercontent.com/shashanthk/interactive-shell/main"
TARGET_NAME="generate-ssh-key.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
TARGET_SCRIPT="${SCRIPT_DIR}/${TARGET_NAME}"

usage_wrapper() {
  cat >&2 <<'USAGE'
This wrapper is deprecated.
Use one of:
  ./generate-ssh-key.sh --provider github --email you@example.com
  curl -fsSL https://raw.githubusercontent.com/shashanthk/interactive-shell/main/git_ssh_key_automation.sh | bash -s -- --provider github --email you@example.com
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Missing required command: $1" >&2
    exit 1
  }
}

run_remote_target() {
  local tmp_script
  tmp_script="$(mktemp /tmp/${TARGET_NAME}.XXXXXX)"
  trap 'rm -f "$tmp_script"' EXIT

  require_cmd curl
  echo "Local ${TARGET_NAME} not found; downloading from ${REMOTE_BASE_URL}..." >&2
  curl --fail --silent --show-error --location \
    "${REMOTE_BASE_URL}/${TARGET_NAME}" \
    --output "$tmp_script"

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
