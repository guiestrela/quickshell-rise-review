#!/usr/bin/env python3
"""Static security/portability checks for the hosted PR workflow.

Use --workflow PATH to validate a real workflow (requires PyYAML). With no
arguments, run synthetic positive and negative cases (also requires PyYAML).
This is not proof of a hosted execution or a complete action supply-chain audit.
"""
import argparse
import json
import re
import unittest
from pathlib import Path
import yaml

ALLOWED_ACTIONS = {
    "actions/checkout@v4",
    "actions/setup-python@v5",
    "actions/setup-node@v4",
}
UNTRUSTED = re.compile(r"\$\{\{[^}]*\b(?:github\.event|github\.head_ref|inputs\.)")
SECRET = re.compile(r"\$\{\{[^}]*\bsecrets\.")


def _permissions(value, location, errors):
    if not isinstance(value, dict):
        errors.append(location + ": require explicit permission mapping")
        return
    for scope, level in value.items():
        if level not in ("read", "none"):
            errors.append(location + ": elevated permission " + str(scope))


def violations(workflow):
    errors = []
    if not isinstance(workflow, dict):
        return ["workflow must be a mapping"]
    events = workflow.get("on", workflow.get(True, {}))
    if not isinstance(events, dict):
        errors.append("invalid trigger structure")
        events = {}
    if "pull_request_target" in events:
        errors.append("privileged pull_request_target is not a portable PR gate")
    for event in ("pull_request", "push"):
        config = events.get(event)
        if not isinstance(config, dict):
            errors.append("missing " + event + " gate")
            continue
        branches = config.get("branches", [])
        if not isinstance(branches, list) or "main" not in branches:
            errors.append(event + " must be scoped to main")

    _permissions(workflow.get("permissions"), "workflow", errors)
    jobs = workflow.get("jobs")
    if not isinstance(jobs, dict) or not jobs:
        errors.append("no jobs")
        jobs = {}
    for name, job in jobs.items():
        if not isinstance(job, dict):
            errors.append(str(name) + ": job must be a mapping")
            continue
        _permissions(job["permissions"], str(name), errors) if "permissions" in job else None
        if job.get("runs-on") != "ubuntu-latest":
            errors.append(str(name) + ": require GitHub-hosted ubuntu-latest runner")
        steps = job.get("steps")
        if not isinstance(steps, list) or not steps:
            errors.append(str(name) + ": missing steps")
            continue
        actions_seen = set()
        for step in steps:
            if not isinstance(step, dict):
                errors.append(str(name) + ": step must be a mapping")
                continue
            action = step.get("uses")
            if action:
                actions_seen.add(action)
                if action not in ALLOWED_ACTIONS:
                    errors.append(str(name) + ": unreviewed action " + str(action))
                if action == "actions/checkout@v4":
                    config = step.get("with", {})
                    if not isinstance(config, dict) or config.get("persist-credentials") not in (False, "false"):
                        errors.append(str(name) + ": checkout must disable persisted credentials")
            serialized = json.dumps(step, sort_keys=True)
            if UNTRUSTED.search(serialized):
                errors.append(str(name) + ": untrusted PR expression used in a step")
            if SECRET.search(serialized):
                errors.append(str(name) + ": secret dependency in portable PR gate")
        if "actions/checkout@v4" not in actions_seen:
            errors.append(str(name) + ": checkout step is required")
        if "actions/setup-python@v5" not in actions_seen:
            errors.append(str(name) + ": Python version must be explicit")
        if "actions/setup-node@v4" not in actions_seen:
            errors.append(str(name) + ": Node.js version must be explicit")
        run_commands = [step.get("run", "") for step in steps if isinstance(step, dict)]
        if "bash tests/run-portable-checks.sh" not in run_commands:
            errors.append(str(name) + ": missing portable check runner")
    return errors


def safe_fixture():
    return {
        "on": {"pull_request": {"branches": ["main"]}, "push": {"branches": ["main"]}},
        "permissions": {"contents": "read"},
        "jobs": {"portable": {"runs-on": "ubuntu-latest", "steps": [
            {"uses": "actions/checkout@v4", "with": {"persist-credentials": False}},
            {"uses": "actions/setup-python@v5", "with": {"python-version": "3.12"}},
            {"uses": "actions/setup-node@v4", "with": {"node-version": "22"}},
            {"run": "bash tests/run-portable-checks.sh"},
        ]}},
    }


class WorkflowSecurityTests(unittest.TestCase):
    def test_safe_hosted_workflow(self):
        self.assertEqual(violations(safe_fixture()), [])

    def test_rejects_semantic_security_mutations(self):
        mutations = [
            lambda w: w.update(permissions="write-all"),
            lambda w: w["permissions"].update(contents="write"),
            lambda w: w["on"].update(pull_request_target={"branches": ["main"]}),
            lambda w: w["on"].pop("push"),
            lambda w: w["on"]["push"].update(branches=["release"]),
            lambda w: w["jobs"]["portable"].update(permissions={"id-token": "write"}),
            lambda w: w["jobs"]["portable"].update({"runs-on": ["self-hosted", "linux"]}),
            lambda w: w["jobs"]["portable"]["steps"][0]["with"].update({"persist-credentials": True}),
            lambda w: w["jobs"]["portable"]["steps"].append({"run": 'echo "${{ github.event.pull_request.title }}"'}),
            lambda w: w["jobs"]["portable"]["steps"].append({"run": 'echo "${{ github.head_ref }}"'}),
            lambda w: w["jobs"]["portable"]["steps"].append({"run": 'echo "${{ inputs.command }}"'}),
            lambda w: w["jobs"]["portable"]["steps"].append({"env": {"TOKEN": "${{ secrets.PRIVATE_TOKEN }}"}}),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(case=index):
                workflow = safe_fixture()
                mutate(workflow)
                self.assertTrue(violations(workflow))

    def test_rejects_yaml_comment_and_expression_mutations(self):
        valid = """name: Portable CI
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  portable:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - uses: actions/setup-python@v5
      - uses: actions/setup-node@v4
      - run: bash tests/run-portable-checks.sh
"""
        mutations = [
            valid.replace("contents: read", "contents: write # contents: read"),
            valid.replace("  pull_request:\n", "  pull_request_target: # pull_request:\n"),
            valid.replace(
                "bash tests/run-portable-checks.sh",
                "bash tests/run-portable-checks.sh && echo '${{ github.event.pull_request.title }}'",
            ),
        ]
        for index, text in enumerate(mutations):
            with self.subTest(case=index):
                self.assertTrue(violations(yaml.safe_load(text)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workflow", type=Path)
    args = parser.parse_args()
    if args.workflow:
        import yaml
        issues = violations(yaml.safe_load(args.workflow.read_text(encoding="utf-8")))
        for issue in issues:
            print("CI_SECURITY: " + issue)
        if issues:
            raise SystemExit(1)
        print("STATIC_SECURITY_GATE_OK: not a workflow execution or full CI acceptance")
        return
    unittest.main(argv=["test_pr_ci_security.py"], verbosity=2)


if __name__ == "__main__":
    main()
