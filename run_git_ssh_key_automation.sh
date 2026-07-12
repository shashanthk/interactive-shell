#!/usr/bin/env bash
set -euo pipefail

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

require_cmd curl

echo "Downloading $SCRIPT_NAME..."
curl --fail --silent --show-error --location \
  "${REMOTE_BASE_URL}/${SCRIPT_NAME}" \
  --output "$TMP_SCRIPT"

if [ -n "$EXPECTED_SHA256" ]; then
  actual_sha256="$(sha256_of "$TMP_SCRIPT")"
  if [ "$actual_sha256" != "$EXPECTED_SHA256" ]; then
    echo "ERROR: checksum mismatch for downloaded ${SCRIPT_NAME}@${REMOTE_REF}" >&2
    echo "  expected: $EXPECTED_SHA256" >&2
    echo "  actual:   $actual_sha256" >&2
    exit 1
  fi
  echo "Checksum verified for ${SCRIPT_NAME}@${REMOTE_REF}." >&2
else
  echo "WARNING: no SSH_KEYGEN_TOOL_SHA256 set; skipping integrity check on the downloaded script." >&2
fi

chmod 700 "$TMP_SCRIPT"

echo "Executing downloaded script..."
bash "$TMP_SCRIPT" "$@"
