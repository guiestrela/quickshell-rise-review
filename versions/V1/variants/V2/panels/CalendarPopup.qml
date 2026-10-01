import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../integrations/google-calendar/CalendarModel.js" as CalendarModel

PanelWindow {
    id: calPopup
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-calendar"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6
    property var calendarEvents: []
    property string calendarLoadError: ""
    property bool calendarLoading: false
    property string calendarSyncMessage: ""
    onCalendarSyncMessageChanged: if (calendarSyncMessage !== "") calendarMessageTimer.restart()
    property bool calendarPushArmed: false
    readonly property string calendarPullPath: String(Qt.resolvedUrl("../../../integrations/google-calendar/scripts/calendar-pull")).replace(/^file:\/\//, "")
    readonly property string calendarPushPath: String(Qt.resolvedUrl("../../../integrations/google-calendar/scripts/calendar-push")).replace(/^file:\/\//, "")
    readonly property string calendarEventsPath: String(Qt.resolvedUrl("../../../integrations/google-calendar/scripts/calendar-events")).replace(/^file:\/\//, "")
    property bool editingEvent: false
    property string eventTitle: ""
    property string eventDescription: ""
    property string eventRepeat: "none"
    property string eventRepeatCount: ""
    property var deleteCandidate: null
    readonly property string calendarCreatePath: String(Qt.resolvedUrl("../../../integrations/google-calendar/scripts/calendar-create")).replace(/^file:\/\//, "")
    readonly property string calendarMutatePath: String(Qt.resolvedUrl("../../../integrations/google-calendar/scripts/calendar-mutate")).replace(/^file:\/\//, "")
    readonly property string calendarSetupPath: String(Qt.resolvedUrl("../../../integrations/google-calendar/setup")).replace(/^file:\/\//, "")

    function dateKey(date) {
        return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0") + "-" + String(date.getDate()).padStart(2, "0")
    }
    readonly property string agendaDateKey: {
        var now = new Date()
        var target = new Date(now.getFullYear(), now.getMonth() + root.calendarMonthOffset,
                              root.selectedDay || now.getDate())
        return dateKey(target)
    }
    readonly property var agendaEvents: CalendarModel.eventsForDate(calendarEvents, agendaDateKey)

    function hasEventOnDay(day) {
        if (!day) return false
        var now = new Date()
        var target = new Date(now.getFullYear(), now.getMonth() + root.calendarMonthOffset, day)
        return CalendarModel.eventsForDate(calendarEvents, dateKey(target)).length > 0
    }

    function refreshCalendarEvents() {
        var now = new Date()
        var month = new Date(now.getFullYear(), now.getMonth() + root.calendarMonthOffset, 1)
        var end = new Date(month.getFullYear(), month.getMonth() + 1, 0)
        calendarEventsProc.command = [calendarEventsPath, dateKey(month), dateKey(end)]
        calendarLoading = true
        calendarEventsProc.running = false
        calendarEventsProc.running = true
    }

    function pullGoogleCalendar() {
        var now = new Date()
        var month = new Date(now.getFullYear(), now.getMonth() + root.calendarMonthOffset, 1)
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

    function startEventCreation() { editingEvent = true; eventTitle = ""; eventDescription = ""; eventRepeat = "none"; eventRepeatCount = ""; Qt.callLater(function() { eventTitleInput.forceActiveFocus() }) }
    function saveEvent() {
        var title = String(eventTitle || "").trim()
        if (title === "" || calendarCreateProc.running) return
        calendarCreateProc.command = [calendarCreatePath, title, agendaDateKey, "", eventRepeat, eventRepeat === "none" ? "" : eventRepeatCount, eventDescription]
        calendarCreateProc.running = true
    }
    function connectGoogleCalendar() { calendarSyncMessage = "Opening Google Calendar setup..."; calendarSetupProc.running = false; calendarSetupProc.running = true }
    function deleteEvent(event) { if (!event || !event.uid || !event.instance_id) return; if (!deleteCandidate || deleteCandidate.instance_id !== event.instance_id) { deleteCandidate = event; calendarSyncMessage = "Press DEL again to delete this event."; return } var uid = String(event.uid), instance = String(event.instance_id), scope = instance.indexOf(uid + "__") === 0 ? "instance" : "series"; calendarMutateProc.command = [calendarMutatePath, "delete", scope, String(event.calendar || "default"), uid, instance, "--confirm"]; calendarMutateProc.running = true; deleteCandidate = null }



    property real reveal: root.calendarVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.calendarVisible ? 160 : 120
            easing.type: root.calendarVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.calendarVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.calendarVisible = false
    }

    Rectangle {
        id: card
        width: 280
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: calPopup.root
            ownerActive: calPopup.root.calendarVisible
            targetX: calPopup.root.calendarBarX
            reveal: calPopup.reveal
        }

        x: Math.round((parent.width - width) / 2)
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - calPopup.reveal)
            : (barBottom + gap) - 2 * (1 - calPopup.reveal)
        opacity: calPopup.reveal
        focus: root.calendarVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.calendarVisible = false;
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
                    width: 24; height: 24; radius: root.panelButtonRadius
                    color: "transparent"
                    UiText {
                        anchors.centerIn: parent
                        text: "‹"   // ‹
                        color: prevMa.containsMouse ? root.seal : root.sumi
                        font.family: root.mono; font.pixelSize: 16
                    }
                    MouseArea {
                        id: prevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.calendarMonthOffset--
                    }
                }

                // month + year — click to jump back to today
                UiText {
                    anchors.centerIn: parent
                    text: root.calendarMonthName + "  " + root.calendarYear
                    color: monthMa.containsMouse && root.calendarMonthOffset !== 0 ? root.seal : root.ink
                    font.family: root.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                    MouseArea {
                        id: monthMa
                        anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: root.calendarMonthOffset !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.calendarMonthOffset = 0
                    }
                }

                // › next month
                Rectangle {
                    id: nextBtn
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: root.panelButtonRadius
                    color: "transparent"
                    UiText {
                        anchors.centerIn: parent
                        text: "›"   // ›
                        color: nextMa.containsMouse ? root.seal : root.sumi
                        font.family: root.mono; font.pixelSize: 16
                    }
                    MouseArea {
                        id: nextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.calendarMonthOffset++
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── weekday headers ──
            Row {
                width: parent.width
                Repeater {
                    model: ["MO","TU","WE","TH","FR","SA","SU"]
                    delegate: Item {
                        required property string modelData
                        required property int index
                        width: parent.width / 7
                        height: 20
                        UiText {
                            anchors.centerIn: parent
                            text: modelData
                            color: index >= 5 ? root.seal : root.inkDeep
                            opacity: index >= 5 ? 0.85 : 0.7
                            font.family: root.mono
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
                    model: root.calendarCells
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: parent.width / 7
                        height: 28

                        readonly property int dayOfWeek: index % 7
                        readonly property bool isCurrentMonth: modelData.day !== 0
                        readonly property bool isToday: modelData.today
                        readonly property bool isSelected: isCurrentMonth && root.selectedDay === modelData.day && root.calendarMonthOffset === 0

                        readonly property color textColor: {
                            if (isToday) return root.seal.hsvValue < 0.5 ? root.ink : root.paper;
                            if (!isCurrentMonth) return root.inkDeep;
                            return dayOfWeek >= 5 ? root.seal : root.ink;
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            color: root.seal
                            visible: isToday
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            border.color: root.seal; border.width: 1
                            color: "transparent"
                            visible: isSelected && !isToday
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1
                            width: 4; height: 4; radius: 2
                            color: isToday ? root.paper : root.seal
                            visible: isCurrentMonth && calPopup.hasEventOnDay(modelData.day)
                        }

                        UiText {
                            anchors.centerIn: parent
                            text: modelData.day === 0 ? "" : modelData.day
                            color: textColor
                            opacity: isCurrentMonth ? 1.0 : 0.35
                            font.family: root.mono
                            font.pixelSize: 12
                            font.weight: isToday ? Font.Medium : Font.Light
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: isCurrentMonth
                            enabled: isCurrentMonth
                            cursorShape: isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.selectedDay = modelData.day
                        }
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: root.sep }

            Row {
                width: parent.width
                height: 18
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "AGENDA · " + calPopup.agendaDateKey
                    color: root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 0.5
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: calPopup.calendarLoading ? "…" : "↻"
                    color: refreshAgendaMouse.containsMouse ? root.seal : root.sumi
                    font.family: root.mono
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
                        required property var modelData
                        width: parent.width
                        height: 18
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3; height: 12; radius: 2
                            color: CalendarModel.calendarColor(modelData) || root.seal
                        }
                        UiText {
                            width: 46
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.all_day ? "ALL DAY" : String(modelData.start || "").slice(11, 16)
                            color: root.seal
                            font.family: root.mono
                            font.pixelSize: 8
                        }
                        UiText {
                            width: parent.width - 88
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: String(modelData.title || "Untitled event")
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            width: 22; height: 18; radius: root.tileRadius
                            color: deleteMouse.containsMouse ? root.fillHover : root.fillIdle
                            border.color: deleteMouse.containsMouse ? root.seal : root.sep; border.width: 1
                            UiText { anchors.centerIn: parent; text: "DEL"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 7 }
                            MouseArea { id: deleteMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calPopup.deleteEvent(modelData) }
                        }
                    }
                }
                UiText {
                    width: parent.width
                    visible: !calPopup.calendarLoading && calPopup.agendaEvents.length === 0
                    text: calPopup.calendarLoadError || "No events for this day"
                    color: calPopup.calendarLoadError ? root.sumi : root.inkDeep
                    font.family: root.mono
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }
            Row {
                width: parent.width; height: 24
                Rectangle {
                    width: parent.width; height: 24; radius: root.tileRadius
                    color: newEventMouse.containsMouse ? root.fillHover : root.fillIdle
                    border.color: newEventMouse.containsMouse ? root.seal : root.sep; border.width: 1
                    UiText { anchors.centerIn: parent; text: calPopup.editingEvent ? "CANCEL EVENT" : "+ NEW EVENT"; color: root.seal; font.family: root.mono; font.pixelSize: 8 }
                    MouseArea { id: newEventMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calPopup.editingEvent ? calPopup.editingEvent = false : calPopup.startEventCreation() }
                }
            }
            Column {
                visible: calPopup.editingEvent; width: parent.width; spacing: 5
                TextInput { id: eventTitleInput; width: parent.width; height: 25; text: calPopup.eventTitle; onTextEdited: calPopup.eventTitle = text; color: root.ink; font.family: root.mono; font.pixelSize: 10; leftPadding: 7; Rectangle { z: -1; anchors.fill: parent; color: root.fillIdle; border.color: root.sep; border.width: 1; radius: root.tileRadius } }
                TextInput { width: parent.width; height: 30; text: calPopup.eventDescription; onTextEdited: calPopup.eventDescription = text; color: root.ink; font.family: root.mono; font.pixelSize: 9; leftPadding: 7; Rectangle { z: -1; anchors.fill: parent; color: root.fillIdle; border.color: root.sep; border.width: 1; radius: root.tileRadius } }
                Row {
                    width: parent.width
                    height: 22
                    spacing: 3
                    Repeater {
                        model: [{ v: "none", t: "ONCE" }, { v: "daily", t: "DAY" }, { v: "weekly", t: "WEEK" }, { v: "monthly", t: "MONTH" }, { v: "yearly", t: "YEAR" }]
                        delegate: Rectangle {
                            required property var modelData
                            width: (parent.width - 12) / 5
                            height: 22
                            radius: root.tileRadius
                            color: calPopup.eventRepeat === modelData.v ? root.fillActive : root.fillIdle
                            border.color: calPopup.eventRepeat === modelData.v ? root.seal : root.sep
                            border.width: 1
                            UiText { anchors.centerIn: parent; text: modelData.t; color: root.ink; font.family: root.mono; font.pixelSize: 7 }
                            MouseArea { anchors.fill: parent; onClicked: calPopup.eventRepeat = modelData.v }
                        }

                        Rectangle {
                            width: parent.width; height: 24; radius: root.tileRadius
                            color: connectGoogleMouse.containsMouse ? root.fillHover : root.fillIdle
                            border.color: connectGoogleMouse.containsMouse ? root.seal : root.sep; border.width: 1
                            UiText { anchors.centerIn: parent; text: "CONNECT GOOGLE"; color: root.seal; font.family: root.mono; font.pixelSize: 8 }
                            MouseArea { id: connectGoogleMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calPopup.connectGoogleCalendar() }
                        }
                    }
                }
                TextInput { visible: calPopup.eventRepeat !== "none"; width: parent.width; height: 23; text: calPopup.eventRepeatCount; onTextEdited: calPopup.eventRepeatCount = text; color: root.ink; font.family: root.mono; font.pixelSize: 9; leftPadding: 7; Rectangle { z: -1; anchors.fill: parent; color: root.fillIdle; border.color: root.sep; border.width: 1; radius: root.tileRadius } }
                Rectangle {
                    width: parent.width; height: 25; radius: root.tileRadius; color: root.seal
                    UiText { anchors.centerIn: parent; text: calendarCreateProc.running ? "SAVING..." : "SAVE EVENT"; color: root.paper; font.family: root.mono; font.pixelSize: 8 }
                    MouseArea { anchors.fill: parent; enabled: !calendarCreateProc.running; onClicked: calPopup.saveEvent() }
                }
            }
            Rectangle {
                width: parent.width; height: 24; radius: root.tileRadius
                color: connectGoogleOutside.containsMouse ? root.fillHover : root.fillIdle
                border.color: connectGoogleOutside.containsMouse ? root.seal : root.sep; border.width: 1
                UiText { anchors.centerIn: parent; text: "CONNECT GOOGLE"; color: root.seal; font.family: root.mono; font.pixelSize: 8 }
                MouseArea { id: connectGoogleOutside; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calPopup.connectGoogleCalendar() }
            }
            Row {
                width: parent.width
                height: 24
                spacing: 6
                Repeater {
                    model: ["PULL GOOGLE", calPopup.calendarPushArmed ? "CONFIRM PUSH" : "PUSH GOOGLE"]
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        width: (parent.width - parent.spacing) / 2
                        height: 24
                        radius: root.tileRadius
                        color: actionMouse.containsMouse ? root.fillHover : root.fillIdle
                        border.color: actionMouse.containsMouse ? root.seal : root.sep
                        border.width: 1
                        UiText {
                            anchors.centerIn: parent
                            text: calPopup.calendarLoading || calendarActionProc.running ? "WAIT…" : modelData
                            color: index === 1 && calPopup.calendarPushArmed ? root.color01 : root.seal
                            font.family: root.mono
                            font.pixelSize: 8
                        }
                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !calendarActionProc.running && !calPopup.calendarLoading
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: index === 0 ? calPopup.pullGoogleCalendar() : calPopup.pushGoogleCalendar()
                        }
                    }
                }
            }

            UiText {
                width: parent.width
                visible: calPopup.calendarSyncMessage !== ""
                text: calPopup.calendarSyncMessage
                color: calPopup.calendarSyncMessage.indexOf("failed") >= 0 ? root.color01 : root.sumi
                font.family: root.mono
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
                    var data = JSON.parse(String(this.text || "{}"))
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
        property string output: ""
        command: ["true"]
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                var error = String(this.text || "").trim()
                if (error) calendarMutateProc.output = error
            }
        }
        onExited: function(code) {
            calPopup.calendarSyncMessage = code === 0 ? "Event deleted" : (calendarMutateProc.output || "Could not delete event")
            calendarMutateProc.output = ""
            if (code === 0) calPopup.refreshCalendarEvents()
        }
    }
    Process {
        id: calendarSetupProc
        command: ["bash", "-c", "omarchy-launch-floating-terminal-with-presentation " + calPopup.calendarSetupPath]
        running: false
    }
    Timer { id: calendarPushConfirmTimer; interval: 5000; onTriggered: calPopup.calendarPushArmed = false }
    Timer { id: calendarMessageTimer; interval: 4000; repeat: false; onTriggered: calPopup.calendarSyncMessage = "" }


    onVisibleChanged: if (visible) refreshCalendarEvents()
    Connections {
        target: root
        function onCalendarMonthOffsetChanged() { if (calPopup.visible) calPopup.refreshCalendarEvents() }
    }
}
