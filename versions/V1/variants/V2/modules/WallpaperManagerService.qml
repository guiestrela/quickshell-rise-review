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
    property var poolsByOutput: ({})
    property var queuesByOutput: ({})
    property var scanTokens: ({})
    property var scanErrors: ({})
    property var scanJobs: []
    property var activeScan: null
    property bool scanInFlight: false
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
            : ({ mode: "shuffle", scaling: "zoom", folder: manager.theme.wallpaperManagerFolder,
                 recursive: manager.theme.wallpaperRecursive !== false })
    }
    function scalingFor(outputName) { return String(profileFor(outputName).scaling || "zoom") }
    function poolFor(outputName) { return poolsByOutput[String(outputName)] || [] }
    function countFor(outputName) {
        return String(outputName) === "all" ? pool.length : poolFor(outputName).length
    }
    function hasShuffleOutput() {
        for (var i = 0; i < liveScreens.length; i++)
            if (poolFor(liveScreens[i].name).length > 0 && profileFor(liveScreens[i].name).mode !== "single") return true
        return false
    }
    function fileUrl(path) {
        return "file://" + String(path || "").split("/").map(function(part) {
            return encodeURIComponent(part)
        }).join("/")
    }
    function outputNames(outputName) {
        var selected = String(outputName || "all")
        return liveScreens.filter(function(screen) { return selected === "all" || screen.name === selected })
            .map(function(screen) { return String(screen.name) })
    }
    function rebuildPool() {
        var values = []
        for (var i = 0; i < liveScreens.length; i++) {
            var local = poolFor(liveScreens[i].name)
            for (var j = 0; j < local.length; j++)
                if (values.indexOf(local[j]) < 0) values.push(local[j])
        }
        pool = values
    }
    // One bounded scanner process; queued jobs retain their output and source.
    // Per-output tokens discard late results without touching another monitor.
    function scanFolder(outputName) {
        var names = outputNames(outputName)
        var jobs = scanJobs.slice()
        var tokens = Object.assign({}, scanTokens)
        for (var i = 0; i < names.length; i++) {
            var name = names[i]
            var profile = profileFor(name)
            var token = ++scanRequest
            tokens[name] = token
            jobs = jobs.filter(function(job) { return job.name !== name })
            jobs.push({ name: name, token: token, folder: String(profile.folder || ""), recursive: profile.recursive !== false })
        }
        scanTokens = tokens
        scanJobs = jobs
        pinnedPath = ""
        startNextScan()
    }
    function startNextScan() {
        if (scanInFlight || scanJobs.length === 0) return
        var jobs = scanJobs.slice()
        activeScan = jobs.shift()
        scanJobs = jobs
        scanInFlight = true
        if (activeScan.folder === "") { finishScan(0, "[]"); return }
        var command = ["python3", decodeURIComponent(String(Qt.resolvedUrl('../../../integrations/wallpaper-scan.py')).replace(/^file:\/\//, "")), activeScan.folder]
        if (!activeScan.recursive) command.push("--flat")
        scanner.command = command
        scanner.running = true
    }
    function finishScan(exitCode, text) {
        var job = activeScan
        if (!job) return
        if (scanTokens[job.name] === job.token) {
            var values = []
            var error = ""
            try {
                if (exitCode !== 0) throw Error("scanner failed")
                var data = JSON.parse(String(text || "[]"))
                if (!Array.isArray(data)) throw Error("invalid scanner result")
                values = data.filter(function(path) {
                    return typeof path === "string" && path.indexOf(job.folder.replace(/\/+$/, "") + "/") === 0
                        && !/[\u0000-\u001f\u007f-\u009f]/.test(path)
                })
            } catch (e) { error = "Unable to scan folder" }
            var pools = Object.assign({}, poolsByOutput)
            pools[job.name] = values
            poolsByOutput = pools
            var queues = Object.assign({}, queuesByOutput)
            queues[job.name] = []
            queuesByOutput = queues
            var errors = Object.assign({}, scanErrors)
            errors[job.name] = error
            scanErrors = errors
            rebuildPool()
            var previous = pathFor(job.name)
            var profile = profileFor(job.name)
            var selected = values.indexOf(profile.pinned) >= 0 && !badPaths[profile.pinned] ? profile.pinned
                : values.indexOf(previous) >= 0 && !badPaths[previous] ? previous : deal(previous, job.name)
            var next = Object.assign({}, currentByOutput)
            next[job.name] = selected
            currentByOutput = next
        }
        activeScan = null
        scanInFlight = false
        if (pendingPin !== "" && scanJobs.length === 0) pinAll(pendingPin)
        startNextScan()
    }
    function refillQueue(avoid, outputName, selections) {
        var choices = selections || currentByOutput
        var local = poolFor(outputName)
        var values = local.filter(function(path) { return !badPaths[path] && path !== avoid })
        if (values.length === 0) values = local.filter(function(path) { return !badPaths[path] })
        var unused = values.filter(function(path) {
            return liveScreens.every(function(screen) { return String(screen.name) === String(outputName) || String(choices[String(screen.name)] || "") !== path })
        })
        if (unused.length > 0) values = unused
        for (var k = values.length - 1; k > 0; k--) {
            var swap = Math.floor(Math.random() * (k + 1))
            var temp = values[k]; values[k] = values[swap]; values[swap] = temp
        }
        var queues = Object.assign({}, queuesByOutput)
        queues[String(outputName)] = values
        queuesByOutput = queues
    }
    function deal(avoid, outputName, selections) {
        var choices = selections || currentByOutput
        var name = String(outputName)
        var queue = (queuesByOutput[name] || []).filter(function(path) {
            return !badPaths[path] && path !== avoid && liveScreens.every(function(screen) {
                return String(screen.name) === name || String(choices[String(screen.name)] || "") !== path
            })
        })
        if (queue.length === 0) { refillQueue(avoid, name, choices); queue = (queuesByOutput[name] || []).slice() }
        var selected = queue.length > 0 ? queue.shift() : ""
        var queues = Object.assign({}, queuesByOutput)
        queues[name] = queue
        queuesByOutput = queues
        return selected
    }
    function shuffleAll(forceAdvance, outputName) {
        var names = outputNames(outputName)
        var next = Object.assign({}, currentByOutput)
        pinnedPath = ""
        for (var i = 0; i < names.length; i++) {
            var name = names[i]
            var previous = pathFor(name)
            var profile = profileFor(name)
            if (profile.mode === "single" && forceAdvance !== true && poolFor(name).indexOf(previous) >= 0 && !badPaths[previous]) continue
            next[name] = deal(previous, name, next)
        }
        currentByOutput = next
    }
    function nextAll() { shuffleAll(true) }
    function nextFor(outputName) { shuffleAll(true, outputName) }
    function pinAll(path) {
        var value = String(path || "")
        if (scanInFlight || scanJobs.length > 0) { pendingPin = value; return }
        if (pool.indexOf(value) < 0 || badPaths[value]) { pendingPin = ""; return }
        pendingPin = ""
        pinnedPath = theme.wallpaperManagerSettings && theme.wallpaperManagerSettings.perDisplayConfig ? "" : value
        var next = Object.assign({}, currentByOutput)
        for (var i = 0; i < liveScreens.length; i++) {
            var name = String(liveScreens[i].name)
            if (poolFor(name).indexOf(value) >= 0) next[name] = value
        }
        currentByOutput = next
    }
    function markBad(path) {
        var next = Object.assign({}, badPaths)
        next[String(path)] = true
        badPaths = next
        for (var i = 0; i < liveScreens.length; i++) {
            var name = String(liveScreens[i].name)
            if (pathFor(name) === path) nextFor(name)
        }
    }

    function wakeShuffle() {
        if (pinnedPath !== "" || !theme.wallpaperShuffleOnWake || !theme.wallpaperWakeAvailable
            || theme.wallpaperSessionLocked || theme.wallpaperScreensaverShowing || !hasShuffleOutput()) return
        wakeDebounce.restart()
    }

    Timer {
        id: wakeDebounce
        interval: 400; repeat: false
        onTriggered: {
            if (manager.pinnedPath === "" && manager.theme.wallpaperShuffleOnWake && manager.theme.wallpaperWakeAvailable
                && !manager.theme.wallpaperSessionLocked && !manager.theme.wallpaperScreensaverShowing)
                manager.shuffleAll(false)
        }
    }

    Connections {
        target: manager.theme
        function onWallpaperSessionLockedChanged() { if (!manager.theme.wallpaperSessionLocked) manager.wakeShuffle() }
        function onWallpaperScreensaverShowingChanged() { if (!manager.theme.wallpaperScreensaverShowing) manager.wakeShuffle() }
        function onWallpaperManagerFolderChanged() { manager.badPaths = ({}); manager.pendingPin = ""; manager.scanFolder() }
    }

    Connections {
        target: manager
        function onLiveScreensChanged() {
            manager.scanFolder()
        }
    }

    Process {
        id: scanner
        command: ["true"]
        running: false
        stdout: StdioCollector { waitForEnd: true }
        onExited: function(exitCode) {
            // Defer until the collector has drained; keep scanInFlight true.
            Qt.callLater(function() { manager.finishScan(exitCode, String(scanner.stdout.text || "")) })
        }
    }

    Timer {
        interval: Math.max(1, manager.intervalSeconds) * 1000
        running: manager.pool.length > 0 && manager.intervalSeconds > 0
            && manager.pinnedPath === "" && manager.hasShuffleOutput()
        repeat: true
        onTriggered: manager.shuffleAll()
    }

    Variants {
        model: manager.allowWallpaperEffects ? manager.liveScreens : []
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
                visible: manager.pathFor(modelData.name) !== ""

                readonly property string imagePath: manager.pathFor(modelData.name)
                readonly property string imageUrl: manager.fileUrl(imagePath)
                readonly property bool video: /\.(mp4|webm|mkv|mov|avi)$/i.test(imagePath)
                readonly property bool animated: /\.gif$/i.test(imagePath)
                readonly property string scaling: manager.scalingFor(modelData.name)

                AnimatedImage {
                    anchors.centerIn: parent
                    width: wallpaperWindow.scaling === "zoom" || implicitWidth <= 0
                        ? parent.width
                        : wallpaperWindow.scaling === "fitHeight"
                            ? implicitWidth * parent.height / Math.max(1, implicitHeight)
                            : wallpaperWindow.scaling === "fitWidth" ? parent.width : implicitWidth
                    height: wallpaperWindow.scaling === "zoom" || implicitHeight <= 0
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
