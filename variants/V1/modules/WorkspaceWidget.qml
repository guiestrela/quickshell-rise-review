pragma ComponentBehavior: Bound
import Quickshell.Hyprland
import QtQuick

Item {
    id: wsWidget
    required property var root

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
        var f = Hyprland.focusedWorkspace
        return (f && f.id > n) ? f.id : 0
    }

    readonly property var workspaceList: {
        if (wsWidget.root.workspaceMode === "active") {
            var ids = {}
            var ws = Hyprland.workspaces.values
            for (var i = 0; i < ws.length; i++) if (ws[i].id > 0) ids[ws[i].id] = true   // F13: skip special (negative-id) workspaces
            if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) ids[Hyprland.focusedWorkspace.id] = true
            return Object.keys(ids).map(Number).sort(function(a, b) { return a - b })
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
        columns: wsWidget.root.barVertical ? 1 : Math.max(1, wsWidget.workspaceList.length)
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: wsWidget.workspaceList

            delegate: Item {
                id: wsCell
                required property int modelData
                readonly property int wsId: modelData

                // hover feedback works in every style (the old code scaled the
                // default-only `dot`, invisible in numbers/magic)
                Behavior on scale { NumberAnimation { duration: 120 } }

                readonly property bool isFocused: Hyprland.focusedWorkspace !== null
                                               && Hyprland.focusedWorkspace.id === wsId

                readonly property bool isOccupied: {
                    var ws = Hyprland.workspaces.values
                    for (var i = 0; i < ws.length; i++)
                        if (ws[i].id === wsId) return !isFocused
                    return false
                }

                readonly property bool isEmpty: !isFocused && !isOccupied

                implicitWidth: wsWidget.root.workspaceStyle === "numbers" ? 22
                             : wsWidget.root.workspaceStyle === "magic"   ? (isFocused ? 20 : 18)
                             : (isFocused ? 32 : 16)
                implicitHeight: 28

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
                    onClicked: wsWidget.root.gotoWorkspace(wsCell.wsId)
                    onEntered: wsCell.scale = 1.15
                    onExited:  wsCell.scale = 1.0
                }
            }
        }
    }

}
