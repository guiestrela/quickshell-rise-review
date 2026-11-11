pragma ComponentBehavior: Bound
// ─────────────────────────────────────────────────────────────────────────────
// BarSlot — slot-based bar (WIP port). Step 3: full static layout, all 15 groups
// in 3 regions on one continuous section-pill (matches the default no-split look).
// Real widgets via a component registry. Splits + unlock/drag + slot-aware panel
// bindings come next. Runs as the real TOP bar (shell.qml: Bar → BarSlot).
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import "modules"
import "../../shared/logic/NordVpnLayout.js" as NordVpnLayout
import "../../shared/logic/WallpaperLayout.js" as WallpaperLayout
import "modules/V1Defaults.js" as V1Defaults
import "../../shared/components" as CommonComponents

PanelWindow {
    id: barSlot
    required property var root
    readonly property string screenName: barSlot.screen ? barSlot.screen.name : ""

    color: "transparent"
    // Horizontal bars keep a screen-tall window; vertical bars reserve a side rail.
    // Reserve 35px via exclusiveZone; the mask limits the INPUT region: only the bar
    // strip when locked (clicks below pass through), full screen when unlocked (drag).
    // Anchor the full long axis and reserve space on the selected screen edge.
    anchors {
        left: true; right: true
        top: barSlot.root.barPosition === "top"
        bottom: barSlot.root.barPosition === "bottom"
    }
    implicitWidth: 0
    implicitHeight: barSlot.screen ? barSlot.screen.height : 1440
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 38        // 35 bar + 3px breathing room
    mask: Region {
        x: 0
        y: barSlot.root.barVertical || barSlot.root.barUnlocked ? 0
           : (barSlot.root.barPosition === "bottom" ? barSlot.height - 35 : 0)
        width: barSlot.width
        height: barSlot.root.barVertical || barSlot.root.barUnlocked ? barSlot.height : 35
    }
    // grab keyboard while unlocked so ESC can exit
    WlrLayershell.keyboardFocus: barSlot.root.barUnlocked ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HoverHandler {
        onHoveredChanged: if (hovered && !barSlot.root.anyPopupVisible) barSlot.root.activatePopupScreen(barSlot.screen)
    }

    // keep Hyprland awake while the idle-inhibitor toggle is on (carried over
    // from the legacy single-bar implementation)
    IdleInhibitor { window: barSlot; enabled: barSlot.root.idleInhibited }

    // if unlock ends mid-drag (ESC / ipc lock / click backdrop), kill the drag so the
    // ghost doesn't stay frozen + the source widget doesn't stay dimmed
    Connections {
        target: barSlot.root
        function onBarUnlockedChanged() {
            if (!barSlot.root.barUnlocked && barSlot.dragging) barSlot.cancelDrag()
        }
    }

    readonly property color accent: barSlot.root.seal

    // ── dim backdrop while unlocked (edit mode); click empty → lock ──
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: barSlot.root.barUnlocked ? 0.4 : 0.0
        visible: opacity > 0.001
        z: 1
        Behavior on opacity { NumberAnimation { duration: 180 } }
        MouseArea {
            anchors.fill: parent
            enabled: barSlot.root.barUnlocked
            onClicked: barSlot.root.barUnlocked = false
        }
    }

    // ── unlock drag&drop: ghost + state ──
    property bool dragging: false          // ghost visible (incl. snap-back phase)
    property bool dragActive: false        // mouse currently down (follow cursor)
    property Item dragItem: null           // slot content mirrored by the ghost
    property var  srcModel: null           // source region model + index
    property int  srcIndex: -1
    property var  dropModel: null          // current drop-target model + index
    property int  dropIndex: -1
    property bool dropTray: false
    property real ghostW: 0
    property real ghostH: 0
    property real ghostHomeX: 0
    property real ghostHomeY: 0
    property real ghostX: 0
    property real ghostY: 0
    function beginDrag(item, hx, hy, w, h, sm, si) {
        dragItem = item; ghostW = w; ghostH = h; ghostHomeX = hx; ghostHomeY = hy
        ghostX = hx; ghostY = hy; srcModel = sm; srcIndex = si
        dropModel = null; dropIndex = -1; dropTray = false; dragActive = true; dragging = true
        barSlot.root.trayDragActive = true
        // Keep the tray closed while a drag starts. Opening its full-screen
        // click-outside surface here can steal pointer events from this window
        // and cancel the drag before the user can reorder a widget. Users can
        // still drag into the tray when it was already open.
    }
    // which slot (model+index) is under a desktop-global pointer point?
    function slotAt(wx, wy) {
        var rows = [leftRowItem, centerRowItem, rightRowItem]
        for (var r = 0; r < rows.length; r++) {
            var rep = rows[r].rep
            for (var k = 0; k < rep.count; k++) {
                var it = rep.itemAt(k)
                if (!it || !it.visible || !it.autoShown) continue
                var p = it.mapToGlobal(0, 0)
                var end = it.mapToGlobal(it.width, it.height)
                var left = Math.min(p.x, end.x), right = Math.max(p.x, end.x)
                var top = Math.min(p.y, end.y), bottom = Math.max(p.y, end.y)
                if (wx >= left && wx <= right && wy >= top && wy <= bottom)
                    return { model: rows[r].rmodel, index: k }
            }
        }
        var trayRect = barSlot.root.trayDropRectsByScreen[barSlot.screenName]
        if (barSlot.root.trayVisible && trayRect
                && wx >= trayRect.x && wx <= trayRect.x + trayRect.width
                && wy >= trayRect.y && wy <= trayRect.y + trayRect.height)
            return { tray: true }
        return null
    }
    function moveDrag(localX, localY, globalX, globalY) {
        ghostX = localX - ghostW / 2; ghostY = localY - ghostH / 2
        var hit = slotAt(globalX === undefined ? localX : globalX,
            globalY === undefined ? localY : globalY)
        dropModel = hit ? hit.model : null
        dropIndex = hit && hit.index !== undefined ? hit.index : -1
        dropTray = !!(hit && hit.tray)
        barSlot.root.trayDropActive = dropTray
    }
    function endDrag() {
        dragActive = false
        var swapped = false
        if (dropTray && srcModel && dropIndex < 0) {
            swapped = moveSlotToTray(srcModel, srcIndex)
        } else if (dropModel && dropIndex >= 0 && !(dropModel === srcModel && dropIndex === srcIndex)) {
            swapped = NordVpnLayout.swapModels(srcModel, dropModel, srcIndex, dropIndex)
        }
        dropModel = null; dropIndex = -1; dropTray = false
        barSlot.root.trayDragActive = false
        barSlot.root.trayDropActive = false
        if (swapped) { if (_orderLoaded) saveOrder(); dragging = false }   // content swapped in place + persist
        else { ghostX = ghostHomeX; ghostY = ghostHomeY; snapTimer.restart() }   // snap back
    }
    Timer { id: snapTimer; interval: 240; onTriggered: barSlot.dragging = false }
    // abort a drag with no swap (ESC / ipc lock / backdrop-click while dragging, or a
    // compositor grab-cancel) → clear the ghost immediately so it can't freeze on screen
    function cancelDrag() {
        snapTimer.stop()
        dragActive = false; dragging = false; dragItem = null
        dropModel = null; dropIndex = -1; dropTray = false
        barSlot.root.trayDragActive = false
        barSlot.root.trayDropActive = false
    }

    // ── order persistence (survives restart) ──
    readonly property string orderCachePath: Quickshell.env("HOME") + "/.cache/quickshell_barorder"
    property bool _orderLoaded: false
    function gidsOf(m) { var a = []; for (var i = 0; i < m.count; i++) a.push(m.get(i).gid); return a }
    function serializeOrder() {
        return gidsOf(leftModel).join(",") + "|" + gidsOf(centerModel).join(",") + "|" + gidsOf(rightModel).join(",")
            + "|" + barSlot.root.trayWidgets.join(",")
    }
    function applyTo(m, gids) {
        if (gids.length !== m.count) return                       // stale cache → keep default
        for (var i = 0; i < m.count; i++) if (gids[i] === "" || registry[gids[i]]) m.setProperty(i, "gid", gids[i])
    }
    function applyOrder(str) {
        var parts = str.split("|")
        if (parts.length !== 3 && parts.length !== 4) return
        var l = parts[0].split(","), c = parts[1].split(","), r = parts[2].split(",")
        var tray = parts.length === 4 && parts[3] !== "" ? parts[3].split(",") : []
        var migrated = NordVpnLayout.migrateV1Order(l, c, r)
        if (migrated) { l = migrated.left; c = migrated.center; r = migrated.right }
        migrated = WallpaperLayout.migrateV1Order(l, c, r)
        if (migrated) { l = migrated.left; c = migrated.center; r = migrated.right }
        if (r.indexOf("G18") < 0 && r.length === 9) r.push("G18")
        if (l.concat(c, r).indexOf("G19") < 0 && l.length === 7) l.push("G19")
        // Append optional feature slots without moving any existing widget.
        if (l.concat(c,r).indexOf("G20") < 0) l.push("G20")
        if (l.concat(c,r).indexOf("G21") < 0) l.push("G21")
        if (l.concat(c,r).indexOf("G22") < 0) l.push("G22")
        // Add Indicators to the first vacant saved slot without moving existing widgets.
        if (l.concat(c, r, tray).indexOf("G23") < 0) {
            var regions = [
                { items: c, limit: centerModel.count },
                { items: l, limit: leftModel.count },
                { items: r, limit: rightModel.count }
            ]
            var placed = false
            for (var region = 0; region < regions.length && !placed; region++) {
                var items = regions[region].items
                var empty = items.indexOf("")
                if (empty >= 0) { items[empty] = "G23"; placed = true }
                else if (items.length < regions[region].limit) { items.push("G23"); placed = true }
            }
            if (!placed) return
        }
        // My Elsewhen is appended to a vacant saved slot so legacy layouts keep
        // every existing widget position and tray assignment.
        if (l.concat(c, r, tray).indexOf("G24") < 0) {
            var elsewhenRegions = [
                { items: r, limit: rightModel.count },
                { items: l, limit: leftModel.count },
                { items: c, limit: centerModel.count }
            ]
            var elsewhenPlaced = false
            for (var regionIndex = 0; regionIndex < elsewhenRegions.length && !elsewhenPlaced; regionIndex++) {
                var regionItems = elsewhenRegions[regionIndex].items
                var emptyIndex = regionItems.indexOf("")
                if (emptyIndex >= 0) { regionItems[emptyIndex] = "G24"; elsewhenPlaced = true }
                else if (regionItems.length < elsewhenRegions[regionIndex].limit) {
                    regionItems.push("G24"); elsewhenPlaced = true
                }
            }
            if (!elsewhenPlaced) return
        }
        // F12: only apply a cache that is a valid permutation of all registry ids (correct region
        // sizes, every id known, no duplicate, none missing) — a corrupt cache would otherwise
        // duplicate one widget and silently drop another. On reject, keep the default order.
        if (l.length > leftModel.count || c.length > centerModel.count || r.length > rightModel.count) return
        // Empty slots are legal drop targets; pad older layouts in place.
        while (l.length < leftModel.count) l.push("")
        while (c.length < centerModel.count) c.push("")
        while (r.length < rightModel.count) r.push("")
        for (var t = 0; t < tray.length; t++) if (tray[t] === "G3") return
        var all = l.concat(c, r, tray), seen = {}
        for (var i = 0; i < all.length; i++) {
            if (all[i] === "") continue
            if (!registry[all[i]] || seen[all[i]]) return
            seen[all[i]] = true
        }
        if (Object.keys(seen).length !== Object.keys(registry).length) return
        applyTo(leftModel,   l)
        applyTo(centerModel, c)
        applyTo(rightModel,  r)
        barSlot.root.trayWidgets = tray
    }
    function moveSlotToTray(model, index) {
        if (!model || index < 0 || index >= model.count) return false
        var gid = String(model.get(index).gid || "")
        if (!gid || gid === "G3" || barSlot.root.trayWidgets.indexOf(gid) >= 0) return false
        model.setProperty(index, "gid", "")
        barSlot.root.trayWidgets = barSlot.root.trayWidgets.concat([gid])
        return true
    }
    function restoreTrayWidget(gid) {
        var trayIndex = barSlot.root.trayWidgets.indexOf(gid)
        if (trayIndex < 0) return false
        var models = [leftModel, centerModel, rightModel]
        for (var r = 0; r < models.length; r++) {
            var model = models[r]
            for (var i = 0; i < model.count; i++) {
                if (model.get(i).gid !== "") continue
                model.setProperty(i, "gid", gid)
                var next = barSlot.root.trayWidgets.slice()
                next.splice(trayIndex, 1)
                barSlot.root.trayWidgets = next
                if (_orderLoaded) saveOrder()
                return true
            }
        }
        return false
    }
    function saveOrder() {
        var serialized = serializeOrder()
        orderSaveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + orderCachePath + "')\" && printf '%s' '" + serialized + "' > '" + orderCachePath + "'"]
        orderSaveProc.running = false; orderSaveProc.running = true
        if (!barSlot.root._barLayoutSyncing) barSlot.root.syncBarOrder(barSlot.screenName, serialized)
    }
    Process { id: orderSaveProc }
    Process {
        id: orderLoadProc
        command: ["cat", barSlot.orderCachePath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim()
                if (t.length > 0) barSlot.applyOrder(t)
                barSlot._orderLoaded = true
            }
        }
    }
    // reset the 3 region models back to the default group order
    function resetOrder() {
        var defaults = V1Defaults.defaultOrder()
        for (var i = 0; i < defaults.left.length; i++) leftModel.setProperty(i, "gid", defaults.left[i])
        for (var j = 0; j < defaults.center.length; j++) centerModel.setProperty(j, "gid", defaults.center[j])
        for (var k = 0; k < defaults.right.length; k++) rightModel.setProperty(k, "gid", defaults.right[k])
        barSlot.root.trayWidgets = []
        if (_orderLoaded) saveOrder()
    }

    property var layoutController: ({
        ready: function () {
            return barSlot._orderLoaded
                && island._splitsLoaded
                && barSlot.backingWindowVisible
        },
        splitAll: function () {
            island.leftSplits     = Array(leftModel.count - 1).fill(true)
            island.rightSplits    = Array(rightModel.count - 1).fill(true)
            island.boundarySplits = [true, true]
        },
        mergeAll: function () {
            island.leftSplits     = Array(leftModel.count - 1).fill(false)
            island.rightSplits    = Array(rightModel.count - 1).fill(false)
            island.boundarySplits = [false, false]
            barSlot.root.barAnim  = 0
        },
        defaultLayout: function () {
            var defaults = V1Defaults.defaultSplits()
            island.leftSplits = defaults.left
            island.rightSplits = defaults.right
            island.boundarySplits = defaults.boundary
            barSlot.resetOrder()
        },
        applySplits: function (serialized) { island.applySplits(serialized) },
        applyOrder: function (serialized) { barSlot.applyOrder(serialized) },
        restoreTrayWidget: function (gid) { return barSlot.restoreTrayWidget(gid) }
    })

    Component.onCompleted: {
        if (!barSlot.root.activePopupScreenName) barSlot.root.activatePopupScreen(barSlot.screen)
        barSlot.root.registerBarLayoutController(barSlot.screenName, barSlot.layoutController)
        barSlot.root.registerTrayWidgetRegistry(barSlot.screenName, barSlot.registry)
    }

    Component.onDestruction: {
        if (barSlot.root
                && barSlot.root.isActivePopupScreenName(barSlot.screenName)
                && barSlot.root.anyPopupVisible) {
            barSlot.root.closePopups()
        }
        barSlot.root.unregisterBarLayoutController(barSlot.screenName, barSlot.layoutController)
        barSlot.root.unregisterTrayWidgetRegistry(barSlot.screenName, barSlot.registry)
        barSlot.root.removeTrayDropRect(barSlot.screenName)
    }

    ShaderEffectSource {
        id: ghost
        sourceItem: barSlot.dragItem
        width: barSlot.ghostW; height: barSlot.ghostH
        x: barSlot.ghostX; y: barSlot.ghostY
        visible: barSlot.dragging
        z: 100
        // dim while dragging over empty space (no valid drop → snap-back)
        opacity: barSlot.dragActive ? (barSlot.dropModel ? 0.95 : 0.45) : 0.92
        scale: barSlot.dragActive ? 1.06 : 1.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on x { enabled: !barSlot.dragActive; NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !barSlot.dragActive; NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 120 } }
    }


    // ─────────────────────────── group registry ───────────────────────────
    Component { id: compElsewhen; ElsewhenWidget { root: barSlot.root; screen: barSlot.screen } }
    Component { id: compOneDrive; OneDriveWidget { root: barSlot.root } }
    Component { id: compLauncher;  LauncherWidget  { root: barSlot.root } }
    Component { id: compWorkspace; WorkspaceWidget { root: barSlot.root; monitor: Hyprland.monitorFor(barSlot.screen) } }
    Component {
        id: compStatus                                   // G3: arch · tray · notif
        Item {
            visible: implicitWidth > 0.5
            implicitWidth: barSlot.root.modStatus ? Math.round(statusRow.implicitWidth) + 10 : 0
            implicitHeight: 28
            opacity: barSlot.root.modStatus ? 1 : 0
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Rectangle {
                anchors.centerIn: parent
                width: parent.implicitWidth; height: barSlot.root.pillH; radius: barSlot.root.pillRadius
                color: barSlot.root.pill; border.color: barSlot.root.pillBorder; border.width: barSlot.root.pillBorderW
                PillShadow { theme: barSlot.root }
            }
            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)
                spacing: 4
                ArchUpdaterWidget  { root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    TrayWidget         { root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                    NotificationWidget { root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
    Component { id: compMem;    MemoryWidget { root: barSlot.root } }
    Component { id: compCpu;    CpuWidget    { root: barSlot.root } }
    Component { id: compTemperature; CpuTemperatureWidget { root: barSlot.root } }
    Component { id: compStorage; StorageWidget { root: barSlot.root } }
    Component { id: compGpu;    GpuWidget    { root: barSlot.root } }
    Component { id: compVol;    AudioWidget  { root: barSlot.root } }
    Component { id: compClaude; ClaudeWidget { root: barSlot.root } }
    Component { id: compIndicators; IndicatorsWidget { root: barSlot.root } }

    Component {
        id: compCenter                                   // G8: weather·clock·date
        Item {
            id: g8
            implicitWidth: Math.round(centerRow.implicitWidth) + 18
            implicitHeight: 28

            // ── responsive stage (narrow-monitor overlap fix) ──
            // Presentation-only inside G8 — never touches root.mod* user toggles.
            // Mutable state with hysteresis, NOT a computed property: downshift when
            // the CURRENT stage no longer fits (24px slack), upshift only when the
            // LARGER stage would fit with 48px slack — measured against that stage's
            // own needed width, else minimal⇄compact oscillates.
            property int stage: 0                        // 0 normal · 1 compact · 2 minimal
            readonly property bool showWeather: stage <= 1
            readonly property bool showDate:    stage === 0
            readonly property bool showIcons:   iconsRow.hasActive
            // needed widths per stage: reactive bindings over the UNCOLLAPSED content
            // (the stage-gated wrapper widths shrink and would mislead the upshift
            // decision). 18 = pill padding, 8 = row spacing per visible neighbour.
            readonly property real needMinimal: 18 + clock.implicitWidth
                + (showIcons && iconsRow.implicitWidth > 0.5 ? 8 + iconsRow.implicitWidth : 0)
            readonly property real needCompact: needMinimal
                + (weather.implicitWidth > 0.5 ? 8 + weather.implicitWidth : 0)
            readonly property real needNormal: needCompact
                + (dateLabel.implicitWidth > 0.5 ? 8 + dateLabel.implicitWidth : 0)
            function updateStage() {
                // compact only while G8 actually occupies the center slot: after a
                // drag swap G8 can sit in a SIDE row — its own width then feeds the
                // very side-row width that centerAvail is measured from, and the
                // stage delta (~weather+date) exceeds the 24/48px hysteresis window
                // → boundary-width flutter. As a side widget G8 stays at normal.
                if (barSlot.gidsOf(centerModel).indexOf("G8") < 0) {
                    if (stage !== 0) stage = 0
                    return
                }
                var avail = island.centerAvail
                var s = stage
                if (s === 0 && needNormal  + 24 > avail) s = 1
                if (s === 1 && needCompact + 24 > avail) s = 2
                if (s === 2 && needCompact + 48 <= avail) s = 1
                if (s === 1 && needNormal  + 48 <= avail) s = 0
                if (s !== stage) stage = s
            }
            // publish the clock + status-icon floor width for the side-row budget
            Binding { target: island; property: "g8FloorWidth"; value: g8.needMinimal }
            // 80ms one-shot coalesces width flutter (track changes, tray churn)
            Timer { id: restageTimer; interval: 80; repeat: false; onTriggered: g8.updateStage() }
            onNeedNormalChanged:  restageTimer.restart()
            onNeedCompactChanged: restageTimer.restart()
            Connections { target: island; function onCenterAvailChanged() { restageTimer.restart() } }
            Component.onCompleted: restageTimer.restart()

            Rectangle {
                anchors.centerIn: parent
                width: parent.implicitWidth; height: barSlot.root.pillH; radius: barSlot.root.pillRadius
                color: barSlot.root.pill; border.color: barSlot.root.pillBorder; border.width: barSlot.root.pillBorderW
                PillShadow { theme: barSlot.root }
            }
            Row {
                id: centerRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)   // integer center → sharp text
                spacing: 8
                Item {                                   // weather wrapper (stage-gated)
                    visible: width > 0.5
                    width: g8.showWeather ? weather.implicitWidth : 0
                    height: 28
                    clip: true
                    opacity: g8.showWeather ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    WeatherWidget {
                        id: weather
                        anchors.fill: parent
                        root: barSlot.root
                    }
                }
                ClockWidget   { id: clock;   root: barSlot.root }
                Item {                                   // date (stage-gated)
                    visible: width > 0.5
                    width: g8.showDate ? dateLabel.implicitWidth : 0
                    height: 28
                    clip: true
                    opacity: g8.showDate ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    CommonComponents.UiText {
                        id: dateLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            void clock.now;
                            var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
                            var d = new Date();
                            return days[d.getDay()] + " " + d.getDate();
                        }
                        color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.5)
                        font.family: barSlot.root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 0.5
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            barSlot.root.activatePopupScreen(barSlot.screen)
                            barSlot.root.calendarTick++;
                            barSlot.root.calendarVisible = !barSlot.root.calendarVisible
                        }
                    }
                }
                Item {                                   // indicator icons wrapper (stage-gated)
                    visible: g8.showIcons || width > 0.5
                    width: g8.showIcons ? iconsRow.implicitWidth : 0
                    height: 28
                    clip: true
                    opacity: g8.showIcons ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Row {
                        id: iconsRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        readonly property bool hasActive: voxInd.state === "recording"
                            || voxInd.state === "transcribing"
                            || omarchyUpdateInd.updateAvailable
                        VoxtypeWidget            { id: voxInd;           root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        UpdateWidget             { id: omarchyUpdateInd; root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }

    Component { id: compMpris; MprisWidget { root: barSlot.root } }
    Component {
        id: compQuick                                    // G10: idle-inhib · media · theme
        Item {
            visible: implicitWidth > 0.5
            implicitWidth: barSlot.root.modQuick ? Math.round(qcRow.implicitWidth) + 16 : 0
            implicitHeight: 28
            opacity: barSlot.root.modQuick ? 1 : 0
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Rectangle {
                anchors.centerIn: parent
                width: parent.implicitWidth; height: barSlot.root.pillH; radius: barSlot.root.pillRadius
                color: barSlot.root.pill; border.color: barSlot.root.pillBorder; border.width: barSlot.root.pillBorderW
                PillShadow { theme: barSlot.root }
            }
            Row {
                id: qcRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)
                spacing: 4
                MediaBrowserWidget  { root: barSlot.root; screen: barSlot.screen; anchors.verticalCenter: parent.verticalCenter }
                ThemeDisplayWidget  { root: barSlot.root; screen: barSlot.screen; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    Component { id: compNetwork;    NetworkWidget      { root: barSlot.root } }
    Component { id: compNordVpn;    NordVPNWidget      { root: barSlot.root } }
    Component { id: compWallpapers; WallpaperManagerQuickWidget { root: barSlot.root; screen: barSlot.screen } }
    Component { id: compDisplayManager; DisplayManagerWidget { root: barSlot.root; screen: barSlot.screen } }
    Component { id: compPower;      PowerProfileWidget { root: barSlot.root } }
    Component { id: compBattery;    BatteryWidget      { root: barSlot.root } }
    Component { id: compBrightness; BrightnessWidget   { root: barSlot.root } }
    Component { id: compBluetooth;  BluetoothWidget    { root: barSlot.root } }

    readonly property var registry: ({
        "G24": compElsewhen, "G22": compOneDrive, "G1": compLauncher, "G2": compWorkspace, "G3": compStatus,
        "G4": compMem, "G5": compCpu, "G6": compVol, "G7": compClaude,
        "G8": compCenter,
        "G9": compMpris, "G10": compQuick, "G11": compNetwork,
        "G12": compBattery, "G13": compBrightness, "G14": compPower, "G15": compBluetooth,
        "G16": compNordVpn, "G17": compWallpapers, "G18": compDisplayManager, "G19": compGpu, "G20": compTemperature, "G21": compStorage, "G23": compIndicators
    })

    // ───────────────────── reusable region row of slots ─────────────────────
    component SlotRow: Row {
        property var rmodel
        property var splitsArr          // per-gap split flags (split AFTER slot i)
        property var toggleGap          // function(i): toggle the split after slot i
        property alias rep: repeater
        spacing: 6
        height: 32
        // index of the LAST currently shown slot (skips disabled and auto-hidden
        // narrow-stage widgets) —
        // a split/grow only makes sense BEFORE this (else it opens a gap to nowhere)
        readonly property int lastVisibleIndex: {
            void(width)
            var last = -1
            for (var k = 0; k < repeater.count; k++) {
                var it = repeater.itemAt(k)
                if (it && it.hasContent && it.autoShown) last = k
            }
            return last
        }
        Repeater {
            id: repeater
            model: rmodel
            delegate: Item {
                id: slot
                required property string gid
                required property int index
                // workspace draws a pill 4px wider than its implicitWidth on each
                // side; pad its slot symmetrically so inter-group gaps stay uniform.
                readonly property int pad: slot.gid === "G2" ? barSlot.root.wsPillPad : 0
                readonly property bool occupied: gid !== "" && barSlot.registry[gid] !== undefined
                readonly property bool placeholderShown: !occupied && barSlot.root.barUnlocked
                readonly property bool hasContent: occupied && Math.round(ldr.implicitWidth) > 0.5
                readonly property bool hasGapAfter: splitsArr ? (index < splitsArr.length) : false
                // split AFTER this slot → grow it so the group separates (gap opens).
                // ONLY for widgets with content — a 0-width widget (battery/brightness on
                // a desktop) must NOT grow, else it shows up as an empty pill.
                readonly property bool splitAfter: autoShown && hasGapAfter && splitsArr[index]
                readonly property real grow: (splitAfter && hasContent && index < lastVisibleIndex) ? 16 : 0
                readonly property real cr: pad + Math.round(ldr.implicitWidth)
                // display width: follows the stage (grow via splitAfter is
                // autoShown-aware so hidden slots also drop their split growth)
                readonly property real naturalSlotWidth: placeholderShown ? 32 : occupied ? Math.round(ldr.implicitWidth) + 2 * pad + grow : 0
                // budget width: the ONLY width the narrow-stage decision may read.
                // MUST stay stage-independent (no autoShown/lastVisibleIndex terms,
                // which flip with the stage): a stage-dependent budget feeds back
                // into its own decision and oscillates once ≥2 split-grows (2×16px)
                // exceed the 24px hysteresis window. Conservative: counts the split
                // grow even for hidden/trailing slots (≤16px overestimate, fail-safe).
                readonly property real budgetSlotWidth: placeholderShown ? 32 : occupied ? Math.round(ldr.implicitWidth) + 2 * pad
                    + ((hasGapAfter && splitsArr[index] && hasContent) ? 16 : 0) : 0
                readonly property bool autoShown: island.groupVisibleAtStage(slot.gid, island.narrowStage)
                onBudgetSlotWidthChanged: island.scheduleNarrowUpdate()
                width: autoShown ? naturalSlotWidth : 0
                height: 32
                visible: placeholderShown || (hasContent && (autoShown || width > 0.5))   // stays visible while collapsing
                opacity: autoShown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Loader {
                    id: ldr
                    x: slot.pad
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: slot.occupied ? barSlot.registry[slot.gid] : null
                    // dim the original while its ghost is being dragged
                    opacity: (barSlot.dragItem === ldr && barSlot.dragActive) ? 0.25 : 1.0
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 24
                    visible: slot.placeholderShown
                    radius: barSlot.root.tileRadius
                    color: barSlot.root.fillIdle
                    border.color: barSlot.root.sep
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "·"
                        color: barSlot.root.sumi
                        font.family: barSlot.root.mono
                        font.pixelSize: 14
                    }
                }
                // ── drag-catcher: only in unlock mode, overlays the widget ──
                MouseArea {
                    anchors.fill: parent
                    enabled: barSlot.root.barUnlocked && slot.autoShown && slot.hasContent
                    visible: barSlot.root.barUnlocked && slot.autoShown
                    z: 25
                    preventStealing: true
                    cursorShape: Qt.OpenHandCursor
                    onPressed: {
                        var p = ldr.mapToItem(null, 0, 0)
                        barSlot.beginDrag(ldr, p.x, p.y, Math.round(ldr.implicitWidth), slot.height, rmodel, slot.index)
                    }
                    onPositionChanged: (e) => {
                        if (!barSlot.dragging) return
                        var w = mapToItem(null, e.x, e.y)
                        var g = mapToGlobal(e.x, e.y)
                        barSlot.moveDrag(w.x, w.y, g.x, g.y)
                    }
                    onReleased: barSlot.endDrag()
                    onCanceled: barSlot.cancelDrag()
                }
                // drop-target highlight (the group under the cursor, not the source)
                Rectangle {
                    anchors.fill: parent
                    radius: barSlot.root.pillRadius
                    color: Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.18)
                    border.color: barSlot.accent
                    border.width: 2
                    z: 26
                    visible: barSlot.dragging
                        && barSlot.dropModel === rmodel && barSlot.dropIndex === slot.index
                        && !(barSlot.srcModel === rmodel && barSlot.srcIndex === slot.index)
                }
                // ── split toggle for the gap AFTER this slot (child of slot → tracks it) ──
                Item {
                    visible: slot.hasContent && slot.autoShown && slot.hasGapAfter && slot.index < lastVisibleIndex
                    width: 14
                    height: slot.height
                    x: (slot.cr + slot.pad + slot.width + 6) / 2 - width / 2   // centered in the gap (cr+pad = pill-right, matches gapInterval)
                    z: 30
                    MouseArea {
                        id: mkMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if ((!barSlot.root.layoutProtected || barSlot.root.barUnlocked) && toggleGap) toggleGap(slot.index)
                    }
                }
            }
        }
    }

    Item {
        id: island
        visible: !barSlot.root.barVertical
        // vertical placement via y (NOT conditional top/bottom anchors): toggling
        // anchors live left a stale edge set → island stretched top+bottom → widgets
        // spread to mid-screen. A plain y switches cleanly on a live position change.
        // Fit the complete saved layout on narrow/portrait outputs. Keep logical
        // coordinates at their natural size, then scale the whole strip together.
        readonly property real availableWidth: Math.max(1, barSlot.width - 10)
        readonly property real completeWidth: sideNaturalWidth(leftRowItem, 0)
            + sideNaturalWidth(rightRowItem, 0) + centerRowItem.width
            + 2 * centerGap + 2 * rowMargin + 48
        readonly property real fitScale: Math.min(1, availableWidth / Math.max(1, completeWidth))
        x: 5
        width: availableWidth / fitScale
        scale: fitScale
        transformOrigin: Item.TopLeft
        height: 32
        y: barSlot.root.barPosition === "bottom" ? (parent.height - height * fitScale - 3) : 3 + (32 - height * fitScale) / 2
        z: 2                                  // above the dim backdrop
        focus: barSlot.root.barUnlocked       // receive keys while unlocked
        Keys.onEscapePressed: barSlot.root.barUnlocked = false

        // edit-mode frame around the bar while unlocked (gentle pulse)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: barSlot.root.islandRadius + 2
            color: "transparent"
            border.color: barSlot.accent
            border.width: barSlot.root.barUnlocked ? 1 : 0    // width 0 hides it when locked
            z: 40
            SequentialAnimation on opacity {
                running: barSlot.root.barUnlocked
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.45; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            }
        }

        // DOUBLE-click EMPTY bar area → unlock (sits below widgets/markers).
        // double-click so a stray single click while aiming for Control/Volume can't
        // accidentally trigger unlock. (lock again via dim backdrop click / ESC.)
        MouseArea {
            anchors.fill: parent
            z: -1
            onDoubleClicked: if (!barSlot.root.layoutProtected) barSlot.root.barUnlocked = true
        }

        // ── split state (positional, per within-region gap) ──
        property var leftSplits:  [true, true, true, true, true, true, true, false, false, false, false, false, false, false]   // gaps in leftModel
        property var rightSplits: [true, true, true, true, true, true, true, true, false, false, false, false, false]   // gaps in rightModel
        property var boundarySplits: [true, true]   // [left↔center, center↔right]

        readonly property real lcBoundaryX: leftRowItem.x + leftRowItem.width + 9    // just right of Claude
        readonly property real crBoundaryX: rightRowItem.x - 9                       // just left of Mpris

        // ── G8 collision handling (narrow-monitor overlap fix) ──
        // free span between the side rows; the only stage-decision input — reads
        // ONLY left/right geometry (never the center row), so stage changes that
        // resize G8 cannot feed back into this value (no binding loop).
        readonly property int centerGap: 12
        readonly property int rowMargin: 4    // single source for the side-row edge margins + budget math
        readonly property real centerAvail: rightRowItem.x - (leftRowItem.x + leftRowItem.width) - 2 * centerGap
        // centered while space allows; clamped between the rows when squeezed.
        // If even the current G8 width cannot fit (max < min), fall back to the
        // screen-clamped ideal — the documented extreme case may overlap.
        readonly property real idealCenterX: Math.round((width - centerRowItem.width) / 2)
        readonly property real minCenterX: Math.round(leftRowItem.x + leftRowItem.width + centerGap)
        readonly property real maxCenterX: Math.round(rightRowItem.x - centerGap - centerRowItem.width)
        readonly property real centerTargetX: maxCenterX < minCenterX
            ? Math.max(4, Math.min(idealCenterX, width - centerRowItem.width - 4))
            : Math.max(minCenterX, Math.min(idealCenterX, maxCenterX))

        // Natural widths stay independent of the output scale. Every enabled
        // group remains visible; fitScale handles portrait outputs per monitor.
        property int narrowStage: 0            // 0 normal · 1 compact · 2 portrait · 3 emergency
        property real g8FloorWidth: 80         // published by G8: its clock-only minimal width
        function groupVisibleAtStage(gid, stage) {
            return true
        }
        function sideNaturalWidth(row, stage) {
            var sum = 0, n = 0
            for (var k = 0; k < row.rep.count; k++) {
                var it = row.rep.itemAt(k)
                if (!it || (!it.hasContent && !it.placeholderShown)) continue
                if (!groupVisibleAtStage(it.gid, stage)) continue
                sum += it.budgetSlotWidth; n++
            }
            return sum + Math.max(0, n - 1) * row.spacing
        }
        function narrowCandidateWidth(stage) {
            // side rows + G8 floor + row margins + both center gaps
            return sideNaturalWidth(leftRowItem, stage) + sideNaturalWidth(rightRowItem, stage)
                 + g8FloorWidth + 2 * centerGap + 2 * rowMargin
        }
        function updateNarrowStage() {
            narrowStage = 0
        }
        function scheduleNarrowUpdate() { narrowTimer.restart() }
        Timer { id: narrowTimer; interval: 80; repeat: false; onTriggered: island.updateNarrowStage() }
        onWidthChanged: scheduleNarrowUpdate()
        onG8FloorWidthChanged: scheduleNarrowUpdate()

        // ── split persistence (survives restart) ──
        readonly property string splitCachePath: Quickshell.env("HOME") + "/.cache/quickshell_barsplits"
        property bool _splitsLoaded: false
        function _b2s(a) { return a.map(function (b) { return b ? "1" : "0" }).join("") }
        function _s2b(s, n) { var a = []; for (var i = 0; i < n; i++) a.push(s.charAt(i) === "1"); return a }
        function serializeSplits() { return _b2s(leftSplits) + "|" + _b2s(rightSplits) + "|" + _b2s(boundarySplits) }
        function applySplits(str) {
            var p = str.split("|")
            if (p.length !== 3) return
            if (/^[01]+$/.test(p[0]) && p[0].length <= leftSplits.length) {
                var left = _s2b(p[0], p[0].length)
                if (left.length === 6) left.push(true) // legacy GPU boundary
                leftSplits = left.concat(Array(leftSplits.length - left.length).fill(false))
            }
            if (/^[01]+$/.test(p[1]) && p[1].length <= rightSplits.length)
                rightSplits = _s2b(p[1], p[1].length).concat(Array(rightSplits.length - p[1].length).fill(false))
            if (p[2].length === boundarySplits.length) boundarySplits = _s2b(p[2], boundarySplits.length)
        }
        function saveSplits() {
            var serialized = serializeSplits()
            splitSaveProc.command = ["bash", "-c",
                "mkdir -p \"$(dirname '" + splitCachePath + "')\" && printf '%s' '" + serialized + "' > '" + splitCachePath + "'"]
            splitSaveProc.running = false; splitSaveProc.running = true
            if (!barSlot.root._barLayoutSyncing) barSlot.root.syncBarSplits(barSlot.screenName, serialized)
        }
        onLeftSplitsChanged:     if (_splitsLoaded) saveSplits()
        onRightSplitsChanged:    if (_splitsLoaded) saveSplits()
        onBoundarySplitsChanged: if (_splitsLoaded) saveSplits()
        Process { id: splitSaveProc }
        Process {
            id: splitLoadProc
            command: ["cat", island.splitCachePath]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    var t = this.text.trim()
                    if (t.length > 0) island.applySplits(t)
                    island._splitsLoaded = true
                }
            }
        }

        // island-X of the gap between slot i and i+1 of a region's repeater
        // uncovered interval [from,to] for a within-region split: 4px after the
        // content-right of slot i, 4px before the next VISIBLE slot's content-left.
        function gapInterval(rep, i) {
            var a = rep.itemAt(i)
            if (!a || !a.hasContent || !a.autoShown) return null
            var b = null                                   // next VISIBLE slot (skip 0-width)
            for (var k = i + 1; k < rep.count; k++) { var it = rep.itemAt(k); if (it && it.hasContent && it.autoShown) { b = it; break } }
            if (!b) return null
            // a.width - a.grow = slot's pill-right edge (handles workspace ±4 overflow);
            // 0 = next slot's pill-left edge. 4px padding on each side.
            var aR = a.mapToItem(island, a.width - a.grow, 0).x + 4
            var bL = b.mapToItem(island, 0, 0).x - 4
            return (bL > aR) ? [aR, bL] : null
        }
        // run rectangles (island coords): pill breaks at each active split, small gap
        function computeRuns() {
            // each split = an uncovered interval [from, to]; runs = covered gaps between.
            var cuts = []
            // within-region: a small 12px gap around the break
            for (var i = 0; i < leftSplits.length; i++)
                if (leftSplits[i])  { var ci = gapInterval(leftRowItem.rep, i);  if (ci) cuts.push(ci) }
            for (var j = 0; j < rightSplits.length; j++)
                if (rightSplits[j]) { var cj = gapInterval(rightRowItem.rep, j); if (cj) cuts.push(cj) }
            // boundary: cut out the WHOLE empty whitespace so the pill hugs the content
            // center boundaries — if the center is empty (its widget disabled) AND both
            // sides are split, merge into ONE cut so no thin center pill is left over
            // right edge for boundary cuts: if the right region is empty, cut all the
            // way to the island edge so no thin pill is left at the right margin
            var rEnd = rightRowItem.width < 1 ? island.width : rightRowItem.x - 4
            if (boundarySplits[0] && boundarySplits[1] && centerRowItem.width < 1) {
                var lm = leftRowItem.x + leftRowItem.width + 4
                if (rEnd > lm) cuts.push([lm, rEnd])
            } else {
                if (boundarySplits[0]) { var l1 = leftRowItem.x + leftRowItem.width + 4, r1 = centerRowItem.x - 4; if (r1 > l1) cuts.push([l1, r1]) }
                if (boundarySplits[1]) { var l2 = centerRowItem.x + centerRowItem.width + 4; if (rEnd > l2) cuts.push([l2, rEnd]) }
            }
            cuts.sort(function (a, b) { return a[0] - b[0] })
            var runs = [], start = 0
            for (var k = 0; k < cuts.length; k++) {
                if (cuts[k][0] > start) runs.push({ x: start, w: cuts[k][0] - start })
                if (cuts[k][1] > start) start = cuts[k][1]
            }
            if (island.width > start) runs.push({ x: start, w: island.width - start })
            return runs
        }
        readonly property var runs: {
            void(leftSplits); void(rightSplits); void(boundarySplits);
            void(leftRowItem.width); void(rightRowItem.width); void(centerRowItem.width); void(island.width);
            void(centerRowItem.x);   // clamped center can move without any width change
            // (left x is anchor-constant; right x is derived from width + island.width above)
            return computeRuns()
        }

        // ── ParticleStream shim: expose the API it expects over our `runs` ──
        readonly property var pillRuns: { var a = []; for (var i = 0; i < runs.length; i++) a.push({ s: i, e: i }); return a }
        function runRightEdge(i) { return runs[i].x + runs[i].w }
        function runLeftEdge(i)  { return runs[i].x }

        // ── section pill(s): one per run (one continuous pill when no splits) ──
        Repeater {
            model: island.runs
            delegate: Rectangle {
                required property var modelData
                x: modelData.x
                width: Math.max(0, modelData.w)
                height: island.height
                radius: barSlot.root.islandRadius
                color: barSlot.root.barBg
                border.color: barSlot.root.islandBorder
                border.width: barSlot.root.pillBorderW
                PillShadow { theme: barSlot.root }
                // no Behavior: tracks the slot positions directly as the gap opens
            }
        }

        // ── gap particle animation (flows in split gaps only when enabled) ──
        Item {
            id: particleLayer
            anchors.fill: parent
            z: 1                          // above the section pills, below the widgets
            visible: barSlot.root.barAnim > 0 && island.runs.length > 1

            LazyLoader {
                active: particleLayer.visible

                ParticleStream {
                    parent: particleLayer
                    x: 0
                    y: 0
                    width: particleLayer.width
                    height: particleLayer.height
                    theme:  barSlot.root
                    layout: island
                    mode:   barSlot.root.barAnim
                    active: true
                    monitor: barSlot.screen ? barSlot.screen.name : ""
                }
            }
        }

        // ── region models (physical L→R order) ──
        ListModel {
            id: leftModel
            ListElement { gid: "G1" } ListElement { gid: "G2" } ListElement { gid: "G3" }
            ListElement { gid: "G4" } ListElement { gid: "G5" } ListElement { gid: "G6" }
            ListElement { gid: "G7" } ListElement { gid: "G19" } ListElement { gid: "G20" } ListElement { gid: "G21" } ListElement { gid: "G22" }
            ListElement { gid: "" } ListElement { gid: "" } ListElement { gid: "" } ListElement { gid: "" }
        }
        ListModel { id: centerModel; ListElement { gid: "G8" } ListElement { gid: "G23" } ListElement { gid: "" } ListElement { gid: "" } ListElement { gid: "" } ListElement { gid: "" } ListElement { gid: "" } ListElement { gid: "" } }
        ListModel {
            id: rightModel
            ListElement { gid: "G9" }  ListElement { gid: "G10" } ListElement { gid: "G17" }
            ListElement { gid: "G14" } ListElement { gid: "G12" } ListElement { gid: "G13" }
            ListElement { gid: "G11" } ListElement { gid: "G16" } ListElement { gid: "G15" } ListElement { gid: "G18" } ListElement { gid: "G24" }
            ListElement { gid: "" } ListElement { gid: "" } ListElement { gid: "" }
        }

        SlotRow {
            id: leftRowItem
            anchors { left: parent.left; leftMargin: island.rowMargin; verticalCenter: parent.verticalCenter }
            rmodel: leftModel
            splitsArr: island.leftSplits
            toggleGap: function (i) { var a = island.leftSplits.slice(); a[i] = !a[i]; island.leftSplits = a }
        }
        SlotRow {
            id: centerRowItem
            // no centerIn: x is clamped between the side rows on narrow monitors
            anchors.verticalCenter: parent.verticalCenter
            x: island.centerTargetX
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            rmodel: centerModel
        }
        SlotRow {
            id: rightRowItem
            anchors { right: parent.right; rightMargin: island.rowMargin; verticalCenter: parent.verticalCenter }
            rmodel: rightModel
            splitsArr: island.rightSplits
            toggleGap: function (i) { var a = island.rightSplits.slice(); a[i] = !a[i]; island.rightSplits = a }
        }

        // ── slot-aware panel X positions: publish per-screen anchors ──
        // find a group's slot and map its (frac·width) to window/screen X.
        function groupX(gid, frac) {
            var rows = [leftRowItem, centerRowItem, rightRowItem]
            for (var r = 0; r < rows.length; r++) {
                var row = rows[r]
                var rep = row.rep
                if (!rep) continue
                for (var k = 0; k < rep.count; k++) {
                    var it = rep.itemAt(k)
                    if (it && it.gid === gid) {
                        return it.mapToItem(null, it.width * frac, 0).x
                    }
                }
            }
            return 0
        }

        readonly property string panelScreenName: barSlot.screen ? barSlot.screen.name : ""
        readonly property var panelAnchors: {
            void(island.width)
            void(island.x)
            void(island.fitScale)
            void(leftRowItem.x); void(centerRowItem.x); void(rightRowItem.x)
            void(leftRowItem.width); void(centerRowItem.width); void(rightRowItem.width)
            return {
                tray:         island.groupX("G3",  0.0),
                notif:        island.groupX("G3",  0.0),
                quickActions: island.groupX("G10", 0.5),
                volume:       island.groupX("G6",  0.5),
                network:      island.groupX("G11", 0.5),
                battery:      island.groupX("G12", 0.5),
                memory:       island.groupX("G4",  0.5),
                cpu:          island.groupX("G5",  0.5),
                gpu:          island.groupX("G19", 0.5),
                thermal:      island.groupX("G20", 0.5),
                oneDrive:        island.groupX("G22", 0.5),
                elsewhen:     island.groupX("G24", 0.5),
                storage:      island.groupX("G21", 0.5),
                ai:           island.groupX("G7",  0.5),
                workspace:    island.groupX("G2",  0.5),
                arch:         island.groupX("G3",  0.5),
                bluetooth:    island.groupX("G15", 0.5),
                brightness:   island.groupX("G13", 0.5),
                power:        island.groupX("G14", 0.5),
                mpris:        island.groupX("G9",  0.5),
                weather:      island.groupX("G8",  0.5),
                launcher:     island.groupX("G1",  0.5)
            }
        }
        Connections {
            target: barSlot.root
            function onBarPositionChanged() {
                if (!barSlot.root.barVertical) barSlot.root.publishBarAnchors(island.panelScreenName, island.panelAnchors)
            }
        }
        onPanelAnchorsChanged: if (!barSlot.root.barVertical) barSlot.root.publishBarAnchors(panelScreenName, panelAnchors)
        Component.onCompleted: if (!barSlot.root.barVertical) barSlot.root.publishBarAnchors(panelScreenName, panelAnchors)

        // ── boundary split markers (left↔center, center↔right) ──
        // positioned via real Row geometries (no mapToItem → robust).
        component BoundaryMarker: Item {
            id: bm
            property real bx
            property bool splitOn
            property var toggleFn
            visible: bx > 0
            x: bx - width / 2
            width: 14
            height: island.height
            z: 30
            MouseArea {
                id: bMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if ((!barSlot.root.layoutProtected || barSlot.root.barUnlocked) && bm.toggleFn) bm.toggleFn()
            }
        }
        BoundaryMarker {
            bx: island.lcBoundaryX
            splitOn: island.boundarySplits[0]
            toggleFn: function () { var a = island.boundarySplits.slice(); a[0] = !a[0]; island.boundarySplits = a }
        }
        BoundaryMarker {
            bx: island.crBoundaryX
            splitOn: island.boundarySplits[1]
            toggleFn: function () { var a = island.boundarySplits.slice(); a[1] = !a[1]; island.boundarySplits = a }
        }
    }
}
