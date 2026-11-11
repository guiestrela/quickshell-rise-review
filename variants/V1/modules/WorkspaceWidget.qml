pragma ComponentBehavior: Bound
import Quickshell.Hyprland
import QtQuick
import Quickshell
import Quickshell.Io
import "../../../shared/logic/MonitorWorkspaces.js" as MonitorWorkspaces

Item {
    id: wsWidget
    required property var root
    property var monitor: null
    readonly property string monitorName: monitor ? monitor.name : ""
    property var workspaceBlocks: ({})
    readonly property var activeWorkspace: monitor ? monitor.activeWorkspace : Hyprland.focusedWorkspace
    readonly property int workspaceBlock: MonitorWorkspaces.blockFor(workspaceBlocks, monitorName,
        activeWorkspace ? activeWorkspace.id : 0)
    function workspaceId(slot) { return MonitorWorkspaces.idFor(workspaceBlock, slot) }
    readonly property var workspaceEntries: {
        var entries = []
        for (var i = 0; i < workspaceList.length; i++)
            entries.push({ id: workspaceId(workspaceList[i]), slot: workspaceList[i], guest: false })
        var guests = MonitorWorkspaces.guestIds(workspaceBlock, monitorName, Hyprland.workspaces.values)
        for (var j = 0; j < guests.length; j++)
            entries.push({ id: guests[j], slot: MonitorWorkspaces.slotFor(guests[j]), guest: true })
        return entries
    }
    function workspaceIndexFor(id) {
        for (var i = 0; i < workspaceEntries.length; i++) if (workspaceEntries[i].id === Number(id)) return i
        return -1
    }
    function focusWorkspace(slot, guest, actualId) {
        if (root.hyprDispatchModeReady === false) return
        if (guest) root.gotoWorkspace(actualId)
        else if (root.omarchyPerMonitorWorkspaces && monitorName) root.gotoWorkspace(slot, monitorName)
        else root.gotoWorkspace(workspaceId(slot))
    }
    function scrollWorkspace(delta) {
        var index = activeWorkspace ? workspaceIndexFor(activeWorkspace.id) : -1
        var target = Math.max(0, Math.min(workspaceEntries.length - 1, index + delta))
        if (index >= 0 && target !== index) {
            var entry = workspaceEntries[target]
            focusWorkspace(entry.slot, entry.guest, entry.id)
        }
    }
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: wsWidget.workspaceBlocks = MonitorWorkspaces.parseBlocks(text())
        onLoadFailed: wsWidget.workspaceBlocks = ({})
    }

    implicitWidth: wsRow.implicitWidth
    implicitHeight: wsWidget.root.barVertical ? wsRow.implicitHeight : 28

    // The focused workspace's id ONLY when it's a real (positive) workspace beyond
    // the persist range — else 0. An int signals on value change only, so switching
    // between in-range workspaces does NOT renotify → workspaceList stays identical
    // → the Repeater model is stable → the per-delegate width/colour Behaviors keep
    // animating instead of the whole model rebuilding (B2). `id > n` (n≥5) also
    // excludes negative special/scratchpad ids (B3).
    readonly property int extraWs: {
        if (wsWidget.root.workspaceMode === "active") return 0
        var n = wsWidget.root.workspaceMode === "5" ? 5 : 10
        var f = wsWidget.activeWorkspace
        var slot = f ? MonitorWorkspaces.slotFor(f.id) : 0
        return slot > n ? slot : 0
    }

    readonly property var workspaceList: {
        if (wsWidget.root.workspaceMode === "active") {
            return MonitorWorkspaces.slots("active", wsWidget.workspaceBlock,
                wsWidget.activeWorkspace ? wsWidget.activeWorkspace.id : 0, Hyprland.workspaces.values)
        }
        var n = wsWidget.root.workspaceMode === "5" ? 5 : 10
        var list = []; for (var j = 1; j <= n; j++) list.push(j)
        if (extraWs > 0) list.push(extraWs)   // focused-beyond-range, stable per id
        return list
    }

    Rectangle {
        x: -wsWidget.root.wsPillPad; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(wsRow.width) + 2 * wsWidget.root.wsPillPad
        height: wsWidget.root.barVertical ? wsRow.implicitHeight : wsWidget.root.pillH
        radius: wsWidget.root.pillRadius
        color: wsWidget.root.pill
        border.color: wsWidget.root.pillBorder
        border.width: wsWidget.root.pillBorderW
        PillShadow { theme: wsWidget.root }
    }

    // right-click anywhere opens the workspace panel
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: wsWidget.root.workspaceVisible = !wsWidget.root.workspaceVisible
    }

    Grid {
        id: wsRow
        columns: wsWidget.root.barVertical ? 1 : Math.max(1, wsWidget.workspaceEntries.length)
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: wsWidget.workspaceEntries

            delegate: Item {
                id: wsCell
                required property var modelData
                required property int index
                readonly property int wsId: modelData.slot
                readonly property bool isGuest: modelData.guest
                readonly property bool isFirstGuest: isGuest
                    && (index === 0 || !wsWidget.workspaceEntries[index - 1].guest)
                readonly property int actualWorkspaceId: modelData.id

                // hover feedback works in every style (the old code scaled the
                // default-only `dot`, invisible in numbers/magic)
                Behavior on scale { NumberAnimation { duration: 120 } }

                readonly property bool isFocused: wsWidget.activeWorkspace !== null
                                               && wsWidget.activeWorkspace.id === actualWorkspaceId

                readonly property bool isOccupied: {
                    var ws = Hyprland.workspaces.values
                    for (var i = 0; i < ws.length; i++)
                        if (ws[i].id === wsCell.actualWorkspaceId && (!wsWidget.monitor || !ws[i].monitor
                                || ws[i].monitor.name === wsWidget.monitor.name)) return !isFocused
                    return false
                }

                readonly property bool isEmpty: !isFocused && !isOccupied

                implicitWidth: (wsWidget.root.workspaceStyle === "numbers" ? 22
                             : wsWidget.root.workspaceStyle === "magic"   ? (isFocused ? 20 : 18)
                             : (isFocused ? 32 : 16))
                             + (isFirstGuest && !wsWidget.root.barVertical ? 6 : 0)
                implicitHeight: 28 + (isFirstGuest && wsWidget.root.barVertical ? 6 : 0)

                Behavior on implicitWidth {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                // ── DEFAULT style: glow + dot ──
                // glow — alle states, nur opacity variiert
                Rectangle {
                    visible: wsWidget.root.workspaceStyle === "default"
                    anchors.centerIn: parent
                    width:  wsCell.isFocused ? 34 : 16
                    height: wsCell.isFocused ? 16 : 16
                    radius: wsCell.isFocused ?  8 :  8
                    color: wsCell.isFocused
                        ? Qt.rgba(wsWidget.root.seal.r, wsWidget.root.seal.g, wsWidget.root.seal.b, 0.20)
                        : wsCell.isOccupied
                        ? Qt.rgba(wsWidget.root.seal.r, wsWidget.root.seal.g, wsWidget.root.seal.b, 0.18)
                        : Qt.rgba(wsWidget.root.seal.r, wsWidget.root.seal.g, wsWidget.root.seal.b, 0.06)

                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // pill / kreis
                Rectangle {
                    id: dot
                    visible: wsWidget.root.workspaceStyle === "default"
                    anchors.centerIn: parent
                    width:  wsCell.isFocused  ? 26 : 8
                    height: 8
                    radius: 4
                    color:  wsCell.isFocused
                        ? wsWidget.root.seal
                        : wsCell.isOccupied
                        ? wsWidget.root.seal
                        : Qt.rgba(wsWidget.root.seal.r, wsWidget.root.seal.g, wsWidget.root.seal.b, 0.25)

                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // ── NUMBERS style: a digit on a rounded badge (radius follows
                //    the bar radius switch: round/12 ⇄ 5) ──
                Rectangle {
                    visible: wsWidget.root.workspaceStyle === "numbers"
                    anchors.centerIn: parent
                    width:  20
                    height: 20
                    radius: wsWidget.root.styleRadiusSmall ? 5 : height / 2
                    color: wsCell.isFocused  ? Qt.rgba(wsWidget.root.seal.r, wsWidget.root.seal.g, wsWidget.root.seal.b, 0.30)
                         : wsCell.isOccupied ? Qt.rgba(wsWidget.root.seal.r, wsWidget.root.seal.g, wsWidget.root.seal.b, 0.12)
                                      : Qt.rgba(wsWidget.root.seal.r, wsWidget.root.seal.g, wsWidget.root.seal.b, 0.04)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Text {
                        anchors.centerIn: parent
                        text: wsCell.wsId
                        // focused = the only BRIGHT digit (lightened seal + bold + bigger);
                        // others dimmed so the active workspace is unmistakable
                        color: wsCell.isFocused  ? Qt.lighter(wsWidget.root.seal, 1.3)
                             : wsCell.isOccupied ? Qt.rgba(wsWidget.root.seal.r, wsWidget.root.seal.g, wsWidget.root.seal.b, 0.5)
                                          : Qt.rgba(wsWidget.root.seal.r, wsWidget.root.seal.g, wsWidget.root.seal.b, 0.28)
                        font.family: wsWidget.root.mono
                        font.pixelSize: wsCell.isFocused ? 13 : 12
                        font.weight: wsCell.isFocused ? Font.Bold : Font.Normal
                    }
                }

                // ── MAGIC style: the 3 ORIGINAL sparkle glyphs (filled / hollow / dot),
                //    all forced into ONE font (Adwaita Mono has all three) so they share
                //    a metric → no cross-font fallback misalignment ──
                Text {
                    visible: wsWidget.root.workspaceStyle === "magic"
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: wsCell.isFocused ? 0 : 1   // active lifted vs occupied/empty
                    text: wsCell.isFocused  ? String.fromCodePoint(0x2726)    // ✦ filled four-point star (active)
                         : wsCell.isOccupied ? String.fromCodePoint(0x2727)    // ✧ hollow four-point star (occupied)
                                      : String.fromCodePoint(0x00B7)    // · middle dot (empty)
                    color: wsCell.isFocused  ? wsWidget.root.seal
                         : wsCell.isOccupied ? Qt.rgba(wsWidget.root.seal.r, wsWidget.root.seal.g, wsWidget.root.seal.b, 0.7)
                                      : Qt.rgba(wsWidget.root.seal.r, wsWidget.root.seal.g, wsWidget.root.seal.b, 0.3)
                    font.family: "Adwaita Mono"   // all 3 sparkle glyphs live here → one consistent metric
                    font.pixelSize: wsCell.isFocused ? 22 : 18
                    renderType: Text.NativeRendering   // crisp hinted raster (default QtRendering softens small symbols)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: wsWidget.focusWorkspace(wsCell.wsId, wsCell.isGuest, wsCell.actualWorkspaceId)
                    onEntered: wsCell.scale = 1.15
                    onExited:  wsCell.scale = 1.0
                }
            }
        }
    }

}
