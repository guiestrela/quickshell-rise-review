# Integrated services

Rise runs as an Omarchy full-bar plugin. These features stay inside its V1 and
V2 interfaces and use Rise colors, typography, spacing, and popup behavior.

## Notifications

When the Omarchy notification service is available, Rise reads its on-screen
notifications and persisted history from `~/.local/state/omarchy/notifications`
and uses Omarchy's notification IPC for dismiss, invoke, clear-history, and DND
actions. Its history window has a separate Wayland namespace from Omarchy's
toast windows. Mako remains a fallback for standalone sessions.

## Weather

The existing weather popup keeps its current conditions and forecast and now
includes a configurable city/place and local radar map. The location is saved
locally; leaving it blank returns to automatic detection. It uses the reported
location, RainViewer radar
tiles, and public Esri map tiles. Network access is needed for current data and
map tiles; when radar metadata is unavailable, the map remains usable without
the overlay.

## Calendar and Google sync

The calendar popup reads local Caldir events and adds **Pull Google** and
**Push Google** actions. Push requires a second click within five seconds.
Calendar helper scripts and their upstream license are in
`versions/V1/integrations/google-calendar/`.

After installing Rise, run the integrated setup from its installed directory:

```bash
~/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise/versions/V1/integrations/google-calendar/setup [--hosted]
```

It installs the release-verified Caldir runtime and guides Google OAuth setup.
It does not change `shell.json` or replace Rise's clock. To install the runtime
without connecting Google yet, run:

```bash
~/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise/versions/V1/integrations/google-calendar/setup --binaries-only
```

OAuth has two modes, and the popup offers both as a choice while Google is not
connected yet:

- **Direct** (default) uses your own Google Cloud OAuth client. Tokens never
  leave this machine and Google, but you must create the client yourself.
- **Hosted** (`--hosted`) relays sign-in and every token refresh through
  caldir.org with its own client. No Google Cloud project is needed, but your
  tokens depend on that relay staying reachable.

An existing session is reused as is, so `--hosted` only picks the mode when
there is nothing to reuse. When the runtime is installed but no session
exists, the popup switches modes with `calendar-auth-mode switch` instead of
re-running setup.

The popup hides its Google choices once the runtime is installed and a Google
session exists, and reports any blocking setup reason in the popup itself.
That check is available on its own:

```bash
~/.config/omarchy/plugins/io.github.guiestrela.quickshell-rise/versions/V1/integrations/google-calendar/setup --check
```

It only verifies that this build can reach its pinned Caldir release, without
downloading, installing, or signing in. The pinned sha256 digest is always
enforced, and a checkout that owns the pinned release is also checked against
it. Rise vendors this integration and publishes no Caldir release of its own,
so it resolves the release from
`guiestrela/omarchy-google-calendar-clock-refresh`; set
`CALENDAR_CLOCK_RELEASE_REPOSITORY` or `CALENDAR_CLOCK_ASSET_BASE_URL` to
override.

The calendar can also read existing local Caldir calendars without Google
sync. Required setup tools are `curl`, `jq`, `tar`, and `sha256sum`.

## NordVPN

The network popup reports NordVPN status and supports connect, disconnect, and
connecting to a country entered in the Rise panel. The bar pill adds a small
VPN mark while connected. Install and authenticate the official NordVPN Linux
client first; the controls use its `nordvpn` CLI. The panel also exposes the
client's Firewall, Kill Switch, Real-time Protection, OpenVPN protocol, and
pause controls. Real-time Protection requires NordVPN DNS and may reset a
custom DNS configuration.

## Wallpaper folder

Open any Rise wallpaper picker and click **+ FOLDER** to add a recursive media
folder. Right-click that control to clear the folder. Choosing a folder requires `zenity`.
The folder is saved in
`~/.cache/quickshell-rise/wallpaper-folder`, and its images join the existing
Rise picker and Omarchy transition flow. Scanning is bounded to 32 directory
levels and 10,000 entries, and does not follow symlinks.

The manager deals a different image to each display, supports still images,
animated GIFs, and silent looping videos. Select an image in the Rise picker to
pin it across displays until the next manual or timed shuffle. It updates Omarchy's current
background from the primary display for lock-screen use. Middle-click the
palette widget for the next set. Set `RISE_WALLPAPER_INTERVAL` to at least 60
seconds to enable automatic shuffling. `RISE_WALLPAPER_DIR` overrides the saved
folder.
