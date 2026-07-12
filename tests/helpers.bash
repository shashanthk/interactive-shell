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
