import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtMultimedia

// Rise-native wallpaper service. It reuses the Rise folder chooser, picks a
// separate item for each output, and owns only its wallpaper-layer surfaces.
Item {
    id: manager
    required property var theme
    property var pool: []
    property var dealtQueue: []
    property var currentByOutput: ({})
    property var badPaths: ({})
    property int scanRequest: 0
    property string pinnedPath: ""
    property string pendingPin: ""
    // Test seam: isolated harnesses exercise selection/scaling without invoking
    // the Omarchy wallpaper command. Production remains Rise's single owner.
    property bool allowWallpaperEffects: true

    readonly property int intervalSeconds: theme.wallpaperShuffleInterval
    readonly property var liveScreens: {
        var result = []
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var screen = Quickshell.screens[i]
            if (screen && screen.name !== "" && screen.width > 0 && screen.height > 0)
                result.push(screen)
        }
        return result
    }

    function pathFor(outputName) { return String(currentByOutput[String(outputName)] || "") }
    function profileFor(outputName) {
        return manager.theme.wallpaperProfileFor
            ? manager.theme.wallpaperProfileFor(String(outputName))
            : ({ mode: "shuffle", scaling: "zoom", folder: manager.theme.wallpaperManagerFolder })
    }
    function scalingFor(outputName) { return String(profileFor(outputName).scaling || "zoom") }
    function fileUrl(path) {
        return "file://" + String(path || "").split("/").map(function(part) {
            return encodeURIComponent(part)
        }).join("/")
    }

    function scanFolder() {
        if (theme.wallpaperManagerFolder === "") {
            pool = []
            dealtQueue = []
            currentByOutput = ({})
            pinnedPath = ""
            pendingPin = ""
            return
        }
        scanRequest++
        var scanCommand = ["python3", String(Qt.resolvedUrl("../integrations/wallpaper-scan.py")).replace(/^file:\/\//, ""), theme.wallpaperManagerFolder]
        if (theme.wallpaperRecursive === false) scanCommand.push("--flat")
        scanner.command = scanCommand
        scanner.running = false
        scanner.running = true
    }

    function refillQueue(avoid) {
        var values = []
        for (var i = 0; i < pool.length; i++)
            if (!badPaths[pool[i]] && pool[i] !== avoid) values.push(pool[i])
        if (values.length === 0)
            for (var j = 0; j < pool.length; j++) if (!badPaths[pool[j]]) values.push(pool[j])
        for (var k = values.length - 1; k > 0; k--) {
            var swap = Math.floor(Math.random() * (k + 1))
            var temp = values[k]; values[k] = values[swap]; values[swap] = temp
        }
        dealtQueue = values
    }

    function deal(avoid) {
        if (dealtQueue.length === 0) refillQueue(avoid)
        if (dealtQueue.length === 0) return ""
        var queue = dealtQueue.slice()
        var selected = queue.shift()
        dealtQueue = queue
        return selected
    }

    function shuffleAll() {
        if (pool.length === 0) { scanFolder(); return }
        pinnedPath = ""
        var next = ({})
        var used = ({})
        for (var i = 0; i < liveScreens.length; i++) {
            var name = String(liveScreens[i].name)
            var previous = pathFor(name)
            var profile = profileFor(name)
            // Single keeps its per-display choice; Shuffle advances it. A
            // newly connected display gets one initial deal in either mode.
            var candidate = profile.mode === "single" && previous !== "" && !badPaths[previous]
                ? previous : deal(previous)
            // If the folder is smaller than the display count, repeats are
            // allowed only after every eligible image has been dealt.
            if (candidate !== "" && used[candidate]) candidate = previous
            next[name] = candidate
            if (candidate !== "") used[candidate] = true
        }
        currentByOutput = next
        var primaryPath = liveScreens.length > 0 ? pathFor(liveScreens[0].name) : ""
        if (manager.allowWallpaperEffects && primaryPath !== "" && !/\.(mp4|webm|mkv|mov|avi)$/i.test(primaryPath)) {
            syncCurrent.command = ["bash", "-c", "omarchy-theme-bg-set \"$1\"", "rise-wallpaper-current", primaryPath]
            syncCurrent.running = false
            syncCurrent.running = true
        }
    }

    function pinAll(path) {
        var value = String(path || "")
        if (pool.length === 0) { pendingPin = value; return }
        if (pool.indexOf(value) < 0 || badPaths[value]) return
        pendingPin = ""
        pinnedPath = value
        var next = ({})
        for (var i = 0; i < liveScreens.length; i++) next[String(liveScreens[i].name)] = value
        currentByOutput = next
        if (manager.allowWallpaperEffects && liveScreens.length > 0 && !/\.(mp4|webm|mkv|mov|avi)$/i.test(value)) {
            syncCurrent.command = ["bash", "-c", "omarchy-theme-bg-set \"$1\"", "rise-wallpaper-current", value]
            syncCurrent.running = false
            syncCurrent.running = true
        }
    }

    function markBad(path) {
        var next = Object.assign({}, badPaths)
        next[String(path)] = true
        badPaths = next
        dealtQueue = dealtQueue.filter(function(value) { return value !== path })
        shuffleAll()
    }

    Connections {
        target: manager.theme
        function onWallpaperManagerFolderChanged() { manager.badPaths = ({}); manager.pendingPin = ""; manager.scanFolder() }
    }

    Connections {
        target: manager
        function onLiveScreensChanged() {
            if (manager.pool.length > 0) manager.shuffleAll()
        }
    }

    Process {
        id: scanner
        command: ["true"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var data = JSON.parse(String(this.text || "[]"))
                    manager.pool = Array.isArray(data) ? data : []
                    manager.dealtQueue = []
                    manager.currentByOutput = ({})
                    if (manager.pendingPin !== "") manager.pinAll(manager.pendingPin)
                    else manager.shuffleAll()
                } catch (e) {
                    manager.pool = []
                    manager.currentByOutput = ({})
                }
            }
        }
    }

    Process { id: syncCurrent; command: ["true"]; running: false }

    Timer {
        interval: Math.max(60, manager.intervalSeconds) * 1000
        running: manager.theme.wallpaperManagerFolder !== "" && manager.intervalSeconds >= 60 && manager.pinnedPath === ""
        repeat: true
        onTriggered: manager.shuffleAll()
    }

    Variants {
        model: manager.liveScreens
        delegate: Component {
            PanelWindow {
                id: wallpaperWindow
                required property var modelData
                screen: modelData
                color: "#000000"
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.namespace: "quickshell-rise-wallpaper"
                visible: manager.theme.wallpaperManagerFolder !== "" && manager.pathFor(modelData.name) !== ""

                readonly property string imagePath: manager.pathFor(modelData.name)
                readonly property string imageUrl: manager.fileUrl(imagePath)
                readonly property bool video: /\.(mp4|webm|mkv|mov|avi)$/i.test(imagePath)
                readonly property bool animated: /\.gif$/i.test(imagePath)
                readonly property string scaling: manager.scalingFor(modelData.name)

                AnimatedImage {
                    anchors.centerIn: parent
                    width: wallpaperWindow.scaling === "zoom" || wallpaperWindow.implicitWidth <= 0
                        ? parent.width
                        : wallpaperWindow.scaling === "fitHeight"
                            ? implicitWidth * parent.height / Math.max(1, implicitHeight)
                            : wallpaperWindow.scaling === "fitWidth" ? parent.width : implicitWidth
                    height: wallpaperWindow.scaling === "zoom" || wallpaperWindow.implicitHeight <= 0
                        ? parent.height
                        : wallpaperWindow.scaling === "fitWidth"
                            ? implicitHeight * parent.width / Math.max(1, implicitWidth)
                            : wallpaperWindow.scaling === "fitHeight" ? parent.height : implicitHeight
                    visible: wallpaperWindow.imagePath !== "" && !wallpaperWindow.video
                    source: visible ? wallpaperWindow.imageUrl : ""
                    fillMode: wallpaperWindow.scaling === "zoom"
                        ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    smooth: true
                    playing: wallpaperWindow.visible && wallpaperWindow.animated
                    onStatusChanged: if (status === Image.Error) manager.markBad(wallpaperWindow.imagePath)
                }

                VideoOutput {
                    id: videoOutput
                    anchors.centerIn: parent
                    width: wallpaperWindow.scaling === "actual" ? implicitWidth : parent.width
                    height: wallpaperWindow.scaling === "actual" ? implicitHeight : parent.height
                    visible: wallpaperWindow.visible && wallpaperWindow.video
                    fillMode: wallpaperWindow.scaling === "zoom"
                        ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit
                }
                MediaPlayer {
                    source: wallpaperWindow.video ? wallpaperWindow.imageUrl : ""
                    autoPlay: wallpaperWindow.visible && wallpaperWindow.video
                    loops: MediaPlayer.Infinite
                    videoOutput: videoOutput
                    audioOutput: AudioOutput { muted: true }
                    onErrorOccurred: function(error, errorString) {
                        if (error !== MediaPlayer.NoError) manager.markBad(wallpaperWindow.imagePath)
                    }
                }
            }
        }
    }

    Component.onCompleted: scanFolder()
}
