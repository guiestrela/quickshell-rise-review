pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models
import Quickshell

Item {
    id: rail
    required property var root
    required property var barWindow
    required property var models
    required property var registry
    property var splitState: null
    property var runs: []
    function splitAfter(region, index) {
        if (!splitState) return true
        var flags = region === 0 ? splitState.leftSplits : region === 2 ? splitState.rightSplits : []
        return index < flags.length ? flags[index] : false
    }
    function updateRuns() {
        var cells = []
        for (var i = 0; i < items.count; i++) {
            var cell = items.objectAt(i)
            if (cell && cell.visible) cells.push(cell)
        }
        cells.sort(function(a, b) { return a.mapToItem(rail, 0, 0).y - b.mapToItem(rail, 0, 0).y })
        var result = [], current = null, previous = null
        for (var j = 0; j < cells.length; j++) {
            var c = cells[j], start = c.mapToItem(rail, 0, 0).y
            var separate = !previous || (previous.modelData.region === c.modelData.region
                ? splitAfter(previous.modelData.region, previous.modelData.index)
                : !splitState || splitState.boundarySplits[Math.min(previous.modelData.region, 1)])
            if (separate) {
                current = {y: start - 3, h: c.contentHeight + 6}
                result.push(current)
            } else current.h = start + c.contentHeight + 3 - current.y
            previous = c
        }
        runs = result
    }
    Connections {
        target: rail.splitState
        function onLeftSplitsChanged() { layoutTimer.restart() }
        function onRightSplitsChanged() { layoutTimer.restart() }
        function onBoundarySplitsChanged() { layoutTimer.restart() }
    }
    readonly property real surfaceY: surface.y
    readonly property real surfaceHeight: surface.height
    readonly property int pillWidth: 32
    // These delegates exist only in the vertical loader; horizontal bindings
    // are recreated independently when orientation changes.
    function standardizeSurface(widget) {
        if (!widget) return
        for (var i = 0; i < widget.children.length; i++) {
            var surface = widget.children[i]
            if (surface.border === undefined || surface.radius === undefined) continue
            surface.color = "transparent"
            surface.border.width = 0
            for (var j = 0; j < surface.children.length; j++) {
                var effect = surface.children[j]
                if (effect.theme !== undefined && effect.blur !== undefined) effect.visible = false
            }
            surface.width = Qt.binding(function() { return rail.pillWidth })
            surface.x = Qt.binding(function() { return (widget.width - rail.pillWidth) / 2 })
        }
    }
    property int revision: 0
    property int sourceRegion: -1
    property int sourceIndex: -1
    readonly property var anchorNames: ({
        G1: ["launcher"], G2: ["workspace"], G3: ["arch", "tray", "notif"],
        G4: ["memory"], G5: ["cpu"], G6: ["volume"], G7: ["ai"],
        G8: ["calendar", "weather"], G9: ["mpris"], G10: ["quickActions"],
        G11: ["network"], G12: ["battery"], G13: ["brightness"], G14: ["power"],
        G15: ["bluetooth"], G16: ["vpn"], G17: ["wallpaperManager"],
        G18: ["displayManager"], G19: ["gpu"]
    })
    function cells() {
        void(revision)
        var out = []
        for (var r = 0; r < models.length; r++) {
            for (var i = 0; i < models[r].count; i++) {
                var gid = models[r].get(i).gid
                if (gid || rail.root.barUnlocked) out.push({gid: gid, region: r, index: i})
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
                xs[names[n]] = rail.root.barPosition === "right" ? rail.barWindow.screen.width - rail.root.verticalBarWidth / 2 : rail.root.verticalBarWidth / 2
            }
        }
        rail.updateRuns()
        rail.root.publishVerticalAnchors(barWindow.screenName, values)
        rail.root.publishBarAnchors(barWindow.screenName, xs)
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
    focus: rail.root.barUnlocked
    Keys.onEscapePressed: rail.root.barUnlocked = false
    Rectangle {
        id: surface
        anchors.fill: parent
        color: "transparent"
        radius: rail.root.pillRadius
        border.color: rail.root.pillBorder
        border.width: 0
        Repeater {
            model: rail.runs
            delegate: Rectangle {
                required property var modelData
                objectName: "vertical-run-surface"
                x: (rail.width - rail.pillWidth) / 2
                y: modelData.y
                width: rail.pillWidth
                height: Math.max(0, modelData.h)
                radius: rail.root.pillRadius
                color: rail.root.barBg
                border.color: rail.root.islandBorder
                border.width: rail.root.styleBorder === true ? 1 : 0
                PillShadow { theme: rail.root }
            }
        }
        Item {
            id: gapLayout
            readonly property var pillRuns: rail.runs.map(function(run, i) { return {s:i, e:i} })
            function runRightEdge(i) { return rail.runs[i].y + rail.runs[i].h }
            function runLeftEdge(i) { return rail.runs[i].y }
        }
        Loader {
            active: rail.root.barAnim > 0 && rail.runs.length > 1
            sourceComponent: Component {
                ParticleStream {
                    x: rail.width
                    width: rail.height
                    height: rail.width
                    rotation: 90
                    transformOrigin: Item.TopLeft
                    theme: rail.root
                    layout: gapLayout
                    mode: rail.root.barAnim
                    active: true
                    monitor: rail.barWindow.screenName
                }
            }
        }
        Flickable {
            id: scroll
            anchors.fill: parent
            anchors.margins: 3
            contentHeight: stack.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: !rail.root.barUnlocked
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
                    spacing: 6
                    onImplicitHeightChanged: layoutTimer.restart()
                }
                Column {
                    id: centerRegion
                    width: parent.width
                    y: rail.regionStart(1)
                    spacing: 6
                    onYChanged: anchorTimer.restart()
                    onImplicitHeightChanged: layoutTimer.restart()
                }
                Column {
                    id: bottomRegion
                    width: parent.width
                    y: rail.regionStart(2)
                    spacing: 6
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
                        readonly property bool groupedSurface: gid === "G3" || gid === "G8" || gid === "G10"
                        parent: rail.regionColumns[modelData.region]
                        width: parent.width
                        readonly property real contentHeight: loader.item && loader.item.implicitWidth > 0 ? Math.max(36, loader.item.implicitHeight + (groupedSurface ? 8 : 0)) : rail.root.barUnlocked ? 32 : 0
                        height: contentHeight > 0 ? contentHeight + (rail.splitAfter(modelData.region, modelData.index) ? 12 : 0) : 0
                        visible: height > 0
                        onYChanged: anchorTimer.restart()
                        onHeightChanged: layoutTimer.restart()
                        Rectangle {
                            objectName: "vertical-group-surface-" + cell.gid
                            visible: false // The split run owns the only surface and border.
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: (cell.contentHeight - height) / 2
                            width: rail.pillWidth
                            height: Math.max(rail.root.pillH, loader.implicitHeight + 8)
                            radius: rail.root.pillRadius
                            color: rail.root.pill
                            border.color: rail.root.pillBorder
                            border.width: rail.root.pillBorderW
                            PillShadow { theme: rail.root }
                        }
                        Loader {
                            id: loader
                            onLoaded: { rail.standardizeSurface(item); layoutTimer.restart() }
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -(cell.height - cell.contentHeight) / 2
                            sourceComponent: cell.gid === "G2" ? workspace
                                : cell.gid === "G3" ? statusGroupComponent : cell.gid === "G8" ? clock
                                : cell.gid === "G10" ? quick : rail.registry[cell.gid] || null
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: rail.root.barUnlocked && !rail.root.layoutProtected
                            preventStealing: true
                            onPressed: { rail.sourceRegion = cell.modelData.region; rail.sourceIndex = cell.modelData.index }
                            onReleased: function(mouse) {
                                var point = mapToItem(stack, mouse.x, mouse.y)
                                var sourceRegion = rail.sourceRegion, sourceIndex = rail.sourceIndex
                                var targetRegion = -1, targetIndex = -1
                                for (var i = 0; i < items.count; i++) {
                                    var candidate = items.objectAt(i) as Item
                                    var candidateData = items.model[i]
                                    if (candidate && candidateData && candidate.visible && point.y >= candidate.mapToItem(stack, 0, 0).y && point.y <= candidate.mapToItem(stack, 0, candidate.height).y) {
                                        targetRegion = candidateData.region; targetIndex = candidateData.index; break
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
            onDoubleClicked: if (!rail.root.layoutProtected) rail.root.barUnlocked = true
        }
    }
    component Action: Item {
        id: action
        property string label: ""
        property color contentColor: rail.root.ink
        signal activated()
        signal secondaryActivated()
        implicitWidth: 32; implicitHeight: 32
        Text { anchors.centerIn: parent; text: action.label; color: action.contentColor; font.family: rail.root.mono; font.pixelSize: 11 }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                rail.root.activatePopupScreen(rail.barWindow.screen)
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
            implicitWidth: 32
            implicitHeight: clockColumn.implicitHeight
            readonly property real clockCenterY: time.y + time.height / 2
            readonly property real weatherCenterY: weather.y + weather.height / 2
            Column {
                id: clockColumn
                width: parent.width
                spacing: 0
                WeatherWidget {
                    id: weather
                    implicitHeight: 24
                    root: rail.root
                    width: 32
                    visible: rail.root.modWeather
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Action {
                    id: time
                    contentColor: rail.root.ink
                    anchors.horizontalCenter: parent.horizontalCenter
                    label: Qt.formatDateTime(now.date, rail.root.clock12h ? "hh\nmm\nAP" : "HH\nmm")
                    SystemClock { id: now; precision: SystemClock.Minutes }
                    implicitHeight: rail.root.clock12h ? 44 : 32
                    onActivated: rail.root.calendarVisible = !rail.root.calendarVisible
                    onSecondaryActivated: rail.root.weatherVisible = !rail.root.weatherVisible
                }
            }
        }
    }

    Component {
        id: statusGroupComponent
        Item {
            implicitWidth: rail.root.modStatus ? 32 : 0
            visible: rail.root.modStatus
            implicitHeight: rail.root.modStatus ? column.implicitHeight : 0
            Column {
                id: column
                width: parent.width
                spacing: 6
                ArchUpdaterWidget { root: rail.root; anchors.horizontalCenter: parent.horizontalCenter }
                TrayWidget { root: rail.root; anchors.horizontalCenter: parent.horizontalCenter }
                NotificationWidget { root: rail.root; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }
    Component {
        id: quick
        Item {
            implicitWidth: rail.root.modQuick ? 32 : 0
            visible: rail.root.modQuick
            implicitHeight: rail.root.modQuick ? column.implicitHeight : 0
            Column {
                id: column
                width: parent.width
                spacing: 6
                IdleInhibitorWidget { root: rail.root; anchors.horizontalCenter: parent.horizontalCenter }
                MediaBrowserWidget { root: rail.root; screen: rail.barWindow.screen; anchors.horizontalCenter: parent.horizontalCenter }
                ThemeDisplayWidget { root: rail.root; screen: rail.barWindow.screen; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }
    Component.onDestruction: {
        if (root) {
            var next = Object.assign({}, rail.root.verticalAnchorsByScreen)
            delete next[barWindow.screenName]
            rail.root.verticalAnchorsByScreen = next
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
