import QtQuick
import "../logic/ArchUpdaterWidgetLogic.js" as ArchUpdaterWidgetLogic
import Quickshell
import Quickshell.Io
import "../logic/IconMap.js" as IconMap
import "../components" as CommonComponents

Item {
    id: rootMod
    property string colorGid: "G3"
    property color contentColor: rootMod.root.ink
    required property var root
    required property color iconColor
    required property color badgeColor
    required property color badgeTextColor

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

    function finishCheck() { return ArchUpdaterWidgetLogic.finishCheck(rootMod, {refreshWatchdog: refreshWatchdog, root: root, checkStdout: checkStdout}) }

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
            rootMod.root.archScanError = "Update check timed out. Previous results retained."
            rootMod.refreshing = false
            checkProc.running = false
        }
    }

    Timer {
        interval: 1800000; running: rootMod.root.modStatus || rootMod.root.archVisible; repeat: true; triggeredOnStart: true
        onTriggered: rootMod.root.archRefreshTick++
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
            "bash", decodeURIComponent(String(Qt.resolvedUrl("../../scripts/qs-arch-update-check.sh")).replace(/^(file|qs):\/\//, ""))
        ]
        rootMod.refreshing = true
        refreshWatchdog.restart()
        checkProc.command = cmd
        checkProc.running = false
        checkProc.running = true
    }

    function parseOutput(text) { return ArchUpdaterWidgetLogic.parseOutput(rootMod, {root: root}, text) }

    Item {
        anchors.centerIn: parent
        width: 20
        height: 20

        CommonComponents.IconText {
            id: ic
            anchors.centerIn: parent
            text: rootMod.refreshing ? "\uE5D5" : IconMap.icon("package_2")
            color: rootMod.iconColor
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
            color: rootMod.badgeColor

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: rootMod.badgeCount > 99 ? "99+" : String(rootMod.badgeCount)
                color: rootMod.badgeTextColor
                font.family: rootMod.root.mono
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

    CommonComponents.TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

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
                rootMod.root.archRefreshTick++;
            } else {
                rootMod.root.archVisible = true;
            }
        }
    }
}
