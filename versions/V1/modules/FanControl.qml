pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

Column {
    id: control
    required property var theme
    property bool active: false
    property var channels: []
    property int uid: -1
    property string pendingMode: ""
    property int percent: 60
    property string currentMode: ""
    property string status: "Detecting fan controls…"
    readonly property bool writable: channels.length > 0 && channels.every(c => c.writable)
    readonly property bool canControl: active && channels.length > 0 && !authorization.running
    onCanControlChanged: console.info("[Rise fan] active=" + active
        + " channels=" + channels.length + " running=" + backend.running
        + " authorizing=" + authorization.running + " enabled=" + canControl)
    spacing: 5
    height: implicitHeight

    function send(mode) {
        if (!canControl) return
        if (!backend.running) {
            pendingMode = mode
            start()
            return
        }
        if (!writable && mode !== "restore") {
            if (uid < 0) return
            pendingMode = mode
            let paths = []
            for (let channel of channels) paths.push(channel.id, channel.id + "_enable")
            authorization.command = ["pkexec", "chown", "--", String(uid)].concat(paths)
            status = "Authorize CPU fan control…"
            authorization.running = true
            return
        }
        backend.write(JSON.stringify({mode: mode, percent: percent}) + "\n")
        currentMode = mode === "restore" ? "" : mode
    }
    function start() {
        if (active && !backend.running) {
            channels = []; currentMode = ""
            status = "Detecting fan controls…"
            backend.stdinEnabled = true
            backend.running = true
        }
    }
    onActiveChanged: {
        if (active) start()
        else {
            pendingMode = ""
            // Keep the controller and its temperature monitoring alive for the selected mode.
            if (currentMode === "") backend.stdinEnabled = false
        }
    }
    Component.onCompleted: start()

    component Action: Rectangle {
        property string label: ""
        property bool available: true
        property bool chosen: false
        signal triggered()
        height: 24
        radius: 3
        color: chosen ? control.theme.seal : control.theme.fillActive
        border.width: 0
        opacity: available ? 1 : 0.45
        UiText {
            anchors.centerIn: parent
            text: (parent.chosen ? "✓ " : "") + parent.label
            color: parent.chosen ? control.theme.paper : control.theme.ink
            font.family: control.theme.mono
            font.pixelSize: 9
            font.weight: parent.chosen ? Font.DemiBold : Font.Normal
        }
        MouseArea {
            anchors.fill: parent
            enabled: parent.available
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.triggered()
        }
    }
    UiText {
        width: parent.width
        text: control.channels.length
            ? "CPU fans · " + (control.currentMode === "" ? "Auto"
                : control.currentMode === "manual" ? "Manual " + control.percent + "%"
                : control.currentMode === "full" ? "Full speed"
                : control.currentMode.charAt(0).toUpperCase() + control.currentMode.slice(1))
                + " · " + control.channels.map(c => c.label).join(" + ")
            : "No CPU fan control detected"
        color: control.theme.ink
        font.family: control.theme.mono
        font.pixelSize: 9
        wrapMode: Text.Wrap
    }
    Row {
        width: parent.width
        spacing: 4
        Repeater {
            model: ["Silent", "Standard", "Performance", "Full"]
            Action {
                required property string modelData
                width: (control.width - 12) / 4
                label: modelData === "Full" ? "Full speed" : modelData
                available: control.canControl
                chosen: control.currentMode === modelData.toLowerCase()
                onTriggered: control.send(modelData.toLowerCase())
            }
        }
    }
    Row {
        width: parent.width
        spacing: 4
        Action {
            width: 30; label: "−"; available: control.canControl && control.percent > 40
            onTriggered: { control.percent = Math.max(40, control.percent - 5); control.send("manual") }
        }
        Action {
            width: control.width - 128; label: "Manual " + control.percent + "%"
            available: control.canControl; chosen: control.currentMode === "manual"
            onTriggered: control.send("manual")
        }
        Action {
            width: 30; label: "+"; available: control.canControl && control.percent < 100
            onTriggered: { control.percent = Math.min(100, control.percent + 5); control.send("manual") }
        }
        Action {
            width: 56; label: "Restore"; available: control.canControl
            onTriggered: control.send("restore")
        }
    }
    UiText {
        width: parent.width
        text: !control.writable && control.channels.length && control.status === "CPU fans selected automatically"
            ? "Choose a profile to authorize CPU fan control" : control.status
        color: control.theme.sumiHi
        font.family: control.theme.mono; font.pixelSize: 9
        wrapMode: Text.Wrap
    }
    Process {
        id: authorization
        onExited: (code) => {
            if (code === 0 && control.active && backend.running) {
                backend.write(JSON.stringify({mode: "discover"}) + "\n")
            } else {
                control.pendingMode = ""
                control.status = "Fan authorization cancelled or failed (" + code + ")"
            }
        }
    }
    Process {
        id: backend
        command: ["python3", decodeURIComponent(String(Qt.resolvedUrl("../../../scripts/rise-fan-control")).replace(/^(file|qs):\/\//, ""))]
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                try {
                    let result = JSON.parse(line)
                    console.info("[Rise fan] " + line)
                    if (result.channels !== undefined) {
                        control.channels = result.channels
                        control.uid = result.uid
                        if (control.pendingMode !== "" && control.writable) {
                            let mode = control.pendingMode
                            control.pendingMode = ""
                            control.send(mode)
                        } else if (control.pendingMode !== "") {
                            control.pendingMode = ""
                            control.status = "CPU fan access is still unavailable"
                            return
                        }
                    }
                    if (result.error) {
                        control.currentMode = ""
                        control.status = result.error
                    } else if (result.status) control.status = result.status
                } catch (e) { control.status = "Invalid fan controller response" }
            }
        }
        onExited: (code) => {
            console.info("[Rise fan] backend exited " + code)
            control.currentMode = ""
            if (control.active) {
                control.status = "Fan controller stopped (" + code + ")"
            }
        }
    }
}
