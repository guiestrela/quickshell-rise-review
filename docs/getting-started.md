# Install Quickshell Rise

Rise runs inside Omarchy's existing shell as a full-bar plugin. Use the plugin
manager for installation, activation, and updates. The standalone instructions
later in this guide apply only to legacy installations.

## Check the requirements

The supported plugin requires Omarchy with its Quickshell plugin system.
Install fonts before enabling Rise. The dependency checks in the legacy
standalone installer do not run when the plugin manager adds Rise.

Install the required packages:

```bash
sudo pacman -S \
  quickshell git jq curl pacman-contrib coreutils util-linux procps-ng \
  ttf-jetbrains-mono-nerd ttf-material-symbols-variable
```

Optional packages enable hardware controls and individual widgets:

```bash
sudo pacman -S \
  wireplumber libpulse pamixer brightnessctl upower \
  power-profiles-daemon bluez-utils iwd impala hypridle \
  gpu-screen-recorder cava
```

The optional commands affect these surfaces:

- **Audio**: `wpctl`, `pactl`, and `pamixer`
- **Brightness**: `brightnessctl`
- **Battery and power profiles**: `upower` and `powerprofilesctl`
- **Bluetooth**: `bluetoothctl`
- **Wi-Fi**: `iwctl` and `impala`
- **Idle control**: `hypridle`
- **Screen recording**: `gpu-screen-recorder`
- **Media waveform**: `cava`

## AI usage availability

The supported Rise setup installs all four collectors and their user systemd
timers automatically; it does not install provider CLIs or require accounts,
credentials, or usage data. Python 3 and a working user systemd manager are
required for collector installation. Claude and Codex report data only when
their local sessions/credentials and supported data sources are available;
OpenCode needs its local usage database; Copilot needs existing `gh` auth.
Without provider data, the widget has no usage to show; the bar remains usable.

## Install the Omarchy plugin

Follow the complete [README installation command](../README.md#install) to install
fonts, CAVA, the plugin, AI collectors, and the optional recovery hook.
For a minimal plugin installation after its dependencies are available:

```bash
omarchy plugin add https://github.com/guiestrela/quickshell-rise-review.git --enable
omarchy restart shell
```

The plugin lives at `~/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise`.
The plugin manager does not execute `install.sh` or install AI collectors; use
the separate collector command in the README. Enabling the plugin loads Rise
at shell startup; no standalone post-boot hook is needed.

Both variants are included. Switch through Rise's controls or its scoped IPC:

```bash
quickshell ipc -p "$OMARCHY_PATH/shell" call quickshell-rise.variant activate v2
```

To return to the built-in bar:

```bash
omarchy plugin disable io.github.guiestrela.quickshell-rise
omarchy restart shell
```

Disabling preserves the installed plugin and settings. Do not use the legacy
uninstaller below to remove a plugin-managed installation.

## Legacy standalone installation

The remaining installation, autostart, and removal commands in this guide are
for the standalone `~/.config/quickshell/bar` layout only. Do not run them beside
an enabled Rise plugin.

### Install an interface

The V1 and V2 arguments select the interface that opens after installation. Both interfaces are installed inside the same shell generation.

Install V1:

```bash
curl -fsSL https://raw.githubusercontent.com/guiestrela/quickshell-dots/main/install.sh | bash -s V1
```

Install V2:

```bash
curl -fsSL https://raw.githubusercontent.com/guiestrela/quickshell-dots/main/install.sh | bash -s V2
```

The installer writes the shell to `~/.config/quickshell/bar`. A foreign configuration at that path is moved to `~/.config/quickshell/bar.bak.<timestamp>` before installation.

Reinstalling Rise keeps the previously active interface unless you pass `V1` or `V2`. It also preserves a custom `quotes.txt` from the installed Rise directory.

### Legacy standalone installer flags

The standalone `install.sh` also installs AI usage collectors on every run.
`--ai-backend` is accepted as a compatibility no-op; `--no-ai-backend` is
rejected because collectors are now required. These flags do not affect the
Omarchy plugin-manager setup described in the [README](../README.md#install).

| Flag | Result |
|---|---|
| `--autostart` | Install the Omarchy post-boot hook and let Rise manage the stock-bar state |
| `--no-autostart` | Remove the Rise post-boot hook and leave persistent startup disabled |
| `--ai-backend` | Deprecated compatibility flag; collectors are installed regardless |
| `--no-ai-backend` | Rejected; AI usage collectors are required |

For example, install V2 with autostart and the AI usage backends:

```bash
curl -fsSL https://raw.githubusercontent.com/guiestrela/quickshell-dots/main/install.sh | bash -s V2 --autostart
```

Without an autostart flag, an existing Rise hook is refreshed. On a new
interactive Omarchy Quattro install, the installer asks whether to enable Rise at
login and hide the stock bar. Pressing Enter accepts the default **Yes**. Other new
Omarchy installs print the manual hook commands. A non-interactive install without
either flag starts Rise for the current session and leaves persistent startup
unchanged.

### Understand autostart behavior

On Omarchy Quattro, `--autostart` hides the stock bar only after Rise reports the requested variant and `ready=true`. Rise records ownership of that hidden state so the uninstaller can restore it without overriding a choice made by another tool.

On Omarchy installations without Quattro, Rise starts after login through the same post-boot hook. Other Hyprland environments need their own session startup entry because they do not expose the Omarchy hook system.

### Install the post-boot hook manually

Install the published Omarchy hook when Rise is already installed without `--autostart`:

```bash
mkdir -p "$HOME/.config/omarchy/hooks/post-boot.d"
curl -fsSL \
  -o "$HOME/.config/omarchy/hooks/post-boot.d/quickshell-rise" \
  https://raw.githubusercontent.com/guiestrela/quickshell-dots/main/contrib/post-boot.d/quickshell-rise
chmod +x "$HOME/.config/omarchy/hooks/post-boot.d/quickshell-rise"
```

The hook starts Rise, waits for lifecycle readiness, and then hides an owned Quattro stock bar. It leaves the stock bar visible when Rise does not become healthy.

### Remove Quickshell Rise

The uninstaller stops the registered Rise instance, removes installed helpers and hooks, and restores the previous configuration when a backup exists.

Run the published uninstaller:

```bash
curl -fsSL https://raw.githubusercontent.com/guiestrela/quickshell-dots/main/uninstall.sh | bash
```

The uninstaller restores the Quattro stock bar only when Rise owns that state. A stock bar hidden before Rise was installed remains unchanged.

## Continue with Rise

Read [Use Quickshell Rise](usage.md) for interface controls, widgets, styles, keybindings, and inter-process communication (IPC). Use [Maintain and recover Quickshell Rise](maintenance-and-recovery.md) for lifecycle commands, updates, logs, and recovery.

[Back to the project README](../README.md)
