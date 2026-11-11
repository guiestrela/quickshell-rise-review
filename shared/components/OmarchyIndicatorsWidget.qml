pragma ComponentBehavior: Bound
import QtQuick

// Rise presentation only: no processes, service instances, or per-output IPC.
Item {
    id: widget
    required property var root
    required property var coordinator
    required property color contentColor
    property bool revealInactive: false
    property bool vertical: false
    property real iconSpacing: 4
    readonly property bool hasActive: coordinator ? coordinator.hasActive : false
    readonly property bool revealed: revealInactive || hover.hovered
    readonly property var entries: [
        {id: "PasswordlessSudo", glyph: "󰟵", active: coordinator ? coordinator.passwordless : false,
            available: coordinator ? coordinator.available : false, label: "Passwordless sudo", activeLabel: "Disable passwordless sudo"},
        {id: "ScreenRecording", glyph: "󰻂", active: coordinator ? coordinator.recording : false,
            available: coordinator ? coordinator.available : false, label: "Screen recording", activeLabel: "Stop recording"},
        {id: "RemoteSession", glyph: "󰢹", active: coordinator ? coordinator.remote : false,
            available: false, label: "Remote session", activeLabel: coordinator && coordinator.remoteSession && coordinator.remoteSession.peers.length
                ? "Remote session: " + coordinator.remoteSession.peers.join(", ") : "Remote session"},
        {id: "Reminder", glyph: "󰢌", active: coordinator ? coordinator.reminderCount > 0 : false,
            available: coordinator ? coordinator.available : false, label: "Set a reminder", activeLabel: coordinator ? coordinator.reminderTooltip : "Reminders"},
        {id: "NightLight", glyph: "󰔎", active: coordinator ? coordinator.night : false,
            available: coordinator ? !!coordinator.nightlight : false, label: "Enable night light", activeLabel: "Disable night light"},
        {id: "Dnd", glyph: "󰂛", active: coordinator ? coordinator.silenced : false,
            available: coordinator ? !!coordinator.notifications : false, label: "Silence notifications", activeLabel: "Allow notifications"},
        {id: "StayAwake", glyph: "", active: coordinator ? coordinator.awake : false,
            available: coordinator ? !!coordinator.idle : false, label: "Stay awake", activeLabel: "Allow idle lock"}
    ]
    readonly property var displayedEntries: entries.filter(function(entry) { return entry.active })
        .concat(revealed ? entries.filter(function(entry) { return !entry.active && entry.available }) : [])
    readonly property int count: displayedEntries.length
    // Rise's existing tooltip host uses AutoText. Keep helper/peer text from
    // becoming markup there without changing other widgets' tooltip contracts.
    function plainTooltip(value) {
        return String(value).replace(/</g, "‹").replace(/>/g, "›")
    }
    // Derive size from the model, not Grid's deferred polish: a collapsed
    // ancestor must not prevent newly active icons from obtaining geometry.
    implicitWidth: count === 0 ? 0 : vertical ? 28 : count * 20 + (count - 1) * iconSpacing
    implicitHeight: vertical ? (count === 0 ? 0 : count * 24 + (count - 1) * iconSpacing) : 28
    visible: count > 0
    HoverHandler { id: hover }
    Grid {
        id: grid
        columns: widget.vertical ? 1 : 7
        spacing: widget.iconSpacing
        anchors.centerIn: parent
        Repeater {
            model: widget.displayedEntries
            Item {
                id: indicator
                required property var modelData
                readonly property bool active: modelData.active
                visible: active || (widget.revealed && modelData.available)
                width: 20
                height: 24
                UiText {
                    anchors.centerIn: parent
                    text: indicator.modelData.glyph
                    textFormat: Text.PlainText
                    font.family: widget.root.mono
                    font.pixelSize: 13
                    color: widget.contentColor
                    opacity: indicator.active ? 1 : 0.45
                }
                TooltipMixin {
                    id: tip
                    root: widget.root
                    owner: indicator
                    text: widget.plainTooltip(indicator.active ? indicator.modelData.activeLabel : indicator.modelData.label)
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: indicator.modelData.id === "RemoteSession" ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onEntered: tip.show()
                    onExited: tip.hide()
                    onClicked: {
                        tip.hide()
                        if (widget.coordinator) widget.coordinator.activate(indicator.modelData.id)
                    }
                }
            }
        }
    }
}
