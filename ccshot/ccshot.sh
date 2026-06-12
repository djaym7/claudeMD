#!/bin/zsh
# ccshot — paste a macOS clipboard screenshot to a remote host for Claude Code over SSH.
# Validates the clipboard image locally, streams it over ONE ssh connection, and prints +
# copies the absolute remote path so you can paste it straight into Claude Code.
#   Usage:  ccshot [remote-host]    (host comes from CCSHOT_HOST env var or 1st argument)
#   Env:    CCSHOT_HOST, CCSHOT_DIR (CCSHOT_DIR default: .ccshots, relative to remote $HOME)
emulate -L zsh

# Ensure Homebrew + system bins resolve even when launched from a stripped
# environment such as the macOS Shortcuts / launchd sandbox (no ~/.zshrc, minimal PATH).
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# When launched from a GUI sandbox (Shortcuts/launchd), SSH_AUTH_SOCK may be unset.
# Recover the agent socket from the per-user launchd session so ssh auth still works.
[[ -z "${SSH_AUTH_SOCK:-}" ]] && export SSH_AUTH_SOCK="$(launchctl getenv SSH_AUTH_SOCK 2>/dev/null)"

host="${1:-${CCSHOT_HOST:-}}"
remote_dir="${CCSHOT_DIR:-.ccshots}"

[[ -n "$host" ]] || {
  print -u2 "ccshot: no host configured — set CCSHOT_HOST in your shell or pass a host as the first argument"
  exit 2; }

command -v pngpaste >/dev/null 2>&1 || {
  print -u2 "ccshot: pngpaste not found — run: brew install pngpaste"; exit 127; }

tmp="$(mktemp -t ccshot)" || {
  print -u2 "ccshot: could not create local temp file"; exit 1; }

if ! pngpaste "$tmp" 2>/dev/null || [[ ! -s "$tmp" ]]; then
  print -u2 "ccshot: no image on the clipboard — copy a screenshot first (Ctrl-Shift-Cmd-4)"
  rm -f "$tmp"; exit 1
fi

remote_path="$(ssh "$host" "mkdir -p \"\$HOME/$remote_dir\" && f=\$(mktemp \"\$HOME/$remote_dir/clip-\$(date +%Y%m%d-%H%M%S)-XXXXXX.png\") && cat >| \"\$f\" && printf %s \"\$f\"" < "$tmp")"
rc=$?
rm -f "$tmp"

[[ $rc -eq 0 && -n "$remote_path" ]] || {
  print -u2 "ccshot: upload to '$host' failed (rc=$rc)"; exit 1; }

print -r -- "$remote_path"
printf %s "$remote_path" | pbcopy 2>/dev/null \
  && print -u2 "ccshot: ✓ uploaded — path copied to clipboard, paste it into Claude Code"
