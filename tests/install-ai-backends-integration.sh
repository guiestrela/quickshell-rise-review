#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
mockbin="$tmp/mockbin"
mkdir -p "$home" "$mockbin"
export HOME="$home" PATH="$mockbin:$PATH"
export SYSTEMCTL_LOG="$tmp/systemctl.log"
export OMARCHY_LOG="$tmp/omarchy.log"

cat > "$mockbin/systemctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
[[ "${SYSTEMCTL_FAIL:-}" != "$*" ]]
MOCK
cat > "$mockbin/omarchy" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$OMARCHY_LOG"
[[ "$1 $2" == "plugin add" ]]
mkdir -p "$RISE_PLUGIN_DIR/scripts" "$RISE_PLUGIN_DIR/systemd"
cp "$RISE_SOURCE/scripts/install-ai-backends" "$RISE_PLUGIN_DIR/scripts/install-ai-backends"
chmod +x "$RISE_PLUGIN_DIR/scripts/install-ai-backends"
for collector in claude-usage opencode-usage codex-usage copilot-usage; do
  cp "$RISE_SOURCE/scripts/$collector" "$RISE_PLUGIN_DIR/scripts/$collector"
done
for provider in claude opencode codex copilot; do
  for suffix in service timer; do
    cp "$RISE_SOURCE/systemd/$provider-usage.$suffix" "$RISE_PLUGIN_DIR/systemd/$provider-usage.$suffix"
  done
done
MOCK
cat > "$mockbin/claude" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected Claude invocation\n' >&2; exit 91
MOCK
cat > "$mockbin/codex" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected Codex invocation\n' >&2; exit 92
MOCK
cat > "$mockbin/opencode" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected OpenCode invocation\n' >&2; exit 93
MOCK
cat > "$mockbin/gh" <<'MOCK'
#!/usr/bin/env bash
printf 'unexpected gh invocation\n' >&2; exit 94
MOCK
chmod +x "$mockbin"/*
export RISE_SOURCE="$repo"
export RISE_PLUGIN_DIR="$home/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise"
export RISE_PLUGIN_REPO_URL="https://example.invalid/quickshell-rise.git"

# Exercise the documented one-command path with no flags, provider CLIs, auth,
# caches, network, or real systemd/DBus. Omarchy and systemctl are record-only mocks.
"$repo/scripts/install-rise" > "$tmp/first.log"
[[ "$(cat "$OMARCHY_LOG")" == "plugin add https://example.invalid/quickshell-rise.git" ]]
for provider in claude opencode codex copilot; do
  [[ -x "$home/.local/bin/$provider-usage" ]]
  [[ -f "$home/.config/systemd/user/$provider-usage.service" ]]
  [[ -f "$home/.config/systemd/user/$provider-usage.timer" ]]
done
[[ "$(wc -l < "$SYSTEMCTL_LOG")" -eq 6 ]]
rg -Fx -- '--user daemon-reload' "$SYSTEMCTL_LOG" >/dev/null
for provider in claude opencode codex copilot; do
  rg -Fx -- "--user enable --now $provider-usage.timer" "$SYSTEMCTL_LOG" >/dev/null
done
! rg -q 'gh auth|prime|cache|codex --|opencode --|claude --' "$SYSTEMCTL_LOG"

# Run the collector installer again to prove file-copy idempotency and the same
# deterministic systemd request set.
"$RISE_PLUGIN_DIR/scripts/install-ai-backends" "$RISE_PLUGIN_DIR" > "$tmp/second.log"
[[ "$(wc -l < "$SYSTEMCTL_LOG")" -eq 12 ]]

# Missing systemd support must fail explicitly before touching user files.
missing="$tmp/missing-systemctl"
mkdir -p "$missing/bin" "$missing/home"
ln -s "$(command -v python3)" "$missing/bin/python3"
if PATH="$missing/bin" HOME="$missing/home" /usr/bin/bash "$repo/scripts/install-ai-backends" "$repo" >"$tmp/missing.out" 2>&1; then
  printf 'expected missing-systemctl failure\n' >&2; exit 1
fi
rg -q 'systemctl is required.*No collector files were changed' "$tmp/missing.out"
[[ ! -e "$missing/home/.local/bin" ]]

# A timer-enable error must be non-zero and clearly reported, not claimed as success.
if SYSTEMCTL_FAIL='--user enable --now codex-usage.timer' HOME="$home" "$repo/scripts/install-ai-backends" "$repo" >"$tmp/fail.out" 2>&1; then
  printf 'expected systemd enable failure\n' >&2; exit 1
fi
rg -q 'files are installed, but its timer could not be enabled' "$tmp/fail.out"

printf 'AI_USAGE_INSTALL_INTEGRATION_PASS\n'
