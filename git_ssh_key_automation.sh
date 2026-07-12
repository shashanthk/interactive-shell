#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible entrypoint retained for older users.
# Prefer using generate-ssh-key.sh directly.

# REF pins which branch/tag/commit of this repo to fetch generate-ssh-key.sh
# from. Defaults to the floating `main` branch for convenience, but anyone
# running this over curl | bash without cloning is trusting whatever is at
# that ref *at fetch time*, with no integrity check, unless they pin it.
# For unattended/production use, override both of these:
#   export SSH_KEYGEN_TOOL_REF=<commit-sha-or-tag>
#   export SSH_KEYGEN_TOOL_SHA256=<sha256 of generate-ssh-key.sh at that ref>
REMOTE_REF="${SSH_KEYGEN_TOOL_REF:-main}"
REMOTE_BASE_URL="https://raw.githubusercontent.com/shashanthk/interactive-shell/${REMOTE_REF}"
EXPECTED_SHA256="${SSH_KEYGEN_TOOL_SHA256:-}"
TARGET_NAME="generate-ssh-key.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
TARGET_SCRIPT="${SCRIPT_DIR}/${TARGET_NAME}"

usage_wrapper() {
  cat >&2 <<'USAGE'
This wrapper is deprecated.
Use one of:
  ./generate-ssh-key.sh --provider github --email you@example.com
  curl -fsSL https://raw.githubusercontent.com/shashanthk/interactive-shell/main/git_ssh_key_automation.sh | bash -s -- --provider github --email you@example.com

For unattended/production use, pin to a known commit and verify its
checksum instead of trusting the floating main branch:
  export SSH_KEYGEN_TOOL_REF=<commit-sha>
  export SSH_KEYGEN_TOOL_SHA256=<sha256 of generate-ssh-key.sh at that commit>
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: Missing required command: $1" >&2
    exit 1
  }
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "ERROR: no sha256 utility found (need sha256sum or shasum) to verify SSH_KEYGEN_TOOL_SHA256" >&2
    exit 1
  fi
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

  if [ -n "$EXPECTED_SHA256" ]; then
    local actual_sha256
    actual_sha256="$(sha256_of "$tmp_script")"
    if [ "$actual_sha256" != "$EXPECTED_SHA256" ]; then
      echo "ERROR: checksum mismatch for downloaded ${TARGET_NAME}@${REMOTE_REF}" >&2
      echo "  expected: $EXPECTED_SHA256" >&2
      echo "  actual:   $actual_sha256" >&2
      exit 1
    fi
    echo "Checksum verified for ${TARGET_NAME}@${REMOTE_REF}." >&2
  else
    echo "WARNING: no SSH_KEYGEN_TOOL_SHA256 set; skipping integrity check on the downloaded script. See --help for how to pin and verify a specific commit." >&2
  fi

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
