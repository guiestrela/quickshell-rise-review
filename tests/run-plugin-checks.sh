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
check "shell syntax" bash -n "${shell_files[@]}"

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

qml_files=()
while IFS= read -r -d '' file; do qml_files+=("$file"); done < <(find versions -type f -name '*.qml' -print0)
if [[ "${#qml_files[@]}" -eq 0 ]]; then
  printf 'FAIL: no QML files found under versions/.\n' >&2
  exit 1
fi
check "QML lint (${#qml_files[@]} files)" "$qmllint" -I /usr/lib/qt6/qml "${qml_files[@]}"

regressions=(
  tests/qs-arch-update-regression.sh
  tests/qs-barctl-regression.sh
  tests/qs-codex-usage-regression.sh
  tests/qs-quattro-runtime-regression.sh
  tests/qs-shell-update-regression.sh
  tests/qs-theme-update-regression.sh
)
for suite in "${regressions[@]}"; do
  check "$(basename "$suite")" bash "$suite"
done

check "patch whitespace" git diff --check
printf 'ALL PLUGIN CHECKS PASSED\n'
