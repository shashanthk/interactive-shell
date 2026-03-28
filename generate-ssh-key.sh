#!/usr/bin/env bash
set -euo pipefail

SCRIPT_VERSION="1.0.0"
DEFAULT_KEY_TYPE="ed25519"
DEFAULT_RSA_BITS="4096"
SUPPORTED_PROVIDERS="github gitlab bitbucket azure custom"

COLOR=1
DRY_RUN=0
FORCE=0
COPY_TO_CLIPBOARD=0
PRINT_PUBLIC_KEY=0
START_AGENT=1

PROVIDER=""
EMAIL=""
KEY_TYPE="$DEFAULT_KEY_TYPE"
KEY_NAME=""
CUSTOM_HOST=""
CUSTOM_PORT="22"

SSH_DIR="${HOME}/.ssh"
SSH_CONFIG="${SSH_DIR}/config"
SSH_ADD_BIN="ssh-add"
SSH_KEYGEN_BIN="ssh-keygen"
SSH_AGENT_BIN="ssh-agent"

log() { printf '%s\n' "$*"; }
warn() { printf '%sWARNING:%s %s\n' "$(color yellow)" "$(color reset)" "$*" >&2; }
err() { printf '%sERROR:%s %s\n' "$(color red)" "$(color reset)" "$*" >&2; }
success() { printf '%s%s%s\n' "$(color green)" "$*" "$(color reset)"; }

color() {
  if [ "$COLOR" -eq 0 ] || [ ! -t 1 ]; then
    return 0
  fi
  case "$1" in
    red) printf '\033[31m' ;;
    green) printf '\033[32m' ;;
    yellow) printf '\033[33m' ;;
    blue) printf '\033[34m' ;;
    reset) printf '\033[0m' ;;
  esac
}

usage() {
  cat <<'USAGE'
Usage:
  ./generate-ssh-key.sh --provider <provider> --email <email> [options]

Options:
  --help                     Show this help message
  --version                  Show script version
  --provider <name>          github | gitlab | bitbucket | azure | custom
  --email <email>            Email comment embedded in key
  --key-type <type>          ed25519 | rsa (default: ed25519)
  --key-name <name>          Key filename suffix (default: id_<provider>)
  --custom-host <host>       Required when --provider custom
  --custom-port <port>       Custom host SSH port (default: 22)
  --force                    Overwrite existing key files
  --dry-run                  Print actions without changing files
  --copy-to-clipboard        Copy public key using system clipboard utility
  --print-public-key         Print generated public key to stdout
  --no-color                 Disable colored output
  --no-agent                 Skip starting ssh-agent / adding key

Examples:
  ./generate-ssh-key.sh --provider github --email user@example.com
  ./generate-ssh-key.sh --provider gitlab --key-type ed25519 --copy-to-clipboard
  ./generate-ssh-key.sh --provider custom --custom-host git.example.com --email user@example.com
USAGE
}

version() { printf '%s\n' "$SCRIPT_VERSION"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Missing required command: $1"
    return 1
  }
}

validate_provider() {
  case "$1" in
    github|gitlab|bitbucket|azure|custom) return 0 ;;
    *) err "Invalid provider '$1'. Supported: $SUPPORTED_PROVIDERS"; return 1 ;;
  esac
}

validate_email() {
  # conservative validation; blocks spaces and shell metacharacters that are never valid emails
  printf '%s' "$1" | grep -Eq "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$" || {
    err "Invalid email format: $1"
    return 1
  }
}

validate_key_type() {
  case "$1" in
    ed25519|rsa) return 0 ;;
    *) err "Invalid key type '$1'. Use ed25519 or rsa."; return 1 ;;
  esac
}

