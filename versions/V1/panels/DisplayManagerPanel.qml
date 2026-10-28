import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel
    required property var root
    property bool connectedStyle: false
    readonly property int barBottom: 35
    readonly property int gap: 8
    property Component headerComponent: null
    readonly property Item surfaceHost: frameCard
    readonly property var controller: root.displayManagerControllerApi
    readonly property var selectedDisplay: controller.previewMonitor(controller.selectedMonitor)
    property bool draftAutoWorkspaces: root.displayManagerAutoWorkspaces
    function applyChanges() {
        if (controller.busy || controller.loading || controller.rollbackPending) return false
        var m = selectedDisplay
        if (m && !m.disabled) {
            if (!posX.contentItem.acceptableInput || !posY.contentItem.acceptableInput) return false
            var x = posX.valueFromText(posX.contentItem.text, posX.locale), y = posY.valueFromText(posY.contentItem.text, posY.locale)
            if (!Number.isInteger(x) || !Number.isInteger(y) || !controller.stageMonitor(m.name, { x: x, y: y })) return false
        }
        if (!controller.applyDrafts()) return false
        root.displayManagerAutoWorkspaces = draftAutoWorkspaces
        return true
    }
    screen: root.activePopupScreen
    visible: root.displayManagerVisible && root.activePopupScreen !== null
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-rise-display-manager"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    onVisibleChanged: if (visible) { panel.controller.refresh(); panel.controller.refreshWorkspaces() }

    function activeDisplayCount() {
        return controller.previewMonitors.filter(function(m) { return !m.disabled }).length
    }
    function mirrorTargets() {
        return controller.previewMonitors.filter(function(m) { return !m.disabled && m.name !== controller.selectedMonitor && (!m.mirrorOf || m.mirrorOf === "none") }).map(function(m) { return m.name })
    }
    function modeFor(m) {
        return String(m.width) + "x" + String(m.height) + "@" + String(Number(m.refreshRate || 60))
    }
    function displayMode(m) {
        if (!m) return "preferred"
        if (typeof m.mode === "string" && m.mode) return m.mode
        var state = m.disabled && controller.savedDisplayStates ? controller.savedDisplayStates[m.name] || m : m
        if (!(Number(state.width) > 0 && Number(state.height) > 0 && Number(state.refreshRate) > 0)) return "preferred"
        return state.width + "x" + state.height + "@" + Number(state.refreshRate)
    }
    function sameMode(a, b) {
        a = String(a).trim().replace(/Hz$/i, "")
        b = String(b).trim().replace(/Hz$/i, "")
        if (a === b) return true
        var aa = a.split("@"), bb = b.split("@")
        return aa.length === 2 && bb.length === 2 && aa[0] === bb[0]
            && isFinite(Number(aa[1])) && isFinite(Number(bb[1])) && Math.abs(Number(aa[1]) - Number(bb[1])) < 0.05
    }
    function modeOptions(m) {
        var options = ["preferred"]
        if (m && Array.isArray(m.availableModes)) {
            for (var mode of m.availableModes) if (typeof mode === "string" && options.indexOf(mode) < 0) options.push(mode)
        }
        var selected = displayMode(m)
        if (!options.some(function(value) { return sameMode(value, selected) })) options.push(selected)
        return options
    }
    function modeIndex(m, options) {
        var selected = displayMode(m)
        for (var i = 0; i < options.length; i++) if (sameMode(options[i], selected)) return i
        return 0
    }
    function commitCanvasPosition(name, startX, startY, dx, dy, ratio) {
        var m = controller.previewMonitor(name)
        if (!m || controller.busy || controller.loading || controller.rollbackPending || m.disabled || (m.mirrorOf && m.mirrorOf !== "none")
            || !isFinite(dx) || !isFinite(dy) || !isFinite(ratio) || ratio <= 0) return false
        var x = Math.round(startX + dx / ratio), y = Math.round(startY + dy / ratio)
        if (x < -32768 || x > 32767 || y < -32768 || y > 32767) return false
        var rotated = Number(m.transform || 0) % 2 === 1
        var w = Number(rotated ? m.height : m.width) / Number(m.scale || 1)
        var h = Number(rotated ? m.width : m.height) / Number(m.scale || 1)
        if (!isFinite(x) || !isFinite(y) || !isFinite(w) || !isFinite(h) || w <= 0 || h <= 0) return false
        var peers = []
        for (var i = 0; i < controller.previewMonitors.length; i++) {
            var other = controller.previewMonitors[i]
            if (other.name === name || other.disabled || (other.mirrorOf && other.mirrorOf !== "none")) continue
            var pos = controller.previewPositions[other.name] || other
            var otherRotated = Number(other.transform || 0) % 2 === 1
            var ow = Number(otherRotated ? other.height : other.width) / Number(other.scale || 1)
            var oh = Number(otherRotated ? other.width : other.height) / Number(other.scale || 1)
            var ox = Number(pos.x || 0), oy = Number(pos.y || 0)
            if (!isFinite(ox) || !isFinite(oy) || !isFinite(ow) || !isFinite(oh) || ow <= 0 || oh <= 0) return false
            peers.push({ x: ox, y: oy, w: ow, h: oh })
        }
        function overlaps(px, py) {
            for (var p of peers) {
                if (px < p.x + p.w && px + w > p.x && py < p.y + p.h && py + h > p.y) return true
            }
            return false
        }
        // Magnetic edge attachment: 12 pixels in the canvas, not desktop pixels.
        // Snap only edges with a shared passage, never isolated corner contact.
        var distance = 12 / ratio, best = null
        function consider(px, py, adjustment) {
            if (adjustment > distance || px < -32767 || px > 32767 || py < -32767 || py > 32767
                || overlaps(px, py)) return
            if (!best || adjustment < best.distance) best = { x: px, y: py, distance: adjustment }
        }
        for (var peer of peers) {
            if (y < peer.y + peer.h && y + h > peer.y) {
                var right = Math.ceil(peer.x + peer.w), left = Math.floor(peer.x - w)
                consider(right, y, Math.abs(right - x))
                consider(left, y, Math.abs(left - x))
            }
            if (x < peer.x + peer.w && x + w > peer.x) {
                var bottom = Math.ceil(peer.y + peer.h), top = Math.floor(peer.y - h)
                consider(x, bottom, Math.abs(bottom - y))
                consider(x, top, Math.abs(top - y))
            }
        }
        if (best) { x = best.x; y = best.y }
        if (overlaps(x, y)) {
            controller.error = "Displays cannot overlap. Place this display beside another."
            return false
        }
        return controller.stageMonitor(name, { x: x, y: y })
    }
    component RiseButton: Controls.Button {
        id: button
        font.family: panel.root.mono; font.pixelSize: 11
        implicitWidth: Math.max(58, contentItem.implicitWidth + 24); implicitHeight: 30
        contentItem: Text {
            text: button.text; textFormat: Text.PlainText
            color: panel.root.ink; font: button.font
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: panel.root.tileRadius
            color: button.down || button.checked ? panel.root.fillActive : button.hovered ? panel.root.fillHover : panel.root.fillIdle
            border.color: button.hovered || button.checked ? panel.root.seal : panel.root.sep
            opacity: button.enabled ? 1 : 0.45
        }
    }
    component RiseComboBox: Controls.ComboBox {
        id: combo
        font.family: panel.root.mono; font.pixelSize: 11
        implicitWidth: 160; implicitHeight: 30
        leftPadding: 10; rightPadding: 24
        contentItem: Text {
            text: combo.displayText; textFormat: Text.PlainText; color: panel.root.ink
            font: combo.font; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
        }
        indicator: Text { x: combo.width - 18; y: 7; text: "▾"; color: panel.root.seal; font: combo.font }
        background: Rectangle { radius: panel.root.tileRadius; color: combo.hovered ? panel.root.fillHover : panel.root.fillIdle; border.color: combo.activeFocus ? panel.root.seal : panel.root.sep }
        delegate: Controls.ItemDelegate {
            width: combo.width
            text: String(modelData)
            contentItem: Text { text: parent.text; textFormat: Text.PlainText; color: panel.root.ink; font: combo.font; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.highlighted ? panel.root.fillActive : panel.root.paper }
        }
        popup: Controls.Popup {
            y: combo.height + 4; width: combo.width; padding: 2
            implicitHeight: Math.min(240, contentItem.implicitHeight + 4)
            contentItem: ListView { clip: true; implicitHeight: contentHeight; model: combo.popup.visible ? combo.delegateModel : null; currentIndex: combo.highlightedIndex }
            background: Rectangle { color: panel.root.paper; radius: panel.root.tileRadius; border.color: panel.root.sep }
        }
    }
    component RiseSpinBox: Controls.SpinBox {
        id: spin
        font.family: panel.root.mono; font.pixelSize: 11
        implicitWidth: 115; implicitHeight: 30
        leftPadding: 24; rightPadding: 24
        contentItem: TextInput {
            text: spin.textFromValue(spin.value, spin.locale); font: spin.font; color: panel.root.ink
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            readOnly: !spin.editable; validator: spin.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
        }
        background: Rectangle { color: panel.root.fillIdle; radius: panel.connectedStyle ? Math.min(4, panel.root.tileRadius) : panel.root.tileRadius; border.color: panel.root.sep }
        up.indicator: Rectangle { x: spin.width - width; width: 24; height: spin.height; color: spin.up.pressed ? panel.root.fillActive : panel.root.fillHover; Text { anchors.centerIn: parent; text: "+"; color: panel.root.ink; font: spin.font } }
        down.indicator: Rectangle { width: 24; height: spin.height; color: spin.down.pressed ? panel.root.fillActive : panel.root.fillHover; Text { anchors.centerIn: parent; text: "−"; color: panel.root.ink; font: spin.font } }
    }
    component RiseSlider: Controls.Slider {
        id: slider
        implicitWidth: 200; implicitHeight: 30
        background: Rectangle { x: slider.leftPadding; y: (slider.height - height) / 2; width: slider.availableWidth; height: 4; radius: 2; color: panel.root.sep
            Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 2; color: panel.root.seal }
        }
        handle: Rectangle { x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width); y: (slider.height - height) / 2; width: 14; height: 14; radius: 7; color: panel.root.seal; opacity: slider.enabled ? 1 : 0.4 }
    }
    component RiseCheckBox: Controls.CheckBox {
        id: check
        implicitWidth: checkLabel.implicitWidth + 24; implicitHeight: 30
        width: implicitWidth; height: implicitHeight
        indicator: null
        contentItem: Text {
            id: checkLabel
            text: check.text + (check.checked ? " · ON" : " · OFF")
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 11
        }
        background: Rectangle {
            radius: panel.root.tileRadius
            color: check.checked ? panel.root.fillActive : panel.root.fillIdle
            border.color: check.checked || check.activeFocus ? panel.root.seal : panel.root.sep
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: panel.root.displayManagerVisible = false
    }
    Rectangle {
        id: frameCard
        x: panel.connectedStyle ? Math.round(Math.max(6, Math.min(panel.root.displayManagerBarX - width / 2, panel.width - width - 6))) : Math.round(Math.max(0, Math.min(panel.width - width - 16, panel.root.displayManagerBarX - (width + 16) / 2))) + 8
        y: panel.connectedStyle ? (panel.root.barPosition === "bottom" ? panel.height - panel.root.v2BarHeight - 6 - height : panel.root.v2BarHeight + 6) : (panel.root.barPosition === "bottom" ? panel.height - panel.barBottom - panel.gap - height : panel.barBottom + panel.gap)
        width: Math.min(456, panel.width - 16)
        height: panelContent.implicitHeight + (panel.connectedStyle ? 32 : 24)
        radius: panel.connectedStyle ? panel.root.panelRadius : panel.root.pillRadius
        color: panel.connectedStyle ? "transparent" : panel.root.bg
        border.color: panel.connectedStyle ? panel.root.sep : panel.root.pillBorder
        border.width: panel.connectedStyle ? 0 : panel.root.pillBorderW
        focus: panel.visible
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                panel.root.displayManagerVisible = false
                event.accepted = true
            }
        }
        MouseArea { anchors.fill: parent; onClicked: {} }

        FocusScope {
            anchors.fill: parent
            anchors.margins: panel.connectedStyle ? 16 : 12
            focus: true

            Column {
                id: panelContent
                width: parent.width
                spacing: 10

                Loader {
                    width: parent.width
                    height: item ? item.implicitHeight : 0
                    sourceComponent: panel.headerComponent
                    visible: sourceComponent !== null
                }
                Item {
                    visible: !panel.connectedStyle
                    width: parent.width
                    height: 24
                    Text {
                        objectName: "display-v1-title"
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Display Manager"
                        renderType: Text.NativeRendering
                        color: panel.root.ink
                        font.family: panel.root.mono
                        font.pixelSize: 13
                        font.letterSpacing: 2
                        font.weight: Font.Medium
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        renderType: Text.NativeRendering
                        color: closeMouse.containsMouse ? panel.root.seal : panel.root.sumi
                        font.pixelSize: 12
                        MouseArea {
                            id: closeMouse
                            objectName: "display-v1-close"
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.root.displayManagerVisible = false
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: panel.root.sep }

                Item {
                    width: parent.width
                    height: 24
                    Text { id: displaySectionLabel; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "DISPLAYS · drag cards to arrange"; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 11; font.bold: true }
                    RiseButton { objectName: panel.connectedStyle ? "display-refresh-v2" : "display-refresh"; anchors.right: parent.right; width: 28; height: 24; text: "↻"; onClicked: { panel.controller.refresh(); panel.controller.refreshWorkspaces() } }
                }
                Text {
                    visible: panel.controller.busy || panel.controller.loading
                    text: panel.controller.busy ? "Applying…" : "Reading displays…"
                    color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 11
                }
                Rectangle {
                    id: stage
                    objectName: "display-canvas"
                    width: parent.width; height: 200
                    radius: panel.root.tileRadius; color: panel.root.fillIdle; border.color: panel.root.sep
                    clip: true
                    readonly property var bounds: {
                        var xs=[0], ys=[0]
                        for (var i=0;i<panel.controller.previewMonitors.length;i++) {
                            var m=panel.controller.previewMonitors[i]; if(m.disabled) continue
                            var pos=panel.controller.previewPositions[m.name] || m
                            var rotated=Number(m.transform || 0) % 2 === 1
                            xs.push(Number(pos.x || 0),Number(pos.x || 0)+Number(rotated ? m.height : m.width)/Number(m.scale || 1))
                            ys.push(Number(pos.y || 0),Number(pos.y || 0)+Number(rotated ? m.width : m.height)/Number(m.scale || 1))
                        }
                        return {left:Math.min.apply(null,xs), top:Math.min.apply(null,ys), right:Math.max.apply(null,xs), bottom:Math.max.apply(null,ys)}
                    }
                    readonly property real ratio: Math.min((width-40)/Math.max(1,bounds.right-bounds.left),(height-40)/Math.max(1,bounds.bottom-bounds.top))
                    Repeater {
                        model: panel.controller.previewMonitors
                        delegate: Rectangle {
                            id: monitorCard
                            required property var modelData
                            readonly property var position: panel.controller.previewPositions[modelData.name] || modelData
                            readonly property bool portrait: Number(modelData.transform || 0) % 2 === 1
                            x: 20 + (Number(position.x || 0) - stage.bounds.left) * stage.ratio
                            y: 20 + (Number(position.y || 0) - stage.bounds.top) * stage.ratio
                            width: Math.max(24,Number(portrait ? modelData.height : modelData.width)/Number(modelData.scale || 1)*stage.ratio)
                            height: Math.max(24,Number(portrait ? modelData.width : modelData.height)/Number(modelData.scale || 1)*stage.ratio)
                            visible: !modelData.disabled
                            radius: Math.min(8,panel.root.tileRadius)
                            color: panel.controller.selectedMonitor === modelData.name ? panel.root.fillActive : panel.root.paper
                            border.color: panel.controller.selectedMonitor === modelData.name ? panel.root.seal : panel.root.sep
                            Text { anchors.centerIn: parent; width: parent.width-8; text: monitorCard.modelData.name; textFormat: Text.PlainText; horizontalAlignment: Text.AlignHCenter; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 11; elide: Text.ElideRight }
                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                property real originX: 0; property real originY: 0
                                property real monitorX: 0; property real monitorY: 0
                                property real dragRatio: 1
                                property bool moved: false
                                enabled: !panel.controller.busy && !panel.controller.loading && panel.controller.rollbackPending !== true && (!monitorCard.modelData.mirrorOf || monitorCard.modelData.mirrorOf === "none")
                                cursorShape: Qt.SizeAllCursor
                                drag.target: monitorCard
                                onPressed: {
                                    moved=false
                                    panel.controller.selectedMonitor=monitorCard.modelData.name
                                    originX=monitorCard.x; originY=monitorCard.y
                                    monitorX=Number(monitorCard.position.x || 0); monitorY=Number(monitorCard.position.y || 0); dragRatio=stage.ratio
                                }
                                function restoreBindings() {
                                    monitorCard.x=Qt.binding(function() { return 20+(Number(monitorCard.position.x || 0)-stage.bounds.left)*stage.ratio })
                                    monitorCard.y=Qt.binding(function() { return 20+(Number(monitorCard.position.y || 0)-stage.bounds.top)*stage.ratio })
                                }
                                onPositionChanged: if (drag.active) moved=true
                                onReleased: {
                                    // Staging rebuilds previewMonitors and can destroy this delegate.
                                    // Restore its bindings before handing control to the controller.
                                    var name = monitorCard.modelData.name
                                    var dx = monitorCard.x-originX, dy = monitorCard.y-originY
                                    restoreBindings()
                                    if (moved) panel.commitCanvasPosition(name,monitorX,monitorY,dx,dy,dragRatio)
                                }
                                onCanceled: restoreBindings()
                            }
                        }
                    }
                }
                Row {
                    objectName: "display-monitor-list"
                    width: parent.width; spacing: 6
                    Repeater { model: panel.controller.previewMonitors
                        delegate: RiseButton { required property var modelData; text: modelData.name + (modelData.disabled ? " · OFF" : ""); onClicked: panel.controller.selectedMonitor=modelData.name }
                    }
                }

                Text { text: "CONFIGURATION · " + (panel.controller.selectedMonitor || "No monitor selected"); color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 11; font.bold: true }
                Row {
                    enabled: !panel.controller.busy && !panel.controller.loading && panel.controller.rollbackPending !== true && panel.controller.selectedMonitor !== ""
                    width: parent.width
                    spacing: 8
                    Text { text: "Mode"; color: panel.root.ink; width: 74; anchors.verticalCenter: parent.verticalCenter; font.family: panel.root.mono; font.pixelSize: 11 }
                    RiseComboBox {
                        id: modeBox
                        objectName: "display-resolution"
                        width: parent.width - 82
                        model: panel.modeOptions(panel.selectedDisplay)
                        currentIndex: panel.modeIndex(panel.selectedDisplay, model)
                        onActivated: if (panel.selectedDisplay) panel.controller.stageMonitor(panel.selectedDisplay.name, { mode: currentText })
                    }
                }
                Row {
                    enabled: !panel.controller.busy && !panel.controller.loading && panel.controller.rollbackPending !== true && panel.controller.selectedMonitor !== ""
                    width: parent.width; spacing: 8
                    Text { text: "Position"; color: panel.root.ink; width: 74; anchors.verticalCenter: parent.verticalCenter; font.family: panel.root.mono; font.pixelSize: 11 }
                    RiseSpinBox { id: posX; from: -32767; to: 32767; value: panel.selectedDisplay ? Number(panel.selectedDisplay.x || 0) : 0; editable: true; onValueModified: if (panel.selectedDisplay) panel.controller.stageMonitor(panel.selectedDisplay.name, { x: value }) }
                    RiseSpinBox { id: posY; from: -32767; to: 32767; value: panel.selectedDisplay ? Number(panel.selectedDisplay.y || 0) : 0; editable: true; onValueModified: if (panel.selectedDisplay) panel.controller.stageMonitor(panel.selectedDisplay.name, { y: value }) }
                    RiseButton { objectName: "display-position-apply"; text: "Apply"; onClicked: panel.applyChanges() }
                }
                Row {
                    enabled: !panel.controller.busy && !panel.controller.loading && panel.controller.rollbackPending !== true && panel.controller.selectedMonitor !== ""
                    width: parent.width; spacing: 8
                    Text { text: "Scale"; color: panel.root.ink; width: 74; anchors.verticalCenter: parent.verticalCenter; font.family: panel.root.mono; font.pixelSize: 11 }
                    RiseComboBox {
                        objectName: "display-scale"
                        width: 120
                        model: panel.controller.scalePresets
                        currentIndex: { var m = panel.selectedDisplay; return m ? Math.max(0, panel.controller.scalePresets.indexOf(Number(m.scale || 1))) : 0 }
                        onActivated: if (panel.selectedDisplay) panel.controller.stageMonitor(panel.selectedDisplay.name, { scale: Number(currentText) })
                    }
                    Text { text: "Rotation"; color: panel.root.ink; anchors.verticalCenter: parent.verticalCenter; font.family: panel.root.mono; font.pixelSize: 11 }
                    RiseComboBox {
                        objectName: "display-rotation"
                        width: 140
                        model: ["0°", "90°", "180°", "270°", "Flipped", "Flipped 90°", "Flipped 180°", "Flipped 270°"]
                        currentIndex: { var m = panel.selectedDisplay; return m ? Number(m.transform || 0) : 0 }
                        onActivated: (index) => { if (panel.selectedDisplay) panel.controller.stageMonitor(panel.selectedDisplay.name, { transform: index }) }
                    }
                }
                Row {
                    objectName: "display-monitor-workspaces"
                    enabled: !panel.controller.busy && !panel.controller.loading && !panel.controller.rollbackPending
                        && !panel.controller.workspaceLoading && !panel.controller.workspaceCommitPending
                        && panel.controller.extraQueue.length === 0 && panel.controller.workspaceStateReady
                        && panel.selectedDisplay && !panel.selectedDisplay.disabled
                        && (!panel.selectedDisplay.mirrorOf || panel.selectedDisplay.mirrorOf === "none")
                    width: parent.width; spacing: 8
                    height: Math.max(30, workspaceButtons.implicitHeight)
                    Text { text: "Workspaces"; color: panel.root.ink; width: 74; anchors.verticalCenter: parent.verticalCenter; font.family: panel.root.mono; font.pixelSize: 11 }
                    Flow {
                        id: workspaceButtons
                        width: parent.width - 82; spacing: 3
                        Repeater {
                            model: 10
                            delegate: RiseButton {
                                required property int index
                                objectName: "display-workspace-" + (index + 1)
                                width: 28; height: 30; leftPadding: 0; rightPadding: 0
                                checkable: true
                                text: String(index + 1)
                                checked: panel.controller.workspaceOwner(index + 1) === panel.controller.selectedMonitor
                                onClicked: panel.controller.stageWorkspace(index + 1, panel.controller.selectedMonitor)
                            }
                        }
                    }
                }
                Row {
                    enabled: !panel.controller.busy && !panel.controller.loading && panel.controller.rollbackPending !== true && panel.controller.selectedMonitor !== ""
                    width: parent.width; spacing: 8
                    Text { text: "Mode"; color: panel.root.ink; anchors.verticalCenter: parent.verticalCenter; font.family: panel.root.mono; font.pixelSize: 11 }
                    RiseButton {
                        objectName: "display-mirror"
                        readonly property bool mirrorActive: Boolean(panel.selectedDisplay && panel.selectedDisplay.mirrorOf && panel.selectedDisplay.mirrorOf !== "none")
                        text: "Mirror · " + (mirrorActive ? "ON" : "OFF")
                        enabled: mirrorActive || (panel.mirrorTargets().length > 0 && panel.selectedDisplay && !panel.selectedDisplay.disabled)
                        onClicked: panel.controller.toggleMirror(true)
                    }
                    RiseButton { objectName: "display-enable"; text: "Enable"; onClicked: panel.controller.enableMonitor(panel.controller.selectedMonitor, true) }
                    RiseButton { objectName: "display-disable"; enabled: panel.activeDisplayCount() > 1; text: "Disable"; onClicked: panel.controller.stageDisable(panel.controller.selectedMonitor) }
                }
                Rectangle { width: parent.width; height: 1; color: panel.root.sep }
                Row {
                    enabled: !panel.controller.busy && !panel.controller.loading && panel.controller.rollbackPending !== true && panel.controller.selectedMonitor !== ""
                    width: parent.width; spacing: 8
                    Text { text: "Brightness"; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    RiseSlider { objectName: "display-brightness"; from: 1; to: 100; stepSize: 1; value: panel.controller.brightnessPercent; enabled: panel.controller.brightnessAvailable && !panel.controller.busy; onPressedChanged: if (!pressed) panel.controller.setBrightness(value) }
                    Text { text: panel.controller.brightnessAvailable ? panel.controller.brightnessPercent + "%" : "Unavailable"; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    enabled: !panel.controller.busy && !panel.controller.loading && panel.controller.rollbackPending !== true && panel.controller.selectedMonitor !== ""
                    width: parent.width; spacing: 8
                    Text { text: "Text size"; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    RiseComboBox { objectName: "display-text-size"; model: panel.controller.textSizeStops; currentIndex: panel.controller.textSizeIndex; onActivated: (index) => panel.controller.setTextSize(index) }
                }
                Row {
                    enabled: !panel.controller.busy && !panel.controller.loading && panel.controller.rollbackPending !== true
                    width: parent.width; spacing: 8
                    RiseCheckBox { objectName: "display-workspaces"; text: "Auto-bind workspaces"; checked: panel.draftAutoWorkspaces; onToggled: panel.draftAutoWorkspaces = checked }
                    RiseButton { objectName: "display-save"; text: "Save layout"; enabled: !panel.controller.busy && !panel.controller.hasDrafts && !panel.controller.workspaceLoading && !panel.controller.workspaceCommitPending && panel.draftAutoWorkspaces === panel.root.displayManagerAutoWorkspaces; onClicked: panel.controller.saveLayout() }
                }
                Column {
                    objectName: "display-confirmation"
                    visible: panel.controller.rollbackPending === true
                    width: parent.width; spacing: 6
                    Text {
                        objectName: "display-confirmation-countdown"
                        width: parent.width; wrapMode: Text.Wrap; textFormat: Text.PlainText
                        text: "Keep this configuration? Reverting in " + panel.controller.rollbackSeconds + " s."
                        color: panel.root.seal; font.family: panel.root.mono; font.pixelSize: 11
                    }
                    Row {
                        spacing: 8
                        RiseButton { objectName: "display-keep"; text: "Keep configuration"; enabled: !panel.controller.confirmationBusy; onClicked: panel.controller.confirmChanges() }
                        RiseButton { objectName: "display-revert"; text: "Revert now"; enabled: !panel.controller.confirmationBusy; onClicked: panel.controller.revertChanges() }
                    }
                }
                Text {
                    visible: panel.controller.error !== "" || panel.controller.workspaceError !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: panel.controller.error || panel.controller.workspaceError; textFormat: Text.PlainText
                    color: panel.root.seal
                    font.family: panel.root.mono
                    font.pixelSize: 11
                }
                Text { width: parent.width; wrapMode: Text.Wrap; text: "Layout save creates a backup\nbefore updating the managed monitors.lua block."; color: panel.root.ink; opacity: 0.65; font.family: panel.root.mono; font.pixelSize: 10 }
            }
        }
    }
    Binding {
        target: frameCard
        property: "x"
        when: !panel.connectedStyle && panel.root.barVertical === true
        value: !when ? 0 : panel.root.barPosition === "left" ? panel.root.verticalBarWidth + panel.gap
            : Math.max(panel.gap, panel.width - panel.root.verticalBarWidth - frameCard.width - panel.gap)
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: frameCard
        property: "y"
        when: !panel.connectedStyle && panel.root.barVertical === true
        value: !when ? 0 : Math.max(panel.gap, Math.min(panel.height - frameCard.height - panel.gap,
            panel.root.verticalAnchorY("displayManager") - frameCard.height / 2))
        restoreMode: Binding.RestoreBindingOrValue
    }
}
