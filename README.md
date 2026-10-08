# Quickshell Rise

Quickshell Rise is a full-bar plugin for Omarchy. It replaces the built-in
Omarchy bar with the Rise interface and runs inside Omarchy's existing
`omarchy-shell` process. V1 and V2 are included and can be switched without
starting another Quickshell instance.

The project includes system panels and integrations for Omarchy themes,
notifications, audio, network, weather, calendar, NordVPN, and wallpaper
folders. Its bar styling and interactions follow the Quickshell Rise design.

## Requirements

- Omarchy with the Quickshell plugin system and `omarchy-shell`.
- Quickshell dependencies used by the selected Rise widgets.
- Optional integrations require their respective tools or accounts. See
  [Integrated services](docs/integrations.md).

## Install

Install Rise with Omarchy's plugin manager. Confirm the repository when
Omarchy asks:

```bash
omarchy plugin add https://github.com/guiestrela/quickshell-rise-review.git --enable
```

To install the AI usage collectors and their user systemd timers, run:

```bash
"$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise/scripts/install-ai-backends" \
  "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise"
```

The optional post-update recovery hook can be installed with:

```bash
omarchy hook install post-update \
  "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise/contrib/post-boot.d/quickshell-rise"
```

The post-update hook makes Omarchy restart its shell after `omarchy update`
has released the update lock, so the selected Rise bar is loaded from updated
plugin files.

The plugin replaces the built-in bar while enabled. Disable it to return to the
Omarchy bar:

```bash
omarchy plugin disable io.github.guiestrela.quickshell-rise
omarchy restart shell
```

To inspect or validate the installed plugin:

```bash
omarchy plugin list
omarchy plugin validate ~/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise
```

## AI usage

The collector command above installs Claude, OpenCode, Codex, and GitHub
Copilot collectors and their timers. No provider-specific setup is needed.

The installer requires `python3` and a working user `systemd` manager. It
installs each collector script and service/timer unit regardless of whether
provider tools, accounts, credentials, or local data exist. It then reloads
user systemd units and enables/starts all four timers. On missing `systemctl`,
reload, or timer-enable errors it exits non-zero and reports the incomplete
state so it can be repaired by rerunning the installer. Re-running is safe.

Collectors do not install provider CLIs, initiate login, or prime caches during
setup. Each provider only reports data when its own source is available: Claude
needs its local Claude Code credentials and network access; Codex needs its
local Codex account/session; OpenCode needs its local usage database; Copilot
needs an existing `gh` authentication and network access. Missing data does
not block Rise or imply a quota is available.

The installer writes collectors to `~/.local/bin` and units to
`~/.config/systemd/user`. It also disables and removes the legacy
`claude-usage-cookie` and `claude-usage-calc` collectors/units if present.
It does not install provider tools, change Rise's widget configuration, or
activate/restart the bar. The AI usage widget remains governed by the user's
existing Rise widget setting; turn it on in Control Panel → Widgets if desired.

Python 3 is the only collector runtime dependency; provider CLI/account/data
availability affects reported usage, not installation.

To show the widget, click the **Launcher** on the bar to open the Control Panel,
then open **Widgets** and turn on **AI usage**. The pill appears when a provider
has an active session or recent usage data.

## Variants

Rise ships with two interfaces. Both run in the Omarchy shell process and share
the same panels and system integrations.

| Variant | Interface |
|---|---|
| V1 | Original Rise layout with split sections and gap animations |
| V2 | Compact redesign with Full, Fit, Dock, and Notch bar shells |

Switch variants from Rise's built-in controls, or through its scoped IPC target:

```bash
quickshell ipc -p "$OMARCHY_PATH/shell" call quickshell-rise.variant activate v2
```

## Features

- Omarchy theme and system status integration.
- Rise panels for workspaces, audio, network, Bluetooth, brightness, power,
  media, calendar, weather, updates, and notification history.
- Weather forecasts and radar, with a configurable location.
- Local calendar view with optional Google Calendar synchronization.
- NordVPN controls when the official client is installed.
- Per-display wallpaper folders, shuffle, pinning, and scaling controls.
- V1 and V2 layouts, with configurable widget groups and panel styles.

## Documentation

| Guide | Contents |
|---|---|
| [Usage](docs/usage.md) | Widgets, styles, variants, keybindings, and IPC |
| [Integrated services](docs/integrations.md) | Weather, calendar, NordVPN, and wallpaper integration |
| [Architecture](docs/architecture.md) | Variants, state, IPC, and project structure |
| [Maintenance and recovery](docs/maintenance-and-recovery.md) | Updates, logs, compatibility, and recovery |
| [Development](docs/development.md) | Local development and release workflow |

## License

[MIT](LICENSE)
