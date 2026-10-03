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

Add the repository as an Omarchy plugin and select it as the active bar:

```bash
omarchy plugin add https://github.com/guiestrela/quickshell-rise-review.git
omarchy plugin enable io.github.guiestrela.quickshell-rise
omarchy hook install post-update "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise/contrib/post-boot.d/quickshell-rise"
omarchy restart shell
```

The post-update hook makes Omarchy restart its shell after `omarchy update`
has released the update lock, so the selected Rise bar is loaded from the
updated plugin files. Omarchy's plugin installer does not run plugin scripts,
so this hook is installed explicitly as part of setup.

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

## Optional AI usage collectors

The AI usage collectors are optional and are not required to install or run
the bar. To install them after adding the plugin:

```bash
bash "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise/scripts/install-ai-backends"
```

The script requires `python3` and installs collectors as follows:

- **Claude and OpenCode:** installed even if their CLIs or local usage data
  are not yet available. Displaying usage still requires the relevant local
  account/session or usage database.
- **Codex:** installed when the `codex` command is available.
- **GitHub Copilot:** installed when `gh` is available and authenticated.

The script writes collectors to `~/.local/bin` and service/timer units to
`~/.config/systemd/user`, reloads the user systemd manager, enables and starts
the installed providers' timers, and runs the collectors once to prime their
caches. When migrating an older setup, it also disables and removes the legacy
`claude-usage-cookie` and `claude-usage-calc` collectors and their units.
It does not change the plugin installation.

See [AI usage dependencies](docs/getting-started.md#install-ai-usage-dependencies)
for the Arch package and provider setup commands.

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
