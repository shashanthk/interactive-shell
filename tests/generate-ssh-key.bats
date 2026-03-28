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
  run stat -c '%a' "$HOME/.ssh/id_github"
  [ "$output" = "600" ]
}

@test "generates RSA key successfully" {
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider gitlab --email user@example.com --key-type rsa --no-color
  [ "$status" -eq 0 ]
  [ -f "$HOME/.ssh/id_gitlab" ]
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
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --no-color
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
  ln -s /tmp "$HOME/.ssh/id_github"
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --force --no-color
  [ "$status" -ne 0 ]
  [[ "$output" == *"Refusing to use symlink target"* ]]
}

@test "copy to clipboard works with xclip" {
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --copy-to-clipboard --no-color
  [ "$status" -eq 0 ]
}

@test "clipboard utility missing fails" {
  rm -f "$TEST_ROOT/bin/xclip"
  run "$BATS_TEST_DIRNAME/../generate-ssh-key.sh" --provider github --email user@example.com --copy-to-clipboard --no-color
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
  run stat -c '%a' "$HOME/.ssh"
  [ "$output" = "700" ]
}
