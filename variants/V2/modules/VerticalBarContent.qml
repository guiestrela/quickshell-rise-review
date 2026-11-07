pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/components" as CommonComponents
import "../../../shared/logic/VerticalBarContentValuesLogic.js" as VerticalBarContentValuesLogic
import "../../../shared/logic/VerticalBarContentLogic.js" as VerticalBarContentLogic
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
    property bool pendingUnlockTap: false
    property point pendingUnlockTapPosition: Qt.point(0, 0)
    property int sourceRegion: -1
    property int sourceIndex: -1
    readonly property bool fit: rail.root.barShellStyle !== "full"
    readonly property int outerGap: rail.root.barShellStyle === "fit" ? 2 : 0
    readonly property int notchWing: rail.root.barShellStyle === "notch" ? 12 : 0
    // Retain the last anchor while the shared panel reveal animates closed.
    property real panelNotchY: height / 2
    readonly property string panelAnchor: {
        var names = {control: "launcher", workspace: "workspace", calendar: "calendar",
            weather: "weather", cpu: "cpu", gpu: "gpu", thermal: "thermal",
            aiUsage: "ai", mem: "memory", vol: "volume", network: "network",
            vpn: "vpn", bluetooth: "bluetooth", battery: "battery",
            brightness: "brightness", mpris: "mpris", notif: "notif",
            oneDrive: "oneDrive", powerProfile: "power", storage: "storage", arch: "arch", tray: "tray",
            displayManager: "displayManager", wallpaperManager: "wallpaperManager"}
        for (var name in names)
            if (root[name + "Visible"] === true) return names[name]
        return ""
    }
    readonly property real activePanelY: panelAnchor ? rail.root.verticalAnchorY(panelAnchor) : panelNotchY
    onActivePanelYChanged: if (panelAnchor) panelNotchY = activePanelY
    readonly property real panelNotchProgress: notchWing > 0 &&
        rail.root.activePopupScreenName === barWindow.screenName
        ? Math.max(0, Math.min(1, rail.root.panelInsetReveal || 0)) : 0
    readonly property var anchorNames: ({
        G1: ["launcher"], G2: ["workspace"], G3: ["arch", "tray", "notif"],
        G4: ["memory"], G5: ["cpu"], G6: ["volume"], G7: ["ai"],
        G8: ["calendar", "weather"], G9: ["mpris"], G10: ["quickActions"],
        G11: ["network"], G12: ["battery"], G13: ["brightness"], G14: ["power"],
        G15: ["bluetooth"], G16: ["thermal"], G17: ["gpu"], G18: ["storage"],
        G19: ["vpn"], G20: ["wallpaperManager"], G21: ["displayManager"], G22: ["oneDrive"], G23: []
    })
    function regionBaseSlotCount(region) {
        if (region === 0) return barWindow.leftBaseSlotCount
        if (region === 1) return barWindow.centerBaseSlotCount
        return barWindow.rightBaseSlotCount
    }
    function regionExtraSlotLimit(region) {
        if (region === 0) return barWindow.leftExtraSlotLimit
        if (region === 1) return barWindow.centerExtraSlotLimit
        return barWindow.rightExtraSlotLimit
    }
    function regionBaseColumnVisible(region) {
        void(rail.revision)
        if (region < 0 || region >= models.length) return false
        if (rail.root.barUnlocked) return true
        var baseCount = regionBaseSlotCount(region)
        for (var i = 0; i < Math.min(baseCount, models[region].count); i++)
            if (models[region].get(i).gid !== "") return true
        return false
    }
    function regionExtraColumnVisible(region) {
        void(rail.revision)
        if (region < 0 || region >= models.length) return false
        var baseCount = regionBaseSlotCount(region)
        if (models[region].count <= baseCount) return false
        if (rail.root.barUnlocked) return true
        for (var i = baseCount; i < models[region].count; i++)
            if (models[region].get(i).gid !== "") return true
        return false
    }
    function canAddExtraSlot(region) {
        void(rail.revision)
        if (region < 0 || region >= models.length) return false
        return Math.max(0, models[region].count - regionBaseSlotCount(region)) < regionExtraSlotLimit(region)
    }
    function addExtraSlot(region) {
        if (region < 0 || region >= models.length) return
        barWindow.addExtraSlot(models[region], regionBaseSlotCount(region), regionExtraSlotLimit(region))
    }
    function removeExtraSlot(region, index) {
        if (region < 0 || region >= models.length) return
        barWindow.removeExtraSlot(models[region], index, regionBaseSlotCount(region))
    }
    function cells() { return VerticalBarContentLogic.cells(rail, {models: models}) }
    function slotAtGlobalPoint(globalX, globalY) {
        var clipStart = scroll.mapToGlobal(0, 0)
        var clipEnd = scroll.mapToGlobal(scroll.width, scroll.height)
        var clipLeft = Math.min(clipStart.x, clipEnd.x), clipRight = Math.max(clipStart.x, clipEnd.x)
        var clipTop = Math.min(clipStart.y, clipEnd.y), clipBottom = Math.max(clipStart.y, clipEnd.y)
        if (globalX < clipLeft || globalX > clipRight || globalY < clipTop || globalY > clipBottom)
            return null
        for (var i = 0; i < items.count; i++) {
            var cell = items.objectAt(i)
            if (!cell || !cell.modelData || !cell.visible || cell.height <= 0) continue
            var start = cell.mapToGlobal(0, 0)
            var end = cell.mapToGlobal(cell.width, cell.height)
            var left = Math.min(start.x, end.x), right = Math.max(start.x, end.x)
            var top = Math.min(start.y, end.y), bottom = Math.max(start.y, end.y)
            if (globalX >= left && globalX <= right && globalY >= top && globalY <= bottom)
                return {model: rail.models[cell.modelData.region], index: cell.modelData.index}
        }
        return null
    }
    readonly property var regionColumns: [topRegion, centerRegion, bottomRegion]
    readonly property var regionBaseColumns: [topBaseSlots, centerBaseSlots, bottomBaseSlots]
    readonly property var regionExtraColumns: [topExtraSlots, centerExtraSlots, bottomExtraSlots]
    function regionHeight(region) {
        return VerticalBarContentValuesLogic.regionHeight(rail, {}, region)
    }
    function regionAnchorHeight(region) {
        return rail.regionBaseColumns[region].implicitHeight
            + (rail.root.barUnlocked && rail.canAddExtraSlot(region) ? 32 : 0)
    }
    function regionLayoutHeight() {
        return rail.fit
            ? rail.regionAnchorHeight(0) + rail.regionAnchorHeight(1) + rail.regionAnchorHeight(2) + 24
            : scroll.height
    }
    function regionStart(region) {
        if (region === 0) return 0
        var layoutHeight = rail.regionLayoutHeight()
        if (region === 1) {
            var topEnd = rail.regionColumns[0].y + rail.regionColumns[0].implicitHeight
            var centerBaseHeight = rail.regionAnchorHeight(1)
            return Math.max(topEnd + 12, Math.max(0, (layoutHeight - centerBaseHeight) / 2))
        }
        var centerEnd = rail.regionColumns[1].y + rail.regionColumns[1].implicitHeight
        return Math.max(centerEnd + 12, layoutHeight - rail.regionHeight(2))
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
        function onBarUnlockedChanged() {
            rail.sourceRegion = -1
            rail.sourceIndex = -1
            rail.revision++
        }
        function onBarPositionChanged() { anchorTimer.restart() }
    }
    focus: rail.root.barUnlocked
    Keys.onEscapePressed: rail.root.barUnlocked = false
    Rectangle {
        id: surface
        x: rail.outerGap
        width: parent.width - 2 * rail.outerGap
        y: rail.fit ? Math.max(rail.outerGap, (parent.height - height) / 2) : 0
        height: rail.fit ? Math.min(parent.height - 2 * Math.max(rail.outerGap, rail.notchWing), stack.implicitHeight + 12) : parent.height
        radius: rail.fit ? 8 : 0
        topLeftRadius: rail.root.barShellStyle === "dock" && rail.root.barPosition === "left" ? 0 : radius
        bottomLeftRadius: topLeftRadius
        topRightRadius: rail.root.barShellStyle === "dock" && rail.root.barPosition === "right" ? 0 : radius
        bottomRightRadius: topRightRadius
        color: rail.notchWing > 0 ? "transparent" : rail.root.barBg
        border.width: 0 // Foreground border stays above widget fills.
        border.color: rail.root.islandBorder
        Shape {
            id: notch
            visible: rail.notchWing > 0
            x: 0; y: -rail.notchWing
            width: parent.width; height: parent.height + 2 * rail.notchWing
            readonly property real edgeX: rail.root.barPosition === "left" ? 0.5 : width - 0.5
            readonly property real innerX: rail.root.barPosition === "left" ? width - 0.5 : 0.5
            readonly property real insetY: Math.max(rail.notchWing + 16,
                Math.min(height - rail.notchWing - 16, rail.panelNotchY - surface.y + rail.notchWing))
            readonly property real insetX: innerX + (rail.root.barPosition === "left" ? -5 : 5) * rail.panelNotchProgress
            readonly property real halfWidth: 7 * rail.panelNotchProgress
            readonly property real tangent: 4.25 * rail.panelNotchProgress
            readonly property real tip: 2 * rail.panelNotchProgress
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                strokeWidth: 0
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
        Rectangle {
            objectName: "vertical-bar-border"
            anchors.fill: parent
            z: 3
            color: "transparent"
            visible: rail.root.barBorderEnabled && rail.notchWing === 0
            radius: surface.radius
            topLeftRadius: surface.topLeftRadius
            bottomLeftRadius: surface.bottomLeftRadius
            topRightRadius: surface.topRightRadius
            bottomRightRadius: surface.bottomRightRadius
            border.width: 1
            border.color: rail.root.v2BarBorder
        }
        Shape {
            objectName: "vertical-notch-border"
            z: 3
            visible: rail.root.barBorderEnabled && rail.notchWing > 0
            x: notch.x; y: notch.y
            width: notch.width; height: notch.height
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: rail.root.v2BarBorder
                strokeWidth: 1
                fillColor: "transparent"
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
            anchors.leftMargin: 1
            anchors.rightMargin: 1
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
            Timer {
                id: unlockTapTimer
                interval: 400
                repeat: false
                onTriggered: rail.pendingUnlockTap = false
            }
            TapHandler {
                enabled: !rail.root.barUnlocked
                acceptedButtons: Qt.LeftButton
                gesturePolicy: TapHandler.DragThreshold
                onTapped: function(eventPoint, button) {
                    if (button !== Qt.LeftButton || rail.root.layoutProtected) {
                        rail.pendingUnlockTap = false
                        unlockTapTimer.stop()
                        return
                    }
                    var point = eventPoint.position
                    var dx = point.x - rail.pendingUnlockTapPosition.x
                    var dy = point.y - rail.pendingUnlockTapPosition.y
                    if (rail.pendingUnlockTap && dx * dx + dy * dy <= 256) {
                        rail.pendingUnlockTap = false
                        unlockTapTimer.stop()
                        rail.root.barUnlocked = true
                    } else {
                        rail.pendingUnlockTap = true
                        rail.pendingUnlockTapPosition = point
                        unlockTapTimer.restart()
                    }
                }
            }
            Item {
                id: stack
                width: scroll.width
                implicitHeight: Math.max(
                    rail.regionColumns[0].y + rail.regionHeight(0),
                    rail.regionColumns[1].y + rail.regionHeight(1),
                    rail.regionColumns[2].y + rail.regionHeight(2)
                ) + 24
                height: Math.max(scroll.height, implicitHeight)
                onImplicitHeightChanged: anchorTimer.restart()
                onHeightChanged: anchorTimer.restart()
                Column {
                    id: topRegion
                    width: parent.width
                    spacing: 4
                    onImplicitHeightChanged: layoutTimer.restart()
                    Column {
                        id: topBaseSlots
                        width: parent.width
                        visible: rail.regionBaseColumnVisible(0)
                        spacing: 4
                        onImplicitHeightChanged: layoutTimer.restart()
                    }
                    AddSlotButton { owner: rail; region: 0; anchors.horizontalCenter: parent.horizontalCenter }
                    Column {
                        id: topExtraSlots
                        width: parent.width
                        visible: rail.regionExtraColumnVisible(0)
                        spacing: 4
                        onImplicitHeightChanged: layoutTimer.restart()
                    }
                }
                Column {
                    id: centerRegion
                    width: parent.width
                    y: rail.regionStart(1)
                    spacing: 4
                    onYChanged: anchorTimer.restart()
                    onImplicitHeightChanged: layoutTimer.restart()
                    Column {
                        id: centerBaseSlots
                        width: parent.width
                        visible: rail.regionBaseColumnVisible(1)
                        spacing: 4
                        onImplicitHeightChanged: layoutTimer.restart()
                    }
                    AddSlotButton { owner: rail; region: 1; anchors.horizontalCenter: parent.horizontalCenter }
                    Column {
                        id: centerExtraSlots
                        width: parent.width
                        visible: rail.regionExtraColumnVisible(1)
                        spacing: 4
                        onImplicitHeightChanged: layoutTimer.restart()
                    }
                }
                Column {
                    id: bottomRegion
                    width: parent.width
                    y: rail.regionStart(2)
                    spacing: 4
                    onYChanged: anchorTimer.restart()
                    onImplicitHeightChanged: layoutTimer.restart()
                    Column {
                        id: bottomBaseSlots
                        width: parent.width
                        visible: rail.regionBaseColumnVisible(2)
                        spacing: 4
                        onImplicitHeightChanged: layoutTimer.restart()
                    }
                    Column {
                        id: bottomExtraSlots
                        width: parent.width
                        visible: rail.regionExtraColumnVisible(2)
                        spacing: 4
                        onImplicitHeightChanged: layoutTimer.restart()
                    }
                    AddSlotButton { owner: rail; region: 2; anchors.horizontalCenter: parent.horizontalCenter }
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
                        readonly property bool emptySlot: gid === ""
                        readonly property bool extraSlot: {
                            if (modelData.index < 0 || modelData.index >= rail.models[modelData.region].count)
                                return false
                            return rail.models[modelData.region].get(modelData.index).extra === true
                        }
                        readonly property var contentItem: loader.item
                        parent: cell.modelData.index < rail.regionBaseSlotCount(cell.modelData.region)
            ? rail.regionBaseColumns[cell.modelData.region]
            : rail.regionExtraColumns[cell.modelData.region]
                        width: parent.width
                        height: loader.item && loader.item.implicitWidth > 0 ? Math.max(32, loader.item.implicitHeight) + (rail.root.sepAfter(gid) ? 8 : 0) : rail.root.barUnlocked ? 32 : 0
                        visible: height > 0
                        onYChanged: anchorTimer.restart()
                        onHeightChanged: layoutTimer.restart()
                        Rectangle {
                            objectName: "vertical-module-surface"
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(parent.width, rail.root.verticalModuleSurfaceWidth)
                            height: Math.min(parent.height, loader.implicitHeight)
                            radius: rail.root.widgetSurfaceRadius(cell.gid)
                            color: rail.root.widgetFillColor(cell.gid)
                            opacity: rail.root.widgetSurfaceStyle(cell.gid).opacity
                            border.width: rail.root.widgetHasBorder(cell.gid) ? rail.root.widgetSurfaceStyle(cell.gid).borderWidth : rail.root.barUnlocked ? 1 : 0
                            border.color: rail.root.barUnlocked ? rail.root.seal : rail.root.widgetBorderColor(cell.gid)
                        }
                        Loader {
                            id: loader
                            opacity: rail.barWindow.dragging
                                && rail.barWindow.srcModel === rail.models[cell.modelData.region]
                                && rail.barWindow.srcIndex === cell.modelData.index ? 0.35 : 1
                            onLoaded: layoutTimer.restart()
                            anchors.horizontalCenter: parent.horizontalCenter
                            sourceComponent: cell.gid === "G2" ? workspace
                                : cell.gid === "G3" ? statusGroupComponent : cell.gid === "G8" ? clock
                                : cell.gid === "G10" ? quick : rail.registry[cell.gid] || null
                        }
                        Rectangle {
                            visible: rail.root.sepAfter(cell.gid)
                            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 10; height: 1; color: rail.root.sep
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: rail.root.barUnlocked && !rail.root.layoutProtected
                                && !cell.emptySlot && loader.item && loader.item.implicitWidth > 0
                            visible: enabled
                            preventStealing: true
                            z: 1
                            cursorShape: Qt.OpenHandCursor
                            onPressed: {
                                var origin = loader.mapToItem(null, 0, 0)
                                rail.barWindow.beginDrag(loader, origin.x, origin.y,
                                    Math.max(1, Math.round(loader.implicitWidth)), Math.max(1, cell.height),
                                    rail.models[cell.modelData.region], cell.modelData.index)
                            }
                            onPositionChanged: function(event) {
                                if (!rail.barWindow.dragActive) return
                                var local = mapToItem(null, event.x, event.y)
                                var global = mapToGlobal(event.x, event.y)
                                rail.barWindow.moveDrag(local.x, local.y, global.x, global.y)
                            }
                            onReleased: rail.barWindow.endDrag()
                            onCanceled: rail.barWindow.cancelDrag()
                        }
                        Rectangle {
                            objectName: "vertical-drop-target-" + cell.modelData.region + "-" + cell.modelData.index
                            anchors.fill: parent
                            radius: rail.root.widgetSurfaceRadius(cell.gid)
                            color: Qt.rgba(rail.barWindow.accent.r, rail.barWindow.accent.g,
                                rail.barWindow.accent.b, 0.18)
                            border.color: rail.barWindow.accent
                            border.width: 2
                            z: 4
                            visible: rail.barWindow.dragging
                                && rail.barWindow.dropModel === rail.models[cell.modelData.region]
                                && rail.barWindow.dropIndex === cell.modelData.index
                                && !(rail.barWindow.srcModel === rail.models[cell.modelData.region]
                                    && rail.barWindow.srcIndex === cell.modelData.index)
                        }
                        Rectangle {
                            objectName: cell.emptySlot && rail.root.barUnlocked
                                ? "vertical-empty-slot-" + cell.modelData.region + "-" + cell.modelData.index : ""
                            function activate() {
                                if (cell.extraSlot)
                                    rail.removeExtraSlot(cell.modelData.region, cell.modelData.index)
                            }
                            visible: cell.emptySlot && rail.root.barUnlocked
                            z: 2
                            anchors.centerIn: parent
                            width: 28; height: 28
                            radius: rail.root.tileRadius
                            color: removeMouse.containsMouse ? rail.root.fillHover : rail.root.fillIdle
                            border.color: removeMouse.containsMouse ? rail.root.seal : rail.root.sep
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: cell.extraSlot ? "×" : "·"
                                color: removeMouse.containsMouse ? rail.root.seal : rail.root.sumi
                                font.family: rail.root.mono
                                font.pixelSize: cell.extraSlot ? 12 : 14
                            }
                            MouseArea {
                                id: removeMouse
                                objectName: "vertical-slot-remove-action-" + cell.modelData.region + "-" + cell.modelData.index
                                anchors.fill: parent
                                z: 5
                                enabled: cell.extraSlot
                                hoverEnabled: enabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: parent.activate()
                            }
                        }
                    }
                }
            }
        }
    }
    component AddSlotButton: Rectangle {
        id: addSlotButton
        required property var owner
        required property int region
        objectName: "vertical-slot-add-cell-" + region
        visible: owner.root.barUnlocked && owner.revision >= 0 && owner.canAddExtraSlot(region)
        implicitWidth: visible ? 28 : 0
        implicitHeight: visible ? 28 : 0
        width: 28; height: 28
        anchors.horizontalCenter: parent.horizontalCenter
        z: 5
        radius: owner.root.tileRadius
        color: addMouse.containsMouse ? owner.root.fillActive : owner.root.fillIdle
        border.color: addMouse.containsMouse ? owner.root.seal : owner.root.sep
        border.width: 1
        function activate() { owner.addExtraSlot(region) }
        Text {
            anchors.centerIn: parent
            text: "+"
            color: addMouse.containsMouse ? addSlotButton.owner.root.seal : addSlotButton.owner.root.ink
            font.family: addSlotButton.owner.root.mono
            font.pixelSize: 14
        }
        MouseArea {
            id: addMouse
            objectName: "vertical-slot-add-action-" + parent.region
            anchors.fill: parent
            z: 5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.activate()
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
        WorkspaceWidget { root: rail.root; monitor: Hyprland.monitorFor(rail.barWindow.screen) }
    }
    Component {
        id: clock
        Item {
            HoverHandler { id: indicatorHover }
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
                    onActivated: rail.root.calendarVisible = !rail.root.calendarVisible
                    onSecondaryActivated: rail.root.weatherVisible = !rail.root.weatherVisible
                }
            }
        }
    }

    Component {
        id: statusGroupComponent
        Item {
            implicitWidth: rail.root.modStatus ? 34 : 0
            visible: rail.root.modStatus
            implicitHeight: rail.root.modStatus ? column.implicitHeight : 0
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
            implicitWidth: rail.root.modQuick ? 34 : 0
            visible: rail.root.modQuick
            implicitHeight: rail.root.modQuick ? column.implicitHeight : 0
            Column {
                id: column
                width: parent.width
                spacing: 3
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
    function layoutSnapshot() { return VerticalBarContentLogic.layoutSnapshot(rail, {items: items, stack: stack}) }
    Component.onCompleted: layoutTimer.restart()
    onHeightChanged: anchorTimer.restart()
}
