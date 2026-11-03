# Code review, lint, and regressions

## Diagnose before modifying

Count warnings in the current checkout without reusing totals from an earlier session. Use the same `qmllint` version, imports, and options before and after. Record files analyzed, warnings, categories, and failures; a zero exit status does not mean there are no warnings.

The project runner counts console lines beginning with `Warning:`. The JSON report may also include diagnostics that the console does not show. Use JSON to locate suggestions, but do not mix the two metrics when reporting a reduction. Do not reduce coverage or disable categories to obtain a lower count.

### `PanelWindow` and metadata

Tooling may resolve the public `PanelWindow` type as the non-instantiable `Quickshell._Window` interface, while the runtime selects a platform implementation. This can produce `Type PanelWindow is not creatable. [uncreatable-type]` for valid code. The Quickshell documentation describes language server limitations when resolving `PanelWindow`:

https://quickshell.org/docs/v0.3.2/guide/install-setup/

Do not assume every warning in this category is false. Check imports, the installed version's `.qmltypes`, and a minimal example. Confirm on Wayland with an isolated hidden window, without loading the production bar. If the example loads, relevant tests pass, and logs are healthy, report the tooling limitation and preserve the component. Do not modify metadata in `/usr/lib`, switch backends, or add suppressions merely to clear lint. Do not hardcode a warning count in the skill: it varies with code and dependencies.

For a broad review, record which components produce warnings and compile those components in the runtime. Compiling with `Qt.createComponent` does not instantiate panel services; this and a hidden window validate resolution/loading, but do not prove interaction with every panel.

## Fix scope without changing behavior

- Qualify external object references with the correct ID, such as `notifPanel.root`. Distinguish the external `root` ID from an internal component's `root` property; a collision may point to the wrong object.
- Use `pragma ComponentBehavior: Bound` when internal components need IDs from their creation context. Check delegates afterward: roles previously injected implicitly by the model may need `required property var modelData` or `required property int index`.
- Use clear local IDs for properties in inline components and delegates. Do not globally replace identifiers without checking scope, comments, strings, and handlers.
- Automatic lint suggestions help insert prefixes, but review the diff. JSON offsets use UTF-16 code units; do not apply them as UTF-8 byte indices. Inserting an ID into a single-line declaration also requires a valid separator.
- Preserve commands, arguments, visibility guards, and timers. Capture data before updating models that may destroy the delegate.

## Shared contracts, responses, and resources

When extracting or fixing a shared panel, check the V1 and V2 root contracts. A property present only in V2, such as `aiUsageReveal`, must not be implicitly required in V1. Test opening/closing with both roots and preserve animation progress where it exists.

Validate the entire response being used before replacing the displayed state. Catching an exception after updating temperature, location, or other fields can leave new data alongside an old forecast. Cover valid JSON with an invalid structure, incomplete lists, null entries, and zero values; do not use truthiness as numeric validation.

Packaged resources should resolve relative to the module, for example `Qt.resolvedUrl("../quotes.txt")`, instead of using old installation paths under `~/.config/quickshell`. Preserve the same configuration root and relative structure in the fixture: a resource outside the root may become `qrc:/qs-blackhole` in the Quickshell scanner. When a fixture needs real `FileView` behavior or plugins linked to the Quickshell executable, use `qs`; `qmltestrunner` alone may not load those plugins.

For scanner limits, check the work before materializing the collection. Limiting processing after `list(os.scandir(...))` does not limit enumeration or memory use. The regression should count consumed entries as well as returned results.

## Choose tests that actually exercise the change

Use existing fixtures and extend them for the affected V1/V2 variants and styles. For bindings and interaction, prefer loading production content over duplicating the implementation in the test. Validate observable effects: selected value, submitted identity, confirmation, count, worker shutdown, and late results after closing.

An offscreen fixture may replace the window with an Item/Rectangle and remove layer-shell properties. This tests the content, not the backend. When needed, supplement it with hidden Wayland loading. Do not start the real bar as a probe.

Explicitly mock Process, FileView, collectors, and service boundaries before instantiating panels that query accounts or real state. Being hidden does not prevent `Component.onCompleted` from starting a query. Preserve the necessary mock contract, including `exited`, `started`, and `streamFinished` signals, properties, and methods used. A failure caused by an incomplete mock does not prove a production defect.

Include secondary effects in isolation. Mocking pacman/sudo without mocking `notify-send` can still send real notifications through the inherited bus. Capture these calls in a fixture and verify the expected effect without accessing the session.

Permission fixtures must control the simulated chain of trust. `/tmp` is writable by other users; actual configuration directories may also have different permissions than expected. Mock metadata for ancestors outside the fixture while retaining real checks inside it, including rejection of directories writable by third parties. Do not change user permissions or weaken production validation to make a test pass.

For headless tests, use a temporary runtime directory with mode 0700, `QT_QPA_PLATFORM=offscreen`, the software backend, and `QT_QPA_PLATFORMTHEME=''`. Failure to create an IPC socket under a sandbox may be an environmental restriction: confirm in the authorized context before modifying code. Do not ignore `ERROR` or declare success while a test is blocked.

Regressions that compare exact text may need adjustment after qualifying references. Preserve the assertion's intent and retain behavioral validation; do not weaken a test to make it pass. Also consider runtime diagnostics: QtTest may pass with `ReferenceError`, `TypeError`, `Binding loop`, or `Unable to assign` in the log.

## Apply without overwriting local differences

Compare the checkout, Git base, and installation. The installation may contain old tests and legitimate differences even when the main code matches. Build minimal patches and run `git apply --check` in the installation directory, not in the already edited checkout. A context failure requires inspecting the difference; do not copy the entire file for convenience.

A local migration may leave removed paths in the index and new files still untracked. When discovering validation scripts, consider `git ls-files --cached --others --exclude-standard` and check that each file still exists. Do not interpret a difference in QML file counts as a regression without comparing files. Old empty adapters should only be removed after checking their consumers and preserving a copy when a backup is available.

If an installed test uses an old helper path, fix the fixture to use a temporary tree that preserves production relative paths. Do not run the real helper to compensate for a misplaced mock. Validate in the checkout and repeat relevant tests in the installation when those tests were actually updated.

Restart only after validating and applying authorized changes. Compare enabled plugins before/after, check `omarchy-shell shell ping`, and inspect the correct PID's log. Distinguish simulated tests, native loading, current session health, and remaining limitations in the report. None of these checks guarantees the absence of every future defect.

Before authorized native tests, record the variant and relevant preferences with contents and hashes; keep the snapshot outside the watched tree. Read the handler before clicking: left-clicking the clock toggles `clock12h`; it does not open a calendar. Restore changes made by the test and verify the original state while preserving concurrent user changes. For screenshots of rotated outputs, prefer selecting the output by name and check its transform before using global coordinates.

For reviews that apply changes to the installation, record changed files, backups, checkout and installation results, and final session health. Do not reuse an old suite approval as if it ran after new changes; indicate when only relevant tests were repeated. Distinguish simulated hotplug from physical disconnection, without changing real monitors merely to obtain evidence.
