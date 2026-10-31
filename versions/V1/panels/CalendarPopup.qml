pragma ComponentBehavior: Bound
import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../integrations/google-calendar/CalendarModel.js" as CalendarModel

PanelWindow {
    id: calPopup
    required property var root

    screen: calPopup.root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-calendar"

    readonly property int barBottom: 35
    readonly property int gap: 8
    property var calendarEvents: []
    property string calendarLoadError: ""
    property bool calendarLoading: false
    property string calendarSyncMessage: ""
    onCalendarSyncMessageChanged: if (calendarSyncMessage !== "") calendarMessageTimer.restart()
    property bool calendarPushArmed: false
    readonly property string calendarPullPath: String(Qt.resolvedUrl("../integrations/google-calendar/scripts/calendar-pull")).replace(/^file:\/\//, "")
    readonly property string calendarPushPath: String(Qt.resolvedUrl("../integrations/google-calendar/scripts/calendar-push")).replace(/^file:\/\//, "")
    readonly property string calendarEventsPath: String(Qt.resolvedUrl("../integrations/google-calendar/scripts/calendar-events")).replace(/^file:\/\//, "")
    property bool editingEvent: false
    property string eventTitle: ""
    property string eventDescription: ""
    property string eventRepeat: "none"
    property string eventRepeatCount: ""
    property var deleteCandidate: null
    readonly property string calendarCreatePath: String(Qt.resolvedUrl("../integrations/google-calendar/scripts/calendar-create")).replace(/^file:\/\//, "")
    readonly property string calendarMutatePath: String(Qt.resolvedUrl("../integrations/google-calendar/scripts/calendar-mutate")).replace(/^file:\/\//, "")
    readonly property string calendarSetupPath: String(Qt.resolvedUrl("../integrations/google-calendar/setup")).replace(/^file:\/\//, "")
    readonly property string calendarAuthModePath: String(Qt.resolvedUrl("../integrations/google-calendar/scripts/calendar-auth-mode")).replace(/^file:\/\//, "")
    readonly property string calendarRuntimeCheckPath: String(Qt.resolvedUrl("../integrations/google-calendar/scripts/calendar-runtime-check")).replace(/^file:\/\//, "")
    property bool calendarRuntimeReady: false
    property bool calendarSessionReady: false
    readonly property bool calendarConnected: calendarRuntimeReady && calendarSessionReady
    property string calendarSetupMode: "direct"
    property string calendarSetupError: ""

    function dateKey(date) {
        return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0") + "-" + String(date.getDate()).padStart(2, "0")
    }
    readonly property string agendaDateKey: {
        var now = new Date()
        var target = new Date(now.getFullYear(), now.getMonth() + calPopup.root.calendarMonthOffset,
                              calPopup.root.selectedDay || now.getDate())
        return dateKey(target)
    }
    readonly property var agendaEvents: CalendarModel.eventsForDate(calendarEvents, agendaDateKey)

    function hasEventOnDay(day) {
        if (!day) return false
        var now = new Date()
        var target = new Date(now.getFullYear(), now.getMonth() + calPopup.root.calendarMonthOffset, day)
        return CalendarModel.eventsForDate(calendarEvents, dateKey(target)).length > 0
    }

    function refreshCalendarEvents() {
        var now = new Date()
        var month = new Date(now.getFullYear(), now.getMonth() + calPopup.root.calendarMonthOffset, 1)
        var end = new Date(month.getFullYear(), month.getMonth() + 1, 0)
        calendarEventsProc.command = [calendarEventsPath, dateKey(month), dateKey(end)]
        calendarLoading = true
        calendarEventsProc.running = false
        calendarEventsProc.running = true
    }

    function pullGoogleCalendar() {
        var now = new Date()
        var month = new Date(now.getFullYear(), now.getMonth() + calPopup.root.calendarMonthOffset, 1)
        var end = new Date(month.getFullYear(), month.getMonth() + 1, 0)
        calendarSyncMessage = "Pulling updates from Google…"
        calendarActionProc.command = [calendarPullPath, dateKey(month), dateKey(end)]
        calendarActionProc.running = true
    }

    function pushGoogleCalendar() {
        if (!calendarPushArmed) {
            calendarPushArmed = true
            calendarSyncMessage = "Press push again within 5 seconds to send local changes."
            calendarPushConfirmTimer.restart()
            return
        }
        calendarPushArmed = false
        calendarPushConfirmTimer.stop()
        calendarSyncMessage = "Sending local changes to Google…"
        calendarActionProc.command = [calendarPushPath, "--confirm"]
        calendarActionProc.running = true
    }

    function startEventCreation() {
        editingEvent = true; eventTitle = ""; eventDescription = ""; eventRepeat = "none"; eventRepeatCount = ""
        Qt.callLater(function() { eventTitleInput.forceActiveFocus() })
    }
    function saveEvent() {
        var title = String(eventTitle || "").trim()
        if (title === "" || calendarCreateProc.running) return
        calendarCreateProc.command = [calendarCreatePath, title, agendaDateKey, "", eventRepeat, eventRepeat === "none" ? "" : eventRepeatCount, eventDescription]
        calendarCreateProc.running = true
    }
    function refreshGoogleState() {
        calendarAuthProc.running = false
        calendarAuthProc.running = true
        calendarRuntimeProc.running = false
        calendarRuntimeProc.running = true
    }
    function connectGoogleCalendar(mode) {
        calendarSetupError = ""
        calendarSetupMode = mode === "hosted" ? "hosted" : "direct"
        calendarSyncMessage = "Checking Google Calendar setup..."
        calendarSetupProc.command = [calendarSetupPath, "--check"]
        calendarSetupProc.running = false
        calendarSetupProc.running = true
    }
    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'"
    }
    function calendarTerminalCommand(args) {
        var inner = args.map(shellQuote).join(" ")
        return ["bash", "-c", "omarchy-launch-floating-terminal-with-presentation " + shellQuote(inner)]
    }
    function launchCalendarSetup() {
        var args = calendarRuntimeReady
            ? [calendarAuthModePath, "switch", calendarSetupMode]
            : [calendarSetupPath]
        if (!calendarRuntimeReady && calendarSetupMode === "hosted") args.push("--hosted")
        calendarTerminalProc.command = calendarTerminalCommand(args)
        calendarTerminalProc.running = false
        calendarTerminalProc.running = true
    }
    function deleteEvent(event) {
        if (!event || !event.uid || !event.instance_id) return
        if (!deleteCandidate || deleteCandidate.instance_id !== event.instance_id) {
            deleteCandidate = event
            calendarSyncMessage = "Press DEL again to delete this event."
            return
        }
        var uid = String(event.uid), instance = String(event.instance_id)
        var scope = instance.indexOf(uid + "__") === 0 ? "instance" : "series"
        calendarMutateProc.command = [calendarMutatePath, "delete", scope, String(event.calendar || "default"), uid, instance, "--confirm"]
        calendarMutateProc.running = true
        deleteCandidate = null
    }

    property real reveal: calPopup.root.calendarVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: calPopup.root.calendarVisible ? 160 : 120
            easing.type: calPopup.root.calendarVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: calPopup.root.calendarVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: calPopup.root.calendarVisible = false
    }

    Rectangle {
        id: card
        width: 280
        height: col.implicitHeight + 24
        radius: calPopup.reveal > 0.001 ? calPopup.root.pillRadius : 0
        color: calPopup.root.bg
        border.color: calPopup.root.pillBorder
        border.width: calPopup.root.pillBorderW
        PillShadow { theme: calPopup.root }

        x: Math.round((parent.width - width) / 2)
        y: calPopup.root.barPosition === "bottom" ? (parent.height - calPopup.barBottom - calPopup.gap - height) : (calPopup.barBottom + calPopup.gap)
        opacity: calPopup.reveal
        focus: calPopup.root.calendarVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                calPopup.root.calendarVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // ── header: month name + navigation chevrons ──
            Item {
                width: parent.width
                height: 24

                // ‹ previous month
                Rectangle {
                    id: prevBtn
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: calPopup.root.tileRadius
                    color: "transparent"
                    UiText {
                        anchors.centerIn: parent
                        text: "‹"   // ‹
                        color: prevMa.containsMouse ? calPopup.root.seal : calPopup.root.sumi
                        font.family: calPopup.root.mono; font.pixelSize: 16
                    }
                    MouseArea {
                        id: prevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calPopup.root.calendarMonthOffset--
                    }
                }

                // month + year — click to jump back to today
                UiText {
                    anchors.centerIn: parent
                    text: calPopup.root.calendarMonthName + "  " + calPopup.root.calendarYear
                    color: monthMa.containsMouse && calPopup.root.calendarMonthOffset !== 0 ? calPopup.root.seal : calPopup.root.ink
                    font.family: calPopup.root.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                    MouseArea {
                        id: monthMa
                        anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: calPopup.root.calendarMonthOffset !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: calPopup.root.calendarMonthOffset = 0
                    }
                }

                // › next month
                Rectangle {
                    id: nextBtn
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: calPopup.root.tileRadius
                    color: "transparent"
                    UiText {
                        anchors.centerIn: parent
                        text: "›"   // ›
                        color: nextMa.containsMouse ? calPopup.root.seal : calPopup.root.sumi
                        font.family: calPopup.root.mono; font.pixelSize: 16
                    }
                    MouseArea {
                        id: nextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calPopup.root.calendarMonthOffset++
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: calPopup.root.sep }

            // ── weekday headers ──
            Row {
                width: parent.width
                Repeater {
                    model: ["MO","TU","WE","TH","FR","SA","SU"]
                    delegate: Item {
                        id: weekdayCell
                        required property string modelData
                        required property int index
                        width: parent.width / 7
                        height: 20
                        UiText {
                            anchors.centerIn: parent
                            text: weekdayCell.modelData
                            color: weekdayCell.index >= 5 ? calPopup.root.seal : calPopup.root.inkDeep
                            opacity: weekdayCell.index >= 5 ? 0.85 : 0.7
                            font.family: calPopup.root.mono
                            font.pixelSize: 10
                            font.letterSpacing: 2
                        }
                    }
                }
            }

            // ── day grid ──
            Grid {
                columns: 7
                rowSpacing: 2
                columnSpacing: 0
                width: parent.width
                Repeater {
                    model: calPopup.root.calendarCells
                    delegate: Item {
                        id: dayCell
                        required property var modelData
                        required property int index
                        width: parent.width / 7
                        height: 28

                        readonly property int dayOfWeek: index % 7
                        readonly property bool isCurrentMonth: modelData.day !== 0
                        readonly property bool isToday: modelData.today
                        readonly property bool isSelected: isCurrentMonth && calPopup.root.selectedDay === modelData.day && calPopup.root.calendarMonthOffset === 0

                        readonly property color textColor: {
                            if (isToday) return calPopup.root.seal.hsvValue < 0.5 ? calPopup.root.ink : calPopup.root.paper;
                            if (!isCurrentMonth) return calPopup.root.inkDeep;
                            return dayOfWeek >= 5 ? calPopup.root.seal : calPopup.root.ink;
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            color: calPopup.root.seal
                            visible: dayCell.isToday
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            border.color: calPopup.root.seal; border.width: 1
                            color: "transparent"
                            visible: dayCell.isSelected && !dayCell.isToday
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1
                            width: 4; height: 4; radius: 2
                            color: dayCell.isToday ? calPopup.root.paper : calPopup.root.seal
                            visible: dayCell.isCurrentMonth && calPopup.hasEventOnDay(dayCell.modelData.day)
                        }

                        UiText {
                            anchors.centerIn: parent
                            text: dayCell.modelData.day === 0 ? "" : dayCell.modelData.day
                            color: dayCell.textColor
                            opacity: dayCell.isCurrentMonth ? 1.0 : 0.35
                            font.family: calPopup.root.mono
                            font.pixelSize: 12
                            font.weight: dayCell.isToday ? Font.Medium : Font.Light
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: dayCell.isCurrentMonth
                            enabled: dayCell.isCurrentMonth
                            cursorShape: dayCell.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: calPopup.root.selectedDay = dayCell.modelData.day
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: calPopup.root.sep }

            Item {
                width: parent.width
                height: 18
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "AGENDA · " + calPopup.agendaDateKey
                    color: calPopup.root.sumiHi
                    font.family: calPopup.root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 0.5
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: calPopup.calendarLoading ? "…" : "↻"
                    color: refreshAgendaMouse.containsMouse ? calPopup.root.seal : calPopup.root.sumi
                    font.family: calPopup.root.mono
                    font.pixelSize: 12
                    MouseArea {
                        id: refreshAgendaMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calPopup.refreshCalendarEvents()
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 4
                Repeater {
                    model: calPopup.agendaEvents.slice(0, 4)
                    delegate: Row {
                        id: agendaRow
                        required property var modelData
                        width: parent.width
                        height: 18
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3; height: 12; radius: 2
                            color: CalendarModel.calendarColor(agendaRow.modelData) || calPopup.root.seal
                        }
                        UiText {
                            width: 46
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: agendaRow.modelData.all_day ? "ALL DAY" : String(agendaRow.modelData.start || "").slice(11, 16)
                            color: calPopup.root.seal
                            font.family: calPopup.root.mono
                            font.pixelSize: 8
                        }
                        UiText {
                            width: parent.width - 88
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: String(agendaRow.modelData.title || "Untitled event")
                            color: calPopup.root.ink
                            font.family: calPopup.root.mono
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            width: 22; height: 18; radius: calPopup.root.tileRadius
                            color: deleteMouse.containsMouse ? calPopup.root.fillHover : calPopup.root.fillIdle
                            border.color: deleteMouse.containsMouse ? calPopup.root.seal : calPopup.root.sep; border.width: 1
                            UiText { anchors.centerIn: parent; text: "DEL"; color: calPopup.root.sumiHi; font.family: calPopup.root.mono; font.pixelSize: 7 }
                            MouseArea { id: deleteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calPopup.deleteEvent(agendaRow.modelData) }
                        }
                    }
                }
                UiText {
                    width: parent.width
                    visible: !calPopup.calendarLoading && calPopup.agendaEvents.length === 0
                    text: calPopup.calendarLoadError || "No events for this day"
                    color: calPopup.calendarLoadError ? calPopup.root.sumi : calPopup.root.inkDeep
                    font.family: calPopup.root.mono
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }

            Row {
                width: parent.width; height: 24
                Rectangle { width: parent.width; height: 24; radius: calPopup.root.tileRadius; color: newEventMouse.containsMouse ? calPopup.root.fillHover : calPopup.root.fillIdle; border.color: newEventMouse.containsMouse ? calPopup.root.seal : calPopup.root.sep; border.width: 1
                    UiText { anchors.centerIn: parent; text: calPopup.editingEvent ? "CANCEL EVENT" : "+ NEW EVENT"; color: calPopup.root.seal; font.family: calPopup.root.mono; font.pixelSize: 8 }
                    MouseArea { id: newEventMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calPopup.editingEvent ? calPopup.editingEvent = false : calPopup.startEventCreation() }
                }
            }
            Column {
                visible: calPopup.editingEvent; width: parent.width; spacing: 5
                TextInput { id: eventTitleInput; width: parent.width; height: 25; text: calPopup.eventTitle; onTextEdited: calPopup.eventTitle = text; color: calPopup.root.ink; font.family: calPopup.root.mono; font.pixelSize: 10; leftPadding: 7 }
                TextInput { width: parent.width; height: 30; text: calPopup.eventDescription; onTextEdited: calPopup.eventDescription = text; color: calPopup.root.ink; font.family: calPopup.root.mono; font.pixelSize: 9; leftPadding: 7 }
                Row {
                    width: parent.width
                    height: 22
                    spacing: 3
                    Repeater {
                        model: [{ v: "none", t: "ONCE" }, { v: "daily", t: "DAY" }, { v: "weekly", t: "WEEK" }, { v: "monthly", t: "MONTH" }, { v: "yearly", t: "YEAR" }]
                        delegate: Rectangle {
                            id: repeatOption
                            required property var modelData
                            width: (parent.width - 12) / 5
                            height: 22
                            radius: calPopup.root.tileRadius
                            color: calPopup.eventRepeat === modelData.v ? calPopup.root.fillActive : calPopup.root.fillIdle
                            border.color: calPopup.eventRepeat === modelData.v ? calPopup.root.seal : calPopup.root.sep
                            border.width: 1
                            UiText { anchors.centerIn: parent; text: repeatOption.modelData.t; color: calPopup.root.ink; font.family: calPopup.root.mono; font.pixelSize: 7 }
                            MouseArea { anchors.fill: parent; onClicked: calPopup.eventRepeat = repeatOption.modelData.v }
                        }
                    }
                }
                TextInput { visible: calPopup.eventRepeat !== "none"; width: parent.width; height: 23; text: calPopup.eventRepeatCount; onTextEdited: calPopup.eventRepeatCount = text; color: calPopup.root.ink; font.family: calPopup.root.mono; font.pixelSize: 9; leftPadding: 7; Rectangle { z: -1; anchors.fill: parent; color: calPopup.root.fillIdle; border.color: calPopup.root.sep; border.width: 1; radius: calPopup.root.tileRadius } }
                Rectangle { width: parent.width; height: 25; radius: calPopup.root.tileRadius; color: calPopup.root.seal
                    UiText { anchors.centerIn: parent; text: calendarCreateProc.running ? "SAVING..." : "SAVE EVENT"; color: calPopup.root.paper; font.family: calPopup.root.mono; font.pixelSize: 8 }
                    MouseArea { anchors.fill: parent; enabled: !calendarCreateProc.running; onClicked: calPopup.saveEvent() }
                }
            }
            UiText {
                width: parent.width
                visible: !calPopup.calendarConnected
                text: "Google sync needs setup. Direct uses your own Google Cloud client and keeps refreshes between this machine and Google; Hosted needs no client but relays sign-in and refreshes through caldir.org."
                color: calPopup.root.sumi
                font.family: calPopup.root.mono
                font.pixelSize: 7
                wrapMode: Text.Wrap
            }
            Row {
                id: calendarSetupModeRow
                visible: !calPopup.calendarConnected
                width: parent.width
                height: 24
                spacing: 6
                Repeater {
                    model: [{ v: "direct", t: "GOOGLE DIRECT" }, { v: "hosted", t: "GOOGLE HOSTED" }]
                    delegate: Rectangle {
                        id: setupModeOption
                        required property var modelData
                        width: (calendarSetupModeRow.width - calendarSetupModeRow.spacing) / 2
                        height: 24
                        radius: calPopup.root.tileRadius
                        color: setupModeMouse.containsMouse ? calPopup.root.fillHover : calPopup.root.fillIdle
                        border.color: setupModeMouse.containsMouse ? calPopup.root.seal : calPopup.root.sep
                        border.width: 1
                        UiText { anchors.centerIn: parent; text: setupModeOption.modelData.t; color: calPopup.root.seal; font.family: calPopup.root.mono; font.pixelSize: 8 }
                        MouseArea {
                            id: setupModeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calPopup.connectGoogleCalendar(setupModeOption.modelData.v)
                        }
                    }
                }
            }
            Row {
                id: calendarSyncActionsRow
                width: parent.width
                height: 24
                spacing: 6
                Repeater {
                    model: ["PULL GOOGLE", calPopup.calendarPushArmed ? "CONFIRM PUSH" : "PUSH GOOGLE"]
                    delegate: Rectangle {
                        id: syncActionOption
                        required property string modelData
                        required property int index
                        width: (calendarSyncActionsRow.width - calendarSyncActionsRow.spacing) / 2
                        height: 24
                        radius: calPopup.root.tileRadius
                        color: actionMouse.containsMouse ? calPopup.root.fillHover : calPopup.root.fillIdle
                        border.color: actionMouse.containsMouse ? calPopup.root.seal : calPopup.root.sep
                        border.width: 1
                        UiText {
                            anchors.centerIn: parent
                            text: calPopup.calendarLoading || calendarActionProc.running ? "WAIT…" : syncActionOption.modelData
                            color: syncActionOption.index === 1 && calPopup.calendarPushArmed ? calPopup.root.color01 : calPopup.root.seal
                            font.family: calPopup.root.mono
                            font.pixelSize: 8
                        }
                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !calendarActionProc.running && !calPopup.calendarLoading
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: syncActionOption.index === 0 ? calPopup.pullGoogleCalendar() : calPopup.pushGoogleCalendar()
                        }
                    }
                }
            }

            UiText {
                width: parent.width
                visible: calPopup.calendarSyncMessage !== ""
                text: calPopup.calendarSyncMessage
                color: calPopup.calendarSyncMessage.indexOf("failed") >= 0 ? calPopup.root.color01 : calPopup.root.sumi
                font.family: calPopup.root.mono
                font.pixelSize: 8
                wrapMode: Text.Wrap
            }
        }
    }

    Process {
        id: calendarEventsProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(String(this.text || "{}"))
                    if (data.ok === true && Array.isArray(data.events)) {
                        calPopup.calendarEvents = data.events
                        calPopup.calendarLoadError = ""
                    } else {
                        calPopup.calendarEvents = []
                        calPopup.calendarLoadError = String(data.error || "Calendar data is unavailable")
                    }
                } catch (e) {
                    calPopup.calendarEvents = []
                    calPopup.calendarLoadError = "Calendar data is unavailable"
                }
                calPopup.calendarLoading = false
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && calPopup.calendarLoading) {
                calPopup.calendarLoadError = "Calendar bridge unavailable"
                calPopup.calendarLoading = false
            }
        }
    }

    Process {
        id: calendarActionProc
        command: ["true"]
        running: false
        property string output: ""
        stdout: StdioCollector { onStreamFinished: calendarActionProc.output = String(this.text || "").trim() }
        stderr: StdioCollector {
            onStreamFinished: {
                var error = String(this.text || "").trim()
                if (error) calendarActionProc.output = error
            }
        }
        onExited: function(exitCode) {
            calPopup.calendarSyncMessage = exitCode === 0
                ? (calendarActionProc.output || "Google calendar updated")
                : (calendarActionProc.output || "Google calendar action failed")
            if (exitCode === 0) calPopup.refreshCalendarEvents()
            else calPopup.refreshGoogleState()
        }
    }
    Process {
        id: calendarCreateProc
        command: ["true"]
        running: false
        stdout: StdioCollector { onStreamFinished: calPopup.calendarSyncMessage = String(this.text || "").trim() }
        stderr: StdioCollector { onStreamFinished: { var error = String(this.text || "").trim(); if (error) calPopup.calendarSyncMessage = error } }
        onExited: function(code) {
            calPopup.editingEvent = false
            calPopup.calendarSyncMessage = code === 0 ? "Event saved" : (calPopup.calendarSyncMessage || "Could not save event")
            if (code === 0) calPopup.refreshCalendarEvents()
        }
    }
    Process {
        id: calendarMutateProc
        command: ["true"]
        running: false
        stderr: StdioCollector { onStreamFinished: { var error = String(this.text || "").trim(); if (error) calendarMutateProc.output = error } }
        property string output: ""
        onExited: function(code) {
            calPopup.calendarSyncMessage = code === 0 ? "Event deleted" : (calendarMutateProc.output || "Could not delete event")
            calendarMutateProc.output = ""
            if (code === 0) calPopup.refreshCalendarEvents()
        }
    }
    Process {
        id: calendarRuntimeProc
        command: [calPopup.calendarRuntimeCheckPath]
        running: false
        onExited: function(exitCode) { calPopup.calendarRuntimeReady = exitCode === 0 }
    }
    Process {
        id: calendarAuthProc
        command: [calPopup.calendarAuthModePath, "status", "--json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var state = {}
                try { state = JSON.parse(String(this.text || "{}")) } catch (e) { state = {} }
                var mode = String(state.mode || "")
                calPopup.calendarSessionReady = String(state.session || "") !== "" && (mode === "direct" || mode === "hosted")
            }
        }
        onExited: function(exitCode) { if (exitCode !== 0) calPopup.calendarSessionReady = false }
    }
    Process {
        id: calendarSetupProc
        command: [calPopup.calendarSetupPath, "--check"]
        running: false
        stdout: StdioCollector { onStreamFinished: calPopup.calendarSetupError = String(this.text || "").trim() }
        stderr: StdioCollector {
            onStreamFinished: {
                var error = String(this.text || "").trim()
                if (error) calPopup.calendarSetupError = error
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                calPopup.calendarSyncMessage = calPopup.calendarSetupError || "Google Calendar setup is unavailable"
                calPopup.calendarSetupError = ""
                return
            }
            calPopup.calendarSetupError = ""
            // An installed runtime only needs the mode switched, which the
            // bundled helper does without re-downloading the Caldir runtime.
            calPopup.calendarSyncMessage = calPopup.calendarRuntimeReady
                ? "Switching Google OAuth mode..."
                : "Opening Google Calendar setup..."
            calPopup.root.calendarVisible = false
            calPopup.launchCalendarSetup()
        }
    }
    Process {
        id: calendarTerminalProc
        command: ["true"]
        running: false
    }
    Timer { id: calendarPushConfirmTimer; interval: 5000; onTriggered: calPopup.calendarPushArmed = false }
    Timer { id: calendarMessageTimer; interval: 6000; repeat: false; onTriggered: calPopup.calendarSyncMessage = "" }

    Component.onCompleted: refreshGoogleState()
    onVisibleChanged: if (visible) { refreshCalendarEvents(); refreshGoogleState() }
    Connections {
        target: calPopup.root
        function onCalendarMonthOffsetChanged() { if (calPopup.visible) calPopup.refreshCalendarEvents() }
    }
    SidePanelPositioner { root: calPopup.root; target: card; anchorName: "calendar" }
}
