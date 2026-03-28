# Security Review

## Summary
The original script had multiple security weaknesses (input handling, overwrite behavior, symlink risks, and curl-pipe execution guidance). This repository now includes a hardened replacement script: `generate-ssh-key.sh`.

## Findings and fixes

### 1) Unsafe interpolation of user input
- **Severity:** High
- **Issue:** User input was transformed and used in filesystem and config contexts with weak validation.
- **Vulnerable pattern:** unvalidated names used in key filenames and host aliases.
- **Fix:** strict validation functions for provider/email/key-name/host/port.
- **Fixed pattern:** reject metacharacters, path separators, traversal, leading dot names.

### 2) Symlink overwrite attack
- **Severity:** High
- **Issue:** Existing symlink at target key path could redirect write/overwrite.
- **Vulnerable pattern:** direct writes to `$ssh_key_file` without symlink checks.
- **Fix:** explicit symlink rejection before key generation and overwrite.

### 3) Existing key overwrite UX and safety
- **Severity:** Medium
- **Issue:** Interactive overwrite prompt made automation brittle and could be bypassed in pipelines.
- **Fix:** explicit `--force` for overwrite; deterministic non-interactive behavior.

### 4) Permissions hardening gaps
- **Severity:** Medium
- **Issue:** `.ssh` permissions may remain insecure and script only corrected after generation.
- **Fix:** enforce `.ssh` 700 before key write, private key 600/public key 644.

### 5) Command dependency assumptions
- **Severity:** Medium
- **Issue:** failures were opaque when `ssh-keygen`/`ssh-agent` missing.
- **Fix:** command checks with clear error messages and non-zero exits.

### 6) Clipboard portability and failures
- **Severity:** Low
- **Issue:** no robust per-OS detection for clipboard tools.
- **Fix:** OS-specific detection: `pbcopy`, `wl-copy`, `xclip`, `clip.exe`.

### 7) Root execution risk
- **Severity:** Low
- **Issue:** running as root writes keys into root account context, often unintended.
- **Recommendation:** avoid root execution except in controlled automation.

## Secure defaults recommendation
- Default to `ed25519`.
- Disable implicit overwrite unless `--force` is set.
- Never accept path separators in key names.
- Avoid storing passphrase in env vars/history (current script uses empty passphrase by default; future enhancement can add secure prompt mode).

## Additional recommendations
- Add optional passphrase prompt mode (`read -s`).
- Add explicit root warning banner.
- Add checksum verification for downloaded scripts in `run_git_ssh_key_automation.sh`.
