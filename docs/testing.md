# Testing Guide

## Local tests
Run unit/integration tests:
```bash
bats tests/
```

## Lint and formatting
```bash
shellcheck generate-ssh-key.sh run_git_ssh_key_automation.sh git_ssh_key_automation.sh
shfmt -d generate-ssh-key.sh run_git_ssh_key_automation.sh git_ssh_key_automation.sh tests/*.bats tests/*.bash
```

## Covered scenarios
- Happy path: ed25519/rsa, provider matrix, existing `.ssh`, clipboard success
- Failure path: missing dependency, invalid input, existing key without `--force`, missing required args
- Security path: metacharacter input, path traversal key names, symlink attacks
- File-mode checks: `.ssh` corrected to `700`, private key `600`

## Docker-based testing
```bash
docker build -t ssh-key-tool-test .
docker run --rm ssh-key-tool-test bats tests/
docker run --rm ssh-key-tool-test shellcheck generate-ssh-key.sh
```

## CI behavior
The GitHub Actions workflow fails if any of the following fail:
1. Shellcheck
2. shfmt diff check
3. Bats tests
4. Docker image build
