#!/usr/bin/env python3
"""Guard the portable PR workflow boundary and least-privilege contract."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
workflow = ROOT / ".github/workflows/ci-portable.yml"
assert workflow.is_file(), "missing pull-request workflow: .github/workflows/ci-portable.yml"
source = workflow.read_text(encoding="utf-8")

assert "name: Portable CI" in source
assert "pull_request:" in source
assert "contents: read" in source
assert "runs-on: ubuntu-latest" in source
assert "actions/checkout@v4" in source
assert "actions/setup-node@v4" in source
assert "run: bash tests/run-portable-checks.sh" in source
assert "self-hosted" not in source
assert "manifest.json" not in source
assert (ROOT / "tests/run-portable-checks.sh").is_file()
print("Portable PR workflow contract PASS")
