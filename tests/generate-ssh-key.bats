#!/usr/bin/env bats

load ./helpers.bash

setup() {
  setup_test_env
}

@test "generates ED25519 key for github" {
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --no-color
  [ "$status" -eq 0 ]
  [ -f "$HOME/.ssh/id_github" ]
  [ -f "$HOME/.ssh/id_github.pub" ]
  run stat_perm "$HOME/.ssh/id_github"
  if is_windows_bash; then
    # NTFS via Git Bash doesn't reliably map chmod bits to an exact
    # POSIX octal value; just confirm stat succeeded.
    [ -n "$output" ]
  else
    [ "$output" = "600" ]
  fi
}

@test "generates RSA key successfully" {
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider gitlab --email user@example.com --key-type rsa --no-color
  [ "$status" -eq 0 ]
  [ -f "$HOME/.ssh/id_gitlab" ]
}

@test "name input sets default key filename and alias convention" {
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --name "John Doe" --no-color
  [ "$status" -eq 0 ]
  [ -f "$HOME/.ssh/id_john_doe" ]
  [ -f "$HOME/.ssh/id_john_doe.pub" ]
  run cat "$HOME/.ssh/config"
  [[ "$output" == *"Host john-doe-github"* ]]
}

@test "supports provider matrix" {
  for provider in github gitlab bitbucket azure; do
    run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider "$provider" --email user@example.com --key-name "id_${provider}_x" --no-color
    [ "$status" -eq 0 ]
  done
}

@test "custom provider requires host" {
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider custom --email user@example.com --no-color
  [ "$status" -ne 0 ]
  [[ "$output" == *"Custom host cannot be empty"* ]]
}

@test "fails if ssh-keygen missing" {
  rm -f "$TEST_ROOT/bin/ssh-keygen"

  # A real ssh-keygen elsewhere on PATH (e.g. openssh-client preinstalled
  # on Linux/macOS/Windows CI runners) would let the script fall through
  # to it once only the mock is removed. minimal_path keeps just the
  # mocks plus what's needed to start the script and pass validation,
  # so this test is deterministic regardless of the host.
  PATH="$(minimal_path)" run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --no-color
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required command: ssh-keygen"* ]]
}

@test "invalid email rejected including metacharacters" {
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email 'foo@example.com; rm -rf /' --no-color
  [ "$status" -ne 0 ]
}

@test "invalid provider rejected" {
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider nope --email user@example.com --no-color
  [ "$status" -ne 0 ]
}

@test "existing key without force fails" {
  touch "$HOME/.ssh/id_github" "$HOME/.ssh/id_github.pub"
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --no-color
  [ "$status" -ne 0 ]
  [[ "$output" == *"use --force"* ]]
}

@test "existing key with force succeeds" {
  touch "$HOME/.ssh/id_github" "$HOME/.ssh/id_github.pub"
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --force --no-color
  [ "$status" -eq 0 ]
}

@test "path traversal in key name is rejected" {
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --key-name '../evil' --no-color
  [ "$status" -ne 0 ]
}

@test "symlink attack is rejected" {
  if is_windows_bash; then
    # Creating real symlinks on Windows requires elevated privileges /
    # Developer Mode, which isn't reliably available in CI. The
    # underlying safe_file_target() defense is still exercised on
    # Linux/macOS.
    skip "symlink creation requires elevated privileges on Windows"
  fi
  ln -s /tmp "$HOME/.ssh/id_github"
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --force --no-color
  [ "$status" -ne 0 ]
  [[ "$output" == *"Refusing to use symlink target"* ]]
}

@test "copy to clipboard succeeds using the platform tool" {
  tool="$(platform_clipboard_tool)"
  if [ ! -x "$TEST_ROOT/bin/$tool" ]; then
    cat >"$TEST_ROOT/bin/$tool" <<'MOCK'
#!/usr/bin/env bash
cat >/dev/null
MOCK
    chmod +x "$TEST_ROOT/bin/$tool"
  fi

  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --copy-to-clipboard --no-color
  [ "$status" -eq 0 ]
}

@test "clipboard utility missing fails" {
  rm -f "$TEST_ROOT/bin/xclip" "$TEST_ROOT/bin/pbcopy" "$TEST_ROOT/bin/clip.exe" "$TEST_ROOT/bin/clip" "$TEST_ROOT/bin/wl-copy"

  # minimal_path guarantees no real system clipboard utility (pbcopy on
  # macOS, clip.exe on Windows, xclip/wl-copy on Linux) is reachable
  # either, regardless of which OS this test runs on.
  PATH="$(minimal_path)" run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --copy-to-clipboard --no-color
  [ "$status" -ne 0 ]
}

@test "missing required params fails" {
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --no-color
  [ "$status" -ne 0 ]
}

@test "dry-run does not create files" {
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --dry-run --no-color
  [ "$status" -eq 0 ]
  [ ! -f "$HOME/.ssh/id_github" ]
}

@test "wrong ssh dir permissions are corrected" {
  chmod 777 "$HOME/.ssh"
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --no-color
  [ "$status" -eq 0 ]
  run stat_perm "$HOME/.ssh"
  if is_windows_bash; then
    # NTFS via Git Bash doesn't reliably map chmod bits to an exact
    # POSIX octal value; just confirm stat succeeded.
    [ -n "$output" ]
  else
    [ "$output" = "700" ]
  fi
}
