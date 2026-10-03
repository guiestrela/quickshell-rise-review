# Develop Quickshell Rise

This guide covers repository startup, duplicate-bar prevention, regression tests, linting, and the release checklist. Run development copies by their exact path because Quickshell treats path identity as part of the shell identity.

## Start the repository copy

Stop the installed bar before you launch the checkout. Two bars can overlap and reserve the screen edge twice.

```bash
$HOME/.config/quickshell/bin/qs-barctl stop-wait
```

From the repository root, start the integrated shell entry point:

```bash
qs -p "$PWD/versions/V1/shell.qml"
```

The entry point can load either isolated variant through the shared `VariantHost`. It reads the same external active-variant state as the installed generation.

Press `Ctrl+C` in the launching terminal to stop the development process. Restore the installed bar afterward:

```bash
$HOME/.config/quickshell/bin/qs-barctl start-wait
```

Use the same literal configuration path for startup, logs, IPC, and process selection. Do not replace it with a symlink or a different canonical path during one test run.

## Run the regression suites

Run the repository-wide automated checks from any directory:

```bash
./tests/run-plugin-checks.sh
```

The runner checks shell syntax, runs ShellCheck when installed, lints every QML
file under `versions/`, runs the six isolated shell regression suites, and checks
patch whitespace. It stops at the first failure. QML lint can report existing
warnings from Quickshell-specific types; warnings are counted, while lint errors
fail the run. This command does not replace live V1/V2 checks in a Wayland
session.

The six shell suites use isolated fixtures for lifecycle, installer, updater, theme, package, and AI usage behavior.

Run them from the repository root:

```bash
./tests/qs-arch-update-regression.sh
./tests/qs-barctl-regression.sh
./tests/qs-codex-usage-regression.sh
./tests/qs-quattro-runtime-regression.sh
python3 tests/test_update_panel.py
./tests/qs-theme-update-regression.sh
```

The update panel tests exercise both UI variants with isolated helper fixtures; no package, theme or shell updates are applied. The Shell updater has been removed. Packages and Themes remain available.

Stop after the first failure and preserve its output. A later passing suite does not invalidate an earlier lifecycle or rollback failure.

## Check shell scripts

Validate shell syntax for entry points, helpers, and tests:

```bash
for file in install.sh uninstall.sh \
  scripts/qs-barctl scripts/qs-proj scripts/*.sh tests/*.sh; do
  bash -n "$file" || exit 1
done
```

Run ShellCheck over the same shell surfaces:

```bash
shellcheck --severity=warning install.sh uninstall.sh \
  scripts/qs-barctl scripts/qs-proj scripts/*.sh tests/*.sh
```

Check patch whitespace before committing:

```bash
git diff --check
```

## Check QML changes

Run `qmllint` against every changed QML file. Include the Qt 6 import directory used by the installed Quickshell package.

For example, validate both bar surfaces:

```bash
/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml \
  versions/V1/BarSlot.qml \
  versions/V1/variants/V2/BarSlot.qml
```

Quickshell-specific IPC types can expose local `qmllint` version limits. Treat an exit without diagnostics separately from a reported QML error, then verify the same file through a live load.

## Review runtime behavior

Static checks do not prove layer-shell or animation behavior. Exercise the affected state in the running shell.

For lifecycle and layout changes, verify:

- V1 to V2 and V2 to V1 keep one Quickshell process
- Each variant reaches `ready=true`
- Only one bar surface and one exclusive zone exist per monitor
- Top and bottom positions preserve panel alignment
- Theme changes update colors without restarting another bar
- Disabled hardware widgets do not leave empty space or pointer targets
- A failed target variant returns to the previously ready variant

Use `qs list --all`, controller status, logs, and screenshots as evidence for runtime claims.

## Prepare a release

Release the plugin through the plugin manager or the documented installation workflow. The bar does not update its own Shell generation.

Before updating `main`:

1. Group code and documentation into reviewable commits
2. Run all remaining regression suites and the update-panel tests
3. Run shell syntax, ShellCheck, QML, and whitespace checks
4. Test V1 and V2 through the installed controller
5. Confirm installer, hooks, and controller come from the same commit
6. Push the reviewed branch and update `main` without rewriting published history

Keep the integrated payload, companion helpers and lifecycle controller in the same tested generation. Deployment and shell restarts require separate authorization.

Read [Understand Quickshell Rise architecture](architecture.md) for the lifecycle and deployment boundaries behind these checks.

[Back to the project README](../README.md)