validate_key_name() {
  [ -n "$1" ] || { err "Key name cannot be empty"; return 1; }
  case "$1" in
    */*|*..*|.*) err "Key name must not contain path traversal or leading dot"; return 1 ;;
    *[!A-Za-z0-9._-]*) err "Key name contains unsupported characters"; return 1 ;;
  esac
}

validate_host() {
  [ -n "$1" ] || { err "Custom host cannot be empty"; return 1; }
  printf '%s' "$1" | grep -Eq '^[A-Za-z0-9.-]+$' || {
    err "Custom host has invalid characters"
    return 1
  }
}

validate_port() {
  printf '%s' "$1" | grep -Eq '^[0-9]+$' || { err "Port must be numeric"; return 1; }
  [ "$1" -ge 1 ] && [ "$1" -le 65535 ] || { err "Port must be between 1 and 65535"; return 1; }
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --help) usage; exit 0 ;;
      --version) version; exit 0 ;;
      --provider) PROVIDER="${2:-}"; shift 2 ;;
      --email) EMAIL="${2:-}"; shift 2 ;;
      --key-type) KEY_TYPE="${2:-}"; shift 2 ;;
      --key-name) KEY_NAME="${2:-}"; shift 2 ;;
      --custom-host) CUSTOM_HOST="${2:-}"; shift 2 ;;
      --custom-port) CUSTOM_PORT="${2:-}"; shift 2 ;;
      --force) FORCE=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      --copy-to-clipboard) COPY_TO_CLIPBOARD=1; shift ;;
      --print-public-key) PRINT_PUBLIC_KEY=1; shift ;;
      --no-color) COLOR=0; shift ;;
      --no-agent) START_AGENT=0; shift ;;
      --) shift; break ;;
      *) err "Unknown argument: $1"; usage; exit 2 ;;
    esac
  done
}

provider_defaults() {
  case "$PROVIDER" in
    github)
      HOST_ALIAS="github.com"
      HOST_NAME="ssh.github.com"
      HOST_PORT="443"
      HOST_USER="git"
      KEY_HELP_URL="https://github.com/settings/ssh/new"
      ;;
    gitlab)
      HOST_ALIAS="gitlab.com"
      HOST_NAME="altssh.gitlab.com"
      HOST_PORT="443"
      HOST_USER="git"
      KEY_HELP_URL="https://gitlab.com/-/profile/keys"
      ;;
    bitbucket)
      HOST_ALIAS="bitbucket.org"
      HOST_NAME="ssh.bitbucket.org"
      HOST_PORT="443"
      HOST_USER="git"
      KEY_HELP_URL="https://bitbucket.org/account/settings/ssh-keys/"
      ;;
    azure)
      HOST_ALIAS="ssh.dev.azure.com"
      HOST_NAME="ssh.dev.azure.com"
      HOST_PORT="22"
      HOST_USER="git"
      KEY_HELP_URL="https://learn.microsoft.com/azure/devops/repos/git/use-ssh-keys-to-authenticate"
      ;;
    custom)
      HOST_ALIAS="$CUSTOM_HOST"
      HOST_NAME="$CUSTOM_HOST"
      HOST_PORT="$CUSTOM_PORT"
      HOST_USER="git"
      KEY_HELP_URL=""
      ;;
  esac
}

ensure_ssh_dir() {
  if [ -e "$SSH_DIR" ] && [ ! -d "$SSH_DIR" ]; then
    err "$SSH_DIR exists but is not a directory"
    exit 1
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] mkdir -p '$SSH_DIR'"
    return
  fi

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  # reject dangerous permissions
  current_mode=$(stat -c '%a' "$SSH_DIR" 2>/dev/null || stat -f '%Mp%Lp' "$SSH_DIR")
  case "$current_mode" in
    700|0700) ;;
    *)
      warn "$SSH_DIR permissions were $current_mode; correcting to 700"
      chmod 700 "$SSH_DIR"
      ;;
  esac
}

safe_file_target() {
  target="$1"
  if [ -L "$target" ]; then
    err "Refusing to use symlink target: $target"
    exit 1
  fi
}

generate_key() {
  private_key="$1"
  safe_file_target "$private_key"
  safe_file_target "$private_key.pub"

  if [ -e "$private_key" ] || [ -e "$private_key.pub" ]; then
    if [ "$FORCE" -ne 1 ]; then
      err "Key file already exists: $private_key (use --force to overwrite)"
      exit 1
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      log "[dry-run] rm -f '$private_key' '$private_key.pub'"
    else
      rm -f "$private_key" "$private_key.pub"
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ "$KEY_TYPE" = "rsa" ]; then
      log "[dry-run] $SSH_KEYGEN_BIN -t rsa -b $DEFAULT_RSA_BITS -C '$EMAIL' -f '$private_key'"
    else
      log "[dry-run] $SSH_KEYGEN_BIN -t ed25519 -C '$EMAIL' -f '$private_key'"
    fi
    return
  fi

  if [ "$KEY_TYPE" = "rsa" ]; then
    "$SSH_KEYGEN_BIN" -q -t rsa -b "$DEFAULT_RSA_BITS" -C "$EMAIL" -f "$private_key" -N ""
  else
    "$SSH_KEYGEN_BIN" -q -t ed25519 -C "$EMAIL" -f "$private_key" -N ""
  fi

  chmod 600 "$private_key"
  chmod 644 "$private_key.pub"
}

upsert_ssh_config() {
  local_host="$1"
  local_name="$2"
  local_user="$3"
  local_port="$4"
  local_identity="$5"

  block=$(cat <<EOF_BLOCK
Host ${local_host}
    HostName ${local_name}
    User ${local_user}
    Port ${local_port}
    IdentityFile ${local_identity}
    IdentitiesOnly yes
EOF_BLOCK
)

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] append/update host block in '$SSH_CONFIG' for Host ${local_host}"
    return
  fi

  [ -f "$SSH_CONFIG" ] || touch "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"

  if grep -q "^Host ${local_host}$" "$SSH_CONFIG"; then
    warn "Host ${local_host} already exists in config; leaving existing block unchanged"
  else
    printf '\n%s\n' "$block" >>"$SSH_CONFIG"
  fi
}

start_agent_and_add_key() {
  key_file="$1"
  if [ "$START_AGENT" -ne 1 ]; then
    return
  fi

  require_cmd "$SSH_AGENT_BIN"
  require_cmd "$SSH_ADD_BIN"

  if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      log "[dry-run] eval \"\$($SSH_AGENT_BIN -s)\""
    else
      eval "$("$SSH_AGENT_BIN" -s)" >/dev/null
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[dry-run] $SSH_ADD_BIN '$key_file'"
  else
    "$SSH_ADD_BIN" "$key_file" >/dev/null
  fi
}

copy_public_key() {
  pub_file="$1"
  if [ "$COPY_TO_CLIPBOARD" -ne 1 ]; then
    return 0
  fi

  os_name=$(uname -s)
  case "$os_name" in
    Darwin)
      require_cmd pbcopy
      if [ "$DRY_RUN" -eq 1 ]; then
        log "[dry-run] pbcopy < '$pub_file'"
      else
        pbcopy <"$pub_file"
      fi
      ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        if command -v clip.exe >/dev/null 2>&1; then
          if [ "$DRY_RUN" -eq 1 ]; then
            log "[dry-run] clip.exe < '$pub_file'"
          else
            clip.exe <"$pub_file"
          fi
        else
          err "WSL detected but clip.exe is unavailable"
          exit 1
        fi
      elif command -v wl-copy >/dev/null 2>&1; then
        if [ "$DRY_RUN" -eq 1 ]; then
          log "[dry-run] wl-copy < '$pub_file'"
        else
          wl-copy <"$pub_file"
        fi
      elif command -v xclip >/dev/null 2>&1; then
        if [ "$DRY_RUN" -eq 1 ]; then
          log "[dry-run] xclip -selection clipboard < '$pub_file'"
        else
          xclip -selection clipboard <"$pub_file"
        fi
      else
        err "No clipboard utility found (expected wl-copy or xclip)"
        exit 1
      fi
      ;;
    *)
      err "Unsupported OS for clipboard copy: $os_name"
      exit 1
      ;;
  esac
}

main() {
  parse_args "$@"

  [ -n "$PROVIDER" ] || { err "--provider is required"; usage; exit 2; }
  [ -n "$EMAIL" ] || { err "--email is required"; usage; exit 2; }

  validate_provider "$PROVIDER"
  validate_email "$EMAIL"
  validate_key_type "$KEY_TYPE"

  if [ "$PROVIDER" = "custom" ]; then
    validate_host "$CUSTOM_HOST"
    validate_port "$CUSTOM_PORT"
  fi

  provider_defaults

  if [ -z "$KEY_NAME" ]; then
    KEY_NAME="id_${PROVIDER}"
  fi
  validate_key_name "$KEY_NAME"

  PRIVATE_KEY_PATH="$SSH_DIR/$KEY_NAME"
  PUBLIC_KEY_PATH="$PRIVATE_KEY_PATH.pub"

  require_cmd "$SSH_KEYGEN_BIN"

  ensure_ssh_dir
  generate_key "$PRIVATE_KEY_PATH"
  upsert_ssh_config "$HOST_ALIAS" "$HOST_NAME" "$HOST_USER" "$HOST_PORT" "$PRIVATE_KEY_PATH"
  start_agent_and_add_key "$PRIVATE_KEY_PATH"
  copy_public_key "$PUBLIC_KEY_PATH"

  success "SSH key workflow complete for provider: $PROVIDER"
  log "Private key: $PRIVATE_KEY_PATH"
  log "Public key:  $PUBLIC_KEY_PATH"

  if [ -n "$KEY_HELP_URL" ]; then
    log "Add public key in provider UI: $KEY_HELP_URL"
  fi

  if [ "$PRINT_PUBLIC_KEY" -eq 1 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      log "[dry-run] cat '$PUBLIC_KEY_PATH'"
    else
      cat "$PUBLIC_KEY_PATH"
    fi
  fi
}

main "$@"
