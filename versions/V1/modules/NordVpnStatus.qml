import QtQuick
import Quickshell.Io

Item {
    id: controller
    property bool enabled: false
    property int refreshInterval: 15000
    property var command: ["nordvpn", "status"]
    property string status: "Unknown"
    property int completedCount: 0
    readonly property bool busy: statusProcess.running

    function refresh() {
        if (!enabled || statusProcess.running) return false
        statusProcess.running = true
        return true
    }

    onEnabledChanged: {
        if (!enabled) {
            if (statusProcess.running) statusProcess.running = false
            status = "Unknown"
        }
    }

    Process {
        id: statusProcess
        command: controller.command
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var statusLine = String(this.text || "").split("\n").filter(function(line) {
                    return line.trim().indexOf("Status:") === 0
                })[0] || ""
                var value = statusLine ? statusLine.substring(statusLine.indexOf(":") + 1).trim() : ""
                controller.status = value ? (/^connected/i.test(value) ? "Connected" : "Disconnected") : "Unknown"
            }
        }
        onExited: function(exitCode) {
            controller.completedCount += 1
            if (exitCode !== 0) controller.status = "Unavailable"
        }
    }

    Timer {
        interval: Math.max(2000, controller.refreshInterval)
        running: controller.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: controller.refresh()
    }
}
