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
omarchy plugin add https://github.com/guiestrela/quickshell-dots.git
omarchy plugin enable io.github.guiestrela.quickshell-rise
bash "$HOME/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise/scripts/install-ai-backends"
omarchy restart shell
```

The third command installs the optional Claude, Codex, and OpenCode usage
collectors without changing the plugin installation. It installs providers
available on the system and enables their user timers. Each provider still
needs its local CLI/account or usage database.
See [AI usage dependencies](docs/getting-started.md#install-ai-usage-dependencies)
for the Arch package and provider setup commands.

To show the widget, click the **Launcher** on the bar to open the Control Panel,
then open **Widgets** and turn on **AI usage**. The pill appears when a provider
has an active session or recent usage data.

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
