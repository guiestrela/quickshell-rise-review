pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQml.Models
import Quickshell
import Quickshell.Hyprland

Item {
    id: rail
    required property var root
    required property var barWindow
    required property var models
    required property var registry
    readonly property real surfaceY: Math.max(0, surface.y - notchWing)
    readonly property real surfaceHeight: Math.min(height, surface.height + 2 * notchWing)
    property int revision: 0
    property int sourceRegion: -1
    property int sourceIndex: -1
    readonly property bool fit: root.barShellStyle !== "full"
    readonly property int outerGap: root.barShellStyle === "fit" ? 2 : 0
    readonly property int notchWing: root.barShellStyle === "notch" ? 12 : 0
    // Retain the last anchor while the shared panel reveal animates closed.
    property real panelNotchY: height / 2
    readonly property string panelAnchor: {
        var names = {control: "launcher", workspace: "workspace", calendar: "calendar",
            weather: "weather", cpu: "cpu", gpu: "gpu", thermal: "thermal",
            aiUsage: "ai", mem: "memory", vol: "volume", network: "network",
            vpn: "vpn", bluetooth: "bluetooth", battery: "battery",
            brightness: "brightness", mpris: "mpris", notif: "notif",
            powerProfile: "power", storage: "storage", arch: "arch", tray: "tray",
            displayManager: "displayManager", wallpaperManager: "wallpaperManager"}
        for (var name in names)
            if (root[name + "Visible"] === true) return names[name]
        return ""
    }
    readonly property real activePanelY: panelAnchor ? root.verticalAnchorY(panelAnchor) : panelNotchY
    onActivePanelYChanged: if (panelAnchor) panelNotchY = activePanelY
    readonly property real panelNotchProgress: notchWing > 0 &&
        root.activePopupScreenName === barWindow.screenName
        ? Math.max(0, Math.min(1, root.panelInsetReveal || 0)) : 0
    readonly property var anchorNames: ({
        G1: ["launcher"], G2: ["workspace"], G3: ["arch", "tray", "notif"],
        G4: ["memory"], G5: ["cpu"], G6: ["volume"], G7: ["ai"],
        G8: ["calendar", "weather"], G9: ["mpris"], G10: ["quickActions"],
        G11: ["network"], G12: ["battery"], G13: ["brightness"], G14: ["power"],
        G15: ["bluetooth"], G16: ["thermal"], G17: ["gpu"], G18: ["storage"],
        G19: ["vpn"], G20: ["wallpaperManager"], G21: ["displayManager"]
    })
    function cells() {
        void(revision)
        var out = []
        for (var r = 0; r < models.length; r++) {
            for (var i = 0; i < models[r].count; i++) {
                var gid = models[r].get(i).gid
                if (gid || root.barUnlocked) out.push({gid: gid, region: r, index: i})
            }
        }
        return out
    }
    readonly property var regionColumns: [topRegion, centerRegion, bottomRegion]
    function regionHeight(region) {
        return regionColumns[region].implicitHeight
    }
    function regionStart(region) {
        if (region === 0) return 0
        var bottom = stack.height - regionHeight(2)
        if (region === 2) return bottom
        var centerHeight = regionHeight(1)
        return Math.max(regionHeight(0) + 12,
            Math.min((stack.height - centerHeight) / 2, bottom - centerHeight - 12))
    }
    function publishAnchors() {
        var values = {}
        var xs = {}
        for (var i = 0; i < items.count; i++) {
            var item = items.objectAt(i)
            if (!item || !item.visible) continue
            var names = anchorNames[item.modelData.gid] || []
            for (var n = 0; n < names.length; n++) {
                var localY = item.height / 2
                if (item.gid === "G8" && item.contentItem) {
                    if (names[n] === "calendar") localY = item.contentItem.clockCenterY
                    if (names[n] === "weather") localY = item.contentItem.weatherCenterY
                }
                values[names[n]] = item.mapToItem(rail, 0, localY).y
                xs[names[n]] = root.barPosition === "right" ? rail.barWindow.screen.width - root.verticalBarWidth / 2 : root.verticalBarWidth / 2
            }
        }
        root.publishVerticalAnchors(barWindow.screenName, values)
        root.publishBarAnchors(barWindow.screenName, xs)
    }
    Timer { id: layoutTimer; interval: 0; onTriggered: { anchorTimer.restart() } }
    Timer { id: anchorTimer; interval: 0; onTriggered: rail.publishAnchors() }
    Connections { target: rail.models[0]; function onDataChanged() { rail.revision++ } function onCountChanged() { rail.revision++ } }
    Connections { target: rail.models[1]; function onDataChanged() { rail.revision++ } function onCountChanged() { rail.revision++ } }
    Connections { target: rail.models[2]; function onDataChanged() { rail.revision++ } function onCountChanged() { rail.revision++ } }
    Connections {
        target: rail.root
        function onBarUnlockedChanged() { rail.sourceRegion = -1; rail.sourceIndex = -1 }
        function onBarPositionChanged() { anchorTimer.restart() }
    }
    focus: root.barUnlocked
    Keys.onEscapePressed: root.barUnlocked = false
    Rectangle {
        id: surface
        x: rail.outerGap
        width: parent.width - 2 * rail.outerGap
        y: rail.fit ? Math.max(rail.outerGap, (parent.height - height) / 2) : 0
        height: rail.fit ? Math.min(parent.height - 2 * Math.max(rail.outerGap, rail.notchWing), stack.implicitHeight + 12) : parent.height
        radius: rail.fit ? 8 : 0
        topLeftRadius: root.barShellStyle === "dock" && root.barPosition === "left" ? 0 : radius
        bottomLeftRadius: topLeftRadius
        topRightRadius: root.barShellStyle === "dock" && root.barPosition === "right" ? 0 : radius
        bottomRightRadius: topRightRadius
        color: rail.notchWing > 0 ? "transparent" : root.barBg
        border.width: root.barBorderEnabled && rail.notchWing === 0 ? 1 : 0
        border.color: root.islandBorder
        Shape {
            id: notch
            visible: rail.notchWing > 0
            x: 0; y: -rail.notchWing
            width: parent.width; height: parent.height + 2 * rail.notchWing
            readonly property real edgeX: rail.root.barPosition === "left" ? 0 : width
            readonly property real innerX: rail.root.barPosition === "left" ? width : 0
            readonly property real insetY: Math.max(rail.notchWing + 16,
                Math.min(height - rail.notchWing - 16, rail.panelNotchY - surface.y + rail.notchWing))
            readonly property real insetX: innerX + (rail.root.barPosition === "left" ? -5 : 5) * rail.panelNotchProgress
            readonly property real halfWidth: 7 * rail.panelNotchProgress
            readonly property real tangent: 4.25 * rail.panelNotchProgress
            readonly property real tip: 2 * rail.panelNotchProgress
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: rail.root.barBorderEnabled ? rail.root.islandBorder : "transparent"
                strokeWidth: 1
                fillColor: rail.root.barBg
                startX: notch.edgeX; startY: 0
                PathCubic {
                    x: notch.innerX; y: rail.notchWing + 8
                    control1X: notch.edgeX; control1Y: rail.notchWing
                    control2X: notch.innerX; control2Y: rail.notchWing
                }
                PathLine { x: notch.innerX; y: notch.insetY - notch.halfWidth }
                PathCubic {
                    x: notch.insetX; y: notch.insetY
                    control1X: notch.innerX; control1Y: notch.insetY - notch.tangent
                    control2X: notch.insetX; control2Y: notch.insetY - notch.tip
                }
                PathCubic {
                    x: notch.innerX; y: notch.insetY + notch.halfWidth
                    control1X: notch.insetX; control1Y: notch.insetY + notch.tip
                    control2X: notch.innerX; control2Y: notch.insetY + notch.tangent
                }
                PathLine { x: notch.innerX; y: notch.height - rail.notchWing - 8 }
                PathCubic {
                    x: notch.edgeX; y: notch.height
                    control1X: notch.innerX; control1Y: notch.height - rail.notchWing
                    control2X: notch.edgeX; control2Y: notch.height - rail.notchWing
                }
                PathLine { x: notch.edgeX; y: 0 }
            }
        }
        Flickable {
            id: scroll
            anchors.fill: parent
            anchors.margins: 3
            contentHeight: stack.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: !root.barUnlocked
            onContentYChanged: anchorTimer.restart()
            WheelHandler {
                enabled: rail.root.barUnlocked
                target: null
                onWheel: function(event) { scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, scroll.contentY - event.angleDelta.y / 2)) }
            }
            Item {
                id: stack
                width: scroll.width
                implicitHeight: rail.regionHeight(0) + rail.regionHeight(1) + rail.regionHeight(2) + 24
                height: Math.max(scroll.height, implicitHeight)
                onImplicitHeightChanged: anchorTimer.restart()
                onHeightChanged: anchorTimer.restart()
                Column {
                    id: topRegion
                    width: parent.width
                    spacing: 4
                    onImplicitHeightChanged: layoutTimer.restart()
                }
                Column {
                    id: centerRegion
                    width: parent.width
                    y: rail.regionStart(1)
                    spacing: 4
                    onYChanged: anchorTimer.restart()
                    onImplicitHeightChanged: layoutTimer.restart()
                }
                Column {
                    id: bottomRegion
                    width: parent.width
                    y: rail.regionStart(2)
                    spacing: 4
                    onYChanged: anchorTimer.restart()
                    onImplicitHeightChanged: layoutTimer.restart()
                }
                Instantiator {
                    id: items
                    onObjectAdded: layoutTimer.restart()
                    onObjectRemoved: layoutTimer.restart()
                    model: rail.cells()
                    delegate: Item {
                        id: cell
                        required property var modelData
                        readonly property string gid: modelData.gid
                        readonly property var contentItem: loader.item
                        parent: rail.regionColumns[modelData.region]
                        width: parent.width
                        height: loader.item && loader.item.implicitWidth > 0 ? Math.max(32, loader.item.implicitHeight) + (root.sepAfter(gid) ? 8 : 0) : root.barUnlocked ? 32 : 0
                        visible: height > 0
                        onYChanged: anchorTimer.restart()
                        onHeightChanged: layoutTimer.restart()
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.width, loader.implicitWidth + 2 * root.widgetSurfacePadding(cell.gid))
                            height: Math.min(parent.height, loader.implicitHeight)
                            radius: root.widgetSurfaceRadius(cell.gid)
                            color: root.widgetFillColor(cell.gid)
                            opacity: root.widgetSurfaceStyle(cell.gid).opacity
                            border.width: root.widgetHasBorder(cell.gid) ? root.widgetSurfaceStyle(cell.gid).borderWidth : root.barUnlocked ? 1 : 0
                            border.color: root.barUnlocked ? root.seal : root.widgetBorderColor(cell.gid)
                        }
                        Loader {
                            id: loader
                            onLoaded: layoutTimer.restart()
                            anchors.horizontalCenter: parent.horizontalCenter
                            sourceComponent: cell.gid === "G2" ? workspace
                                : cell.gid === "G3" ? status : cell.gid === "G8" ? clock
                                : cell.gid === "G10" ? quick : rail.registry[cell.gid] || null
                        }
                        Rectangle {
                            visible: root.sepAfter(cell.gid)
                            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 10; height: 1; color: root.sep
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: root.barUnlocked
                            preventStealing: true
                            onPressed: { rail.sourceRegion = cell.modelData.region; rail.sourceIndex = cell.modelData.index }
                            onReleased: function(mouse) {
                                var point = mapToItem(stack, mouse.x, mouse.y)
                                var sourceRegion = rail.sourceRegion, sourceIndex = rail.sourceIndex
                                var targetRegion = -1, targetIndex = -1
                                for (var i = 0; i < items.count; i++) {
                                    var candidate = items.objectAt(i)
                                    if (candidate && candidate.visible && point.y >= candidate.mapToItem(stack, 0, 0).y && point.y <= candidate.mapToItem(stack, 0, candidate.height).y) {
                                        targetRegion = candidate.modelData.region; targetIndex = candidate.modelData.index; break
                                    }
                                }
                                rail.sourceRegion = -1; rail.sourceIndex = -1
                                // Swapping can destroy this delegate. Do not touch it afterwards.
                                if (sourceRegion >= 0 && targetRegion >= 0)
                                    rail.barWindow.swapVerticalSlots(sourceRegion, sourceIndex, targetRegion, targetIndex)
                            }
                            onCanceled: { rail.sourceRegion = -1; rail.sourceIndex = -1 }
                        }
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            z: -1
            onDoubleClicked: if (!root.layoutProtected) root.barUnlocked = true
        }
    }
    component Action: Item {
        id: action
        property string label: ""
        property color contentColor: root.ink
        signal activated()
        signal secondaryActivated()
        implicitWidth: 32; implicitHeight: 32
        Text { anchors.centerIn: parent; text: action.label; color: action.contentColor; font.family: root.mono; font.pixelSize: 11 }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                root.activatePopupScreen(rail.barWindow.screen)
                if (mouse.button === Qt.RightButton) action.secondaryActivated()
                else action.activated()
            }
        }
    }
    Component {
        id: workspace
        WorkspaceWidget { root: rail.root }
    }
    Component {
        id: clock
        Item {
            implicitWidth: 34
            implicitHeight: clockColumn.implicitHeight
            readonly property real clockCenterY: time.y + time.height / 2
            readonly property real weatherCenterY: weather.y + weather.height / 2
            Column {
                id: clockColumn
                width: parent.width
                spacing: 0
                WeatherWidget {
                    id: weather
                    implicitHeight: 20
                    root: rail.root
                    width: 32
                    visible: rail.root.modWeather
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Action {
                    id: time
                    contentColor: rail.root.widgetContentColor("G8", rail.root.ink)
                    anchors.horizontalCenter: parent.horizontalCenter
                    label: Qt.formatDateTime(now.date, rail.root.clock12h ? "hh\nmm\nAP" : "HH\nmm")
                    SystemClock { id: now; precision: SystemClock.Minutes }
                    implicitHeight: rail.root.clock12h ? 44 : 32
                    onActivated: root.calendarVisible = !root.calendarVisible
                    onSecondaryActivated: root.weatherVisible = !root.weatherVisible
                }
            }
        }
    }

    Component {
        id: status
        Item {
            implicitWidth: root.modStatus ? 34 : 0
            visible: root.modStatus
            implicitHeight: root.modStatus ? column.implicitHeight : 0
            Column {
                id: column
                width: parent.width
                spacing: 3
                ArchUpdaterWidget { root: rail.root; anchors.horizontalCenter: parent.horizontalCenter }
                TrayWidget { root: rail.root; anchors.horizontalCenter: parent.horizontalCenter }
                NotificationWidget { root: rail.root; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }
    Component {
        id: quick
        Item {
            implicitWidth: root.modQuick ? 34 : 0
            visible: root.modQuick
            implicitHeight: root.modQuick ? column.implicitHeight : 0
            Column {
                id: column
                width: parent.width
                spacing: 3
                IdleInhibitorWidget { root: rail.root; anchors.horizontalCenter: parent.horizontalCenter }
                MediaBrowserWidget { root: rail.root; screen: rail.barWindow.screen; anchors.horizontalCenter: parent.horizontalCenter }
                ThemeDisplayWidget { root: rail.root; screen: rail.barWindow.screen; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }
    Component.onDestruction: {
        if (root) {
            var next = Object.assign({}, root.verticalAnchorsByScreen)
            delete next[barWindow.screenName]
            root.verticalAnchorsByScreen = next
        }
    }
    function layoutSnapshot() {
        var out = []
        for (var i = 0; i < items.count; i++) {
            var cell = items.objectAt(i)
            if (cell && cell.visible) out.push({gid: cell.gid, region: cell.modelData.region, y: cell.mapToItem(stack, 0, 0).y, height: cell.height})
        }
        return out
    }
    Component.onCompleted: layoutTimer.restart()
    onHeightChanged: anchorTimer.restart()
}
