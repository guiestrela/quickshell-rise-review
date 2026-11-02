# Source layout validation

The runtime now uses sibling `variants/V1/` and `variants/V2/` directories.
The lifecycle controller lives in `core/`; common integrations live in
`shared/integrations/`. All 259 runtime files were retained. Visual modules,
themes, assets, and variant settings remain separate.

Both `Bar.qml` and `shell.qml` register the two variant trees for Quickshell's
virtual filesystem scanner. Local imports, resource URLs, helper URLs, test
paths, documentation, and the legacy installer were updated. The installer
stages `scripts/` beside the runtime so relative helper URLs also work in the
installed standalone tree.

Validation on 2026-11-02:

- `bash tests/run-plugin-checks.sh`: passed in full, including shell syntax,
  ShellCheck, 182 QML files, lifecycle failure/retry, panel and layout tests,
  JavaScript regressions, collectors, installer/recovery, and update panels.
  QML lint reported 24 warnings and no errors.
- `python3 tests/test-source-layout.py`: passed for 209 QML/JavaScript files,
  checking local imports/resources and both entry points.
- `TMPDIR=/tmp python3 tests/test-display-integration.py`: passed. The fixture
  compiled both complete variants without instantiating them and exercised
  the display controller using inert helper commands, including confirmation,
  timeouts, and rollback. It did not change real display configuration.
- `git diff --check`: passed.

The restricted sandbox prevented local IPC socket creation and Wayland access.
The complete suite and display fixture passed when rerun with that access.
The installed Rise plugin and the production shell were not changed or restarted;
this does not constitute live visual acceptance of the installed bar.

Four older manual checks outside the main runner still fail their existing
assertions: `qr04n-nordvpn-contract.mjs`, `qr04n-ux-contract.mjs`,
`qr04w-service-contract.mjs`, and `qr04w-wiring.mjs`. The same failures were
reproduced against an untouched archive of the pre-reorganization HEAD. Their
paths were updated, but their older feature expectations were not changed as
part of this structural refactor.

## Installed runtime acceptance

After applying the reorganized runtime, live checks passed on 2026-11-02:

- Installed runtime files match the tested checkout byte for byte.
- Four real variant changes (`V2 → V1 → V2 → V1 → V2`) completed with
  `phase=active`, `ready=true`, and an empty lifecycle error.
- The same single Quickshell process (PID 280455) served all checks.
- Both physical outputs were checked: DP-1 in landscape and DP-2 rotated into
  portrait. Each had exactly one bar surface throughout the accepted states.
- Reserved space was 38 pixels for V1 and returned to 36 pixels for V2 on both
  outputs. Monitor modes, positions, and rotation were not modified.
- Shell ping succeeded, enabled plugins remained unchanged, and the hashes of
  shell configuration and V1/V2 widget preferences were unchanged.
- Fresh logs across the switches contained no runtime errors.
- The original V2 selection was restored and persisted. The visible V2 bars
  were inspected in top-edge captures from both monitors.

Local evidence is in `/tmp/rise-live-layout-validation/` (state snapshots, layer
and monitor geometry, before/after logs, plugin inventories, and captures).
These checks cover the active lifecycle and bar surfaces; they do not claim
manual interaction coverage of every panel, hardware action, or external account.

## Live panel interaction checks

Additional checks on 2026-11-02 used a temporary Wayland virtual pointer and
virtual keyboard; no test plugin or production source instrumentation was added.

Twenty panel open/close scenarios passed:

- V1: Control, CPU, memory, audio, GPU, network, Bluetooth, and Display Manager.
- V2: Control, CPU, memory, audio, network, Bluetooth, Display Manager, GPU,
  thermal sensors, notification history, calendar, and weather.

Panel surfaces were observed through compositor layer snapshots; captures were
saved for rendering inspection. Escape closed the panels. The V2 Control panel
opened on DP-2, closed by Escape there, and a panel opened on DP-1 closed via
the backdrop on DP-2. Final checks retained V2 ready=true, shell ping, the same
PID, enabled plugins, monitor geometry, and reserved space. No runtime errors
were found. An older missing media thumbnail warning remains in the process log.

One interaction did not pass: a second click on the V2 launcher on DP-2 did not
close Control. Escape and backdrop dismissal worked. This behavior was not
attributed to the structural refactor or fixed during these tests.

A coordinate initially assumed to be brightness was the idle-inhibit indicator.
The first click temporarily toggled its in-memory state; automatic review
rejected a blind repeat click. Source inspection confirmed that this state is
not persisted and defaults to false. Switching to V1 destroyed the V2 inhibitor;
on returning to V2, a hover capture confirmed `Idle inhibited: OFF`. Brightness
was excluded because its dedicated widget was not visible. Hardware mutations,
account operations, volume changes, and update/install actions were not tested.

Evidence: `/tmp/rise-panels-live/` and `/tmp/rise-cross-screen-panels.log`.

## Installed maintenance correction

Tests, documentation, and the bundled skill in the active installation were
updated to the reorganized paths on 2026-11-02. Local README content and the
translated skill were preserved. Original maintenance files are backed up under
`~/.local/state/quickshell-rise/backups/maintenance-layout-20261102-122421/`.

The installed lifecycle fixture initially retained the removed
`--no-ai-backend` flag. A checked patch replaced that obsolete invocation with
the inert collector fixture and restored omitted installer safety and runner
checks. Both original files and the intermediate merge were backed up.

`bash tests/run-plugin-checks.sh` subsequently passed in full when launched
from the installed plugin directory, including QML imports, lifecycle tests,
installer/recovery fixtures, and update panels. The formerly missing
`VariantHost.qml` test passed as well. No runtime files were changed and no
shell restart was required for this maintenance correction.
