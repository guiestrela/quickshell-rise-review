---
name: rise-bar
description: Install, configure, develop, and diagnose Quickshell Rise Bar on Omarchy, including V1/V2 variants, widgets, and integrations. Use for requests about Rise Bar or Quickshell Rise; not for other bars or general desktop configuration.
---

# Rise Bar

Maintain Rise while preserving the selected variant, saved settings, and the user's plugins. Respond in the user's language.

## Locate the installation and source code

The plugin is `io.github.guiestrela.quickshell-rise`, from
`https://github.com/guiestrela/quickshell-rise-review`.

Identify the checkout used for the task and the actual installation before editing. The default installation is
`~/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise`.
The skill may be installed separately; do not infer the project path from this skill's directory.

Read `README.md` and the relevant files in the checkout. Some documents and scripts retain legacy paths under `~/.config/quickshell`; confirm the active installation mode before following those procedures.

## Install or update

Read [references/installation.md](references/installation.md) to install the bar with fonts, CAVA, AI usage collectors, and the recovery hook. It contains the complete installation command. For documentation-only requests, provide or edit the instructions without running the installation.

For an existing installation, inspect it first:

```bash
omarchy plugin list
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise"
```

Use `omarchy plugin update io.github.guiestrela.quickshell-rise` to update through the manager while respecting local modifications. Do not replace the entire installation with the checkout to apply a small fix. Compare files, preserve local differences, respect the user's stated backup preference, and apply only what is necessary. When creating a backup, keep it outside the plugin's watched tree. Restart with `omarchy restart shell` when the authorized change requires it; a reload may retain cached QML modules.

## Preserve the architecture

- `Bar.qml` is the plugin entry point in the existing `omarchy-shell` process. Do not start a second bar with `qs -p` to test the active installation.
- `versions/V1/core/StateService.qml`, `VariantHost.qml`, and `IpcRouter.qml` control state, loading, and IPC. Only the selected variant should be instantiated.
- V1 is under `versions/V1/`; V2 is under `versions/V1/variants/V2/`. Each `VariantRoot.qml` creates bars for valid outputs; `BarSlot.qml` arranges widgets. Logic and presentation live in `modules/` and `panels/`.
- Before fixing V1/V2, check whether the V2 file has its own implementation or only imports V1. Fix shared behavior without removing intentional visual differences.
- Omarchy services read `fontFamily`, `position`, `barSize`, and `barHidden` from the bar entry point. These values must remain valid during loading and variant switching.
- State and preferences live outside the code: `~/.local/state/quickshell-rise/active-variant`, `~/.cache/quickshell_widgets`, and `~/.cache/quickshell_widgets_v2`, plus integration-specific caches. Do not delete these files to fix a failure without investigating their purpose.
- Preserve notifications, OSD, lock, idle, audio, networking, and other enabled plugins. Do not use `pkill quickshell`, disable plugins in bulk, or edit `/usr/share/omarchy/` to fix Rise.

For V2 geometry, styles, widgets, or side panels, read [references/vertical-bar.md](references/vertical-bar.md).

Consult `docs/integrations.md`, `docs/usage.md`, and `docs/fan-control.md` in the checkout as appropriate for the affected integration. Do not invoke services with real accounts for a test that can use fixtures.

## Diagnose a crash or hang

Distinguish a bar crash, a helper failure, and a system crash. Collect the PID, command line, and timestamp with `pgrep -a quickshell`, `coredumpctl list`, and `coredumpctl info <PID>`. Read the journal for the correct PID; the process may appear as `omarchy-shell` in the journal even though its executable is `quickshell`.

Also inspect the process's own log: `quickshell log --pid <PID> --tail 200 --no-color`. Not every QML warning reaches the journal. If the sandbox cannot see the session's process or socket, that does not prove the shell is stopped; verify in the session context before restarting.

Check memory/OOM and GPU messages for the relevant period. A SIGABRT in `QGuiApplicationPrivate::createPlatformIntegration` from a probe under `/tmp` may indicate failure to access the graphical session before QML loads; do not attribute it to the installed bar without evidence. Lint warnings do not prove a crash either.

Use isolated probes with simulated helpers. `offscreen` works for components without a layer-shell dependency; `PanelWindow` requires an accessible Wayland session. Check the socket before starting these tests. For headless tests, use a temporary runtime directory, a software backend, and `QT_QPA_PLATFORMTHEME=''` to avoid dependencies on the session's GTK/DBus environment.

In QML, look especially for overlapping processes/timers, access to destroyed objects, undefined optional properties, and invalid bindings. Updating a Repeater model may destroy its delegate: restore bindings and capture arguments before the call that updates the model. Do not continue using the delegate after that call.

## Review code and QML warnings

For warning reviews, batch fixes, or differences between tests and the installation, read [references/code-review.md](references/code-review.md). Distinguish runtime errors, code warnings, and metadata limitations; a lower count does not prove a fix.

Continue fixes within the already authorized scope without repeating confirmation requests. Group changes by shared behavior and validate before applying. If the user requests batches of approximately 100 warnings, use that size as a guide without artificially splitting a fix between V1/V2. Combine validated changes to avoid unnecessary restarts.

## Validate a change

Run the relevant tests from the checkout. For a broad review:

```bash
bash tests/run-plugin-checks.sh
```

The runner checks shell syntax, QML, lifecycle/update regressions, the shell integration contract, and JavaScript tests. ShellCheck is optional; report its absence. This command does not replace Wayland interaction tests. Do not edit the runner while it is executing; Bash may read new content at old offsets. Finish edits before final validation.

For monitor changes or monitor lifecycle changes, use the tests with an inert controller as appropriate:

```bash
TMPDIR=/tmp python3 tests/test-display-integration.py
TMPDIR=/tmp python3 tests/test-display-explicit-apply-pointer.py
TMPDIR=/tmp python3 tests/test-display-pointer.py
```

Check each test's session requirements and simulated boundaries before running it. Do not change real monitors, DNS, VPN, Bluetooth pairing, or fan controls merely to test the interface. If the environment blocks a check, report that limitation without declaring it passed.

After applying a fix to the installation, validate the plugin, run `omarchy-shell shell ping`, inspect fresh logs, and compare enabled plugins. Report what changed, the tests run, backup status, and the limits of the evidence; do not promise that future crashes are impossible.
