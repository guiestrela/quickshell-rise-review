// Full-bar entry point for Omarchy's plugin host. Rise's existing variant
// controller and visual system run as child components in omarchy-shell; this
// wrapper deliberately does not create a second ShellRoot or Quickshell process.

import QtQuick
import Quickshell
import "versions/V1/core"
// Register both lazily loaded variant trees with Quickshell's virtual scanner.
import "versions/V1" as V1Bundle
import "versions/V1/variants/V2" as V2Bundle

Item {
    id: root

    // Omarchy injects these properties into full-bar plugins. Keep them in the
    // component contract so the host can provide its public shell context.
    property string omarchyPath: Quickshell.env("OMARCHY_PATH")
    property var shell: null
    property var barConfig: ({})
    property var manifest: null
    property var pluginRegistry: null
    property var barWidgetRegistry: null

    // Shared services read these from shell.bar, including during variant swaps.
    readonly property string fontFamily: variantHost.activeItem
        ? variantHost.activeItem.fontFamily : "JetBrainsMono Nerd Font"
    readonly property string position: variantHost.activeItem
        ? variantHost.activeItem.position : "top"
    readonly property int barSize: variantHost.activeItem
        ? variantHost.activeItem.barSize : 35
    readonly property bool barHidden: !variantHost.ready

    width: 0
    height: 0

    StateService { id: variantState }
    WallpaperWakeBridge { id: wakeBridge }

    VariantHost {
        id: variantHost
        stateService: variantState
        wallpaperWakeAvailable: wakeBridge.available
        wallpaperSessionLocked: wakeBridge.locked
        wallpaperScreensaverShowing: wakeBridge.screensaverShowing
        v1Source: Qt.resolvedUrl("versions/V1/VariantRoot.qml")
        v2Source: Qt.resolvedUrl("versions/V1/variants/V2/VariantRoot.qml")
    }

    IpcRouter { variantHost: variantHost }
}
