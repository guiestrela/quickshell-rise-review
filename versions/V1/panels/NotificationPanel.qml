import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../integrations/NotificationActions.js" as NotificationActions

PanelWindow {
    id: notifPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Keep this history overlay separate from Omarchy's own notification toast
    // surfaces; sharing a layer-shell namespace can make the compositor treat
    // unrelated full-screen windows as one notification surface.
    WlrLayershell.namespace: "quickshell-rise-notification-history"

    readonly property int barBottom: 35
    readonly property int gap: 8

    // ── quickshell-owned notification history ────────────────────────────────
    // Mako's history is capped (default max-history 5), so polling it and
    // REPLACING our list each time loses everything older. Instead we MERGE each
    // poll into our own retained history (capped 50) and persist it, so entries
    // survive both mako dropping them and a quickshell restart.
    //
    // Identity: mako ids are a per-session counter that RESETS on a mako restart,
    // so a bare id is ambiguous across restarts. We derive a session token
    // (boot-id + mako pid + proc start-time) once per poll; when it changes we
    // bump `generation`, and every entry is keyed "generation:id". Old entries
    // (gen 0) and reused new ids (gen 1) therefore never collide. The bare id is
    // used ONLY for makoctl dismiss/invoke operations.

    property var recent: []             // [{key,id,gen,appName,summary,body,firstSeen,active}]
    property var dismissed: ({})         // composite-key -> true (persisted)
    property string sessionToken: ""
    property int generation: 0
    property int seq: 0                  // monotonic first-seen counter (ordering)
    property bool cacheLoaded: false
    property string lastSaved: ""

    // pending = not dismissed → drives both the list and the badge
    readonly property var pending: {
        var out = []
        for (var i = 0; i < recent.length; i++)
            if (!dismissed[recent[i].key]) out.push(recent[i])
        return out
    }
    readonly property int unreadCount: pending.length
    // scrollable list height cap, clamped to the monitor
    readonly property int listCap: Math.max(120, Math.min(420, notifPanel.height - 220))

    Binding { target: root; property: "notifCount"; value: notifPanel.unreadCount }

    // ── persistent cache (quickshell is the sole writer; write only on change) ──
    readonly property string cachePath: Quickshell.env("HOME") + "/.cache/qs-rise-notifications.json"
    FileView {
        id: cacheFile
        path: notifPanel.cachePath
        onLoaded: {
            try {
                var j = JSON.parse(cacheFile.text())
                notifPanel.sessionToken = j.token || ""
                notifPanel.generation   = j.generation || 0
                notifPanel.seq          = j.seq || 0
                notifPanel.recent       = Array.isArray(j.recent) ? j.recent : []
                notifPanel.dismissed    = (j.dismissed && typeof j.dismissed === "object") ? j.dismissed : ({})
                notifPanel.lastSaved    = cacheFile.text()
            } catch (e) {
                notifPanel.recent = []; notifPanel.dismissed = ({})
            }
            notifPanel.cacheLoaded = true
            notifPanel.poll()
        }
        onLoadFailed: {                  // first run: no cache yet
            notifPanel.cacheLoaded = true
            notifPanel.poll()
        }
    }
    // force the initial load (don't rely on implicit auto-load) — the whole panel
    // is gated on cacheLoaded, so a missed load would mean no notifications ever
    Component.onCompleted: cacheFile.reload()

    function saveCache() {
        if (!notifPanel.cacheLoaded) return
        var state = JSON.stringify({
            token: notifPanel.sessionToken,
            generation: notifPanel.generation,
            seq: notifPanel.seq,
            recent: notifPanel.recent,
            dismissed: notifPanel.dismissed
        })
        if (state === notifPanel.lastSaved) return   // no real change → no write
        notifPanel.lastSaved = state
        cacheFile.setText(state)
    }

    readonly property string snapshotReader: String(Qt.resolvedUrl("../integrations/notification-snapshot.py")).replace(/^file:\/\//, "")

    Process {
        id: pollProc
        command: ["python3", notifPanel.snapshotReader]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var d
                try { d = JSON.parse(this.text) } catch (e) { return }
                notifPanel.merge(d.token || "", d.list || [], d.history || [])
            }
        }
    }
    function poll() {
        if (!notifPanel.cacheLoaded) return
        pollProc.running = false; pollProc.running = true
    }

    // merge this poll's active(list) + history into our retained history
    function merge(token, listArr, histArr) {
        // session / generation
        if (token !== "" && token !== notifPanel.sessionToken) {
            if (notifPanel.sessionToken !== "") notifPanel.generation += 1
            notifPanel.sessionToken = token
        }
        var gen = notifPanel.generation

        // incoming this poll (current generation), by bare id; active = in `list`
        var incoming = {}
        for (var i = 0; i < listArr.length; i++) {
            var n = listArr[i]
            incoming[n.id] = { appName: n.app_name || "", summary: n.summary || "", body: n.body || "", active: true, backend: n.backend || "", timestamp: n.timestamp || 0, actionKind: n.actionKind, crashReference: n.crashReference }
        }
        for (var j = 0; j < histArr.length; j++) {
            var h = histArr[j]
            if (incoming[h.id] === undefined)
                incoming[h.id] = { appName: h.app_name || "", summary: h.summary || "", body: h.body || "", active: false, backend: h.backend || "", timestamp: h.timestamp || 0, actionKind: h.actionKind, crashReference: h.crashReference }
        }

        // existing entries by composite key
        var byKey = {}
        for (var k = 0; k < notifPanel.recent.length; k++) byKey[notifPanel.recent[k].key] = notifPanel.recent[k]

        // update-or-create current-gen entries; oldest id first so newest gets the largest seq
        var ids = []
        for (var idk in incoming) ids.push(parseInt(idk))
        ids.sort(function(a, b) { return a - b })
        for (var m = 0; m < ids.length; m++) {
            var id = ids[m]
            var key = gen + ":" + id
            var src = incoming[id]
            if (byKey[key] !== undefined) {
                var e = byKey[key]
                e.appName = src.appName; e.summary = src.summary; e.body = src.body
                e.backend = src.backend; e.timestamp = src.timestamp
                e.actionKind = src.actionKind; e.crashReference = src.crashReference
            } else {
                byKey[key] = { key: key, id: id, gen: gen,
                    appName: src.appName, summary: src.summary, body: src.body,
                    backend: src.backend, timestamp: src.timestamp,
                    actionKind: src.actionKind, crashReference: src.crashReference,
                    firstSeen: (++notifPanel.seq) }
            }
        }

        // recompute the (transient) active flag for ALL entries, build a NEW array
        var out = []
        for (var ek in byKey) {
            var ee = byKey[ek]
            ee.active = (ee.gen === gen && incoming[ee.id] !== undefined && incoming[ee.id].active === true)
            out.push(ee)
        }
        out.sort(function(a, b) { return b.firstSeen - a.firstSeen })
        if (out.length > 50) out = out.slice(0, 50)

        // prune dismissed keys no longer present (bounds the set)
        var present = {}
        for (var o = 0; o < out.length; o++) present[out[o].key] = true
        var nd = {}, changed = false
        for (var dk in notifPanel.dismissed) {
            if (present[dk]) nd[dk] = true; else changed = true
        }

        notifPanel.recent = out                  // reassign → bindings fire
        if (changed) notifPanel.dismissed = nd
        notifPanel.saveCache()
    }

    // ── actions ──
    Process { id: actionProc; command: ["true"] }
    Process {
        id: clearHistoryProc
        command: ["omarchy-shell", "notifications", "clear"]
        onExited: function() { }
    }
    function runNotificationAction(argv) {
        actionProc.command = argv
        actionProc.running = false; actionProc.running = true
    }

    function dismissOne(entry) {
        var nd = {}
        for (var k in notifPanel.dismissed) nd[k] = true
        nd[entry.key] = true
        notifPanel.dismissed = nd                // reassign → bindings update
        var id = parseInt(entry.id)              // normalize before it touches a shell
        if (entry.active && id > 0) {
            if (root._notifOmarchyShellBackend)
                notifPanel.runNotificationAction(["omarchy-shell", "notifications", "dismiss", String(entry.summary || "")])
            else
                notifPanel.runNotificationAction(["makoctl", "dismiss", "-h", "-n", String(id)])
        }
        notifPanel.saveCache()
    }

    function dismissAll() {
        var nd = {}
        for (var k in notifPanel.dismissed) nd[k] = true
        for (var i = 0; i < notifPanel.recent.length; i++) nd[notifPanel.recent[i].key] = true
        notifPanel.dismissed = nd
        notifPanel.recent = []                   // clear own history; re-merged entries stay dismissed-filtered
        if (root._notifOmarchyShellBackend) {
            notifPanel.runNotificationAction(["omarchy-shell", "notifications", "dismissAll"])
            clearHistoryProc.running = false; clearHistoryProc.running = true
        } else {
            notifPanel.runNotificationAction(["makoctl", "dismiss", "-h", "--all"])
        }
        notifPanel.saveCache()
    }

    property string notificationActionError: ""
    property bool notificationReplySeen: false
    property var nativeBrowserClaims: ({})
    property bool browserOpenReplySeen: false
    readonly property string browserOpenHelper: snapshotReader.replace("notification-snapshot.py", "notification-browser-open.py")
    Process {
        id: browserOpenProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try { notifPanel.finishBrowserOpen(JSON.parse(this.text)) }
                catch (e) { notifPanel.finishBrowserOpen({ok: false, message: "Cannot read browser action result."}) }
            }
        }
        onExited: {
            if (!notifPanel.browserOpenReplySeen)
                notifPanel.finishBrowserOpen({ok: false, message: "The browser could not start."})
        }
    }
    Timer {
        interval: 12000
        running: browserOpenProc.running
        onTriggered: {
            notifPanel.finishBrowserOpen({ok: false, message: "The browser action timed out."})
            browserOpenProc.signal(9)
        }
    }
    function finishBrowserOpen(result) {
        if (notifPanel.browserOpenReplySeen) return
        notifPanel.browserOpenReplySeen = true
        if (result && result.ok === true) {
            notifPanel.notificationActionError = ""
        } else {
            notifPanel.notificationActionError = (result && typeof result.message === "string")
                ? result.message : "This notification has no available browser link."
            root.notifVisible = true
        }
    }
    readonly property string notificationActionHelper: snapshotReader.replace("notification-snapshot.py", "notification-crash-action.py")
    Process {
        id: notificationOpenProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try { notifPanel.finishNotificationAction(JSON.parse(this.text)) }
                catch (e) { notifPanel.finishNotificationAction({ok: false, message: "Cannot read notification action result."}) }
            }
        }
        onExited: {
            if (!notifPanel.notificationReplySeen)
                notifPanel.finishNotificationAction({ok: false, message: "Notification action could not start."})
        }
    }
    Timer {
        interval: 12000
        running: notificationOpenProc.running
        onTriggered: {
            notifPanel.finishNotificationAction({ok: false, message: "Notification action timed out."})
            notificationOpenProc.signal(9)
        }
    }

    function finishNotificationAction(result) {
        if (notifPanel.notificationReplySeen) return
        notifPanel.notificationReplySeen = true
        if (result && result.ok === true) {
            notifPanel.notificationActionError = ""
            root.notifVisible = false
        } else {
            notifPanel.notificationActionError = (result && typeof result.message === "string")
                ? result.message : "This notification action is unavailable."
        }
    }

    function openNotification(entry) {
        if (!root.notifVisible || notificationOpenProc.running || browserOpenProc.running) return
        notifPanel.notificationActionError = ""
        if (entry.backend === "omarchy" && entry.appName === "Chromium") {
            var claim = String(entry.timestamp) + ":" + String(entry.id)
            if (notifPanel.nativeBrowserClaims[claim]) return
            // Reserve synchronously before invoking: rapid clicks cannot replay.
            notifPanel.nativeBrowserClaims[claim] = true
            if (NotificationActions.invokeChromium(NotificationActions.serviceFor(root), entry)) {
                root.notifVisible = false
                return
            }
            delete notifPanel.nativeBrowserClaims[claim]
            // Drop exclusive keyboard focus before asking the browser to
            // activate its new tab. No window-address guessing or focus CLI.
            root.notifVisible = false
            notifPanel.browserOpenReplySeen = false
            browserOpenProc.command = ["python3", notifPanel.browserOpenHelper,
                "--entry", JSON.stringify({backend: "omarchy", id: entry.id,
                    appName: entry.appName, summary: entry.summary || "", body: entry.body || "",
                    timestamp: entry.timestamp})]
            browserOpenProc.running = true
            return
        }
        if (entry.backend === "omarchy" || root._notifOmarchyShellBackend
                || entry.appName === "omarchy-action") {
            // Fixed screenshot/crash actions, never sender command execution.
            notifPanel.notificationReplySeen = false
            notificationOpenProc.command = ["python3", notifPanel.notificationActionHelper,
                "--entry", JSON.stringify({backend: "omarchy", id: entry.id,
                    appName: entry.appName || "", summary: entry.summary || "",
                    body: entry.body || "", timestamp: entry.timestamp || 0,
                    actionKind: entry.actionKind, crashReference: entry.crashReference})]
            notificationOpenProc.running = true
            return
        }
        var id = parseInt(entry.id)
        if (entry.active && id > 0) {
            notifPanel.runNotificationAction(["makoctl", "invoke", "-n", String(id)])
            root.notifVisible = false
        } else {
            notifPanel.notificationActionError = "This notification no longer has an active action."
        }
    }

    // ── poll cadence: fast while open, much slower when closed.
    // Opening the panel still triggers an immediate refresh below; the closed
    // cadence only keeps the badge/history roughly warm without parsing mako
    // JSON every few seconds in idle.
    Timer {
        interval: notifPanel.visible ? 1500 : 10000
        running: notifPanel.cacheLoaded; repeat: true; triggeredOnStart: true
        onTriggered: notifPanel.poll()
    }

    property real reveal: root.notifVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.notifVisible ? 160 : 120
            easing.type: root.notifVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.notifVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: { if (visible) notifPanel.poll() }

    MouseArea {
        anchors.fill: parent
        onClicked: root.notifVisible = false
    }

    Rectangle {
        id: card
        width: 320
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.notifBarX, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: notifPanel.reveal
        focus: root.notifVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.notifVisible = false
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header ──
            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: notifPanel.unreadCount > 0 ? "Notifications · " + notifPanel.unreadCount : "Notifications"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeMa.containsMouse ? root.seal : root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notifVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── notification list (scrollable; each individually dismissable) ──
            UiText {
                width: parent.width
                visible: notifPanel.notificationActionError !== ""
                text: notifPanel.notificationActionError
                color: root.sumi
                font.family: root.mono
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                maximumLineCount: 3
            }

            Flickable {
                width: parent.width
                height: Math.min(listCol.implicitHeight, notifPanel.listCap)
                contentHeight: listCol.implicitHeight
                clip: true
                interactive: listCol.implicitHeight > notifPanel.listCap
                boundsBehavior: Flickable.StopAtBounds   // no overshoot/rebound at the top/bottom edge
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: listCol
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: notifPanel.pending

                        delegate: Rectangle {
                            required property var modelData
                            width: listCol.width
                            height: entryCol.implicitHeight + 16
                            radius: root.tileRadius
                            color: entryMa.containsMouse ? root.fillHover : root.fillIdle
                            border.color: entryMa.containsMouse ? root.seal : root.sep
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Column {
                                id: entryCol
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                anchors.margins: 8
                                anchors.topMargin: 8
                                anchors.rightMargin: 26   // leave room for the ✕
                                spacing: 3

                                UiText {
                                    text: modelData.appName || "App"
                                    color: root.sumiHi
                                    font.family: root.mono
                                    font.pixelSize: 10
                                    font.letterSpacing: 0.5
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                                UiText {
                                    text: modelData.summary || ""
                                    color: root.ink
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    width: parent.width
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                                UiText {
                                    text: modelData.body || ""
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
                                    font.family: root.mono
                                    font.pixelSize: 10
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }
                            }

                            // click body → focus the app (only if still active in mako)
                            MouseArea {
                                id: entryMa
                                anchors.fill: parent
                                enabled: root.notifVisible && !notificationOpenProc.running && !browserOpenProc.running
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notifPanel.openNotification(modelData)
                            }

                            // per-item dismiss ✕ (on top, top-right corner)
                            Rectangle {
                                anchors.top: parent.top; anchors.right: parent.right
                                anchors.topMargin: 4; anchors.rightMargin: 4
                                width: 18; height: 18; radius: 9
                                color: "transparent"
                                UiText {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: xMa.containsMouse ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                                    font.pixelSize: 10
                                }
                                MouseArea {
                                    id: xMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: notifPanel.dismissOne(modelData)
                                }
                            }
                        }
                    }

                    UiText {
                        visible: notifPanel.pending.length === 0
                        width: listCol.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "No notifications"
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)
                        font.family: root.mono
                        font.pixelSize: 11
                    }
                }
            }

            // ── clear all ──
            Rectangle {
                width: parent.width
                height: 28; radius: root.tileRadius
                visible: notifPanel.pending.length > 0
                readonly property bool hovered: clearMa.containsMouse
                color: hovered ? root.fillHover : root.fillIdle
                border.color: hovered ? root.seal : root.sep
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: "Clear all"
                    color: clearMa.containsMouse ? root.seal : root.sumi
                    font.family: root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: clearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: notifPanel.dismissAll()
                }
            }
        }
    }
}
