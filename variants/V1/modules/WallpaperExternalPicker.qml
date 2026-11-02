import QtQuick
import Quickshell.Io

// Keep file-chooser toolkit/lifecycle failures outside the shell process.
Item {
    id: picker
    property bool directoryOnly: false
    property string title: "Choose wallpaper"
    property string selectionKind: ""
    property url currentFolder: "file:///home"
    property url selectedFolder: ""
    property url selectedFile: ""
    property string targetDisplay: "all"
    property bool busy: false
    property bool started: false
    visible: busy
    signal accepted()
    signal rejected()
    signal failed(string message)

    function open() {
        if (busy) return false
        var url = String(currentFolder)
        var path = ""
        try { if (url.startsWith("file:///")) path = decodeURIComponent(url.slice(7)) }
        catch (error) { }
        if (!path.startsWith("/") || /[\x00\r\n]/.test(path)) {
            failed("The picker needs a valid local folder.")
            return false
        }
        var helper = decodeURIComponent(String(Qt.resolvedUrl("../../../scripts/rise-wallpaper-picker")).replace(/^file:\/\//, ""))
        var args = ["/usr/bin/python3", helper, "--folder", path, "--title", title]
        selectionKind = ""
        selectedFolder = ""
        selectedFile = ""
        started = false
        busy = true
        launcher.command = args
        launcher.running = true
        startup.restart()
        return true
    }

    Process {
        id: launcher
        stdout: StdioCollector { id: output; waitForEnd: true }
        onStarted: { picker.started = true; startup.stop() }
        onExited: (exitCode, exitStatus) => {
            startup.stop()
            if (!picker.busy) return
            picker.busy = false
            if (exitStatus === 0 && exitCode === 1) { picker.rejected(); return }
            if (exitStatus !== 0 || exitCode !== 0) {
                picker.failed("Could not open the system file picker.")
                return
            }
            var result
            try { result = JSON.parse(output.text) }
            catch (error) { picker.failed("The picker returned an invalid selection."); return }
            if (!result || result.schema !== 1 || (result.kind !== "folder" && result.kind !== "file")
                    || typeof result.path !== "string" || !result.path.startsWith("/")
                    || /[\u0000-\u001f\u007f-\u009f]/.test(result.path)) {
                picker.failed("The picker returned an invalid local path.")
                return
            }
            var url = "file://" + result.path.split("/").map(encodeURIComponent).join("/")
            picker.selectionKind = result.kind
            if (result.kind === "folder") picker.selectedFolder = url
            else picker.selectedFile = url
            picker.accepted()
        }
    }
    Timer {
        id: startup
        interval: 2000
        onTriggered: {
            if (picker.busy && !picker.started && !launcher.running) {
                picker.busy = false
                picker.failed("Could not start the wallpaper picker.")
            }
        }
    }
}
