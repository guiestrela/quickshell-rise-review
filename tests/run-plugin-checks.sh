#!/usr/bin/env bash
# One-command repository checks for Quickshell Rise.
# Run from any directory; regression suites use isolated fixtures.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

check() {
  local name="$1" log="$tmp/check.log" warnings
  shift
  printf '==> %s\n' "$name"
  if "$@" >"$log" 2>&1; then
    warnings="$(grep -c '^Warning:' "$log" || true)"
    if [[ "$warnings" -gt 0 ]]; then
      printf 'PASS: %s (%s warnings)\n' "$name" "$warnings"
    else
      printf 'PASS: %s\n' "$name"
    fi
  else
    local status=$?
    cat "$log"
    printf 'FAIL: %s (exit %s)\n' "$name" "$status" >&2
    return "$status"
  fi
}

shell_files=(install.sh uninstall.sh scripts/qs-barctl scripts/qs-proj scripts/*.sh tests/*.sh)
check_shell_syntax() {
  local file
  for file in "${shell_files[@]}"; do
    bash -n "$file" || return "$?"
  done
}
check "shell syntax" check_shell_syntax

if command -v shellcheck >/dev/null 2>&1; then
  check "ShellCheck" shellcheck --severity=warning "${shell_files[@]}"
else
  printf 'SKIP: ShellCheck (not installed)\n'
fi

if [[ -x /usr/lib/qt6/bin/qmllint ]]; then
  qmllint=/usr/lib/qt6/bin/qmllint
elif command -v qmllint >/dev/null 2>&1; then
  qmllint="$(command -v qmllint)"
else
  printf 'FAIL: qmllint is required; install the Qt 6 QML tooling.\n' >&2
  exit 127
fi

check_qml() {
  local file count=0 warnings=0 file_warnings status
  printf '==> QML lint (Bar.qml and all files under versions/)\n'
  while IFS= read -r -d '' file; do
    count=$((count + 1))
    if "$qmllint" -I /usr/lib/qt6/qml "$file" >"$tmp/qmllint.log" 2>&1; then
      file_warnings="$(grep -c '^Warning:' "$tmp/qmllint.log" || true)"
      warnings=$((warnings + file_warnings))
    else
      status=$?
      rg '^Error:' "$tmp/qmllint.log" || true
      file_warnings="$(grep -c '^Warning:' "$tmp/qmllint.log" || true)"
      printf 'FAIL: QML lint %s (exit %s; %s warnings)\n' "$file" "$status" "$file_warnings" >&2
      return "$status"
    fi
  done < <(find Bar.qml versions -type f -name '*.qml' -print0)
  if [[ "$count" -eq 0 ]]; then
    printf 'FAIL: no QML files found.\n' >&2
    return 1
  fi
  printf 'PASS: QML lint (%s files; %s warnings)\n' "$count" "$warnings"
}
check_qml

check "variant failure and retry" python3 tests/test-variant-failure-runtime.py
check "network SSID width" python3 tests/test-network-ssid-width.py
check "weather radar lifecycle" python3 tests/test-weather-radar-lifecycle.py
check "system panel bindings" python3 tests/test-system-panels-runtime.py
check "energy panel bindings" python3 tests/test-energy-panels-runtime.py
check "calendar and workspace panels" python3 tests/test-calendar-workspace-panels.py
check "AI widget mouse actions" python3 tests/test-ai-widget-click.py

check "JavaScript regressions" node --test tests/*.test.mjs tests/*.test.cjs tests/test-display-*.cjs
check "bar style previews" python3 tests/test-bar-style-preview.py
check "vertical bar layout" python3 tests/test-vertical-bar-layout.py
check "V1 vertical bar layout" python3 tests/test-v1-vertical-bar.py
check "vertical workspaces" python3 tests/test-vertical-workspaces.py
check "workspace focus and navigation" python3 tests/test-workspace-focus-runtime.py
check "AI collector installation" bash tests/install-ai-backends-integration.sh
check "Codex cache fallback" env TMPDIR="$tmp" python3 tests/codex-cache-fallback-regression.py
check "Codex pipe framing" python3 tests/codex-rpc-buffer-regression.py
check "wallpaper scanner" env TMPDIR="$tmp" python3 tests/test_qr04w_scan.py

regressions=(
  tests/qs-arch-update-regression.sh
  tests/qs-barctl-regression.sh
  tests/qs-codex-usage-regression.sh
  tests/qs-copilot-usage-regression.sh
  tests/qs-quattro-runtime-regression.sh
  tests/qs-theme-update-regression.sh
)
for suite in "${regressions[@]}"; do
  check "$(basename "$suite")" bash "$suite"
done

check "update panel contract/runtime" python3 tests/test_update_panel.py

check "patch whitespace" git diff --check
printf 'ALL PLUGIN CHECKS PASSED\n'
