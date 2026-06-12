# ccshot — Paste macOS Clipboard Screenshots into Claude Code over SSH

A single command (and optional keyboard shortcut) that takes whatever screenshot is on your
Mac's clipboard and makes it instantly available to **Claude Code running on a remote SSH host**.

- **Local command:** `ccshot`
- **Script location:** `~/.local/bin/ccshot`
- **Default remote landing dir:** `~/.ccshots/` on the remote host

> No host is hardcoded — set `CCSHOT_HOST` in your shell config (or pass a host as the first
> argument). The script is portable to any SSH-reachable Linux host where you have write access
> to `$HOME`.

---

## Why this is needed (the SSH/clipboard reality)

The macOS clipboard is `NSPasteboard` — an **OS-level service that exists only on your Mac**,
reachable solely through local macOS APIs by processes in your GUI login session. It is **not**
network-exposed.

Claude Code running on a remote host is a process on a **different machine** with no route to
those APIs, and a normal SSH session carries only your keystrokes and terminal text — **not
pasteboard or GUI data**. So when you paste an image locally, the bytes never leave your Mac in
a form the remote can see.

That's why **local** Claude Code can attach pasted images (it calls the clipboard API directly)
but the **remote** one cannot. The image has to be explicitly pulled *from* the Mac side and
written as a file the remote process can open — which is exactly what `ccshot` does:

1. `pngpaste` extracts the clipboard PNG **locally**.
2. `ssh` streams the bytes to the remote and writes them to a uniquely-named file.
3. The remote **absolute path** is printed and copied to your Mac clipboard.
4. You paste that path into Claude Code, and its file-reading turns the path back into a
   visual image attachment.

---

## How it works (data flow)

```
   macOS clipboard (PNG)
          │  pngpaste  (validates + extracts locally)
          ▼
   local temp file  ──── ssh (ONE connection) ────►  $CCSHOT_HOST
                                                          │
                          mktemp clip-<timestamp>-XXXXXX.png in ~/.ccshots
                          cat > file   (stream bytes in)
                                                          │
          ┌─────────────────────────────────────────────  ┘
          ▼
   remote absolute path printed to stdout  ──►  pbcopy (onto Mac clipboard)
          │
          ▼
   ⌘V into Claude Code over SSH  ──►  Claude reads the path as an image
```

Key design choices:

- **One SSH connection per shot.** Validate locally first, then stream the bytes in a single
  `ssh` call that mints a collision-free filename remotely with `mktemp` and prints the path back.
- **Collision-free remote names** via `mktemp` (`clip-YYYYMMDD-HHMMSS-XXXXXX.png`) — safe even
  if you fire several in the same second.
- **Auto-copy the path** to your Mac clipboard so you just ⌘V into the remote prompt.
- **Fails safe on no image** — if the clipboard has no image (e.g. text), it bails *before*
  opening SSH, so no empty/garbage file is ever created remotely.
- **Self-contained for GUI launch** — sets its own `PATH` and recovers `SSH_AUTH_SOCK` from the
  per-user launchd session, so it works from the macOS Shortcuts / launchd sandbox where there
  is no `~/.zshrc` and only a minimal environment.

---

## Setup

### 1. Install the one dependency

```bash
brew install pngpaste
```

Everything else (`ssh`, `scp`, `osascript`, `pbcopy`/`pbpaste`) ships with macOS.

### 2. Drop the script into `~/.local/bin/`

```bash
mkdir -p ~/.local/bin
# copy ccshot.sh from this repo to ~/.local/bin/ccshot
cp ccshot.sh ~/.local/bin/ccshot
chmod +x ~/.local/bin/ccshot
```

Make sure `~/.local/bin` is on your `PATH`. Add this to `~/.zshrc` if it isn't already:

```zsh
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
```

### 3. Tell `ccshot` which host to target

Pick one:

- **Default for every call** — add to `~/.zshrc`:
  ```zsh
  export CCSHOT_HOST=myhost     # use your SSH alias from ~/.ssh/config
  ```
- **Per call** — pass the host as the first argument:
  ```bash
  ccshot myhost
  ```

### 4. (Recommended) SSH connection multiplexing for speed

If your host has a slow handshake (proxies, jump hosts, MFA), reuse one warm connection across
multiple shots. In `~/.ssh/config`:

```sshconfig
Host myhost
  HostName ssh.example.com
  User youruser
  ServerAliveInterval 240
  ControlMaster auto
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlPersist 10m
```

The first `ccshot` of a session pays the handshake; subsequent ones are near-instant for 10
minutes.

### 5. (Optional) Override the remote landing dir

```zsh
export CCSHOT_DIR=screenshots   # default is .ccshots, relative to remote $HOME
```

---

## The script

```zsh
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
```

### Configuration knobs

| Variable / arg | Default | Purpose |
|----------------|---------|---------|
| `ccshot [host]` (1st arg) | *(none)* | Target a specific SSH host for one call. |
| `CCSHOT_HOST` | *(none — required)* | Default host when no arg given. |
| `CCSHOT_DIR` | `.ccshots` | Remote directory (relative to remote `$HOME`). |

Examples:

