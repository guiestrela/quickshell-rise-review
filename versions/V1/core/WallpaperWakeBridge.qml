import QtQuick
import Quickshell.Io

// Only filtered booleans cross into Rise; no lock/PAM service object is exposed.
Item {
    id: bridge
    property bool available: false
    property bool locked: true
    property bool screensaverShowing: false
    property bool pending: false
    readonly property string readerPath: decodeURIComponent(String(Qt.resolvedUrl("../../../scripts/rise-wallpaper-wake-state")).replace(/^file:\/\//, ""))
    readonly property bool busy: pending || reader.running
    width: 0
    height: 0

    function refresh() {
        if (busy) return false
        pending = true
        reader.command = ["/usr/bin/python3", readerPath]
        reader.running = true
        return true
    }

    function accept(exitCode, text) {
        var value = null
        try { value = JSON.parse(text) } catch (e) {}
        if (exitCode !== 0 || !value || value.schema !== 1
                || typeof value.locked !== "boolean"
                || typeof value.screensaverShowing !== "boolean") {
            // Keep last known state; failure must never synthesize an unlock.
            available = false
            return false
        }
        // On startup/recovery, availability stays false while the baseline is set.
        // During normal sampling it stays true so actual transitions reach listeners.
        locked = value.locked
        screensaverShowing = value.screensaverShowing
        available = true
        return true
    }

    Process {
        id: reader
        stdout: StdioCollector { id: output; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: (exitCode) => {
            Qt.callLater(() => {
                bridge.accept(exitCode, output.text)
                bridge.pending = false
            })
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: bridge.refresh()
    }

    Component.onCompleted: refresh()
}
