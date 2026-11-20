#!/usr/bin/env bash
# Explicit, user-invoked bootstrap for the Arch updater's AUR blacklist.
# Installs only per-user helpers/units, enables the weekly timer, and primes
# the list once. It never uses sudo and never edits/removes a local supplement.
set -euo pipefail

fail() {
  printf 'qs-aur-blacklist-setup: %s\n' "$1" >&2
  exit 1
}

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bin="$HOME/.local/bin"
units="$HOME/.config/systemd/user"
fetcher="$repo/scripts/qs-aur-blacklist-fetch.sh"
service="$repo/systemd/qs-aur-blacklist-fetch.service"
timer="$repo/systemd/qs-aur-blacklist-fetch.timer"

[ -x "$(command -v systemctl 2>/dev/null || true)" ] || fail "systemctl is unavailable"
[ -r "$fetcher" ] || fail "blacklist fetcher source is missing"
[ -r "$service" ] || fail "user service source is missing"
[ -r "$timer" ] || fail "user timer source is missing"

mkdir -p "$bin" "$units" "$HOME/.local/share" || fail "cannot create per-user setup directories"

backup_stamp="$(date +%Y%m%d%H%M%S)"
backup_existing() {
  local path="$1" backup="${1}.pre-qs-aur-setup.${backup_stamp}" suffix=0
  [ -e "$path" ] || return 0
  while [ -e "$backup" ]; do
    suffix=$((suffix + 1))
    backup="${1}.pre-qs-aur-setup.${backup_stamp}.${suffix}"
  done
  cp -p "$path" "$backup" || fail "cannot back up existing file: $path"
}

backup_existing "$bin/qs-aur-blacklist-fetch.sh"
backup_existing "$units/qs-aur-blacklist-fetch.service"
backup_existing "$units/qs-aur-blacklist-fetch.timer"
backup_existing "$HOME/.local/share/qs-aur-blacklist.txt"
backup_existing "$HOME/.local/share/qs-aur-blacklist.txt.meta.json"
install -m 755 "$fetcher" "$bin/qs-aur-blacklist-fetch.sh" || fail "cannot install the per-user fetcher"
install -m 644 "$service" "$units/qs-aur-blacklist-fetch.service" || fail "cannot install the per-user service"
install -m 644 "$timer" "$units/qs-aur-blacklist-fetch.timer" || fail "cannot install the per-user timer"

systemctl --user daemon-reload || fail "systemd user manager could not reload units"
systemctl --user enable --now qs-aur-blacklist-fetch.timer \
  || fail "could not enable the weekly per-user refresh timer"

if "$bin/qs-aur-blacklist-fetch.sh"; then
  printf 'AUR protection setup installed and initial refresh succeeded.\n'
else
  rc=$?
  printf 'AUR protection setup installed, but initial refresh failed; protection remains limited.\n' >&2
  exit "$rc"
fi
