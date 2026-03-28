### GitHub SSH Key Generator (Go)

The tool is written in Go and produces a single portable binary. It automates SSH key generation for GitHub and sets up `~/.ssh/config` for you.

#### Prerequisites

- [Go 1.24+](https://go.dev/dl/) installed
- `ssh-keygen` available on your system (standard on macOS and Linux)

#### Build

```bash
git clone https://github.com/shashanthk/interactive-shell.git
cd interactive-shell
go build -o git-ssh-setup .
```

#### Run

Interactive mode (prompts for your name):

```bash
./git-ssh-setup
```

Non-interactive mode (pass your name as an argument):

```bash
./git-ssh-setup "John Doe"
```

#### Install system-wide

```bash
go install github.com/shashanthk/interactive-shell@latest
```

Then run:

```bash
interactive-shell "John Doe"
```

---

### Legacy shell scripts

The original shell scripts are still available for reference.

1. GitHub SSH key generator (shell)

    If downloaded to local system, run like below:

        ./git_ssh_key_automation.sh

    Remote execution without downloading:

        curl -o- https://raw.githubusercontent.com/shashanthk/interactive-shell/main/git_ssh_key_automation.sh | bash -s "John Doe"