import QtQuick
import Quickshell
import Quickshell.Io
import "../IconMap.js" as IconMap

Item {
    id: rootMod
    required property var root

    property int updateCount: 0
    property int systemCount: 0
    property int aurCount: 0
    property bool refreshing: false

    readonly property bool hasUpdates: rootMod.updateCount > 0
    readonly property bool badgePrefsLoaded: root._widgetsLoaded
    readonly property int packageBadgeCount: (rootMod.badgePrefsLoaded && root.archBadgePackages) ? Math.max(0, rootMod.updateCount) : 0
    readonly property int cleanThemeCount: {
        var n = 0, list = root.themeUpdList || []
        for (var i = 0; i < list.length; i++) {
            var t = list[i] || {}
            if (t.state === "clean" && t.behind > 0) n++
        }
        return n
    }
    readonly property bool hasThemeUpdates: rootMod.cleanThemeCount > 0
    readonly property int themeBadgeCount: (rootMod.badgePrefsLoaded && root.archBadgeThemes) ? Math.max(0, rootMod.cleanThemeCount) : 0
    readonly property int badgeCount: rootMod.packageBadgeCount + rootMod.themeBadgeCount
    readonly property bool hasBadge: rootMod.badgeCount > 0
    readonly property bool hasNotice: rootMod.hasUpdates || rootMod.hasThemeUpdates
        || root.themeUpdLocalEdits > 0

    implicitWidth: 26
    implicitHeight: 28

    // Publish only after both the exit status and stdout are available.
    property bool checkFinished: false
    property bool checkOutputReady: false
    property int checkExitCode: -1
    property bool checkTimedOut: false
    onRefreshingChanged: root.archRefreshing = refreshing

    Process {
        id: checkProc
        running: false
        stdout: StdioCollector {
            id: checkStdout
            onStreamFinished: {
                rootMod.checkOutputReady = true
                rootMod.finishCheck()
            }
        }
        onExited: (exitCode) => {
            rootMod.checkExitCode = exitCode
            rootMod.checkFinished = true
            rootMod.finishCheck()
        }
    }

    function finishCheck() {
        if (!checkFinished || !checkOutputReady) return
        refreshWatchdog.stop()
        if (checkTimedOut) {
            root.archScanError = "Update check timed out. Previous results retained."
        } else if (checkExitCode !== 0 || !parseOutput(checkStdout.text)) {
            root.archScanError = "Update check failed. Previous results retained."
        } else {
            root.archScanError = ""
        }
        refreshing = false
    }

    // safety: if the check ever hangs (AUR RPC stalls past the timeout), unstick
    // `refreshing` so future refreshes aren't blocked forever
    // checkupdates can sync a DB over the network + the 30s AUR timeout, so the
    // legitimate worst case is well past 45s. Kill the process (not just the flag)
    // so the state is unambiguous if it ever hangs.
    Timer {
        id: refreshWatchdog; interval: 70000
        objectName: "package-refresh-watchdog"
        onTriggered: {
            rootMod.checkTimedOut = true
            root.archScanError = "Update check timed out. Previous results retained."
            rootMod.refreshing = false
            checkProc.running = false
        }
    }

    Timer {
        interval: 1800000; running: root.modStatus || root.archVisible; repeat: true; triggeredOnStart: true
        onTriggered: root.archRefreshTick++
    }

    property int extTrigger: root.archRefreshTick
    onExtTriggerChanged: {
        if (!rootMod.refreshing) rootMod.doRefresh()
    }

    function doRefresh() {
        // Wait for a killed process to be reaped before reusing its collectors.
        if (refreshing || checkProc.running) return
        checkFinished = false
        checkOutputReady = false
        checkExitCode = -1
        checkTimedOut = false
        var cmd = [
            "bash", Quickshell.env("HOME") + "/.local/bin/qs-arch-update-check.sh"
        ]
        rootMod.refreshing = true
        refreshWatchdog.restart()
        checkProc.command = cmd
        checkProc.running = false
        checkProc.running = true
    }

    function parseOutput(text) {
        var lines = text.trim().split("\n")
        var updates = []
        var sysCount = 0; var aCount = 0
        var scan = null
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("|")
            if (parts.length >= 4) {
                var src = parts[0]
                if (src === "M") {
                    scan = { id: parts[1] || "", checked: parseInt(parts[2] || "0"),
                        hash: parts[3] || "", count: parseInt(parts[4] || "0") }
                    continue
                }
                if (src !== "S" && src !== "A") continue
                var entry = {name: parts[1], oldVer: parts[2], newVer: parts[3], source: src === "S" ? "system" : "aur"}
                updates.push(entry)
                if (src === "S") sysCount++
                else if (src === "A") aCount++
            }
        }
        // An empty successful scan still includes M metadata. Empty/malformed
        // stdout is not evidence that the machine has no available updates.
        if (!scan || !scan.id || !scan.hash || !isFinite(scan.checked)
                || scan.checked <= 0 || !isFinite(scan.count) || scan.count !== sysCount)
            return false
        root.archScanId = scan.id
        root.archScanCheckedEpoch = scan.checked
        root.archScanHash = scan.hash
        root.archScanSystemCount = scan.count
        rootMod.systemCount = sysCount
        rootMod.aurCount = aCount
        rootMod.updateCount = sysCount + aCount
        root.archUpdates = updates
        return true
    }

    Item {
        anchors.centerIn: parent
        width: 20
        height: 20

        IconText {
            id: ic
            anchors.centerIn: parent
            text: rootMod.refreshing ? "\uE5D5" : IconMap.icon("package_2")
            color: rootMod.refreshing
                ? Qt.rgba(root.sumi.r, root.sumi.g, root.sumi.b, 1)
                : (rootMod.hasNotice ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4))
            font.pixelSize: 14
        }

        Rectangle {
            visible: rootMod.hasBadge && !rootMod.refreshing
            anchors.verticalCenter: ic.verticalCenter
            anchors.verticalCenterOffset: -6
            anchors.horizontalCenter: ic.horizontalCenter
            anchors.horizontalCenterOffset: 7
            width: Math.max(12, badgeText.implicitWidth + 6)
            height: 12
            radius: 6
            color: root.seal

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: rootMod.badgeCount > 99 ? "99+" : String(rootMod.badgeCount)
                color: root.paper
                font.family: root.mono
                font.pixelSize: 7
                font.weight: Font.Bold
            }
        }
    }

    readonly property string tooltipText: {
        if (rootMod.refreshing) return ""
        var parts = []
        if (root.archScanError) parts.push(root.archScanError)
        if (rootMod.systemCount) parts.push(rootMod.systemCount + " system")
        if (rootMod.aurCount) parts.push(rootMod.aurCount + " AUR")
        if (rootMod.cleanThemeCount > 0) parts.push(rootMod.cleanThemeCount + " themes")
        if (root.themeUpdLocalEdits > 0) parts.push(root.themeUpdLocalEdits + " review")
        if (parts.length === 0) return "Up to date"
        return parts.join(" \u00B7 ") + "\nClick to view details"
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: { tip.show(); }
        onExited: { tip.hide(); }
        onClicked: (e) => {
            tip.hide();
            if (e.button === Qt.RightButton) {
                root.archRefreshTick++;
            } else {
                root.archVisible = true;
            }
        }
    }
}
