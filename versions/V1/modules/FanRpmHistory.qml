import QtQuick
import Quickshell.Io

Item {
    id: fan
    required property var theme
    property bool active: false
    property bool externalSource: false
    property int externalRpm: -1
    property string sensorLabel: "FAN1"
    property int rpm: -1
    property int peakRpm: 0
    property var samples: []
    height: 42

    // Board channel, not an asserted CPU_FAN mapping. Never use the GPU tachometer.
    readonly property var rpmScale: recentScale(samples, rpm)
    function recentScale(points, current) {
        if (!points.length || current < 0) return {low: 0, high: 0, fraction: 0}
        var low = Math.max(0, Math.min.apply(null, points) - 10)
        var high = Math.max(low + 20, Math.max.apply(null, points) + 10)
        return {low: low, high: high,
            fraction: Math.max(0, Math.min(1, (current - low) / (high - low)))}
    }
    function acceptSample(raw, code) {
        var value = String(raw === null || raw === undefined ? "" : raw).trim()
        if (code !== 0 || !/^\d+$/.test(value)) {
            rpm = -1
            samples = []
            peakRpm = 0
            trace.requestPaint()
            return
        }
        rpm = Number(value)
        peakRpm = Math.max(peakRpm, rpm)
        var next = samples.slice(-29)
        next.push(rpm)
        samples = next
        trace.requestPaint()
    }
    function refresh() {
        if (!active) return
        if (externalSource) acceptSample(externalRpm >= 0 ? externalRpm : "", externalRpm >= 0 ? 0 : 1)
        else if (!reader.running) reader.running = true
    }
    onActiveChanged: {
        if (active) { rpm = -1; samples = []; peakRpm = 0; refresh() }
    }
    Component.onCompleted: refresh()

    UiText {
        anchors.left: parent.left
        text: fan.rpm >= 0
            ? fan.sensorLabel + " · " + fan.rpmScale.low + "–" + fan.rpmScale.high
            : fan.sensorLabel + " · RPM"
        color: fan.theme.sumiHi
        font.family: fan.theme.mono; font.pixelSize: 10
    }
    UiText {
        anchors.right: parent.right
        text: fan.rpm >= 0 ? fan.rpm + " RPM" : "Unavailable"
        color: fan.rpm >= 0 ? fan.theme.seal : fan.theme.sumiHi
        font.family: fan.theme.mono; font.pixelSize: 10
    }
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.topMargin: 19
        height: 6; radius: 3
        color: fan.theme.fillActive
        Rectangle {
            height: parent.height; radius: parent.radius
            objectName: "fanRpmFill"
            width: parent.width * fan.rpmScale.fraction
            color: fan.theme.seal
            Behavior on width { NumberAnimation { duration: 300 } }
        }
    }
    // Last 30 readings (~60 seconds). Auto-scaled RPM, not fan-control percentage.
    Canvas {
        id: trace
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 12
        visible: fan.samples.length > 1
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var points = fan.samples
            if (points.length < 2) return
            var low = Math.min.apply(null, points)
            var high = Math.max.apply(null, points)
            var span = Math.max(20, high - low)
            ctx.strokeStyle = fan.theme.seal
            ctx.lineWidth = 1
            ctx.beginPath()
            for (var i = 0; i < points.length; i++) {
                var x = i * width / Math.max(1, points.length - 1)
                var y = height - 1 - (points[i] - low) / span * (height - 2)
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
    }
    Timer { interval: 2000; repeat: true; running: fan.active; onTriggered: fan.refresh() }
    Process {
        id: reader
        command: ["timeout", "2", "bash", "-c",
            "for d in /sys/class/hwmon/hwmon*; do "
            + "[[ -r $d/name ]] || continue; read -r n < \"$d/name\"; "
            + "[[ $n == nct6791 && -r $d/fan2_input ]] || continue; "
            + "cat \"$d/fan2_input\"; exit; done; exit 1"]
        stdout: StdioCollector { id: reading }
        onExited: (code) => { if (fan.active) fan.acceptSample(reading.text, code) }
    }
}
