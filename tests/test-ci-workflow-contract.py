#!/usr/bin/env python3
"""Validate the parsed portable workflow contract and unchanged release gate."""
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parent.parent
workflow_path = ROOT / ".github/workflows/ci-portable.yml"
assert workflow_path.is_file(), "missing portable pull-request/push workflow"
workflow = yaml.safe_load(workflow_path.read_text(encoding="utf-8"))
events = workflow.get("on", workflow.get(True, {}))
assert workflow.get("name") == "Portable CI"
assert isinstance(events, dict)
assert events.get("pull_request", {}).get("branches") == ["main"]
assert events.get("push", {}).get("branches") == ["main"]
assert workflow.get("permissions") == {"contents": "read"}
job = workflow.get("jobs", {}).get("portable")
assert isinstance(job, dict), "missing portable job"
assert job.get("runs-on") == "ubuntu-latest"
assert job.get("timeout-minutes") == 15
steps = job.get("steps")
assert isinstance(steps, list)
assert {step.get("uses") for step in steps if step.get("uses")} == {
    "actions/checkout@v4", "actions/setup-python@v5", "actions/setup-node@v4"
}
checkout = next(step for step in steps if step.get("uses") == "actions/checkout@v4")
assert checkout.get("with", {}).get("persist-credentials") is False
python_setup = next(step for step in steps if step.get("uses") == "actions/setup-python@v5")
assert python_setup.get("with", {}).get("python-version") == "3.12"
node_setup = next(step for step in steps if step.get("uses") == "actions/setup-node@v4")
assert node_setup.get("with", {}).get("node-version") == "22"
assert any("PyYAML==6.0.3" in step.get("run", "") for step in steps)
assert any(step.get("run") == "bash tests/run-portable-checks.sh" for step in steps)
assert (ROOT / "tests/run-portable-checks.sh").is_file()
assert "manifest.json" not in workflow_path.read_text(encoding="utf-8")
assert (ROOT / ".github/workflows/release-on-version.yml").is_file()
print("Parsed portable PR/push workflow contract PASS")
