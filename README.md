# SSH Key Generation Toolkit

A secure, testable Bash CLI for generating SSH keys for GitHub, GitLab, Bitbucket, Azure DevOps, and custom Git hosts.

## What are SSH keys?
SSH keys are a cryptographic key pair:
- **Private key**: stays on your machine and must be protected.
- **Public key**: uploaded to your Git hosting provider.

When configured correctly, you can authenticate Git operations without typing your password each time.

## Why ED25519 is recommended
`ed25519` provides strong security with smaller keys and faster operations than classic RSA in most modern environments. Use RSA only for compatibility with older systems.

## Features
- Hardened key generation workflow with `set -euo pipefail`
- Provider support: `github`, `gitlab`, `bitbucket`, `azure`, `custom`
- Validates email, provider, key type, host, and key name
- Defends against path traversal and symlink overwrite attacks
- Optional clipboard copy (`pbcopy`, `wl-copy`, `xclip`, `clip.exe`)
- SSH config host block creation with idempotent behavior
- `--dry-run` mode for safe preview
- Bats test suite, Docker test image, CI workflow

## Installation
```bash
git clone https://github.com/shashanthk/interactive-shell.git
cd interactive-shell
chmod +x generate-ssh-key.sh
```

## Requirements
- Bash 4+
- OpenSSH client tools (`ssh-keygen`, `ssh-agent`, `ssh-add`)
- Optional clipboard utility:
  - macOS: `pbcopy`
  - Linux Wayland: `wl-copy`
  - Linux X11: `xclip`
  - WSL: `clip.exe`
  - Windows (Git Bash / MSYS / Cygwin): `clip.exe` (built in to Windows)

## Usage
```bash
./generate-ssh-key.sh --provider github --email user@example.com
./generate-ssh-key.sh --provider gitlab --email user@example.com --key-type rsa
./generate-ssh-key.sh --provider github --email user@example.com --name "John Doe"
./generate-ssh-key.sh --provider custom --custom-host git.example.com --email user@example.com
```

### Add your public key to provider UI
After generation, the script prints the public key path. Upload the public key in:
- GitHub: https://github.com/settings/ssh/new
- GitLab: https://gitlab.com/-/profile/keys
- Bitbucket: https://bitbucket.org/account/settings/ssh-keys/
- Azure DevOps: https://learn.microsoft.com/azure/devops/repos/git/use-ssh-keys-to-authenticate


### Remote execution (without cloning)
```bash
curl -fsSL https://raw.githubusercontent.com/shashanthk/interactive-shell/main/git_ssh_key_automation.sh |   bash -s -- --provider github --email user@example.com
```

## Supported providers
| Provider | Host alias (default) | HostName | Port |
|---|---|---|---|
| github | `github.com` | `ssh.github.com` | 443 |
| gitlab | `gitlab.com` | `altssh.gitlab.com` | 443 |
| bitbucket | `bitbucket.org` | `ssh.bitbucket.org` | 443 |
| azure | `ssh.dev.azure.com` | `ssh.dev.azure.com` | 22 |
| custom | your host | your host | configurable |

If `--name` is provided, the host alias changes to `name-provider` (example: `john-doe-github`).

## CLI options
| Option | Description |
|---|---|
| `--help` | Show help |
| `--version` | Show version |
| `--provider <name>` | `github`, `gitlab`, `bitbucket`, `azure`, `custom` |
| `--email <email>` | Email for key comment |
| `--name <full name>` | Optional name used for alias (`name-provider`) and default key file (`id_<name>`) |
| `--key-type <type>` | `ed25519` (default) or `rsa` |
| `--key-name <name>` | Key filename under `~/.ssh/` |
| `--custom-host <host>` | Required for `custom` provider |
| `--custom-port <port>` | Port for custom provider |
| `--force` | Overwrite existing key files |
| `--dry-run` | Preview without changes |
| `--copy-to-clipboard` | Copy public key to clipboard |
| `--print-public-key` | Print public key |
| `--no-agent` | Skip `ssh-agent` and `ssh-add` |
| `--no-color` | Disable color output |

## Example output
```text
SSH key workflow complete for provider: github
Private key: /home/user/.ssh/id_github
Public key:  /home/user/.ssh/id_github.pub
Add public key in provider UI: https://github.com/settings/ssh/new
```

## Troubleshooting
- **Missing command**: install OpenSSH tools and clipboard utilities.
- **Permission warnings for `~/.ssh`**: script auto-corrects to `700`.
- **Existing key conflict**: pass `--force` or choose a different `--key-name`.
- **Clipboard failure in Linux**: install `wl-clipboard` or `xclip`.

## Security notes
- Script rejects invalid characters in email and key names.
- Script refuses symlink targets for key files.
- Script enforces private key permissions (`600`) and `.ssh` directory (`700`).
- Avoid running as root unless explicitly required.

See [docs/security.md](docs/security.md) for full threat review.

## Testing
```bash
bats tests/
```

See [docs/testing.md](docs/testing.md).

## Docker
```bash
docker build -t ssh-key-tool-test .
docker run --rm ssh-key-tool-test bats tests/
docker run --rm ssh-key-tool-test shellcheck generate-ssh-key.sh
```

Or with compose:
```bash
docker compose run --rm test
docker compose run --rm shellcheck
```

## Contributing
1. Run `shellcheck`, `shfmt -d`, and `bats tests/`.
2. Add/adjust tests for each behavior change.
3. Keep shell scripts POSIX-aware where practical, and fully quoted.
4. Update docs and changelog.