```bash
ccshot                          # uses $CCSHOT_HOST
ccshot otherhost                # one-off override
CCSHOT_DIR=screenshots ccshot   # land in ~/screenshots instead of ~/.ccshots
```

---

## Daily usage

1. Screenshot to **clipboard**: `⌃⇧⌘4` (region) or `⌃⇧⌘3` (full screen).
   *(The `⌃` Control variant copies to the clipboard instead of saving a file.)*
2. Run `ccshot` — or press the hotkey (below). The remote path is now on your clipboard.
3. In your remote Claude Code session: `⌘V` then Enter. Claude reads the image.

```
$ ccshot
/home/youruser/.ccshots/clip-20260612-185732-309bBY.png
ccshot: ✓ uploaded — path copied to clipboard, paste it into Claude Code
```

If you see `ccshot: no image on the clipboard …`, the clipboard currently holds text (or
nothing). Re-grab a screenshot with `⌃⇧⌘4` and run it again.

---

## Keyboard shortcut (macOS Shortcuts.app)

The hotkey just runs `ccshot` on whatever image is already on the clipboard. The `shortcuts`
CLI can only run/list/view/sign — **authoring must be done in the GUI** (one time):

1. Open **Shortcuts.app** → **File ▸ New Shortcut**.
2. Name it **`ccshot`**.
3. Add the **Run Shell Script** action. Set:
   - **Shell:** `zsh`
   - **Pass Input:** `to stdin` (ignored — there's no input)
   - **Script:** `$HOME/.local/bin/ccshot` *(use the absolute path — the sandbox PATH won't include `~/.local/bin`, but the script self-bootstraps everything else.)*
4. *(Optional)* Add a **Show Notification** action set to the **Shell Script Result** so you get
   a popup with the remote path each time.
5. Open the **Details** panel (ⓘ) → **Add Keyboard Shortcut** → press e.g. **⌃⌥⌘V**.
6. Approve the Accessibility/Automation permission prompt the first time it runs.

Test once with `shortcuts run ccshot` (with an image on the clipboard), then ⌘V to confirm a
remote path landed on your clipboard.

---

## Verification performed

This setup was tested end-to-end, not just written:

- **Lossless round-trip:** a known PNG was placed on the clipboard, uploaded, and the remote
  file's `sha256` matched the local `pngpaste` extraction byte-for-byte.
- **Real screenshot:** confirmed a genuine `⌃⇧⌘4` capture round-tripped (a valid 520×586
  RGBA PNG).
- **Sandbox (the important one):** ran from a stripped, GUI-launched-style environment
  (`env -i`, minimal PATH, no `~/.zshrc`) in **both** warm- and cold-SSH-master states, and
  **even with `SSH_AUTH_SOCK` entirely absent** — all succeeded (rc=0). **The hotkey does not
  require a warm SSH session to be open** as long as your normal SSH auth (keys, agent, or a
  proxy/cookie mechanism) works non-interactively.
- **`pbcopy` works in-sandbox**, so the Shortcut needs no extra "Copy to Clipboard" action.
- **Negative path:** with text (not an image) on the clipboard, `ccshot` exits non-zero with a
  clear message and creates **no** stray remote file.

---

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| `no image on the clipboard` | Clipboard holds text or is empty. Re-screenshot with `⌃⇧⌘4`. |
| `pngpaste not found` | `brew install pngpaste`. |
| `no host configured` | Set `CCSHOT_HOST=myhost` in `~/.zshrc` or pass a host as the first argument. |
| `upload to '<host>' failed` | SSH issue. Test with `ssh <host> true`. May need fresh credentials. |
| Hotkey does nothing | Confirm the Run Shell Script action uses the **absolute** path `$HOME/.local/bin/ccshot`, and that the Shortcut has Accessibility permission. |
| Want capture **and** upload in one keypress | Prepend `screencapture -ic` (interactive region → clipboard) before the script in the Shortcut, or use a Hammerspoon binding. Currently the hotkey only uploads. |

---

## Optional: Hammerspoon hotkey (alternative to Shortcuts.app)

If you'd rather use Hammerspoon (`brew install --cask hammerspoon`), add this to
`~/.hammerspoon/init.lua`:

```lua
-- ⌃⌥⌘S: grab a screen region to the clipboard, then run ccshot and notify with the remote path
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "S", function()
  hs.execute("/usr/sbin/screencapture -i -c")  -- interactive region → clipboard
  hs.timer.doAfter(0.3, function()
    local out, ok = hs.execute("ccshot", true)  -- login shell loads PATH and CCSHOT_HOST
    out = (out or ""):gsub("%s+$", "")
    if ok and out ~= "" then
      hs.pasteboard.setContents(out)
      hs.notify.new({title="ccshot", informativeText=out, withdrawAfter=4}):send()
    else
      hs.notify.new({title="ccshot failed", informativeText=out, withdrawAfter=4}):send()
    end
  end)
end)
```

This variant fuses **capture + upload** into one keypress: press the combo, drag a region, the
remote path lands on your clipboard.

---

## Reference

- The article that inspired this:
  <https://alexanderzeitler.com/articles/paste-clipboard-images-into-claude-code-over-ssh>
  (uses a heavier daemon + reverse-tunnel design; this is the leaner `pngpaste → ssh` workflow.)
