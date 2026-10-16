import QtQuick
import "../modules"
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Wayland
import "../IconMap.js" as IconMap

PanelWindow {
    id: btPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-bluetooth"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    property bool btOn: false
    property bool scanning: false
    property bool scanOwned: false
    property var devices: []   // [{name, mac, connected, paired}]
    readonly property var shownDevices: devices.filter(function(device) {
        if (device.connected || device.paired) return true
        return String(device.name || "").trim().toLowerCase() !== "bt5.0 kb"
    }).slice(0, 8)
    readonly property int numConnected: {
        var n = 0
        for (var i = 0; i < devices.length; i++) if (devices[i].connected) n++
        return n
    }
    property string connMac: ""
    property string connPhase: ""
    property string connectionNotice: ""
    property string expandedDeviceKey: ""
    readonly property bool actionBusy: forgetBusy || trustPending
    property bool trustPending: false
    property var trustTarget: null
    property string trustError: ""
    property bool trustReadbackValid: false
    property bool trustReadbackValue: false
    function nativeDeviceForDevice(device) {
        var list = Bluetooth.devices.values
        for (var i = 0; i < list.length; i++) {
            var candidate = list[i]
            if (candidate.dbusPath === device.dbusPath && candidate.adapter
                    && candidate.adapter.adapterId === device.adapterId) return candidate
        }
        return null
    }
    function requestTrustDevice(device) {
        if (btPanel.actionBusy || connProc.running) return
        if (!btPanel.validBluetoothIdentity({paired: true, mac: device.mac,
                adapterId: device.adapterId, dbusPath: device.dbusPath})) return
        var nativeDevice = btPanel.nativeDeviceForDevice(device)
        if (!nativeDevice || nativeDevice.trusted) return
        btPanel.trustTarget = {dbusPath: device.dbusPath, adapterId: device.adapterId}
        btPanel.trustError = ""
        btPanel.trustPending = true
        trustProc.running = true
    }

    function deviceActionKey(device) {
        return String(device.adapterId || "") + "|" + String(device.mac || "")
    }
    function toggleDeviceActions(device) {
        if (btPanel.actionBusy || connProc.running) return
        var key = btPanel.deviceActionKey(device)
        btPanel.cancelForgetDevice()
        btPanel.expandedDeviceKey = btPanel.expandedDeviceKey === key ? "" : key
    }
    property var forgetTarget: null
    property string forgetError: ""
    property string forgetCommandAdapter: ""
    property string forgetCommandDevice: ""
    property bool forgetReadbackPending: false
    property bool forgetTimedOut: false
    property string forgetNotice: ""
    onForgetNoticeChanged: {
        if (forgetNotice !== "") forgetNoticeTimer.restart()
        else forgetNoticeTimer.stop()
    }
    Timer {
        id: forgetNoticeTimer
        interval: 5000; repeat: false
        onTriggered: btPanel.forgetNotice = ""
    }
    readonly property bool forgetBusy: forgetProc.running || forgetReadbackPending
    readonly property color deviceActionFill: Qt.rgba(
        root.paper.r * 0.88,
        root.paper.g * 0.88,
        root.paper.b * 0.88,
        1.0)

    function refresh() { btData.running = false; btData.running = true }

    function startScan() {
        var adapter = Bluetooth.defaultAdapter
        if (!btPanel.btOn || !adapter || !adapter.enabled || btPanel.scanning || scanProc.running) return
        connectionNotice = ""
        btPanel.scanning = true
        btPanel.scanOwned = !adapter.discovering
        if (btPanel.scanOwned) scanProc.running = true
        scanTimer.restart()
        btPanel.refresh()
    }

    function validBluetoothIdentity(device) {
        return !!device && device.paired === true
            && /^hci[0-9]+$/.test(String(device.adapterId || ""))
            && /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(String(device.mac || ""))
            && String(device.dbusPath || "") === "/org/bluez/" + device.adapterId + "/dev_" + device.mac.replace(/:/g, "_")
    }

    function requestForgetDevice(device) {
        if (btPanel.trustPending || forgetProc.running || connProc.running || forgetReadbackPending) return
        if (!validBluetoothIdentity(device)) return
        forgetError = ""
        forgetNotice = ""
        forgetTarget = { name: String(device.name || "Bluetooth device"), adapterId: String(device.adapterId), mac: String(device.mac), dbusPath: String(device.dbusPath), paired: true }
    }

    function cancelForgetDevice() {
        if (btPanel.trustPending || forgetProc.running || forgetReadbackPending) return
        forgetTarget = null
        forgetError = ""
    }

    function confirmForgetDevice() {
        if (btPanel.trustPending || !forgetTarget || !validBluetoothIdentity(forgetTarget) || forgetProc.running || connProc.running || forgetReadbackPending) return
        forgetError = ""
        forgetCommandAdapter = "/org/bluez/" + forgetTarget.adapterId
        forgetCommandDevice = forgetTarget.dbusPath
        forgetTimedOut = false
        forgetProc.running = true
    }

    function batteryPercentForDevice(mac, rowConnected) {
        if (!rowConnected) return null
        var liveDevices = Bluetooth.devices.values
        for (var i = 0; i < liveDevices.length; i++) {
            var device = liveDevices[i]
            if (device.address !== mac) continue
            if (!device.connected || !device.batteryAvailable) return null
            var level = Number(device.battery)
            if (!isFinite(level) || level < 0 || level > 1) return null
            return Math.round(level * 100)
        }
        return null
    }

    function activateDevice(device) {
        if (!device || connProc.running || btPanel.actionBusy) return
        var mac = String(device.mac || "")
        if (!/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(mac)) return
        connectionNotice = ""
        connMac = mac
        if (device.connected) {
            connPhase = "disconnect"
        } else if (device.paired) {
            connPhase = "connect"
        } else {
            connPhase = "trust"
        }
        connProc.output = ""
        connProc.running = true
    }

    function finishConnection(message) {
        connectionTimeout.stop()
        connPhase = ""
        if (message) connectionNotice = message
        refresh()
    }

    Timer {
        id: connectionNoticeTimer
        interval: 7000; repeat: false
        onTriggered: btPanel.connectionNotice = ""
    }
    onConnectionNoticeChanged: {
        if (connectionNotice !== "") connectionNoticeTimer.restart()
        else connectionNoticeTimer.stop()
    }

    property real reveal: root.bluetoothVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.bluetoothVisible ? 160 : 120
            easing.type: root.bluetoothVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.bluetoothVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.bluetoothVisible = false }

    Rectangle {
        id: card
        width: 300
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: btPanel.root
            ownerActive: btPanel.root.bluetoothVisible
            targetX: btPanel.root.bluetoothBarX
            reveal: btPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.bluetoothBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - btPanel.reveal)
            : (barBottom + gap) - 2 * (1 - btPanel.reveal)
        opacity: btPanel.reveal
        focus: root.bluetoothVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.bluetoothVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header + power toggle ──
            Item {
                width: parent.width
                height: 24
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Bluetooth"
                        color: root.ink; font.family: root.mono; font.pixelSize: 13
                        font.letterSpacing: 2; font.weight: Font.Medium
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: btPanel.btOn && btPanel.numConnected > 0
                        spacing: 3
                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: IconMap.icon("bluetooth_connected")
                            color: root.seal
                            font.pixelSize: 13
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(btPanel.numConnected)
                            color: root.seal
                            font.family: root.mono; font.pixelSize: 11
                        }
                    }
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    // power toggle pill
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46; height: 20; radius: 10
                        color: btPanel.btOn ? root.fillActive
                                            : root.fillIdle
                        border.color: btPanel.btOn ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Rectangle {
                            width: 14; height: 14; radius: 7
                            anchors.verticalCenter: parent.verticalCenter
                            x: btPanel.btOn ? parent.width - width - 3 : 3
                            color: btPanel.btOn ? root.seal : root.sumi
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (!btPanel.actionBusy) { powerProc.running = false; powerProc.running = true } }
                        }
                    }
                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                        Behavior on color { ColorAnimation { duration: 120 } }
                        MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.bluetoothVisible = false }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── off state ──
            UiText {
                visible: !btPanel.btOn
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: "Bluetooth is off"
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
                font.family: root.mono; font.pixelSize: 11
                topPadding: 4; bottomPadding: 4
            }

            // ── scan control (only when on) ──
            Rectangle {
                visible: btPanel.btOn
                width: parent.width
                height: 28; radius: root.panelButtonRadius
                readonly property bool hovered: scanMa.containsMouse
                color: btPanel.scanning ? root.fillActive
                       : hovered ? root.fillHover : root.fillIdle
                border.color: (btPanel.scanning || hovered) ? root.seal : root.sep
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: btPanel.scanning ? "Scanning…" : "Scan for devices"
                    color: btPanel.scanning ? root.seal : root.ink
                    font.family: root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: scanMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !btPanel.scanning && !btPanel.actionBusy
                    onClicked: btPanel.startScan()
                }
            }

            UiText {
                visible: btPanel.connectionNotice !== ""
                width: parent.width
                text: btPanel.connectionNotice
                color: root.seal
                font.family: root.mono; font.pixelSize: 10
                wrapMode: Text.Wrap
            }

            // ── device list ──
            Column {
                width: parent.width
                spacing: 4
                visible: btPanel.btOn
                Repeater {
                    model: btPanel.shownDevices
                    delegate: Rectangle {
                        id: devTile
                        required property var modelData
                        readonly property bool expanded: btPanel.expandedDeviceKey === btPanel.deviceActionKey(modelData)
                        readonly property bool hovered: tileHover.containsMouse || actionMa.containsMouse
                        width: col.width
                        height: 42 + (expanded ? deviceActions.implicitHeight + 8 : 0); radius: root.panelButtonRadius
                        color: modelData.connected ? root.fillActive
                               : hovered ? root.fillHover : root.fillIdle
                        border.color: modelData.connected ? root.seal
                                      : hovered ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Item {
                            id: deviceHeader
                            width: parent.width; height: 42
                        MouseArea {
                            id: tileHover
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onClicked: btPanel.toggleDeviceActions(devTile.modelData)
                            hoverEnabled: true
                        }

                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 8
                            anchors.right: actionButton.left; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            UiText {
                                width: parent.width
                                text: devTile.modelData.name
                                color: root.ink; font.family: root.mono; font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                            Row {
                                width: parent.width
                                spacing: 4
                                UiText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(0, parent.width - (batteryLabel.visible ? batteryLabel.width + parent.spacing : 0))
                                    text: devTile.modelData.connected ? "Connected"
                                          : devTile.modelData.paired ? "Paired" : "Available"
                                    color: root.ink
                                    font.family: root.mono; font.pixelSize: 10; font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                Row {
                                    id: batteryLabel
                                    readonly property var percent: btPanel.batteryPercentForDevice(devTile.modelData.mac, devTile.modelData.connected)
                                    visible: percent !== null
                                    spacing: 2
                                    IconText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "\uE1A4"
                                        color: root.seal
                                        font.pixelSize: 12
                                    }
                                    UiText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: String(batteryLabel.percent) + "%"
                                        color: root.ink
                                        font.family: root.mono; font.pixelSize: 10
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: actionButton
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: actionLabel.implicitWidth + 14
                            height: 24; radius: root.panelButtonRadius
                            color: btPanel.deviceActionFill
                            border.color: root.sep
                            border.width: 1
                            opacity: connProc.running || btPanel.actionBusy ? 0.45 : 1
                            UiText {
                                id: actionLabel
                                anchors.centerIn: parent
                                text: devTile.modelData.connected ? "Disconnect" : "Connect"
                                color: actionMa.containsMouse ? root.seal : root.ink
                                font.family: root.mono; font.pixelSize: 10
                            }
                            MouseArea {
                                id: actionMa
                                anchors.fill: parent
                                enabled: !connProc.running && !btPanel.actionBusy
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: btPanel.activateDevice(devTile.modelData)
                            }
                        }

                                            }

                        Column {
                            id: deviceActions
                            x: 8; y: 46; width: parent.width - 16
                            visible: devTile.expanded
                            spacing: 8
                            Rectangle { width: parent.width; height: 1; color: root.sep }
                            Row {
                                id: deviceActionRow
                                spacing: 8
                                Rectangle {
                            id: forgetButton


                            width: forgetLabel.implicitWidth + 12
                            height: 24; radius: root.panelButtonRadius
                            color: forgetMa.containsMouse && forgetMa.enabled ? root.fillHover : btPanel.deviceActionFill
                            border.color: root.sep; border.width: 1
                            opacity: !devTile.modelData.paired || btPanel.actionBusy || connProc.running ? 0.48 : 1
                            UiText {
                                id: forgetLabel
                                anchors.centerIn: parent
                                text: devTile.modelData.paired ? "Forget" : "Not paired"
                                color: forgetMa.containsMouse && forgetMa.enabled ? root.seal : root.ink
                                font.family: root.mono; font.pixelSize: 9
                            }
                            MouseArea {
                                id: forgetMa
                                anchors.fill: parent
                                enabled: devTile.modelData.paired && !btPanel.actionBusy && !connProc.running
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: btPanel.requestForgetDevice(devTile.modelData)
                            }
                        }
                                                            Rectangle {
                                    id: trustButton
                                    readonly property var nativeDevice: btPanel.nativeDeviceForDevice(devTile.modelData)
                                    width: trustLabel.implicitWidth + 14
                                    height: 24; radius: root.panelButtonRadius
                                    color: trustMa.containsMouse && trustMa.enabled ? root.fillHover : btPanel.deviceActionFill
                                    border.color: root.sep; border.width: 1
                                    opacity: trustMa.enabled ? 1 : 0.48
                                    UiText {
                                        id: trustLabel
                                        anchors.centerIn: parent
                                        text: trustButton.nativeDevice && trustButton.nativeDevice.trusted ? "Trusted" : "Trust"
                                        color: trustMa.containsMouse && trustMa.enabled ? root.seal : root.ink
                                        font.family: root.mono; font.pixelSize: 9
                                    }
                                    MouseArea {
                                        id: trustMa
                                        anchors.fill: parent
                                        enabled: trustButton.nativeDevice !== null && !trustButton.nativeDevice.trusted
                                            && !btPanel.actionBusy && !connProc.running
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: btPanel.requestTrustDevice(devTile.modelData)
                                    }
                                }
}
                            Rectangle {
                    id: forgetConfirmation
                    visible: btPanel.forgetTarget !== null && btPanel.deviceActionKey(btPanel.forgetTarget) === btPanel.deviceActionKey(devTile.modelData)
                    width: parent.width
                    height: visible ? forgetConfirmationContent.implicitHeight + 16 : 0
                    radius: root.panelButtonRadius; color: root.fillIdle
                    border.color: root.seal; border.width: 1
                    Column {
                        id: forgetConfirmationContent
                        anchors.fill: parent; anchors.margins: 8; spacing: 5
                        UiText {
                            id: prompt
                            width: parent.width
                            text: "Forget " + (btPanel.forgetTarget ? btPanel.forgetTarget.name : "")
                                + "? Removes pairing and may disconnect; pair again to reconnect."
                            color: root.ink; font.family: root.mono; font.pixelSize: 9
                            wrapMode: Text.WordWrap
                        }
                        Row {
                            spacing: 6
                            Rectangle {
                                width: 64; height: 22; radius: root.panelButtonRadius; color: root.seal
                                UiText { anchors.centerIn: parent; text: btPanel.actionBusy ? "Working…" : "Confirm"; color: root.paper; font.family: root.mono; font.pixelSize: 9 }
                                MouseArea { anchors.fill: parent; enabled: !btPanel.actionBusy; onClicked: btPanel.confirmForgetDevice() }
                            }
                            Rectangle {
                                width: 54; height: 22; radius: root.panelButtonRadius; color: root.fillHover
                                UiText { anchors.centerIn: parent; text: "Cancel"; color: root.ink; font.family: root.mono; font.pixelSize: 9 }
                                MouseArea { anchors.fill: parent; enabled: !btPanel.actionBusy; onClicked: btPanel.cancelForgetDevice() }
                            }
                        }
                        UiText {
                            visible: btPanel.forgetError !== ""
                            width: parent.width; text: btPanel.forgetError
                            color: root.seal; font.family: root.mono; font.pixelSize: 9; wrapMode: Text.WordWrap
                        }
                    }
                }
                                                    UiText {
                                visible: btPanel.trustError !== ""
                                width: parent.width; text: btPanel.trustError
                                color: root.seal; font.family: root.mono; font.pixelSize: 9
                                wrapMode: Text.WordWrap
                            }
}
}
                }

                UiText {
                    visible: btPanel.forgetNotice !== "" && btPanel.forgetTarget === null
                    width: parent.width; text: btPanel.forgetNotice
                    color: root.seal; font.family: root.mono; font.pixelSize: 9; wrapMode: Text.WordWrap
                }
                UiText {
                    visible: btPanel.btOn && btPanel.devices.length === 0
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: btPanel.scanning ? "Searching…" : "No devices — tap Scan"
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)
                    font.family: root.mono; font.pixelSize: 11
                    topPadding: 2; bottomPadding: 2
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Rectangle {
                width: parent.width
                height: 28; radius: root.panelButtonRadius
                color: btSetMa.containsMouse ? root.fillPrimaryHover : root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText { anchors.centerIn: parent; text: "Bluetooth settings"; color: root.paper; font.family: root.mono; font.pixelSize: 11 }
                MouseArea {
                    id: btSetMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.bluetoothVisible = false; btRunner.running = false; btRunner.running = true }
                }
            }
        }
    }

    // ── power state; devices come from BlueZ's live adapter models ──
    Process {
        id: btData
        command: ["bash", "-c",
            "if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then " +
            "  echo ON; " +
            "  conn=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}'); " +
            "  paired=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}'); " +
            "  bluetoothctl devices 2>/dev/null | while read -r _ mac rest; do " +
            "    c=0; p=0; " +
            "    printf '%s\\n' \"$conn\"   | grep -qx \"$mac\" && c=1; " +
            "    printf '%s\\n' \"$paired\" | grep -qx \"$mac\" && p=1; " +
            "    echo \"$c|$p|$mac|$rest\"; " +
            "  done; " +
            "else echo OFF; fi"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                if (lines[0] !== "ON") {
                    btPanel.btOn = false; btPanel.devices = []
                    if (btPanel.forgetReadbackPending) {
                        btPanel.forgetReadbackPending = false
                        btPanel.forgetError = "Could not verify whether the device was forgotten."
                    }
                    return
                }
                btPanel.btOn = true
                var devs = []
                var nativeDevices = []
                var adapters = Bluetooth.adapters.values
                for (var a = 0; a < adapters.length; a++) {
                    var adapterDevices = adapters[a].devices.values
                    for (var nd = 0; nd < adapterDevices.length; nd++)
                        nativeDevices.push(adapterDevices[nd])
                }
                // bluetoothctl includes discovered, unpaired devices from the
                // current BlueZ cache; keep those rows even when the native model
                // has not published their Device1 object to this shell yet.
                for (var i = 1; i < lines.length; i++) {
                    var parts = lines[i].split("|")
                    if (parts.length < 4) continue
                    var mac = String(parts[2] || "").toUpperCase()
                    if (!/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/.test(mac)) continue
                    if (devs.some(function(device) { return String(device.mac).toUpperCase() === mac })) continue
                    var name = parts.slice(3).join("|").trim()
                    if (!name || name === parts[2]) name = parts[2]
                    var nativeIdentity = null
                    for (var d = 0; d < nativeDevices.length; d++) {
                        if (String(nativeDevices[d].address).toUpperCase() === mac && nativeDevices[d].adapter) {
                            nativeIdentity = nativeDevices[d]
                            break
                        }
                    }
                    devs.push({
                        connected: parts[0] === "1",
                        paired: parts[1] === "1",
                        mac: mac,
                        adapterId: nativeIdentity ? nativeIdentity.adapter.adapterId : "",
                        dbusPath: nativeIdentity ? nativeIdentity.dbusPath : "",
                        name: name
                    })
                }
                // Read all Device1 objects from the live adapter model. The
                // global Bluetooth.devices model omits unconnected discoveries.
                for (var discoveredIndex = 0; discoveredIndex < nativeDevices.length; discoveredIndex++) {
                    var discovered = nativeDevices[discoveredIndex]
                    var address = String(discovered.address || "")
                    if (!/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(address)) continue
                    if (!discovered.adapter) continue
                    var alreadyListed = devs.some(function(device) {
                        return String(device.mac).toUpperCase() === address.toUpperCase()
                    })
                    if (alreadyListed) continue
                    devs.push({
                        connected: !!discovered.connected,
                        paired: !!discovered.paired,
                        mac: address,
                        adapterId: discovered.adapter.adapterId,
                        dbusPath: discovered.dbusPath,
                        name: String(discovered.name || discovered.deviceName || address)
                    })
                }
                // connected first, then paired, then the rest
                devs.sort(function(a, b) {
                    var ra = a.connected ? 0 : a.paired ? 1 : 2
                    var rb = b.connected ? 0 : b.paired ? 1 : 2
                    return ra - rb
                })
                btPanel.devices = devs
                if (btPanel.forgetReadbackPending && btPanel.forgetTarget) {
                    var remainsPaired = devs.some(function(device) {
                        return device.mac === btPanel.forgetTarget.mac
                            && device.adapterId === btPanel.forgetTarget.adapterId && device.paired
                    })
                    // bluetoothctl may list only its default adapter. A missing row
                    // is not proof of removal while the selected native device is paired.
                    var liveReadbackDevices = nativeDevices
                    for (var n = 0; n < liveReadbackDevices.length; n++) {
                        var liveDevice = liveReadbackDevices[n]
                        if (liveDevice.dbusPath === btPanel.forgetTarget.dbusPath
                                && liveDevice.adapter
                                && liveDevice.adapter.adapterId === btPanel.forgetTarget.adapterId
                                && liveDevice.paired) {
                            remainsPaired = true
                            break
                        }
                    }
                    btPanel.forgetReadbackPending = false
                    if (remainsPaired) {
                        btPanel.forgetError = "The device is still paired; it was not removed."
                    } else {
                        btPanel.forgetNotice = "Device forgotten. Pair it again before reconnecting."
                        btPanel.forgetTarget = null
                    }
                }
            }
        }
    }

    // ── power on/off ──
    Process {
        id: powerProc
        command: ["bash", "-c", "bluetoothctl power " + (btPanel.btOn ? "off" : "on")]
        running: false
        onExited: btPanel.refresh()
    }

    Process {
        id: scanProc
        property string output: ""
        command: ["/usr/bin/timeout", "12s", "bluetoothctl", "scan", "on"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: scanProc.output = String(this.text || "").trim()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var error = String(this.text || "").trim()
                if (error) scanProc.output = error
            }
        }
        onExited: (exitCode) => {
            if (exitCode === 0) return
            scanTimer.stop()
            btPanel.scanning = false
            btPanel.scanOwned = false
            var detail = String(scanProc.output || "")
            btPanel.connectionNotice = detail.indexOf("NotReady") >= 0
                ? "Bluetooth adapter is not ready. Reconnect the USB adapter and try again."
                : detail.indexOf("InProgress") >= 0
                    ? "A Bluetooth scan is already in progress. Wait a moment and try again."
                    : exitCode === 124
                        ? "Bluetooth scan timed out. Check the adapter and try again."
                        : "Bluetooth scan failed. " + (detail || "Check the adapter and try again.")
            btPanel.refresh()
        }
    }

    // ── timed discovery scan ──
    Timer {
        id: scanTimer
        interval: 10000
        repeat: false
        onTriggered: {
            var adapter = Bluetooth.defaultAdapter
            if (btPanel.scanOwned && adapter && adapter.discovering) adapter.discovering = false
            btPanel.scanOwned = false
            btPanel.scanning = !!(adapter && adapter.discovering)
            btPanel.refresh()
        }
    }
    Connections {
        target: Bluetooth.defaultAdapter
        function onDiscoveringChanged() {
            var adapter = Bluetooth.defaultAdapter
            if (btPanel.scanning && adapter && !adapter.discovering) {
                btPanel.scanning = false
                btPanel.scanOwned = false
                scanTimer.stop()
                btPanel.refresh()
            }
        }
    }
    Timer {
        interval: 1500; repeat: true
        running: btPanel.scanning && btPanel.visible
        onTriggered: btPanel.refresh()
    }

    // ── connect / disconnect / pair ──
    Process {
        id: connProc
        property string output: ""
        command: ["/usr/bin/timeout", "12s", "bluetoothctl", btPanel.connPhase, btPanel.connMac]
        running: false
        stdout: StdioCollector {
            onStreamFinished: connProc.output = String(this.text || "").trim()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var error = String(this.text || "").trim()
                if (error) connProc.output = error
            }
        }
        onExited: (exitCode) => {
            connectionTimeout.stop()
            if (exitCode !== 0) {
                var failedPhase = btPanel.connPhase
                var detail = String(connProc.output || "")
                var message = detail.indexOf("NotReady") >= 0
                    ? "Bluetooth adapter is not ready. Reconnect the USB adapter and try again."
                    : exitCode === 124
                        ? "Bluetooth " + failedPhase + " timed out. Check that the device is awake and in pairing mode."
                        : "Bluetooth " + failedPhase + " failed. " + (detail || "Check the device and adapter.")
                btPanel.finishConnection(message)
                return
            }
            if (btPanel.connPhase === "trust") btPanel.connPhase = "pair"
            else if (btPanel.connPhase === "pair") btPanel.connPhase = "connect"
            else { btPanel.finishConnection(""); return }
            connProc.output = ""
            Qt.callLater(() => { connProc.running = true })
        }
    }
    Timer {
        id: connectionTimeout
        interval: 14000; repeat: false
        onTriggered: {
            if (!connProc.running) return
            connProc.running = false
            btPanel.finishConnection("Bluetooth action timed out. Check the device and Bluetooth adapter.")
        }
    }
    Connections {
        target: connProc
        function onRunningChanged() {
            if (connProc.running) connectionTimeout.restart()
            else connectionTimeout.stop()
        }
    }

    Process {
        id: forgetProc
        command: ["busctl", "--system", "call", "org.bluez", btPanel.forgetCommandAdapter,
            "org.bluez.Adapter1", "RemoveDevice", "o", btPanel.forgetCommandDevice]
        running: false
        onExited: (exitCode) => {
            forgetTimeout.stop()
            if (btPanel.forgetTimedOut) {
                btPanel.forgetTimedOut = false
                return
            }
            if (exitCode !== 0) {
                btPanel.forgetError = "Could not forget this device; pairing may remain."
                btPanel.refresh()
                return
            }
            btPanel.forgetReadbackPending = true
            btPanel.refresh()
        }
    }
    Timer {
        id: forgetTimeout
        interval: 12000; repeat: false
        onTriggered: {
            if (!forgetProc.running) return
            btPanel.forgetTimedOut = true
            forgetProc.running = false
            btPanel.forgetReadbackPending = true
            btPanel.forgetError = "Forgetting timed out; device state was not assumed."
            btPanel.refresh()
        }
    }
    Connections {
        target: forgetProc
        function onRunningChanged() {
            if (forgetProc.running) forgetTimeout.restart()
            else forgetTimeout.stop()
        }
    }

    Process {
        id: trustProc
        command: ["/usr/bin/timeout", "8", "/usr/bin/busctl", "--timeout=6", "--system",
            "set-property", "org.bluez", btPanel.trustTarget ? btPanel.trustTarget.dbusPath : "",
            "org.bluez.Device1", "Trusted", "b", "true"]
        running: false
        onExited: (exitCode) => {
            if (!btPanel.trustPending) return
            if (exitCode !== 0) {
                btPanel.trustError = "Trust change failed or timed out."
                btPanel.trustPending = false
                return
            }
            btPanel.trustReadbackValid = false
            trustVerify.running = true
        }
    }
    Process {
        id: trustVerify
        command: ["/usr/bin/timeout", "8", "/usr/bin/busctl", "--timeout=6", "--system", "--json=short",
            "get-property", "org.bluez", btPanel.trustTarget ? btPanel.trustTarget.dbusPath : "",
            "org.bluez.Device1", "Trusted"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!btPanel.trustPending) return
                try {
                    var response = JSON.parse(this.text)
                    btPanel.trustReadbackValid = response.type === "b" && typeof response.data === "boolean"
                    btPanel.trustReadbackValue = response.data === true
                } catch (error) { btPanel.trustReadbackValid = false }
            }
        }
        onExited: (exitCode) => {
            if (!btPanel.trustPending) return
            btPanel.trustError = exitCode === 0 && btPanel.trustReadbackValid && btPanel.trustReadbackValue
                ? "" : "Trust was not confirmed."
            btPanel.trustPending = false
        }
    }

    Process { id: btRunner; command: ["bash", "-c", root.launchBtCmd] }

    onVisibleChanged: { if (visible) btPanel.refresh() }
}
