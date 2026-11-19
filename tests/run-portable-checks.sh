#!/usr/bin/env bash
# Portable PR checks only; native Quickshell/Wayland gates remain separate.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

check() {
  local name="$1"
  shift
  printf '==> %s\n' "$name"
  "$@"
  printf 'PASS: %s\n' "$name"
}

check_shell_syntax() {
  local file first_line
  while IFS= read -r -d '' file; do
    [[ -f "$file" ]] || continue
    IFS= read -r first_line < "$file" || true
    if [[ "$file" == *.sh || "$first_line" == '#!/usr/bin/env bash' || "$first_line" == '#!/bin/bash' ]]; then
      bash -n "$file"
    fi
  done < <(git ls-files -z --cached --others --exclude-standard -- '*.sh' scripts core hooks contrib shared tests)
}

check_python_syntax() {
  python3 - <<'PYTHON'
import ast
from pathlib import Path

for directory in ('scripts', 'core', 'shared', 'tests'):
    for source in Path(directory).rglob('*'):
        if not source.is_file():
            continue
        data = source.read_bytes()
        if source.suffix == '.py' or (data.startswith(b'#!') and b'python3' in data.split(b'\n', 1)[0]):
            ast.parse(data, filename=str(source))
PYTHON
}

check "shell syntax" check_shell_syntax
check "Python syntax" check_python_syntax
check "portable workflow contract" python3 tests/test-ci-workflow-contract.py
check "PR CI security negative mutations" python3 tests/test_pr_ci_security.py
check "PR CI security workflow parse" python3 tests/test_pr_ci_security.py --workflow .github/workflows/ci-portable.yml
check "source layout and local imports" python3 tests/test-source-layout.py
check "cache writes preserve argv boundaries" python3 tests/test-cache-write-argv.py
check "AI authentication cache fallback" python3 tests/test-ai-auth-status.py
check "qs-barctl regression" bash tests/qs-barctl-regression.sh
check "JavaScript regressions" node --test tests/*.test.mjs tests/*.test.cjs tests/test-display-*.cjs
printf 'PORTABLE CI CHECKS PASSED\n'
