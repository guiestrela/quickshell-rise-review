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

Install Rise and its AI usage collectors in one setup command. In Omarchy's
prompts, confirm that you want to add the repository. When it asks whether to
enable Rise, decline if you want to review the installed plugin first:

```bash
curl -fsSL https://raw.githubusercontent.com/guiestrela/quickshell-rise-review/main/scripts/install-rise | bash
```

This uses `omarchy plugin add` (the Omarchy manager does not run plugin install
hooks), then installs all four local collectors and their user systemd timers.
When run through the command above, the installer passes the terminal to
Omarchy so both prompts remain interactive. The repository must be cloned
before the installer can continue. Confirm the checkout exists before
rescanning and enabling Rise:

```bash
test -d "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise" || {
  echo "Rise was not installed. Re-run the install command and confirm adding the repository." >&2
  exit 1
}
omarchy-shell shell rescanPlugins
for _ in {1..20}; do
  omarchy plugin list | grep -Fq 'io.github.guiestrela.quickshell-rise' && break
  sleep 0.25
done
omarchy plugin list | grep -Fq 'io.github.guiestrela.quickshell-rise' || {
  echo "Rise is not registered. Check the plugin checkout and manifest first." >&2
  exit 1
}
omarchy plugin enable io.github.guiestrela.quickshell-rise
omarchy restart shell
```

If you accepted activation during the add prompt, skip the enable command.
The rescan is asynchronous, so wait for Rise to appear in `omarchy plugin list`
before enabling it. If it never appears, validate the checkout before retrying:

```bash
omarchy plugin validate "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise"
```

Install the optional post-update recovery hook only after confirming its source
file exists in the plugin checkout:

```bash
HOOK="$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise/contrib/post-boot.d/quickshell-rise"
test -f "$HOOK" && omarchy hook install post-update "$HOOK"
```

The post-update hook makes Omarchy restart its shell after `omarchy update`
has released the update lock, so the selected Rise bar is loaded from updated
plugin files. It is separate from AI usage setup.

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

The installation command above also installs the Claude, OpenCode, Codex, and
GitHub Copilot collectors and their timers automatically. No separate AI setup
command or installation flag is needed.

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
