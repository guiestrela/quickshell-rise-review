pragma ComponentBehavior: Bound
import QtQuick
import "../../shared/logic/ThemeValues.js" as ThemeValues
import "../../shared/logic/ThemeWallpaper.js" as ThemeWallpaper
import "../../shared/logic/ThemeIntegrations.js" as ThemeIntegrations
import "../../shared/logic/ThemePalette.js" as ThemePalette
import "../../shared/logic/ThemePanels.js" as ThemePanels
import "../../shared/logic/ThemeAiUsage.js" as ThemeAiUsage
import "../../shared/logic/ThemeLauncher.js" as ThemeLauncher
import "../../shared/logic/ThemeTray.js" as ThemeTray
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "../../shared/logic/Palette.js" as Palette
import "modules"
import "../../shared/logic/WallpaperProfile.js" as WallpaperProfile
import "../../shared/controllers" as CommonControllers
import "../../shared/services" as CommonServices

Item {
    id: theme
    property var variantHost: null
    readonly property alias omarchyIndicators: indicators
    CommonServices.OmarchyIndicators {
        id: indicators
        root: theme
        shell: theme.variantHost && theme.variantHost.omarchyShell !== undefined
            ? theme.variantHost.omarchyShell : null
    }

    property string omarchyCurrentRoot: Quickshell.env("HOME") + "/.config/omarchy/current"
    property string omarchyInstallRoot: Quickshell.env("HOME") + "/.local/share/omarchy"
    property bool omarchyCurrentRootResolved: false
    readonly property string themeNamePath: omarchyCurrentRoot + "/theme.name"
    readonly property string colorsPath: omarchyCurrentRoot + "/theme/colors.toml"
    readonly property string currentBackgroundPath: omarchyCurrentRoot + "/background"
    readonly property string currentBackgroundsPath: omarchyCurrentRoot + "/theme/backgrounds"
    // Optional wallpaper-manager folder. The existing Rise picker, preview
    // pipeline, and Omarchy background transition remain the presentation
    // layer; this adds a user-owned recursive source without a second shell.
    property string wallpaperManagerFolder: String(Quickshell.env("RISE_WALLPAPER_DIR") || "").replace(/\/+$/, "")
    property bool wallpaperRecursive: true
    property string pendingWallpaperFolder: ""
    property bool wallpaperFolderWritePending: false
    readonly property int wallpaperShuffleInterval: {
        if (wallpaperManagerSettings.intervalSec !== undefined) {
            var stored = Number(wallpaperManagerSettings.intervalSec)
            return isFinite(stored) ? Math.max(0, Math.min(86400, Math.floor(stored))) : 0
        }
        var seconds = parseInt(String(Quickshell.env("RISE_WALLPAPER_INTERVAL") || "0"), 10)
        return isFinite(seconds) && seconds >= 60 ? Math.min(seconds, 86400) : 0
    }
    readonly property bool wallpaperShuffleOnWake: wallpaperManagerSettings.shuffleOnWake === true
    readonly property bool wallpaperWakeAvailable: variantHost ? variantHost.wallpaperWakeAvailable : false
    readonly property bool wallpaperSessionLocked: variantHost ? variantHost.wallpaperSessionLocked : false
    readonly property bool wallpaperScreensaverShowing: variantHost ? variantHost.wallpaperScreensaverShowing : false
    function setWallpaperShuffleSettings(patch) { return ThemeWallpaper.setWallpaperShuffleSettings(theme, {}, patch) }
    property string currentThemeName: ""
    readonly property string userBackgroundsPath: currentThemeName === ""
        ? ""
        : Quickshell.env("HOME") + "/.config/omarchy/backgrounds/" + currentThemeName
    readonly property var wallpaperSourcePaths: {
        var paths = [currentBackgroundsPath]
        if (userBackgroundsPath !== "") paths.push(userBackgroundsPath)
        if (wallpaperManagerFolder !== "") paths.push(wallpaperManagerFolder)
        return paths
    }

    CommonServices.WallpaperManagerService { id: wallpaperManagerService; theme: theme }
    readonly property var wallpaperManagerServiceApi: wallpaperManagerService
    property var wallpaperManagerSettings: ({ folder: wallpaperManagerFolder, recursive: true,
        perDisplayConfig: false, displayConfig: { all: { folder: wallpaperManagerFolder,
            recursive: true, mode: "shuffle", scaling: "zoom", pinned: "" } } })
    readonly property var wallpaperOutputs: wallpaperManagerService.liveScreens
    property string wallpaperManagerDisplay: "all"
    property string wallpaperManagerTab: "displays"
    property bool wallpaperManagerVisible: false
    property real wallpaperManagerAnchorX: 0
    property real wallpaperManagerAnchorY: 0
    onWallpaperManagerVisibleChanged: popupOpened("wallpaperManagerVisible")
    function wallpaperProfileFor(name) { return ThemeIntegrations.wallpaperProfileFor(theme, {WallpaperProfile: WallpaperProfile, Quickshell: Quickshell}, name) }
    function setWallpaperProfile(patch, outputName) { return ThemeWallpaper.setWallpaperProfile(theme, {WallpaperProfile: WallpaperProfile, Quickshell: Quickshell, wallpaperManagerService: wallpaperManagerService}, patch, outputName) }
    function setWallpaperPerDisplay(enabled) { return ThemeWallpaper.setWallpaperPerDisplay(theme, {wallpaperManagerService: wallpaperManagerService}, enabled) }
    FileView {
        id: wallpaperProfileFile
        path: Quickshell.env("HOME") + "/.cache/quickshell-rise/wallpaper-manager.json"
        printErrors: false
        onLoaded: {
            try {
                var parsed = JSON.parse(String(text() || "{}"))
                if (parsed && typeof parsed === "object") {
                    theme.wallpaperManagerSettings = parsed
                    theme.wallpaperManagerDisplay = parsed.perDisplayConfig && theme.wallpaperOutputs.length > 0
                        ? String(theme.wallpaperOutputs[0].name) : "all"
                    wallpaperManagerService.scanFolder()
                }
            } catch (error) { console.warn("[WallpaperManager] Ignoring invalid profile settings") }
        }
    }
    Process {
        id: wallpaperProfileDirectory
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell-rise"]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) wallpaperProfileFile.setText(JSON.stringify(theme.wallpaperManagerSettings, null, 2) + "\n")
        }
    }
    function saveWallpaperProfile() { return ThemeWallpaper.saveWallpaperProfile(theme, {wallpaperProfileDirectory: wallpaperProfileDirectory}) }
    function shuffleWallpapers() { return ThemeValues.shuffleWallpapers(theme, {wallpaperManagerService: wallpaperManagerService}) }
    function nextWallpaper(outputName) { return ThemeWallpaper.nextWallpaper(theme, {wallpaperManagerService: wallpaperManagerService}, outputName) }
    function pinWallpaper(path) { return ThemeValues.pinWallpaper(theme, {wallpaperManagerService: wallpaperManagerService}, path) }

    FileView {
        id: wallpaperFolderFile
        path: Quickshell.env("HOME") + "/.cache/quickshell-rise/wallpaper-folder"
        printErrors: false
        onLoaded: {
            if (String(Quickshell.env("RISE_WALLPAPER_DIR") || "") !== "") return
            theme.wallpaperManagerFolder = String(text() || "").trim().replace(/\/+$/, "")
        }
    }
    Process {
        id: wallpaperFolderDirectoryProc
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell-rise"]
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0 || !theme.wallpaperFolderWritePending) return
            wallpaperFolderFile.setText(theme.pendingWallpaperFolder + "\n")
            theme.pendingWallpaperFolder = ""
            theme.wallpaperFolderWritePending = false
        }
    }
    function setWallpaperManagerFolder(path) { return ThemeWallpaper.setWallpaperManagerFolder(theme, {wallpaperFolderDirectoryProc: wallpaperFolderDirectoryProc}, path) }


    function setCurrentThemeName(rawName) { return ThemeIntegrations.setCurrentThemeName(theme, {}, rawName) }

    function reloadCurrentThemeFiles() { return ThemeIntegrations.reloadCurrentThemeFiles(theme, {themeReloadDebounce: themeReloadDebounce}) }

    property color paper:   "#181616"
    property color ink:     "#c5c9c5"
    property color sumi:    "#a6a69c"
    property color color01: "#c4746e"
    property color color02: "#8a9a73"
    property color color03: "#c8b36a"
    property color color04: "#658594"
    property color color05: "#957fb8"
    property color color06: "#7aa89f"
    property color color07: "#c8c093"
    readonly property color inkDeep: color07
    readonly property color indigo:  color04
    readonly property color sealRaw: color01
    readonly property color sumiHi:  Qt.rgba(sumi.r*0.45 + ink.r*0.55, sumi.g*0.45 + ink.g*0.55, sumi.b*0.45 + ink.b*0.55, 1.0)  // lifted section-header text
    property color green:   "#8a9a73"   // gate "OK" verdict
    property color accentHint: sealRaw    // filled by palette; default = same as red
    readonly property color foregroundSoft: Qt.rgba(
        ink.r * 0.88 + paper.r * 0.12,
        ink.g * 0.88 + paper.g * 0.12,
        ink.b * 0.88 + paper.b * 0.12,
        1.0)
    property string barColor: "color01"
    property bool widgetIconsForeground: false
    readonly property bool barColorIsAccent: barColor === "accent"
    // Compatibility alias for older local code/reviews that still use the
    // previous boolean name.
    readonly property bool useThemeAccent: barColorIsAccent

    function paletteColor(id) { return ThemePalette.paletteColor(theme, {}, id) }
    function normalizedPaletteId(id) { return ThemePalette.normalizedPaletteId(theme, {}, id) }
    readonly property color seal: paletteColor(barColor)
    // Legacy global foreground switch is retained only for cache compatibility.
    // Widget colors now inherit Bar Color or use a per-GID palette style.
    readonly property color widgetIconColor: seal
    readonly property var barColorOptions: [
        "color01", "color02", "color03", "color04",
        "color05", "color06", "color07", "foreground"
    ]
    function paletteColorValid(id) { return ThemePalette.paletteColorValid(theme, {}, id) }
    function barColorValid(id) { return ThemePalette.barColorValid(theme, {}, id) }
    function barColorLabel(id) { return ThemePalette.barColorLabel(theme, {}, id) }

    readonly property string mono:  "JetBrainsMono Nerd Font"

    // ── transparency knobs (0.0 = fully transparent, 1.0 = opaque) ──
    property bool barFrost: false
    property real barOpacity:  0.94   // durchgehende V2-Leiste
    property real pillOpacity: 0.18   // einzelne Widget-Pillen (workspace, mem, cpu, …)

    readonly property real surfaceOpacity: barOpacity
    readonly property color bg:     Qt.rgba(paper.r, paper.g, paper.b, 0.98)
    readonly property color barBg:  Qt.rgba(paper.r, paper.g, paper.b,
        barFrost ? 0.68 : surfaceOpacity)
    readonly property color pill:   Qt.rgba(paper.r, paper.g, paper.b, pillOpacity)
    readonly property color fg:     ink
    readonly property color muted:  sumi
    readonly property color accent: seal
    readonly property color warn:   seal
    readonly property color sep:    Qt.rgba(ink.r, ink.g, ink.b, 0.18)

    // ── interactive fill tokens (button/tile backgrounds) ──
    // One source of truth so every panel uses the same hover/active/idle alpha
    // instead of ad-hoc rgba literals scattered across the panels.
    readonly property real  fillActiveAlpha: 0.18
    readonly property real  fillHoverAlpha:  0.10
    readonly property color fillActive:      Qt.rgba(seal.r, seal.g, seal.b, fillActiveAlpha) // selected/active OR ghost-action hover
    readonly property color fillHover:        Qt.rgba(seal.r, seal.g, seal.b, fillHoverAlpha)  // light-seal hover (idle chip → this → fillActive)
    readonly property color fillIdle:         Qt.rgba(0, 0, 0, 0.12)              // resting chip (slight darken)
    // faint, NEUTRAL backdrop behind picker thumbnails — NOT an interactive fill.
    // ink-tinted and much weaker than fillIdle so a thumbnail sits on a quiet frame,
    // not on a dark interactive-looking box.
    readonly property color frameWeak:        Qt.rgba(ink.r, ink.g, ink.b, 0.05)
    readonly property color fillPrimaryHover: Qt.lighter(seal, 1.15)                // solid-seal button hover
    function evenW(w) { return ThemeValues.evenW(theme, {}, w) }  // even px width -> integer-centered native text (crisp)

    // ── Multi-monitor popup routing ─────────────────────────────
    // Bars exist per screen, but panels remain singletons. The bar under the
    // pointer publishes its screen + local anchor map before any widget opens a
    // popup, so the singleton panel can move to the correct output.
    property var activePopupScreen: null
    property string activePopupScreenName: ""
    property var barAnchorsByScreen: ({})
    property bool _closingPopups: false
    property var barLayoutControllers: ({})
    property bool _barLayoutSyncing: false

    readonly property bool anyPopupVisible: oneDriveVisible || calendarVisible || cpuVisible || gpuVisible
        || thermalVisible || aiUsageVisible
        || memVisible || volVisible || controlVisible || networkVisible || vpnVisible || bluetoothVisible
        || batteryVisible || brightnessVisible || mprisVisible || weatherVisible
        || workspaceVisible || imagePickerVisible || mediaBrowserVisible || notifVisible
        || powerProfileVisible || storageVisible || archVisible || trayVisible || trayMenuVisible
        || wallpaperManagerVisible || displayManagerVisible
    readonly property bool keyboardPopupVisible: imagePickerVisible || mediaBrowserVisible || wallpaperManagerVisible || displayManagerVisible

    function registerBarLayoutController(screenName, controller) { return ThemePanels.registerBarLayoutController(theme, {}, screenName, controller) }

    function unregisterBarLayoutController(screenName, controller) { return ThemePanels.unregisterBarLayoutController(theme, {}, screenName, controller) }

    function barLayoutControllerScreenValid(screenName) { return ThemeIntegrations.barLayoutControllerScreenValid(theme, {Quickshell: Quickshell}, screenName) }

    function barLayoutControllerKeys() { return ThemeIntegrations.barLayoutControllerKeys(theme, {}) }

    function applyToBarLayoutControllers(actionName) { return ThemePanels.applyToBarLayoutControllers(theme, {}, actionName) }

    function syncBarOrder(sourceScreenName, serialized) { return ThemePanels.syncBarOrder(theme, {}, sourceScreenName, serialized) }

    function resetAllBarLayouts() {
        applyToBarLayoutControllers("defaultLayout")
        resetBarLayoutPresentation()
    }

    function resetBarLayoutPresentation() {
        var separatorsChanged = barSeps.length > 0
        var densityChanged = iconOnlyGids.length > 0
        var widgetFillsChanged = resetAllWidgetFillColors()
        var mprisChanged = mprisBarStyle !== "default"

        if (separatorsChanged) barSeps = []
        if (densityChanged) iconOnlyGids = []

        // mprisBarStyle has its own persistence handler. If it was already at
        // the default, persist the other layout-only resets explicitly.
        if (mprisChanged) mprisBarStyle = "default"
        else if ((separatorsChanged || densityChanged || widgetFillsChanged)
                && _widgetsLoaded) saveWidgets()
    }

    function activatePopupScreen(screen) { return ThemePanels.activatePopupScreen(theme, {}, screen) }

    function activateFocusedPopupScreen() { return ThemePanels.activateFocusedPopupScreen(theme, {Hyprland: Hyprland, Quickshell: Quickshell}) }

    function activatePopupScreenByName(screenName) { return ThemePanels.activatePopupScreenByName(theme, {Quickshell: Quickshell}, screenName) }

    Connections {
        target: Hyprland

        function onFocusedMonitorChanged() {
            // Enabling/disabling an output can move Hyprland focus while the
            // guarded display change is waiting for the user's confirmation.
            if (theme.displayManagerVisible) return
            if (!theme.keyboardPopupVisible || theme.activePopupScreenName === "") return

            var monitor = Hyprland.focusedMonitor
            var focusedName = monitor ? monitor.name : ""
            if (focusedName !== "" && focusedName !== theme.activePopupScreenName) {
                theme.closePopups()
            }
        }
    }

    function isActivePopupScreenName(screenName) { return ThemePanels.isActivePopupScreenName(theme, {}, screenName) }

    function applyAnchor(name, x) {
        if (name === "tray") trayBarX = x
        else if (name === "trayCaret") trayCaretBarX = x
        else if (name === "notif") notifBarX = x
        else if (name === "notifCaret") notifCaretBarX = x
        else if (name === "quickActions") quickActionsBarX = x
        else if (name === "volume") volumeBarX = x
        else if (name === "network") networkBarX = x
        else if (name === "vpn") vpnBarX = x
        else if (name === "battery") batteryBarX = x
        else if (name === "memory") memoryBarX = x
        else if (name === "cpu") cpuBarX = x
        else if (name === "gpu") gpuBarX = x
        else if (name === "thermal") thermalBarX = x
        else if (name === "oneDrive") oneDriveBarX = x
        else if (name === "storage") storageBarX = x
        else if (name === "ai") aiBarX = x
        else if (name === "workspace") workspaceBarX = x
        else if (name === "arch") archBarX = x
        else if (name === "archCaret") archCaretBarX = x
        else if (name === "bluetooth") bluetoothBarX = x
        else if (name === "brightness") brightnessBarX = x
        else if (name === "power") powerBarX = x
        else if (name === "mpris") mprisBarX = x
        else if (name === "weather") weatherBarX = x
        else if (name === "calendar") calendarBarX = x
        else if (name === "launcher") launcherBarX = x
        else if (name === "trayMenu") trayMenuX = x
    }

    function applyActiveBarAnchors() { return ThemePanels.applyActiveBarAnchors(theme, {}) }

    function publishBarAnchors(screenName, anchors) { return ThemePanels.publishBarAnchors(theme, {}, screenName, anchors) }

    function setPanelAnchor(name, x, screenName) { return ThemePanels.setPanelAnchor(theme, {}, name, x, screenName) }

    function closePopups(except) {
        _closingPopups = true
        if (except !== "calendarVisible") calendarVisible = false
        if (except !== "cpuVisible") cpuVisible = false
        if (except !== "gpuVisible") gpuVisible = false
        if (except !== "thermalVisible") thermalVisible = false
        if (except !== "aiUsageVisible") aiUsageVisible = false
        if (except !== "memVisible") memVisible = false
        if (except !== "volVisible") volVisible = false
        if (except !== "controlVisible") controlVisible = false
        if (except !== "networkVisible") networkVisible = false
        if (except !== "vpnVisible") vpnVisible = false
        if (except !== "bluetoothVisible") bluetoothVisible = false
        if (except !== "batteryVisible") batteryVisible = false
        if (except !== "brightnessVisible") brightnessVisible = false
        if (except !== "mprisVisible") mprisVisible = false
        if (except !== "weatherVisible") weatherVisible = false
        if (except !== "workspaceVisible") workspaceVisible = false
        if (except !== "imagePickerVisible") imagePickerVisible = false
        if (except !== "mediaBrowserVisible") mediaBrowserVisible = false
        if (except !== "notifVisible") notifVisible = false
        if (except !== "powerProfileVisible") powerProfileVisible = false
        if (except !== "oneDriveVisible") oneDriveVisible = false
        if (except !== "storageVisible") storageVisible = false
        if (except !== "archVisible") archVisible = false
        if (except !== "trayVisible") trayVisible = false
        if (except !== "trayMenuVisible") trayMenuVisible = false
        if (except !== "wallpaperManagerVisible") wallpaperManagerVisible = false
        if (except !== "displayManagerVisible") displayManagerVisible = false
        hideTooltip()
        _closingPopups = false
    }

    function popupUsesConnectedInset(prop) {
        return prop !== "imagePickerVisible"
            && prop !== "mediaBrowserVisible"
            && prop !== "trayMenuVisible"
    }

    function popupOpened(prop) {
        if (!_closingPopups && theme[prop]) {
            // The new panel surface publishes its clamped caret position on the
            // first reveal tick. Invalidate the previous panel's cached position
            // now so the bar cannot render one frame at that stale anchor.
            if (popupUsesConnectedInset(prop)) panelInsetReady = false
            closePopups(prop)
        }
    }

    function openImagePicker(mode, screen) { return ThemeValues.openImagePicker(theme, {}, mode, screen) }

    function toggleWallpaperManager(screen, anchorItem) { return ThemeWallpaper.toggleWallpaperManager(theme, {}, screen, anchorItem) }

    function toggleImagePicker(mode, screen) { return ThemeValues.toggleImagePicker(theme, {}, mode, screen) }

    function openMediaBrowser(mode) { return ThemeValues.openMediaBrowser(theme, {}, mode) }

    // ── pill/card border (default, non-borderless mode) ──
    // A premium "inactive window border" look: the surface tone (paper) nudged a
    // tick toward the foreground (ink) → a quiet edge a touch brighter than the
    // background, theme-aware in BOTH dark and light palettes. Tune via pillBorderMix.
    property real pillBorderMix: 0.13
    readonly property color pillBorder: Qt.rgba(
        paper.r * (1 - pillBorderMix) + ink.r * pillBorderMix,
        paper.g * (1 - pillBorderMix) + ink.g * pillBorderMix,
        paper.b * (1 - pillBorderMix) + ink.b * pillBorderMix, 1.0)
    // outer frame (the island edge against the wallpaper): a tick brighter than
    // the inner pill border so the bar lifts off the background → two readable
    // borders (subtle inner pills + a defined outer frame).
    property real islandBorderMix: 0.16
    readonly property color islandBorder: Qt.rgba(
        paper.r * (1 - islandBorderMix) + ink.r * islandBorderMix,
        paper.g * (1 - islandBorderMix) + ink.g * islandBorderMix,
        paper.b * (1 - islandBorderMix) + ink.b * islandBorderMix, 1.0)

    // ── V2 continuous edge-bar tokens ──
    // The compact visible strip uses one full-width surface, one quiet
    // screen-facing edge and a shadow cast away from that edge. Keeping these
    // separate from the pill recipe lets widgets and panels retain their
    // established hierarchy.
    readonly property int v2BarHeight: 33
    readonly property int v2NotchFrameThickness: 6
    readonly property int v2NotchFrameRadius: 14
    // Horizontal rhythm for the bar. Closely related icon buttons use the
    // 2px cluster step; icon+text pairs use 4px; independent widgets use 6px;
    // distinct information sections use 8px. A compact action cell stays 22px
    // wide, yielding a calm 24px centre-to-centre pitch inside icon clusters.
    readonly property int v2IconClusterSpacing: 2
    readonly property int v2InlineSpacing: 4
    readonly property int v2WidgetSpacing: 6
    readonly property int v2SectionSpacing: 8
    readonly property int v2ActionIconCellWidth: 22
    readonly property int v2IconGroupPadding: 5
    property real v2BarBorderMix: 0.22
    readonly property color v2BarBorder: Qt.rgba(
        paper.r * (1 - v2BarBorderMix) + ink.r * v2BarBorderMix,
        paper.g * (1 - v2BarBorderMix) + ink.g * v2BarBorderMix,
        paper.b * (1 - v2BarBorderMix) + ink.b * v2BarBorderMix, 1.0)
    readonly property color v2BarShadow: Qt.rgba(0, 0, 0, 0.46)
    // Popovers, tooltips and their interactive tiles share the calmer V2 shape;
    // bar-widget pills remain independently configurable below.
    readonly property int panelRadius: 6
    readonly property int panelButtonRadius: 6
    readonly property color panelBorder: v2BarBorder
    readonly property int panelBorderW: 1
    readonly property color panelOuterBorderColor: panelTooltipBorderEnabled
        ? panelBorder : Qt.rgba(0, 0, 0, 0)
    readonly property int panelOuterBorderW: panelTooltipBorderEnabled ? panelBorderW : 0

    // Fixed V2 geometry. The former Style section was removed; keeping these
    // shared constants avoids duplicating the established dimensions.
    readonly property int   pillRadius:   12
    readonly property int   pillH:        24
    readonly property int   pillBorderW:  1
    readonly property int   islandRadius: 16
    readonly property int   tileRadius:   10
    readonly property int   wsPillPad:    0
    readonly property color pillShadow:   Qt.rgba(0, 0, 0, 0.55)   // dark, theme-independent

    property string lastAppliedName: ""

    // ── Tooltip state ──
    property string tooltipText: ""
    property real tooltipX: 0
    property real tooltipY: 0
    property real tooltipTopY: 0
    property real tooltipBottomY: 0
    property bool tooltipShown: false
    property var tooltipOwner: null   // the widget currently owning the tooltip

    function showTooltip(text, x, topY, bottomY, owner) { return ThemePanels.showTooltip(theme, {}, text, x, topY, bottomY, owner) }

    // hide only if the caller owns the current tooltip (owner match is stable
    // even when the tooltip text changes, e.g. a live timer). A null/undefined
    // owner force-hides. Legacy string args fall back to a text match.
    function hideTooltip(owner) { return ThemePanels.hideTooltip(theme, {}, owner) }

    // safety net: if the owning widget disappears while its tooltip is shown
    // (e.g. ScreenRecord stops mid-hover, or a slot widget gets disabled), force-hide.
    // Via Connections — NOT a `_visible` property whose change-handler writes
    // tooltipOwner (that property read tooltipOwner → binding loop).
    Connections {
        target: theme.tooltipOwner
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (theme.tooltipOwner && !theme.tooltipOwner.visible) {
                theme.tooltipShown = false; theme.tooltipOwner = null;
            }
        }
    }

    // ── Calendar state ──
    property bool calendarVisible: false
    onCalendarVisibleChanged: popupOpened("calendarVisible")
    property int calendarMonthOffset: 0
    property int calendarTick: 0
    property int selectedDay: 0

    readonly property var calendarCells: {
        void calendarTick;
        const now = new Date();
        const first = new Date(now.getFullYear(), now.getMonth() + calendarMonthOffset, 1);
        const year = first.getFullYear();
        const month = first.getMonth();
        const lastDay = new Date(year, month + 1, 0).getDate();
        const startDay = (first.getDay() + 6) % 7;
        const today = new Date();
        const isCurrentMonth = year === today.getFullYear() && month === today.getMonth();
        const cells = [];
        for (let i = 0; i < startDay; i++) cells.push({day: 0, today: false});
        for (let d = 1; d <= lastDay; d++) {
            cells.push({day: d, today: isCurrentMonth && d === today.getDate()});
        }
        while (cells.length < 42) cells.push({day: 0, today: false});
        return cells;
    }

    readonly property string calendarMonthName: {
        const months = ["JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE",
                        "JULY","AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"];
        const now = new Date();
        return months[(now.getMonth() + calendarMonthOffset + 12000) % 12];
    }

    readonly property string calendarYear: {
        const now = new Date();
        const d = new Date(now.getFullYear(), now.getMonth() + calendarMonthOffset, 1);
        return String(d.getFullYear());
    }

    function openCalendar() { return ThemePanels.openCalendar(theme, {}) }

    // ── CPU panel state ──
    property bool cpuVisible: false
    onCpuVisibleChanged: popupOpened("cpuVisible")

    // ── GPU panel state ──
    property bool gpuVisible: false
    onGpuVisibleChanged: popupOpened("gpuVisible")

    // ── Thermal panel state ──
    property bool thermalVisible: false
    onThermalVisibleChanged: popupOpened("thermalVisible")

    // ── AI usage panel state + which tool the bar pill shows ──
    property bool   aiUsageVisible: false
    property real   aiUsageReveal: aiUsageVisible ? 1 : 0
    Behavior on aiUsageReveal {
        NumberAnimation {
            duration: theme.aiUsageVisible ? 160 : 120
            easing.type: theme.aiUsageVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    onAiUsageVisibleChanged: {
        popupOpened("aiUsageVisible")
        if (aiUsageVisible) refreshAiUsage()
    }
    property string aiTool: "claude"   // "claude", "codex", "opencode", or "copilot" — icon shown in the bar

    // ── AI usage data (single source of truth) ───────────────────
    // The bar pill (ClaudeWidget) and the AiUsagePanel both render from these —
    // the cache parsing lives ONLY here so the two views can never drift apart.
    // Token strings are bare "X.XXM / Y.YM"; the pill tooltip appends " tokens".
    property bool   aiClHas: false
    property bool   aiClFresh: false
    property int    aiClPct5h: 0
    property int    aiClPct7d: 0
    property bool   aiClBlocked: false
    property string aiClTokens: ""
    property string aiClRate: ""
    property int    aiClReset5hTs: 0
    property int    aiClReset7dTs: 0
    property int    aiClToday: 0

    property bool   aiCxHas: false
    property bool   aiCxFresh: false
    property int    aiCxPct5h: 0
    property int    aiCxPct7d: 0
    property string aiCxPlan: ""
    property string aiCxTokens: ""
    property string aiCxRate: ""
    property int    aiCxReset5hTs: 0
    property int    aiCxReset7dTs: 0
    property int    aiCxToday: 0
    property var    aiCxBuckets: []
    property var    aiCxWindows: []
    property int    aiCxPrimaryPct: 0
    property string aiCxPrimaryLabel: ""
    property int    aiCxPrimaryResetTs: 0
    property int    aiCxQuotaPct: 0
    property string aiCxQuotaLabel: ""
    property string aiCxLimitStatus: ""
    property string aiCxLimitReachedType: ""

    property bool   aiOcHas: false
    property bool   aiOcFresh: false
    property int    aiOcPct5h: 0
    property int    aiOcPct7d: 0
    property string aiOcPlan: ""
    property string aiOcTokens: ""
    property string aiOcRate: ""
    property string aiOcModel: ""
    property int    aiOcToday: 0
    property var    aiOcModels: []
    property int    aiClockTick: 0

    // ── Copilot: the metered resource is `premium_interactions`, a MONTHLY
    //    allowance of premium requests that resets on the 1st — Copilot has no
    //    Claude/Codex-style 5h/7d window. It therefore carries a single generic
    //    window (43200 min → "30d") plus the raw credit counters. ──
    property bool   aiCpHas: false
    property bool   aiCpFresh: false
    property int    aiCpPct: 0
    property string aiCpLabel: ""
    property int    aiCpResetTs: 0
    property string aiCpPlan: ""
    property string aiCpSku: ""
    property bool   aiCpUnlimited: false
    property int    aiCpCreditsUsed: 0
    property int    aiCpCreditsEntitlement: 0
    property string aiCpLimitReachedType: ""
    property string aiCpStatus: ""

    // F15: clamp an external 0..1 utilization to a 0–100 int (a negative/over-range value would
    // otherwise produce wrong text and negative/overwide usage bars)
    function aiPct(v) { return ThemeValues.aiPct(theme, {}, v) }

    function aiWindowLabel(minutes) { return ThemeAiUsage.aiWindowLabel(theme, {}, minutes) }

    function aiResetCopilotUsage() { return ThemeValues.aiResetCopilotUsage(theme, {}) }

    // Copilot writes the same schemaVersion-3 bucket/window shape as Codex, so the
    // generic window normalizer is reused instead of re-deriving percentages.
    function aiApplyCopilotCache(d, ageOk) { return ThemeAiUsage.aiApplyCopilotCache(theme, {}, d, ageOk) }

    function aiResetCodexUsage() { return ThemeValues.aiResetCodexUsage(theme, {}) }

    function aiCodexWindowFromCache(w) { return ThemeAiUsage.aiCodexWindowFromCache(theme, {}, w) }

    function aiCodexWindowsFromArray(arr) { return ThemeAiUsage.aiCodexWindowsFromArray(theme, {}, arr) }

    function aiCodexLegacyWindowsFromCache(d) { return ThemeAiUsage.aiCodexLegacyWindowsFromCache(theme, {}, d) }

    function aiCodexBucketsFromCache(d) { return ThemeAiUsage.aiCodexBucketsFromCache(theme, {}, d) }

    function aiCodexGeneralBucket(buckets) { return ThemeAiUsage.aiCodexGeneralBucket(theme, {}, buckets) }

    function aiPlanLabel(plan) { return ThemeAiUsage.aiPlanLabel(theme, {}, plan) }

    function aiApplyCodexCache(d, ageOk) { return ThemeAiUsage.aiApplyCodexCache(theme, {}, d, ageOk) }

    function aiCodexStatusLabel(status, reachedType) { return ThemeAiUsage.aiCodexStatusLabel(theme, {}, status, reachedType) }

    function aiFmtReset(ts) { return ThemeAiUsage.aiFmtReset(theme, {aiClockTick: aiClockTick}, ts) }

    function aiPad2(n) { return ThemeValues.aiPad2(theme, {}, n) }

    function aiFmtResetClock(ts) { return ThemeAiUsage.aiFmtResetClock(theme, {aiClockTick: aiClockTick}, ts) }

    function aiFmtResetDetail(ts) { return ThemeAiUsage.aiFmtResetDetail(theme, {}, ts) }

    Process {
        id: aiReadClaude
        command: ["bash", "-c",
            "f=\"$HOME/.cache/claude-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    theme.aiClHas = true
                    theme.aiClFresh = ageOk && d._source !== "stale"
                    theme.aiClPct5h = theme.aiPct(d["5h-utilization"])
                    theme.aiClPct7d = theme.aiPct(d["7d-utilization"])
                    theme.aiClBlocked = d.status === "rejected" || d.status === "blocked"
                    theme.aiClReset5hTs = parseInt(d["5h-reset"]) || 0
                    theme.aiClReset7dTs = parseInt(d["7d-reset"]) || 0
                    var used = (d["_tokens_used"] || 0), lim = (d["_window_limit"] || 0)
                    theme.aiClTokens = used ? (used / 1e6).toFixed(2) + "M / " + (lim / 1e6).toFixed(1) + "M" : ""
                    var rateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    theme.aiClRate = rateH > 0 ? rateH + "k tok/h" : ""
                    theme.aiClToday = parseInt(d._today_tokens) || 0
                } catch (e) {
                    theme.aiClHas = false; theme.aiClFresh = false
                    theme.aiClPct5h = 0; theme.aiClPct7d = 0
                    theme.aiClBlocked = false; theme.aiClTokens = ""; theme.aiClRate = ""
                    theme.aiClReset5hTs = 0; theme.aiClReset7dTs = 0; theme.aiClToday = 0
                }
            }
        }
    }

    Process {
        id: aiReadCodex
        command: ["bash", "-c",
            "f=\"$HOME/.cache/codex-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    theme.aiApplyCodexCache(d, ageOk)
                } catch (e) {
                    theme.aiResetCodexUsage()
                }
            }
        }
    }

    Process {
        id: aiReadCopilot
        command: ["bash", "-c",
            "f=\"$HOME/.cache/copilot-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    theme.aiApplyCopilotCache(JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim()), ageOk)
                } catch (e) {
                    theme.aiResetCopilotUsage()
                }
            }
        }
    }

    Process {
        id: aiReadOpenCode
        command: ["bash", "-c",
            "f=\"$HOME/.cache/opencode-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    theme.aiOcHas = true
                    theme.aiOcFresh = ageOk && d._source !== "stale"
                    theme.aiOcPct5h = theme.aiPct(d["5h-utilization"])
                    theme.aiOcPct7d = theme.aiPct(d["7d-utilization"])
                    theme.aiOcPlan = d._plan || ""
                    var ocUsed = (d["_tokens_used"] || 0), ocLim = (d["_window_limit"] || 0)
                    theme.aiOcTokens = ocUsed ? (ocUsed / 1e6).toFixed(2) + "M / " + (ocLim / 1e6).toFixed(1) + "M" : ""
                    var ocRateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    theme.aiOcRate = ocRateH > 0 ? ocRateH + "k tok/h" : ""
                    theme.aiOcToday = parseInt(d._today_tokens) || 0
                    theme.aiOcModel = d._model || ""
                    theme.aiOcModels = d._models instanceof Array ? d._models : []
                } catch (e) {
                    theme.aiOcHas = false; theme.aiOcFresh = false
                    theme.aiOcPct5h = 0; theme.aiOcPct7d = 0
                    theme.aiOcPlan = ""; theme.aiOcTokens = ""; theme.aiOcRate = ""; theme.aiOcModel = ""
                    theme.aiOcToday = 0; theme.aiOcModels = []
                }
            }
        }
    }

    function refreshAiUsage(selectedOnly) { return ThemeValues.refreshAiUsage(theme, {aiReadClaude: aiReadClaude, aiReadCodex: aiReadCodex, aiReadOpenCode: aiReadOpenCode, aiReadCopilot: aiReadCopilot}, selectedOnly) }

    Timer {
        // 30s normally; 5s while the AI panel is open (responsive when looked at)
        interval: theme.aiUsageVisible ? 5000 : 30000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: theme.refreshAiUsage(theme.aiUsageVisible)
    }

    CommonServices.SystemTelemetry { id: systemTelemetry; owner: theme; cpuDetailsInBar: false }
    property alias systemCpuHistory: systemTelemetry.systemCpuHistory
    readonly property alias systemCpuMaxSamples: systemTelemetry.systemCpuMaxSamples
    property alias gpuHistory: systemTelemetry.gpuHistory
    property alias systemCpuPercent: systemTelemetry.systemCpuPercent
    property alias systemCpuUserPercent: systemTelemetry.systemCpuUserPercent
    property alias systemCpuSystemPercent: systemTelemetry.systemCpuSystemPercent
    property alias systemCpuIoWaitPercent: systemTelemetry.systemCpuIoWaitPercent
    property alias _systemCpuPrevIdle: systemTelemetry._systemCpuPrevIdle
    property alias _systemCpuPrevTotal: systemTelemetry._systemCpuPrevTotal
    property alias _systemCpuPrevUser: systemTelemetry._systemCpuPrevUser
    property alias _systemCpuPrevSystem: systemTelemetry._systemCpuPrevSystem
    property alias _systemCpuPrevIoWait: systemTelemetry._systemCpuPrevIoWait
    property alias cpuModelName: systemTelemetry.cpuModelName
    property alias cpuCoreCount: systemTelemetry.cpuCoreCount
    property alias cpuThreadCount: systemTelemetry.cpuThreadCount
    property alias cpuClockMHz: systemTelemetry.cpuClockMHz
    property alias cpuMaxClockMHz: systemTelemetry.cpuMaxClockMHz
    property alias cpuEnergyPreference: systemTelemetry.cpuEnergyPreference
    property alias cpuScalingGovernor: systemTelemetry.cpuScalingGovernor
    property alias cpuThrottleCount: systemTelemetry.cpuThrottleCount
    property alias systemLoad1: systemTelemetry.systemLoad1
    property alias systemLoad5: systemTelemetry.systemLoad5
    property alias systemLoad15: systemTelemetry.systemLoad15
    property alias kernelRelease: systemTelemetry.kernelRelease
    property alias cpuTopProcesses: systemTelemetry.cpuTopProcesses
    property alias systemMemTotalMiB: systemTelemetry.systemMemTotalMiB
    property alias systemMemAvailMiB: systemTelemetry.systemMemAvailMiB
    property alias systemMemFreeMiB: systemTelemetry.systemMemFreeMiB
    property alias systemMemBuffersMiB: systemTelemetry.systemMemBuffersMiB
    property alias systemMemCachedMiB: systemTelemetry.systemMemCachedMiB
    property alias memoryType: systemTelemetry.memoryType
    property alias memorySpeedMTs: systemTelemetry.memorySpeedMTs
    readonly property alias systemMemUsedMiB: systemTelemetry.systemMemUsedMiB
    readonly property alias systemMemPercent: systemTelemetry.systemMemPercent
    readonly property alias systemMemUsedGiB: systemTelemetry.systemMemUsedGiB
    readonly property alias systemMemTotalGiB: systemTelemetry.systemMemTotalGiB
    property alias gpuBackend: systemTelemetry.gpuBackend
    property alias gpuName: systemTelemetry.gpuName
    property alias gpuDriverVersion: systemTelemetry.gpuDriverVersion
    property alias gpuPercent: systemTelemetry.gpuPercent
    property alias gpuTemperatureC: systemTelemetry.gpuTemperatureC
    property alias gpuMemoryUsedMiB: systemTelemetry.gpuMemoryUsedMiB
    property alias gpuMemoryTotalMiB: systemTelemetry.gpuMemoryTotalMiB
    property alias gpuClockMHz: systemTelemetry.gpuClockMHz
    property alias gpuPowerW: systemTelemetry.gpuPowerW
    property alias gpuPowerLimitW: systemTelemetry.gpuPowerLimitW
    property alias gpuPerformanceState: systemTelemetry.gpuPerformanceState
    property alias gpuFanPercent: systemTelemetry.gpuFanPercent
    property alias gpuFanRpm: systemTelemetry.gpuFanRpm
    readonly property alias gpuAvailable: systemTelemetry.gpuAvailable
    property alias cpuTemperatureC: systemTelemetry.cpuTemperatureC
    property alias cpuCoreMaxTemperatureC: systemTelemetry.cpuCoreMaxTemperatureC
    property alias cpuTemperatureMaxC: systemTelemetry.cpuTemperatureMaxC
    property alias cpuTemperatureCriticalC: systemTelemetry.cpuTemperatureCriticalC
    property alias nvmeTemperatureC: systemTelemetry.nvmeTemperatureC
    property alias nvmeTemperatureMaxC: systemTelemetry.nvmeTemperatureMaxC
    property alias nvmeTemperatureCriticalC: systemTelemetry.nvmeTemperatureCriticalC
    property alias memoryTemperatureC: systemTelemetry.memoryTemperatureC
    readonly property alias cpuTemperatureAvailable: systemTelemetry.cpuTemperatureAvailable
    property alias barTemperatureSource: systemTelemetry.barTemperatureSource
    readonly property alias barTemperatureC: systemTelemetry.barTemperatureC
    readonly property alias barTemperatureAvailable: systemTelemetry.barTemperatureAvailable
    property alias storagePercent: systemTelemetry.storagePercent
    property alias storageUsedBytes: systemTelemetry.storageUsedBytes
    property alias storageTotalBytes: systemTelemetry.storageTotalBytes
    property alias storageAvailable: systemTelemetry.storageAvailable
    readonly property alias storageUsedGiB: systemTelemetry.storageUsedGiB
    readonly property alias storageTotalGiB: systemTelemetry.storageTotalGiB
    property alias storageDrives: systemTelemetry.storageDrives
    property alias storageInventoryAvailable: systemTelemetry.storageInventoryAvailable
    function barTemperatureSourceValid(source) { return ThemeValues.barTemperatureSourceValid(theme, {systemTelemetry: systemTelemetry}, source) }
    function barTemperatureSourceLabel(source) { return ThemeValues.barTemperatureSourceLabel(theme, {systemTelemetry: systemTelemetry}, source) }
    function barTemperatureSourceAvailable(source) { return ThemeValues.barTemperatureSourceAvailable(theme, {systemTelemetry: systemTelemetry}, source) }
    function parseSystemCpu(text) { return ThemeValues.parseSystemCpu(theme, {systemTelemetry: systemTelemetry}, text) }
    function parseCpuInfo(text) { return ThemeValues.parseCpuInfo(theme, {systemTelemetry: systemTelemetry}, text) }
    function parseSystemLoad(text) { return ThemeValues.parseSystemLoad(theme, {systemTelemetry: systemTelemetry}, text) }
    function parseCpuDetail(text) { return ThemeValues.parseCpuDetail(theme, {systemTelemetry: systemTelemetry}, text) }
    function parseCpuTopProcesses(text) { return ThemeValues.parseCpuTopProcesses(theme, {systemTelemetry: systemTelemetry}, text) }
    function parseSystemMem(text) { return ThemeValues.parseSystemMem(theme, {systemTelemetry: systemTelemetry}, text) }
    function parseMemoryHardware(text) { return ThemeValues.parseMemoryHardware(theme, {systemTelemetry: systemTelemetry}, text) }
    function parseGpuTelemetry(text) { return ThemeValues.parseGpuTelemetry(theme, {systemTelemetry: systemTelemetry}, text) }
    function parseThermalTelemetry(text) { return ThemeValues.parseThermalTelemetry(theme, {systemTelemetry: systemTelemetry}, text) }
    function parseStorageInventory(text) { return ThemeValues.parseStorageInventory(theme, {systemTelemetry: systemTelemetry}, text) }
    function parseStorageTelemetry(text) { return ThemeValues.parseStorageTelemetry(theme, {systemTelemetry: systemTelemetry}, text) }

    // ── Memory panel state ──
    property bool memVisible: false
    onMemVisibleChanged: popupOpened("memVisible")

    // ── Volume panel state ──
    property bool volVisible: false
    property real volReveal: volVisible ? 1 : 0
    Behavior on volReveal {
        NumberAnimation {
            duration: theme.volVisible ? 160 : 120
            easing.type: theme.volVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    onVolVisibleChanged: popupOpened("volVisible")

    // ── Control center state ──
    property bool controlVisible: false
    onControlVisibleChanged: {
        popupOpened("controlVisible")
        if (!controlVisible) wwSubVisible = false
    }

    // ── Bar layout / unlock (drag&drop reorder). barUnlocked is transient. ──
    property bool layoutProtected: false
    property bool barUnlocked: false
    property var  fnDefaultLayout: function () { theme.resetAllBarLayouts() }
    property bool wwSubVisible: false   // "Widgets & Workspaces" fly-out

    // ── module enable flags (controlled by ControlPanel) ──
    property bool modStatus:     true
    property bool modIndicators: true
    property bool modMemory:     true
    property bool modCpu:        true
    property bool modCpuTemperature: true
    property bool modGpu:        true
    property bool modOneDrive: false
    onModOneDriveChanged: if (_widgetsLoaded) saveWidgets()
    property string oneDriveOpenTarget: ""
    property bool oneDriveVisible: false
    onOneDriveVisibleChanged: popupOpened("oneDriveVisible")
    property real oneDriveBarX: 0
    readonly property alias oneDriveService: oneDriveServiceInstance
    CommonServices.OneDriveService {
        id: oneDriveServiceInstance
        owner: theme
        pollingEnabled: theme._widgetsLoaded && (theme.modOneDrive || theme.oneDriveVisible)
    }
    property bool modStorage:    true
    property bool modVolume:     true
    property bool modWeather:    true
    property bool modNetwork:    true
    property bool modNordVpn:    false
    property bool modWallpapers: false
    property bool modDisplayManager: false
    property bool displayManagerVisible: false
    property bool displayManagerAutoWorkspaces: true
    property real displayManagerBarX: 0
    property real displayManagerBarY: 35
    readonly property var displayManagerControllerApi: displayManagerController
    function toggleDisplayManager(screen, anchorItem) { return ThemePanels.toggleDisplayManager(theme, {}, screen, anchorItem) }
    CommonControllers.DisplayManagerController { id: displayManagerController; theme: theme }
    property string nordVpnStatus: "Unknown"
    readonly property var nordVpnStatusController: nordVpnController
    function refreshNordVpnStatus() { return ThemeValues.refreshNordVpnStatus(theme, {nordVpnController: nordVpnController}) }
    CommonControllers.NordVpnController {
        id: nordVpnController
        enabled: theme.modNordVpn
        refreshInterval: 15000
        onVpnStateChanged: theme.nordVpnStatus = nordVpnController.vpnState
    }
    property string networkMode: "none"   // mirrored from NetworkWidget: wifi/ethernet/none
    // Centralized status indicators. These live on Theme so BarSlot-per-monitor
    // widgets don't each spawn their own status poller.
    property bool stayAwake: false            // idle lock disabled / stay-awake indicator
    readonly property bool hypridleAwake: stayAwake // compatibility alias for older modules
    property bool _idleBackendChecked: false
    property bool _idleOmarchyShellBackend: false
    property bool _idleOmarchyShellSystem: false
    property bool _omarchyBackendReprobePending: false
    property int _omarchyBackendRetryIndex: 0
    readonly property var _omarchyBackendRetryDelays: [2000, 5000, 15000]
    readonly property string omarchyShellConfigPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    readonly property string idleStatePath: Quickshell.env("HOME") + "/.local/state/omarchy/indicators/stay-awake"
    property bool notifSilenced: false        // notification do-not-disturb mode
    property bool _notifBackendChecked: false
    property bool _notifOmarchyShellBackend: false
    property bool _notifOmarchyShellSystem: false
    property bool _notifQuietStateAvailable: false
    readonly property string notificationsStatePath: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/quiet.json"
    property bool screenRecording: false
    property int screenRecordingElapsed: 0
    property string _screenRecordingPid: ""
    property string _screenRecordingElapsedProbePid: ""
    property int _screenRecordingBaseElapsed: 0
    property real _screenRecordingBaseMs: 0
    readonly property string screenRecordingStatePath: "/tmp/omarchy-screenrecord-filename"
    property bool _recordingRefreshPending: false
    property string voxState: "idle"          // idle/recording/transcribing
    property string voxHint: ""
    property bool voxAvailable: true
    readonly property bool _statusPollingWanted: modStatus
    readonly property bool _voxActive: voxState === "recording" || voxState === "transcribing"

    function refreshIdleStatus() { return ThemeIntegrations.refreshIdleStatus(theme, {idleStateFile: idleStateFile, idleProc: idleProc}) }
    function refreshStatusIndicators() { return ThemeIntegrations.refreshStatusIndicators(theme, {}) }
    function reprobeOmarchyShellBackends() { return ThemeIntegrations.reprobeOmarchyShellBackends(theme, {idleBackendProc: idleBackendProc, notifBackendProc: notifBackendProc}) }
    function finishOmarchyBackendReprobe() { return ThemeIntegrations.finishOmarchyBackendReprobe(theme, {idleBackendProc: idleBackendProc, notifBackendProc: notifBackendProc, omarchyBackendProbeDebounce: omarchyBackendProbeDebounce}) }
    function omarchyBackendRetryNeeded() { return ThemeIntegrations.omarchyBackendRetryNeeded(theme, {}) }
    function scheduleOmarchyBackendRetry() { return ThemeIntegrations.scheduleOmarchyBackendRetry(theme, {omarchyBackendRetryTimer: omarchyBackendRetryTimer, omarchyBackendConfirmTimer: omarchyBackendConfirmTimer}) }
    function resetOmarchyBackendProbes() { return ThemeIntegrations.resetOmarchyBackendProbes(theme, {omarchyBackendRetryTimer: omarchyBackendRetryTimer, omarchyBackendProbeDebounce: omarchyBackendProbeDebounce, omarchyBackendConfirmTimer: omarchyBackendConfirmTimer}) }
    function parseNotificationsState(text) { return ThemeIntegrations.parseNotificationsState(theme, {}, text) }
    function refreshNotificationStatus() { return ThemeIntegrations.refreshNotificationStatus(theme, {notificationsStateFile: notificationsStateFile, dndProc: dndProc}) }
    function refreshRecordingStatus() { return ThemeIntegrations.refreshRecordingStatus(theme, {recordingPidProc: recordingPidProc}) }
    function reconcileSlowStatusIndicators() { return ThemeValues.reconcileSlowStatusIndicators(theme, {}) }
    function setScreenRecordingPid(pid) { return ThemeIntegrations.setScreenRecordingPid(theme, {recordingElapsedProc: recordingElapsedProc}, pid) }
    function updateScreenRecordingElapsed() { return ThemeIntegrations.updateScreenRecordingElapsed(theme, {}) }
    function refreshVoxtypeStatus() {
        if (!voxAvailable && !modStatus) return
        if (voxProc.running) return
        voxProc.running = true
    }

    Process {
        id: idleBackendProc
        command: ["bash", "-c", "root=${OMARCHY_PATH:-/usr/share/omarchy}; [[ -f $root/shell/plugins/services/idle/manifest.json ]] || exit 2; command -v omarchy-shell >/dev/null 2>&1 && OMARCHY_PATH=$root omarchy-shell idle status >/dev/null 2>&1"]
        running: true
        onExited: (exitCode) => {
            theme._idleOmarchyShellSystem = exitCode !== 2
            theme._idleOmarchyShellBackend = exitCode === 0
            theme._idleBackendChecked = true
            theme.refreshIdleStatus()
            theme.finishOmarchyBackendReprobe()
        }
    }

    FileView {
        id: idleStateFile
        path: theme.idleStatePath
        watchChanges: theme._idleOmarchyShellSystem
        printErrors: false
        onFileChanged: idleStateFile.reload()
        onLoaded: {
            if (theme._idleOmarchyShellSystem) theme.stayAwake = true
        }
        onLoadFailed: {
            if (theme._idleOmarchyShellSystem) theme.stayAwake = false
        }
    }

    Process {
        id: notifBackendProc
        command: ["bash", "-c", "root=${OMARCHY_PATH:-/usr/share/omarchy}; [[ -f $root/shell/plugins/notifications/manifest.json ]] || exit 2; command -v omarchy-shell >/dev/null 2>&1 && OMARCHY_PATH=$root omarchy-shell notifications ping 2>/dev/null | grep -Fxq ok"]
        running: true
        onExited: (exitCode) => {
            theme._notifOmarchyShellSystem = exitCode !== 2
            theme._notifOmarchyShellBackend = exitCode === 0
            theme._notifBackendChecked = true
            theme.refreshNotificationStatus()
            theme.finishOmarchyBackendReprobe()
        }
    }

    FileView {
        id: notificationsStateFile
        path: theme.notificationsStatePath
        watchChanges: theme._notifOmarchyShellSystem
        printErrors: false
        onFileChanged: notificationsStateFile.reload()
        onLoaded: {
            theme._notifQuietStateAvailable = true
            if (theme._notifOmarchyShellSystem) theme.parseNotificationsState(notificationsStateFile.text())
        }
        onLoadFailed: {
            theme._notifQuietStateAvailable = false
            notificationsLegacyStateFile.reload()
        }
    }
    FileView {
        id: notificationsLegacyStateFile
        path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications.json"
        watchChanges: theme._notifOmarchyShellSystem && !theme._notifQuietStateAvailable
        printErrors: false
        onFileChanged: if (!theme._notifQuietStateAvailable) reload()
        onLoaded: if (theme._notifOmarchyShellSystem && !theme._notifQuietStateAvailable)
            theme.parseNotificationsState(notificationsLegacyStateFile.text())
        onLoadFailed: if (theme._notifOmarchyShellSystem && !theme._notifQuietStateAvailable)
            theme.notifSilenced = false
    }

    Timer {
        id: omarchyBackendProbeDebounce
        interval: 250
        repeat: false
        onTriggered: theme.reprobeOmarchyShellBackends()
    }

    Timer {
        id: omarchyBackendRetryTimer
        repeat: false
        onTriggered: theme.reprobeOmarchyShellBackends()
    }

    Timer {
        id: omarchyBackendConfirmTimer
        interval: 2000
        repeat: false
        onTriggered: {
            theme._omarchyBackendRetryIndex = Math.max(1, theme._omarchyBackendRetryIndex)
            theme.reprobeOmarchyShellBackends()
        }
    }

    FileView {
        id: omarchyShellConfigFile
        path: theme.omarchyShellConfigPath
        watchChanges: true
        printErrors: false
        onFileChanged: {
            omarchyShellConfigFile.reload()
            theme.resetOmarchyBackendProbes()
        }
    }

    Process {
        id: idleProc
        command: ["pgrep", "-x", "hypridle"]
        running: false
        onExited: (exitCode) => {
            if (!theme._idleOmarchyShellSystem) theme.stayAwake = exitCode !== 0
        }
    }

    Process {
        id: dndProc
        command: ["makoctl", "mode"]
        running: false
        onExited: (exitCode) => {
            if (exitCode !== 0 && !theme._notifOmarchyShellSystem) theme.notifSilenced = false
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (!theme._notifOmarchyShellSystem) theme.notifSilenced = this.text.indexOf("do-not-disturb") >= 0
            }
        }
    }

    Process {
        id: recordingPidProc
        command: ["pgrep", "-o", "-f", "^gpu-screen-recorder"]
        running: false
        onExited: (exitCode) => {
            if (exitCode !== 0) theme.setScreenRecordingPid("")
            if (theme._recordingRefreshPending) {
                theme._recordingRefreshPending = false
                theme.refreshRecordingStatus()
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(/\s+/)
                theme.setScreenRecordingPid(parts[0] || "")
            }
        }
    }

    FileView {
        id: screenRecordingStateFile
        path: theme.screenRecordingStatePath
        watchChanges: true
        printErrors: false
        onFileChanged: {
            screenRecordingStateFile.reload()
            theme.refreshRecordingStatus()
        }
        onLoaded: theme.refreshRecordingStatus()
        onLoadFailed: theme.refreshRecordingStatus()
    }

    Process {
        id: recordingElapsedProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (theme._screenRecordingElapsedProbePid !== theme._screenRecordingPid) return
                var elapsed = parseInt(this.text.trim())
                if (isNaN(elapsed)) elapsed = 0
                theme._screenRecordingBaseElapsed = Math.max(0, elapsed)
                theme._screenRecordingBaseMs = Date.now()
                theme.updateScreenRecordingElapsed()
            }
        }
    }

    Timer {
        interval: 1500
        running: theme._statusPollingWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.refreshStatusIndicators()
    }

    Timer {
        interval: 45000
        running: theme._statusPollingWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.reconcileSlowStatusIndicators()
    }

    Timer {
        interval: 1000
        running: theme.screenRecording
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.updateScreenRecordingElapsed()
    }

    Process {
        id: voxProc
        command: ["bash", "-c",
            "if command -v voxtype >/dev/null 2>&1; then " +
            "timeout 1 voxtype status --extended --format json 2>/dev/null | jq -r '[(.class // .alt // \"idle\"), ((.tooltip // \"\") | split(\"\\n\")[0])] | @tsv' 2>/dev/null; " +
            "else echo 'MISSING'; fi"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                if (parts[0] === "MISSING") {
                    theme.voxAvailable = false
                    theme.voxState = "idle"
                    theme.voxHint = ""
                    return
                }
                theme.voxAvailable = true
                theme.voxState = parts[0] || "idle"
                theme.voxHint = parts[1] || ""
            }
        }
    }
    Timer {
        interval: theme._voxActive ? 1000 : (theme.voxAvailable ? 10000 : 60000)
        running: theme._statusPollingWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: theme.refreshVoxtypeStatus()
    }
    // battery presence (laptop) — drives the Battery indicator tile's visibility (shown only
    // where a battery exists, like Brightness uses hasBacklight). Direct UPower check, event-driven.
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice.isLaptopBattery
    // NetworkManager active (Omarchy 4.0) → the panel's iwctl scan/connect won't work,
    // so it shows an "open nmtui" button instead of an empty list
    property bool useNM: false
    Process {
        command: ["bash", "-c", "systemctl is-active --quiet NetworkManager && echo 1 || echo 0"]
        running: true
        stdout: StdioCollector { onStreamFinished: theme.useNM = this.text.trim() === "1" }
    }

    // ── wifi/bluetooth settings launchers (Omarchy way, via uwsm-app) ──
    // iwd (Omarchy 3.8.x) → impala/bluetui through omarchy-launch-*; if NetworkManager
    // is the active backend (Omarchy 4.0) → nmtui instead. Quattro removed the
    // dedicated Bluetooth launcher; prefer a retained bluetui, then bluetoothctl.
    readonly property string launchWifiCmd: "if systemctl is-active --quiet NetworkManager 2>/dev/null; then omarchy-launch-or-focus-tui nmtui; else omarchy-launch-wifi; fi"
    readonly property string launchBtCmd:   "if command -v omarchy-launch-bluetooth >/dev/null 2>&1; then exec omarchy-launch-bluetooth; elif command -v omarchy-launch-or-focus-tui >/dev/null 2>&1; then if command -v bluetui >/dev/null 2>&1; then command -v rfkill >/dev/null 2>&1 && rfkill unblock bluetooth >/dev/null 2>&1 || true; exec omarchy-launch-or-focus-tui bluetui; elif command -v bluetoothctl >/dev/null 2>&1; then command -v rfkill >/dev/null 2>&1 && rfkill unblock bluetooth >/dev/null 2>&1 || true; exec omarchy-launch-or-focus-tui bluetoothctl; fi; fi; command -v notify-send >/dev/null 2>&1 && notify-send -a QS-Shell -u critical 'Bluetooth settings unavailable' 'No supported Bluetooth settings backend was found' || true; exit 0"
    property bool modPower:      false   // default off (toggle in ControlPanel)
    property bool modBluetooth:  false   // default off (toggle in ControlPanel)
    property bool modBrightness: true
    property bool modMedia:      true
    property bool modQuick:      true    // G10 group pill (idle-inhibitor · media · theme)
    property bool modMpris:      true    // G9 now-playing / mpris pill
    property string mprisBarStyle: "default" // "default" or "full"
    property bool modClaude:     false   // default off (toggle in ControlPanel)

    // backlight presence — set by BrightnessWidget once it probes /sys/class/backlight.
    // ControlPanel uses this to hide the Brightness toggle on desktops without one.
    property bool hasBacklight:  false

    // ── workspace display mode ──
    property string workspaceMode: "10"   // "10", "5", "active"
    // ── workspace display style (orthogonal to mode; persisted) ──
    // "rings" is the stable cache token for the user-facing Frame style.
    property string workspaceStyle: "default"   // default, numbers, magic, kanji, rings, aurora

    // ── bar screen position (persisted) ──
    property string barPosition: "top"   // top, bottom, left, right
    readonly property bool barVertical: barPosition === "left" || barPosition === "right"
    readonly property int verticalBarWidth: barShellStyle === "fit" ? 40 : 36
    property var verticalAnchorsByScreen: ({})
    function verticalAnchorY(name) { return ThemePanels.verticalAnchorY(theme, {}, name) }
    function publishVerticalAnchors(screenName, values) { return ThemePanels.publishVerticalAnchors(theme, {}, screenName, values) }
    // ── outer bar shell (persisted) ──
    // full  = current edge-to-edge strip
    // fit   = centered content-width capsule
    // dock  = centered content-width surface attached to the screen edge
    // notch = attached content-width surface with desktop-facing side wings
    property string barShellStyle: "full"
    property bool barBorderEnabled: true
    property bool spacerDotsEnabled: true
    property bool panelTooltipBorderEnabled: true
    function barShellStyleValid(value) {
        return value === "full" || value === "fit"
            || value === "dock" || value === "notch"
    }

    // ── picker visual style (theme/wallpaper/screenshot/video pickers) ──
    property string pickerStyle: "tanzaku"   // "tanzaku", "hearthstone", "carousel"
    property string launcherLogoMode: "text"     // "text" or "icon"
    property string launcherLogoText: "omarchy"  // "omarchy", "hyprland", "arch", or "omacom"
    property string launcherLogoIcon: "omarchy"  // see launcherLogoIconGlyph()
    property bool   weatherImperial: false   // false = °C / km·h, true = °F / mph
    property bool   clock12h:        false   // false = 24h, true = 12h (AM/PM)

    // ── widget/workspace state persistence ──
    property var barSeps: []
    property var iconOnlyGids: []
    function sepAfter(gid) { return barSeps.indexOf(gid) >= 0 }
    function iconOnly(gid) { return barVertical || iconOnlyGids.indexOf(gid) >= 0 }
    function toggleSep(gid) {
        var a = barSeps.slice()
        var i = a.indexOf(gid)
        if (i >= 0) a.splice(i, 1); else a.push(gid)
        barSeps = a
        if (_widgetsLoaded) saveWidgets()
    }
    function toggleIconOnly(gid) {
        if (gid === "G3") return // Status is an icon-only group by design.
        var a = iconOnlyGids.slice()
        var i = a.indexOf(gid)
        if (i >= 0) a.splice(i, 1); else a.push(gid)
        iconOnlyGids = a
        if (_widgetsLoaded) saveWidgets()
    }
    function parseGidCsv(s) {
        if (!s || s === "-") return []
        var out = []
        var toks = s.split(",")
        for (var i = 0; i < toks.length; i++)
            if (/^G\d{1,2}$/.test(toks[i]) && toks[i] !== "G3") out.push(toks[i])
        return out
    }

    // ── per-widget palette styles ──
    // Stored by stable GID, so slot reordering and temporarily hidden widgets
    // never lose their visual assignment.
    property var widgetSurfaceStyles: ({})
    function widgetSurfaceStyle(gid) {
        return normalizeWidgetSurfaceStyle(widgetSurfaceStyles[gid] || {})
    }
    function normalizeWidgetSurfaceStyle(raw) {
        var opacity = Number(raw.opacity)
        var borderWidth = Number(raw.borderWidth)
        return {
            borderColor: raw.borderColor === "inherit" || paletteColorValid(raw.borderColor) ? raw.borderColor : "inherit",
            opacity: isFinite(opacity) ? Math.max(0.35, Math.min(1, opacity)) : 1,
            radius: ["auto", "square", "soft", "round"].indexOf(raw.radius) >= 0 ? raw.radius : "auto",
            padding: ["auto", "none", "compact", "roomy"].indexOf(raw.padding) >= 0 ? raw.padding : "auto",
            borderWidth: isFinite(borderWidth) ? Math.round(Math.max(0.5, Math.min(2, borderWidth)) * 2) / 2 : 1
        }
    }
    function setWidgetSurfaceStyle(gid, key, value) {
        if (!widgetGidValid(gid) || ["opacity", "radius", "padding", "borderWidth", "borderColor"].indexOf(key) < 0) return
        var style = widgetSurfaceStyle(gid)
        style[key] = value
        var next = Object.assign({}, widgetSurfaceStyles)
        next[gid] = normalizeWidgetSurfaceStyle(style)
        widgetSurfaceStyles = next
        if (_widgetsLoaded) saveWidgets()
    }
    function resetWidgetSurfaceStyle(gid) {
        var next = Object.assign({}, widgetSurfaceStyles)
        delete next[gid]
        widgetSurfaceStyles = next
        if (_widgetsLoaded) saveWidgets()
    }
    function widgetSurfacePadding(gid) {
        var padding = widgetSurfaceStyle(gid).padding
        return padding === "compact" ? 3 : padding === "roomy" ? 6 : 0
    }
    function widgetSurfaceRadius(gid) {
        var radius = widgetSurfaceStyle(gid).radius
        return radius === "square" ? 0 : radius === "soft" ? 6 : radius === "round" ? 12 : panelButtonRadius
    }
    function widgetSurfaceHeight(gid) {
        return gid === "G22" ? 22 : 24
    }
    function serializeWidgetSurfaceStyles() {
        var out = []
        for (var n = 1; n <= 23; n++) {
            var gid = "G" + n
            if (!widgetSurfaceStyles[gid]) continue
            var style = widgetSurfaceStyle(gid)
            out.push([gid, style.opacity, style.radius, style.padding, style.borderWidth, style.borderColor].join("~"))
        }
        return out.length ? out.join(",") : "-"
    }
    function parseWidgetSurfaceStyles(raw) {
        var out = {}
        if (!raw || raw === "-") return out
        var entries = String(raw).split(",")
        for (var i = 0; i < entries.length; i++) {
            var f = entries[i].split("~")
            if ((f.length !== 5 && f.length !== 6) || !widgetGidValid(f[0])
                || !/^(0(?:\.\d+)?|1(?:\.0+)?)$/.test(f[1])
                || Number(f[1]) < 0.35
                || ["auto", "square", "soft", "round"].indexOf(f[2]) < 0
                || ["auto", "none", "compact", "roomy"].indexOf(f[3]) < 0
                || ["0.5", "1", "1.5", "2"].indexOf(f[4]) < 0
                || (f.length === 6 && f[5] !== "inherit" && !paletteColorValid(f[5]))) continue
            out[f[0]] = { opacity: Number(f[1]), radius: f[2], padding: f[3], borderWidth: Number(f[4]), borderColor: f[5] || "inherit" }
        }
        return out
    }

    property var widgetColorStyles: ({})
    function widgetGidValid(gid) {
        var m = String(gid || "").match(/^G(\d{1,2})$/)
        if (!m) return false
        var n = Number(m[1])
        return n >= 1 && n <= 23
    }
    function widgetColorModeValid(mode) {
        return mode === "fill" || mode === "border" || mode === "both"
    }
    function normalizedWidgetColorMode(mode, colorId) {
        var borderOn = mode === "both" || mode === "border"
        if (!borderOn) return "fill"
        return colorId === "inherit" ? "border" : "both"
    }
    function widgetToneValid(tone) {
        return tone === "auto" || tone === "background" || tone === "foreground"
    }
    function widgetColorStyle(gid) {
        var raw = widgetColorStyles[gid]
        var colorId = raw && (raw.color === "inherit" || paletteColorValid(raw.color))
            ? raw.color
            : "inherit"
        return {
            color: colorId,
            mode: raw && widgetColorModeValid(raw.mode)
                ? normalizedWidgetColorMode(raw.mode, colorId)
                : "fill",
            tone: raw && widgetToneValid(raw.tone) ? raw.tone : "auto"
        }
    }
    function setWidgetColorStyle(gid, colorId, mode, tone) {
        if (!widgetGidValid(gid)) return
        var next = {}
        for (var key in widgetColorStyles) next[key] = widgetColorStyles[key]

        var storedColor = colorId === "inherit"
            ? "inherit"
            : (paletteColorValid(colorId) ? colorId : "color01")
        var storedMode = normalizedWidgetColorMode(mode, storedColor)
        if (storedColor === "inherit" && storedMode !== "border") {
            delete next[gid]
        } else {
            next[gid] = {
                color: storedColor,
                mode: storedMode,
                tone: widgetToneValid(tone) ? tone : "auto"
            }
        }
        widgetColorStyles = next
        if (_widgetsLoaded) saveWidgets()
    }
    function setWidgetPaletteColor(gid, colorId) {
        var style = widgetColorStyle(gid)
        setWidgetColorStyle(gid, colorId, style.mode, style.tone)
    }
    function setWidgetColorMode(gid, mode) {
        var style = widgetColorStyle(gid)
        setWidgetColorStyle(gid, style.color, mode, style.tone)
    }
    function setWidgetBorderEnabled(gid, enabled) {
        var style = widgetColorStyle(gid)
        setWidgetColorStyle(gid, style.color,
            enabled ? (style.color === "inherit" ? "border" : "both") : "fill",
            style.tone)
    }
    function setWidgetTone(gid, tone) {
        var style = widgetColorStyle(gid)
        if (style.color !== "inherit") setWidgetColorStyle(gid, style.color, style.mode, tone)
    }
    function resetWidgetColor(gid) {
        var style = widgetColorStyle(gid)
        setWidgetColorStyle(gid, "inherit",
            style.mode === "both" || style.mode === "border" ? "border" : "fill",
            "auto")
    }
    function resetAllWidgetFillColors() {
        var next = {}
        var changed = false

        for (var n = 1; n <= 23; n++) {
            var gid = "G" + n
            var style = widgetColorStyle(gid)

            if (style.color !== "inherit") changed = true
            if (style.mode === "border" || style.mode === "both") {
                next[gid] = {
                    color: "inherit",
                    mode: "border",
                    tone: "auto"
                }
            }
        }

        if (changed) widgetColorStyles = next
        return changed
    }
    function widgetPaletteId(gid) { return widgetColorStyle(gid).color }
    function widgetColorMode(gid) { return widgetColorStyle(gid).mode }
    function widgetTone(gid) { return widgetColorStyle(gid).tone }
    function widgetHasFill(gid) {
        var style = widgetColorStyle(gid)
        return style.color !== "inherit"
    }
    function widgetHasBorder(gid) {
        var style = widgetColorStyle(gid)
        return style.mode === "border" || style.mode === "both"
    }
    function widgetAssignedColor(gid) {
        var id = widgetPaletteId(gid)
        return id === "inherit" ? seal : paletteColor(id)
    }
    function _linearColorChannel(v) { return ThemePalette._linearColorChannel(theme, {}, v) }
    function _relativeLuminance(c) { return ThemePalette._relativeLuminance(theme, {}, c) }
    function _contrastRatio(a, b) { return ThemePalette._contrastRatio(theme, {}, a, b) }
    function paletteContrastColor(id) { return ThemePalette.paletteContrastColor(theme, {}, id) }
    function widgetContrastColor(gid) {
        var fill = widgetAssignedColor(gid)
        var tone = widgetTone(gid)
        if (tone === "background") return paper
        if (tone === "foreground") return ink
        return _contrastRatio(fill, paper) >= _contrastRatio(fill, ink) ? paper : ink
    }
    function widgetContentColor(gid, fallback) {
        return widgetHasFill(gid) ? widgetContrastColor(gid) : fallback
    }
    function widgetFillColor(gid) {
        return widgetHasFill(gid) ? widgetAssignedColor(gid) : Qt.rgba(0, 0, 0, 0)
    }
    function widgetBorderColor(gid) {
        if (!widgetHasBorder(gid)) return Qt.rgba(0, 0, 0, 0)
        var colorId = widgetSurfaceStyle(gid).borderColor
        return colorId === "inherit" ? panelBorder : paletteColor(colorId)
    }
    function serializeWidgetColorStyles() {
        var out = []
        for (var n = 1; n <= 23; n++) {
            var gid = "G" + n
            var style = widgetColorStyle(gid)
            if (style.color !== "inherit" || style.mode === "border")
                out.push(gid + "~" + style.color + "~" + style.mode + "~" + style.tone)
        }
        return out.length ? out.join(",") : "-"
    }
    function parseWidgetColorStyles(raw) {
        var out = {}
        if (!raw || raw === "-") return out
        var entries = String(raw).split(",")
        for (var i = 0; i < entries.length; i++) {
            var fields = entries[i].split("~")
            if (fields.length !== 4 || !widgetGidValid(fields[0])
                    || (fields[1] !== "inherit" && !paletteColorValid(fields[1]))
                    || !widgetColorModeValid(fields[2])
                    || !widgetToneValid(fields[3])) continue
            out[fields[0]] = {
                color: fields[1],
                mode: normalizedWidgetColorMode(fields[2], fields[1]),
                tone: fields[3]
            }
        }
        return out
    }

    readonly property string widgetsCachePath: Quickshell.env("HOME") + "/.cache/quickshell_widgets_v2"
    property bool _widgetsLoaded: false

    onModMemoryChanged:     if (_widgetsLoaded) saveWidgets()
    onModCpuTemperatureChanged: if (_widgetsLoaded) saveWidgets()
    onModGpuChanged:        if (_widgetsLoaded) saveWidgets()
    onModStorageChanged:    if (_widgetsLoaded) saveWidgets()
    onModBrightnessChanged: if (_widgetsLoaded) saveWidgets()
    onModClaudeChanged:     if (_widgetsLoaded) saveWidgets()
    onModPowerChanged:      if (_widgetsLoaded) saveWidgets()
    onModBluetoothChanged:  if (_widgetsLoaded) saveWidgets()
    onModNetworkChanged:    if (_widgetsLoaded) saveWidgets()
    onModNordVpnChanged:    if (_widgetsLoaded) saveWidgets()
    onModWallpapersChanged: if (_widgetsLoaded) saveWidgets()
    onModDisplayManagerChanged: if (_widgetsLoaded) saveWidgets()
    onDisplayManagerAutoWorkspacesChanged: if (_widgetsLoaded) saveWidgets()
    onModStatusChanged:     if (_widgetsLoaded) saveWidgets()
    onModIndicatorsChanged: if (_widgetsLoaded) saveWidgets()
    onModQuickChanged:      if (_widgetsLoaded) saveWidgets()
    onModCpuChanged:        if (_widgetsLoaded) saveWidgets()
    onModVolumeChanged:     if (_widgetsLoaded) saveWidgets()
    onModMprisChanged:      if (_widgetsLoaded) saveWidgets()
    onMprisBarStyleChanged: if (_widgetsLoaded) saveWidgets()
    onAiToolChanged:        if (_widgetsLoaded) saveWidgets()
    onWorkspaceModeChanged: if (_widgetsLoaded) saveWidgets()
    onPickerStyleChanged:   if (_widgetsLoaded) saveWidgets()
    onLauncherLogoModeChanged: if (_widgetsLoaded) saveWidgets()
    onLauncherLogoTextChanged: if (_widgetsLoaded) saveWidgets()
    onLauncherLogoIconChanged: if (_widgetsLoaded) saveWidgets()
    onWeatherImperialChanged: if (_widgetsLoaded) saveWidgets()
    onClock12hChanged:        if (_widgetsLoaded) saveWidgets()
    onArchBadgePackagesChanged: if (_widgetsLoaded) saveWidgets()
    onArchBadgeThemesChanged:   if (_widgetsLoaded) saveWidgets()
    onWorkspaceStyleChanged:   if (_widgetsLoaded) saveWidgets()
    onBarPositionChanged: {
        barUnlocked = false
        closePopups()
        if (_widgetsLoaded) saveWidgets()
    }
    onBarFrostChanged: if (_widgetsLoaded) saveWidgets()
    onLayoutProtectedChanged: if (_widgetsLoaded) saveWidgets()
    onBarShellStyleChanged:    if (_widgetsLoaded) saveWidgets()
    onBarBorderEnabledChanged: if (_widgetsLoaded) saveWidgets()
    onSpacerDotsEnabledChanged: if (_widgetsLoaded) saveWidgets()
    onPanelTooltipBorderEnabledChanged: if (_widgetsLoaded) saveWidgets()
    onBarColorChanged:         if (_widgetsLoaded) saveWidgets()
    onWidgetIconsForegroundChanged: if (_widgetsLoaded) saveWidgets()
    onBarTemperatureSourceChanged: if (_widgetsLoaded) saveWidgets()

    function saveWidgets() {
        var line = (modMemory    ? "1" : "0") + " "
                 + (modBrightness ? "1" : "0") + " "
                 + (modClaude    ? "1" : "0") + " "
                 + (modPower     ? "1" : "0") + " "
                 + (modBluetooth ? "1" : "0") + " "
                 + workspaceMode + " "
                 + pickerStyle + " "
                 + (weatherImperial ? "1" : "0") + " "
                 + (clock12h        ? "1" : "0") + " "
                 + (modNetwork      ? "1" : "0") + " "
                 + "0 "                                     // +5 legacy shadow field (V2 disabled)
                 + "0 0 "                                     // +6..+7 retired V2 Style fields
                 + workspaceStyle + " "
                 + barPosition + " "
                 + "1 "                                     // +10 legacy border field (V2 always on)
                 + (modStatus ? "1" : "0") + " "          // +11 group pill: status (arch/tray/notif)
                 + (modQuick  ? "1" : "0") + " "          // +12 group pill: quick (idle/media/theme)
                 + (modCpu    ? "1" : "0") + " "          // +13
                 + (modVolume ? "1" : "0") + " "          // +14
                 + (modMpris  ? "1" : "0") + " "          // +15 now-playing / mpris
                 + aiTool + " "                           // +16 AI tool shown in bar (claude/codex/opencode)
                 + "0 "                                     // +17 retired transparent/frost field
                 + launcherLogoMode + " "                 // +18 launcher logo mode (text/icon)
                 + launcherLogoText + " "                 // +19 text logo id
                 + launcherLogoIcon + " "                 // +20 icon logo id
                 + (archBadgePackages ? "1" : "0") + " "  // +21 updater package badge
                 + (archBadgeThemes   ? "1" : "0") + " "  // +22 updater clean-theme badge
                 + "1 1 1 1 1 1 1 1 "                       // +23..+30 legacy compact fields; V2 is always compact
                 + "0 "                                     // +31 reserved (retired updater preference)
                 + barColor + " "                            // +32 V2 bar accent source
                 + (modGpu            ? "1" : "0") + " "  // +33 GPU load
                 + (modCpuTemperature ? "1" : "0") + " "  // +34 CPU temperature
                 + (modStorage        ? "1" : "0") + " "  // +35 root-filesystem usage
                 + (barSeps.length ? barSeps.join(",") : "-") + " "         // +36 separator gids (CSV, "-" = none)
                 + (iconOnlyGids.length ? iconOnlyGids.join(",") : "-") + " " // +37 icon-only gids (CSV, "-" = none)
                 + barTemperatureSource + " "                            // +38 temperature sensor shown in bar
                 + "0 "                                                  // +39 retired global widget-foreground switch
                 + serializeWidgetColorStyles() + " "                   // +40 per-GID palette styles
                 + mprisBarStyle + " "                                  // +41 now-playing bar presentation
                 + barShellStyle + " "                                  // +42 outer bar shell
                 + (barBorderEnabled ? "1" : "0") + " "                 // +43 outer bar border
                 + (panelTooltipBorderEnabled ? "1" : "0") + " "        // +44 panel + tooltip outer border
                 + (modNordVpn ? "1" : "0") + " "                        // +45 NordVPN
                 + (modWallpapers ? "1" : "0") + " "                    // +46 Wallpapers; append-only schema
                 + (modDisplayManager ? "1" : "0") + " "                  // +47 Display Manager; append-only schema
                 + (displayManagerAutoWorkspaces ? "1" : "0") + " " // +48 Display Manager workspace preference
                 + (barFrost ? "1" : "0") + " " // +49 V2 Frost (same field as legacy Notch Frost)
                 + (layoutProtected ? "1" : "0") + " " // +50 layout protection
                 + serializeWidgetSurfaceStyles() + " " // +51 widget surface geometry
                 + (modOneDrive ? "1" : "0") + " " // +52 OneDrive
                 + (spacerDotsEnabled ? "1" : "0") + " " // +53 hover spacer dots
                 + (modIndicators ? "1" : "0") // +54 Indicators widget
        widgetSaveProc.command = ["bash", "-c",
            "echo '" + line + "' > '" + widgetsCachePath + "'"]
        widgetSaveProc.running = false
        widgetSaveProc.running = true
    }

    readonly property var launcherLogoTextOptions: ["omarchy", "hyprland", "arch", "omacom"]
    readonly property var launcherLogoIconOptions: ["omarchy", "hyprland", "arch", "grid", "spark", "power", "dragon", "mark", "nix", "branch", "rebel"]

    function launcherLogoTextIndex(id) { return ThemeLauncher.launcherLogoTextIndex(theme, {}, id) }
    function launcherLogoIconIndex(id) { return ThemeLauncher.launcherLogoIconIndex(theme, {}, id) }
    function launcherLogoTextValid(id) { return ThemeLauncher.launcherLogoTextValid(theme, {}, id) }
    function launcherLogoIconValid(id) { return ThemeLauncher.launcherLogoIconValid(theme, {}, id) }
    function nextLauncherLogoText() { return ThemeLauncher.nextLauncherLogoText(theme, {}) }
    function nextLauncherLogoIcon() { return ThemeLauncher.nextLauncherLogoIcon(theme, {}) }
    function launcherConfigValue(config, a, b, c) { return ThemeLauncher.launcherConfigValue(theme, {}, config, a, b, c) }
    function applyLauncherConfig(config) { return ThemeLauncher.applyLauncherConfig(theme, {}, config) }
    function launcherLogoLabel(id) { return ThemeLauncher.launcherLogoLabel(theme, {}, id) }
    function launcherLogoIconGlyph(id) { return ThemeLauncher.launcherLogoIconGlyph(theme, {}, id) }
    function launcherLogoIconFont(id) { return ThemeValues.launcherLogoIconFont(theme, {}, id) }
    function launcherLogoIconSize(id) { return ThemeLauncher.launcherLogoIconSize(theme, {}, id) }
    function launcherLogoIconXOffset(id) { return ThemeLauncher.launcherLogoIconXOffset(theme, {}, id) }
    function launcherLogoIconYOffset(id) { return ThemeLauncher.launcherLogoIconYOffset(theme, {}, id) }

    Process {
        id: widgetLoadProc
        command: ["cat", theme.widgetsCachePath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(" ")
                if (parts.length >= 4) {
                    theme.modMemory    = parts[0] !== "0"
                    theme.modBrightness = parts[1] !== "0"
                    theme.modClaude    = parts[2] !== "0"
                    theme.modPower     = parts[3] !== "0"
                }
                // parts[4] is the bluetooth flag in the new format, but in the OLD
                // format it was the workspace mode ("10"/"5"/"active") — detect which.
                var wsField = -1
                if (parts.length >= 5) {
                    if (parts[4] === "5" || parts[4] === "active" || parts[4] === "10") {
                        wsField = 4                         // old format: no bluetooth field
                    } else {
                        theme.modBluetooth = parts[4] !== "0"
                        wsField = 5
                    }
                }
                if (wsField >= 0 && parts.length > wsField) {
                    var m = parts[wsField]
                    theme.workspaceMode = (m === "5" || m === "active") ? m : "10"
                    // pickerStyle is the field right after the workspace mode
                    if (parts.length > wsField + 1) {
                        var ps = parts[wsField + 1]
                        if (ps === "hearthstone" || ps === "carousel" || ps === "tanzaku")
                            theme.pickerStyle = ps
                    }
                    // weatherImperial / clock12h follow pickerStyle
                    if (parts.length > wsField + 2) theme.weatherImperial = parts[wsField + 2] === "1"
                    if (parts.length > wsField + 3) theme.clock12h        = parts[wsField + 3] === "1"
                    if (parts.length > wsField + 4) theme.modNetwork      = parts[wsField + 4] === "1"
                    // style tokens — appended after modNetwork, each guarded
                    // +5 is the retired V2 shadow field and is intentionally ignored.
                    // +6..+7 are retired V2 Style fields, retained only so older
                    // cache layouts keep stable offsets.
                    if (parts.length > wsField + 8) {
                        var wss = parts[wsField + 8]
                        if (wss === "numbers" || wss === "magic" || wss === "kanji"
                                || wss === "rings" || wss === "aurora" || wss === "default")
                            theme.workspaceStyle = wss
                    }
                    if (parts.length > wsField + 9) {
                        var bp = parts[wsField + 9]
                        if (["top", "bottom", "left", "right"].indexOf(bp) >= 0) theme.barPosition = bp
                    }
                    // +10 is the retired V2 border toggle; structural borders stay on.
                    // +11..+15 widget-group toggles (default ON → only an explicit "0"
                    // hides; old caches lack these fields → groups stay visible)
                    if (parts.length > wsField + 11) theme.modStatus = parts[wsField + 11] !== "0"
                    if (parts.length > wsField + 12) theme.modQuick  = parts[wsField + 12] !== "0"
                    if (parts.length > wsField + 13) theme.modCpu    = parts[wsField + 13] !== "0"
                    if (parts.length > wsField + 14) theme.modVolume = parts[wsField + 14] !== "0"
                    if (parts.length > wsField + 15) theme.modMpris  = parts[wsField + 15] !== "0"
                    if (parts.length > wsField + 16) {
                        var at = parts[wsField + 16]
                        if (at === "claude" || at === "codex" || at === "opencode" || at === "copilot") theme.aiTool = at
                    }
                    // +17 is the retired transparent/frost field.
                    if (parts.length > wsField + 18) {
                        var lm = parts[wsField + 18]
                        if (lm === "text" || lm === "icon") {
                            theme.launcherLogoMode = lm
                            if (parts.length > wsField + 19 && theme.launcherLogoTextValid(parts[wsField + 19]))
                                theme.launcherLogoText = parts[wsField + 19]
                            if (parts.length > wsField + 20 && theme.launcherLogoIconValid(parts[wsField + 20]))
                                theme.launcherLogoIcon = parts[wsField + 20]
                        } else if (lm === "omarchy" || lm === "hyprland") {
                            // Legacy cache field from the first text-logo picker.
                            theme.launcherLogoMode = "text"
                            theme.launcherLogoText = lm
                        }
                    }
                    if (parts.length > wsField + 21) theme.archBadgePackages = parts[wsField + 21] !== "0"
                    if (parts.length > wsField + 22) theme.archBadgeThemes   = parts[wsField + 22] !== "0"
                    // +23..+30 are retained only as cache-schema placeholders.
                    // V2 has one compact presentation and deliberately ignores them.
                    if (parts.length > wsField + 32 && theme.barColorValid(parts[wsField + 32]))
                        theme.barColor = theme.normalizedPaletteId(parts[wsField + 32])
                    if (parts.length > wsField + 33) theme.modGpu = parts[wsField + 33] !== "0"
                    if (parts.length > wsField + 34) theme.modCpuTemperature = parts[wsField + 34] !== "0"
                    if (parts.length > wsField + 52) theme.modOneDrive = parts[wsField + 52] === "1"
                    if (parts.length > wsField + 35) theme.modStorage = parts[wsField + 35] !== "0"
                    if (parts.length > wsField + 36) theme.barSeps      = theme.parseGidCsv(parts[wsField + 36])
                    if (parts.length > wsField + 37) theme.iconOnlyGids = theme.parseGidCsv(parts[wsField + 37])
                    if (parts.length > wsField + 38 && theme.barTemperatureSourceValid(parts[wsField + 38]))
                        theme.barTemperatureSource = parts[wsField + 38]
                    // +39 was the retired global foreground override. Bar Color
                    // now includes Foreground and per-widget styles provide local overrides.
                    theme.widgetIconsForeground = false
                    if (parts.length > wsField + 40)
                        theme.widgetColorStyles = theme.parseWidgetColorStyles(parts[wsField + 40])
                    if (parts.length > wsField + 41) {
                        var mbs = parts[wsField + 41]
                        if (mbs === "default" || mbs === "full") theme.mprisBarStyle = mbs
                    }
                    if (parts.length > wsField + 42) {
                        var bss = parts[wsField + 42]
                        if (theme.barShellStyleValid(bss)) theme.barShellStyle = bss
                    }
                    if (parts.length > wsField + 43)
                        theme.barBorderEnabled = parts[wsField + 43] !== "0"
                    if (parts.length > wsField + 44)
                        theme.panelTooltipBorderEnabled = parts[wsField + 44] !== "0"
                }
                if (parts.length > wsField + 45) theme.modNordVpn = parts[wsField + 45] === "1"
                if (parts.length > wsField + 46) theme.modWallpapers = parts[wsField + 46] === "1"
                if (parts.length > wsField + 47) theme.modDisplayManager = parts[wsField + 47] === "1"
                    if (parts.length > wsField + 48) theme.displayManagerAutoWorkspaces = parts[wsField + 48] === "1"
                if (parts.length > wsField + 49) theme.barFrost = parts[wsField + 49] === "1"
                if (parts.length > wsField + 50) theme.layoutProtected = parts[wsField + 50] === "1"
                if (parts.length > wsField + 51) theme.widgetSurfaceStyles = theme.parseWidgetSurfaceStyles(parts[wsField + 51])
                if (parts.length > wsField + 53) theme.spacerDotsEnabled = parts[wsField + 53] !== "0"
                if (parts.length > wsField + 54) theme.modIndicators = parts[wsField + 54] !== "0"
                theme._widgetsLoaded = true
            }
        }
    }

    Process { id: widgetSaveProc }

    // ── New widget panel states ──
    property bool networkVisible:   false
    onDisplayManagerVisibleChanged: popupOpened("displayManagerVisible")
    onNetworkVisibleChanged: popupOpened("networkVisible")
    property bool vpnVisible:       false
    onVpnVisibleChanged: popupOpened("vpnVisible")
    property bool storageVisible:   false
    onStorageVisibleChanged: popupOpened("storageVisible")
    property bool bluetoothVisible: false
    onBluetoothVisibleChanged: popupOpened("bluetoothVisible")
    property bool batteryVisible:   false
    onBatteryVisibleChanged: popupOpened("batteryVisible")
    property bool brightnessVisible: false
    onBrightnessVisibleChanged: popupOpened("brightnessVisible")
    property bool mprisVisible:     false
    onMprisVisibleChanged: popupOpened("mprisVisible")
    property bool weatherVisible:   false
    onWeatherVisibleChanged: popupOpened("weatherVisible")
    property bool workspaceVisible: false
    onWorkspaceVisibleChanged: popupOpened("workspaceVisible")

    // ── Image picker state (theme/wallpaper carousel) ──
    property bool   imagePickerVisible:  false
    onImagePickerVisibleChanged: popupOpened("imagePickerVisible")
    property string imagePickerMode:     "wallpaper"   // "theme" or "wallpaper"
    property real   quickActionsBarX:    0
    // ── Media browser state (screenshots/videos carousel) ──
    property bool   mediaBrowserVisible: false
    onMediaBrowserVisibleChanged: popupOpened("mediaBrowserVisible")
    property string mediaBrowserMode:    "screenshots"  // "screenshots" or "videos"
    // ── Idle inhibitor (Wayland idle-inhibit protocol) ──
    property bool   idleInhibited:       false
    // ── Notification state ──
    property bool notifVisible: false
    onNotifVisibleChanged: popupOpened("notifVisible")
    property int  notifCount:   0
    property real notifBarX:    0

    // ── Power Profile state ──
    property bool powerProfileVisible: false
    onPowerProfileVisibleChanged: popupOpened("powerProfileVisible")
    property string powerProfileCurrent: ""

    Process {
        id: initPowerProfile
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo balanced"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim()
                if (p) theme.powerProfileCurrent = p
            }
        }
    }

    // ── Hyprland workspace dispatch (config-mode-aware) ──
    // Hyprland 0.55 added Lua configs but still supports classic hyprlang, and
    // BOTH ship the same version number — so the dispatch form depends on which
    // config is ACTIVE, not the version: classic wants "workspace N", Lua wants
    // hl.dsp.focus({ workspace = N }). Probe the mode once with a harmless token:
    // "hl.dsp" alone yields the Lua error "hl.dispatch: expected a dispatcher"
    // under Lua, or "Invalid dispatcher" under classic — neither switches.
    property bool hyprUsesLua: false
    property bool omarchyPerMonitorWorkspaces: false
    property bool hyprDispatchModeReady: false
    Process {
        id: hyprDispatchProbe
        command: ["bash", "-c", "if hyprctl dispatch 'hl.dsp' 2>&1 | grep -qi 'hl\\.dispatch'; then if [ -r \"${OMARCHY_PATH:-/usr/share/omarchy}/default/hypr/monitor-workspaces.lua\" ]; then echo lua-per-monitor; else echo lua; fi; else echo classic; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var mode = this.text.trim()
                theme.hyprUsesLua = mode.indexOf("lua") === 0
                theme.omarchyPerMonitorWorkspaces = (mode === "lua-per-monitor")
                theme.hyprDispatchModeReady = true
            }
        }
    }
    function gotoWorkspace(id, monitorName) { return ThemeIntegrations.gotoWorkspace(theme, {Hyprland: Hyprland, Quickshell: Quickshell}, id, monitorName) }

    // ── Arch Updater state ──
    property bool archVisible: false
    onArchVisibleChanged: popupOpened("archVisible")
    property var archUpdates: []
    property string archScanError: ""
    property bool archRefreshing: false
    property int archRefreshTick: 0
    property string archScanId: ""
    property int archScanCheckedEpoch: 0
    property string archScanHash: ""
    property int archScanSystemCount: 0
    readonly property int archScanMaxAge: 900

    // ── Arch security gate (pre-install verdict per package) ──
    // idle | scanning | clean | warn | blocked | degraded
    property string archGateState: "idle"
    property var    archGateResults: []   // [{pkg,repo,old,new,verdict,reason}]
    property int    archGateOk: 0
    property int    archGateWarn: 0
    property int    archGateFail: 0
    property int    archGateBlacklist: 0
    property bool   archGateDegraded: false
    property string archGateListDate: ""   // freshest blacklist date (meta updated_at, else mtime)
    property bool   archGateStale: false          // protection list older than the gate's stale window
    property bool   archGateMirrorsAgree: false   // both feed mirrors produced an identical list
    property bool   archGateMirrorMismatch: false // feeds diverged → using their union, flagged

    // Manual retry, e.g. on panel open: a degraded verdict can be a transient
    // (blacklist file mid-update at scan time) and must not stick until the
    // next refresh.
    function archGateRescan() { return ThemeValues.archGateRescan(theme, {archGate: archGate}) }

    Process {
        id: archGate
        // Hang on the DATA, not the refresh trigger: archRefreshTick fires the
        // refresh, but archUpdates is only filled when the refresh finishes — so
        // watching the tick would scan the PREVIOUS list. Watch archUpdates.
        property var watched: theme.archUpdates
        onWatchedChanged: rerun()
        // A rerun restarts even a live scan (running=false→true). That kill makes
        // onExited see a nonzero (terminated) exit; flag it so onExited does NOT
        // mistake the deliberate kill for a crash and force degraded — that false
        // degraded could land AFTER a clean scan and stick ("protection limited" +
        // no "mirrors ✓" despite a healthy feed).
        property bool killing: false
        function rerun() {
            if (running) killing = true
            running = false   // restart even if a previous scan is still running
            theme.archGateResults = []
            theme.archGateOk = 0; theme.archGateWarn = 0; theme.archGateFail = 0
            theme.archGateBlacklist = 0; theme.archGateDegraded = false
            theme.archGateStale = false; theme.archGateMirrorsAgree = false; theme.archGateMirrorMismatch = false
            // Run the gate even with 0 updates — it still emits the meta line, so the
            // panel can always show the blacklist size / protection status.
            theme.archGateState = (theme.archUpdates && theme.archUpdates.length > 0)
                ? "scanning" : "clean"
            stdinEnabled = true   // re-arm stdin each run — onStarted sets it false to send EOF; without this the 2nd+ run reads disabled stdin and hangs in 'scanning'
            running = true
        }
        command: ["bash", decodeURIComponent(String(Qt.resolvedUrl("../../scripts/qs-arch-security-gate.sh")).replace(/^(file|qs):\/\//, ""))]
        stdinEnabled: true
        onStarted: {
            // Feed "pkg|repo|old|new" — exactly the gate's stdin format.
            var ups = theme.archUpdates || []
            for (var i = 0; i < ups.length; i++) {
                var u = ups[i]
                var repo = (u.source === "aur") ? "aur" : "system"
                write(u.name + "|" + repo + "|" + (u.oldVer || "") + "|" + (u.newVer || "") + "\n")
            }
            stdinEnabled = false   // EOF → gate finishes
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var results = [], ok = 0, warn = 0, fail = 0, sawMeta = false
                var lines = this.text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var s = lines[i].trim(); if (!s) continue
                    var o; try { o = JSON.parse(s) } catch (e) { continue }
                    if (o.meta === "gate") {
                        sawMeta = true
                        theme.archGateBlacklist = o.blacklist || 0
                        if (o.degraded) theme.archGateDegraded = true
                        if (o.list_date) theme.archGateListDate = o.list_date
                        if (o.stale) theme.archGateStale = true
                        theme.archGateMirrorsAgree = (o.mirrors_agree === true)
                        theme.archGateMirrorMismatch = (o.mirror_mismatch === true)
                        continue
                    }
                    results.push(o)
                    if (o.verdict === "FAIL") fail++
                    else if (o.verdict === "WARN") warn++
                    else ok++
                }
                theme.archGateResults = results
                theme.archGateOk = ok; theme.archGateWarn = warn; theme.archGateFail = fail
                // Fail-CLOSED: if the gate didn't fully respond (no meta line, or a
                // package has no verdict — gate missing/crashed/partial), do NOT
                // claim "clean". An empty/short answer means "unverified", not "safe".
                if (!sawMeta || results.length !== (theme.archUpdates || []).length)
                    theme.archGateDegraded = true
                theme.archGateState =
                    fail > 0 ? "blocked"
                    : theme.archGateDegraded ? "degraded"
                    : warn > 0 ? "warn" : "clean"
            }
        }
        onExited: (exitCode) => {
            if (killing) { killing = false; return }   // we restarted it on purpose, not a crash
            // Gate exited nonzero (missing script, crash) => force degraded so the
            // panel never shows a false all-clear.
            if (exitCode !== 0) {
                theme.archGateDegraded = true
                if (theme.archGateFail === 0 && theme.archGateWarn === 0)
                    theme.archGateState = "degraded"
            }
        }
    }

    function closeArchUpdatesPanel() { return ThemeValues.closeArchUpdatesPanel(theme, {}) }

    // ── Theme Updater state (fed by ArchUpdaterPanel's FileView over
    //    ~/.cache/qs-theme-updates.json; the panel owns the check Process so it
    //    runs ONCE, not per-monitor). The bar/tooltip only read these counts;
    //    the panel renders themeUpdList. Theme updates run in a visible terminal
    //    through qs-theme-apply-update.sh and are pinned to the checked target
    //    commit. ──
    property int    themeUpdOutdated: 0
    property int    themeUpdLocalEdits: 0
    property int    themeUpdTotal: 0
    property int    themeUpdReachable: 0
    property bool   themeUpdDegraded: false
    property bool   themeUpdCurrentStale: false
    property string themeUpdChecked: ""      // ISO timestamp of the last check, "" = never
    property var    themeUpdList: []          // outdated/unreachable entries shown in the panel
    property bool   themeUpdChecking: false   // a check is in flight (button disabled)
    property int    themeCheckTick: 0         // ++ from the panel button to trigger a check
    property string activeUpdateTab: "packages"   // which ArchUpdaterPanel tab is shown
    property bool   archBadgePackages: true   // package count badge on the bar updater icon
    property bool   archBadgeThemes: true     // clean-theme count badge on the bar updater icon

    // ── Tray state ──
    property bool trayVisible: false
    onTrayVisibleChanged: popupOpened("trayVisible")
    property bool trayHovering: false
    property var trayPinned: []
    property real trayBarX: 10
    property real trayCaretBarX: trayBarX
    onTrayHoveringChanged: {
        if (trayHovering) trayHoverCloseTimer.stop()
        else if (trayVisible) trayHoverCloseTimer.restart()
    }
    Timer {
        id: trayHoverCloseTimer
        interval: 260
        onTriggered: if (!theme.trayHovering) theme.trayVisible = false
    }

    // ── slot-aware panel X anchors (center-X of each group; set by BarSlot) ──
    property real volumeBarX:     0
    property real networkBarX:    0
    property real vpnBarX:        0
    property real batteryBarX:    0
    property real memoryBarX:     0
    property real cpuBarX:        0
    property real gpuBarX:        0
    property real thermalBarX:    0
    property real storageBarX:    0
    property real aiBarX:         0
    property real workspaceBarX:  0
    property real archBarX:       0
    property real archCaretBarX:  archBarX
    property real notifCaretBarX: notifBarX
    property real bluetoothBarX:  0
    property real brightnessBarX: 0
    property real powerBarX:      0
    property real mprisBarX:      0
    property real weatherBarX:    0
    property real calendarBarX:   weatherBarX
    property real launcherBarX:   6   // ControlPanel follows the Launcher/Control group

    // One connected popover at a time: the active panel publishes the exact
    // bar-widget center used by both the caret and the small border opening.
    readonly property bool anchoredPanelVisible: oneDriveVisible || calendarVisible || cpuVisible || gpuVisible
        || thermalVisible || aiUsageVisible
        || memVisible || volVisible || controlVisible || networkVisible || vpnVisible || bluetoothVisible
        || batteryVisible || brightnessVisible || mprisVisible || weatherVisible
        || workspaceVisible || notifVisible || powerProfileVisible || storageVisible
        || archVisible || trayVisible || displayManagerVisible || wallpaperManagerVisible

    // Preserve the panel surface's actually rendered tip while it closes so
    // the matching bar notch retracts at the same point. Edge panels clamp the
    // tip away from their rounded corner, so the raw widget center is not
    // always the final rendered position.
    property real panelInsetX: 0
    property bool panelInsetReady: false
    function setPanelInsetX(x) {
        if (!anchoredPanelVisible) return

        if (isFinite(x) && x > 0) {
            panelInsetX = x
            panelInsetReady = true
        }
    }
    property real panelInsetReveal: anchoredPanelVisible ? 1 : 0
    onPanelInsetRevealChanged: {
        if (!anchoredPanelVisible && panelInsetReveal <= 0.001)
            panelInsetReady = false
    }
    Behavior on panelInsetReveal {
        NumberAnimation {
            duration: theme.anchoredPanelVisible ? 160 : 120
            easing.type: theme.anchoredPanelVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    // ── Tray context-menu state (themed menu, rendered by TrayMenu.qml) ──
    property bool trayMenuVisible: false
    onTrayMenuVisibleChanged: popupOpened("trayMenuVisible")
    property var  trayMenuHandle: null   // the QsMenuHandle of the clicked item
    property real trayMenuX: 0           // global x to anchor the menu under the icon
    property string trayMenuTitle: ""
    property string trayMenuIcon: ""

    function trayDisplayName(item) { return ThemeTray.trayDisplayName(theme, {}, item) }

    function trayDescription(item, displayName) { return ThemeTray.trayDescription(theme, {}, item, displayName) }

    function openTrayMenu(handle, x, title, icon) { return ThemeValues.openTrayMenu(theme, {}, handle, x, title, icon) }

    function trayIsHidden(item) { return ThemeValues.trayIsHidden(theme, {}, item) }

    // toggle: hidden items get pinned (shown in bar); pinned items get unpinned (back to panel)
    function trayToggleHide(item) { return ThemeTray.trayToggleHide(theme, {}, item) }

    Process {
        id: omarchyCurrentRootProbe
        command: ["bash", "-c",
            "state=\"$HOME/.local/state/omarchy/current\"; legacy=\"$HOME/.config/omarchy/current\"; " +
            "if command -v omarchy-shell >/dev/null 2>&1 && [ -d \"$state\" ] && [ -d /usr/share/omarchy ]; then printf '%s\\t%s\\n' \"$state\" /usr/share/omarchy; " +
            "elif [ -d \"$legacy\" ]; then printf '%s\\t%s\\n' \"$legacy\" \"$HOME/.local/share/omarchy\"; " +
            "else printf '%s\\t%s\\n' \"$legacy\" \"$HOME/.local/share/omarchy\"; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                var resolved = parts.length > 0 ? parts[0] : ""
                var installRoot = parts.length > 1 ? parts[1] : ""
                if (resolved) theme.omarchyCurrentRoot = resolved
                if (installRoot) theme.omarchyInstallRoot = installRoot
                theme.omarchyCurrentRootResolved = true
                currentThemeNameWatcher.reload()
                theme.reloadCurrentThemeFiles()
            }
        }
    }

    Timer {
        id: themeReloadDebounce
        interval: 40
        repeat: false
        onTriggered: {
            paletteReader.running = false
            paletteReader.running = true
        }
    }

    // Omarchy writes theme.name immediately after the complete theme directory
    // swap, before its slower application retint commands and final hooks.
    FileView {
        id: currentThemeNameWatcher
        path: theme.themeNamePath
        watchChanges: theme.omarchyCurrentRootResolved
        printErrors: false
        onLoaded: {
            theme.setCurrentThemeName(currentThemeNameWatcher.text())
            theme.reloadCurrentThemeFiles()
        }
        onLoadFailed: theme.setCurrentThemeName("")
        onFileChanged: {
            reload()
            theme.reloadCurrentThemeFiles()
        }
    }

    Process {
        id: paletteReader
        command: ["cat", theme.colorsPath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                Palette.apply(theme, Palette.parse(this.text));
            }
        }
    }

    function ipcApplyTheme(payload) { return ThemeIntegrations.ipcApplyTheme(theme, {Palette: Palette}, payload) }

    function ipcApplyLauncher(payload) { return ThemeLauncher.ipcApplyLauncher(theme, {}, payload) }

    function ipcReloadTheme() { return ThemeIntegrations.ipcReloadTheme(theme, {paletteReader: paletteReader}) }

    function ipcOpenPicker(mode) { return ThemeIntegrations.ipcOpenPicker(theme, {}, mode) }

    // Standalone compatibility while the integrated bootstrap is being rolled
    // out. VariantRoot supplies variantHost, so only the common IPC router owns
    // these targets in integrated mode.
    LazyLoader {
        active: theme.variantHost === null
        IpcHandler {
            target: "theme"
            function apply(payload: string): void { theme.ipcApplyTheme(payload) }
            function applyLauncher(payload: string): void { theme.ipcApplyLauncher(payload) }
            function reload(): void { theme.ipcReloadTheme() }
        }
    }

    LazyLoader {
        id: pickerLoader
        readonly property var owner: theme
        active: theme.variantHost === null
        IpcHandler {
            target: "picker"
            function theme(): void { pickerLoader.owner.ipcOpenPicker("theme") }
            function wallpaper(): void { pickerLoader.owner.ipcOpenPicker("wallpaper") }
            function screenshots(): void { pickerLoader.owner.ipcOpenPicker("screenshots") }
            function videos(): void { pickerLoader.owner.ipcOpenPicker("videos") }
        }
    }
}
