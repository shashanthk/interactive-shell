# Changelog

## 1.0.0 - 2026-03-28
- Added hardened CLI script: `generate-ssh-key.sh`
- Added provider support for GitHub/GitLab/Bitbucket/Azure/custom hosts
- Added strict validation for email/key name/host/port
- Added symlink safety checks and secure permission enforcement
- Added dry-run, force, copy-to-clipboard, print-public-key, version/help flags
- Added Bats test suite with happy/failure/security scenarios
- Added Dockerfile and docker-compose services for testing/lint
- Added GitHub Actions CI workflow for shellcheck, shfmt, bats, and docker build
- Rewrote README and added security/testing docs

- Updated GitLab/Bitbucket provider HostName defaults to SSH-over-443 endpoints (`altssh.gitlab.com`, `ssh.bitbucket.org`)
