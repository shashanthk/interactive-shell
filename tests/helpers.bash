setup_test_env() {
  TEST_ROOT="$BATS_TEST_TMPDIR/testroot"
  HOME="$TEST_ROOT/home"
  export HOME
  mkdir -p "$HOME/.ssh" "$TEST_ROOT/bin"
  export PATH="$TEST_ROOT/bin:$PATH"

  cat >"$TEST_ROOT/bin/ssh-keygen" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
out=""
comment=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -f) out="$2"; shift 2 ;;
    -C) comment="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$out" ] || exit 9
printf 'PRIVATE-%s\n' "$comment" > "$out"
printf 'ssh-ed25519 AAAATEST %s\n' "$comment" > "$out.pub"
MOCK

  cat >"$TEST_ROOT/bin/ssh-agent" <<'MOCK'
#!/usr/bin/env bash
echo "SSH_AUTH_SOCK=/tmp/mock.sock; export SSH_AUTH_SOCK;"
echo "SSH_AGENT_PID=777; export SSH_AGENT_PID;"
MOCK

  cat >"$TEST_ROOT/bin/ssh-add" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK

  cat >"$TEST_ROOT/bin/xclip" <<'MOCK'
#!/usr/bin/env bash
cat >/dev/null
MOCK

  chmod +x "$TEST_ROOT/bin/ssh-keygen" "$TEST_ROOT/bin/ssh-agent" "$TEST_ROOT/bin/ssh-add" "$TEST_ROOT/bin/xclip"
}

# Portable `stat <path> -> octal permission bits`, since GNU `stat -c`
# and BSD/macOS `stat -f` are mutually incompatible.
stat_perm() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

# PATH containing only the test's own mocks plus symlinks to the real
# coreutils generate-ssh-key.sh needs along its non-error-exit code
# path (env/bash to start it via its shebang, grep/mkdir/chmod/stat/
# touch/cat/uname for validation, the ssh dir/config/key-file handling,
# and OS detection in copy_public_key). Tests use this when simulating
# a "missing" tool so a real system copy elsewhere on the host/CI PATH
# (e.g. the openssh-client preinstalled on GitHub's runners, or
# macOS's always-present pbcopy) can't be found and mask the removed
# mock. Deliberately does NOT include ssh-keygen/ssh-agent/ssh-add or
# any clipboard tool - those come only from $TEST_ROOT/bin's mocks (or
# are absent, on purpose).
minimal_path() {
  local shim_dir="$TEST_ROOT/shim"
  mkdir -p "$shim_dir"
  local tool
  for tool in env bash grep mkdir chmod stat touch cat rm uname; do
    ln -sf "$(command -v "$tool")" "$shim_dir/$tool"
  done
  printf '%s' "$TEST_ROOT/bin:$shim_dir"
}

# Name of the clipboard binary generate-ssh-key.sh will look for on
# this OS, matching copy_public_key()'s own uname -s branching.
platform_clipboard_tool() {
  case "$(uname -s)" in
    Darwin) printf 'pbcopy' ;;
    MINGW* | MSYS* | CYGWIN*) printf 'clip.exe' ;;
    *) printf 'xclip' ;;
  esac
}

is_windows_bash() {
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}
