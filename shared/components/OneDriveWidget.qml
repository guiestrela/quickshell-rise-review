pragma ComponentBehavior: Bound
import QtQuick
import "../integrations/onedrive" as OneDrive
import "../integrations/onedrive/Model.js" as Model

Item {
    id: widget
    required property var root
    required property color contentColor
    property real slotWidth: 28
    property real iconPixelSize: 14
    property bool showStatusBadge: true
    property Component backgroundComponent
    Loader {
        anchors.centerIn: parent
        width: parent.width
        height: widget.root.pillH
        sourceComponent: widget.backgroundComponent
    }
    readonly property var service: root.oneDriveService
    readonly property var aggregate: service.aggregate
    readonly property var barState: Model.barState(aggregate)
    readonly property string badgeKind: Model.badgeKind(aggregate.kind)
    implicitWidth: root.modOneDrive ? slotWidth : 0
    implicitHeight: 28
    visible: implicitWidth > 0
    UiText {
        anchors.centerIn: parent
        text: String.fromCodePoint(0xF0160)
        font.family: widget.root.mono
        font.pixelSize: widget.iconPixelSize
        color: widget.contentColor
        opacity: widget.barState.active ? 1 : 0.55
    }
    OneDrive.StatusBadge {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        visible: widget.showStatusBadge && widget.badgeKind !== ""
        badgeSize: 8
        glyph: Model.badgeGlyph(widget.badgeKind)
        glyphColor: widget.badgeKind === "login" || widget.badgeKind === "attention" ? "#e06c75" : widget.root.seal
        ringColor: glyphColor
        background: widget.root.bg
        fontFamily: widget.root.mono
        pulsing: widget.badgeKind === "syncing"
    }
    TooltipMixin {
        id: tip
        root: widget.root
        owner: widget
        text: Model.aggregateTooltip(widget.service.accounts, Date.now())
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: function(mouse) {
            tip.hide()
            widget.service.selectBadgedAccount()
            if (mouse.button === Qt.RightButton) widget.service.checkQuota()
            else if (mouse.button === Qt.MiddleButton) widget.service.openFolder()
            else widget.root.oneDriveVisible = !widget.root.oneDriveVisible
        }
    }
}
