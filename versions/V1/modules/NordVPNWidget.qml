import QtQuick

Item {
    id: nordVpnWidget
    required property var root
    readonly property string nordVpnStatusText: {
        if (root.nordVpnStatus === "Connected") return "NordVPN ON"
        if (root.nordVpnStatus === "Disconnected") return "NordVPN OFF"
        if (root.nordVpnStatus === "Unavailable") return "NordVPN N/A"
        return "NordVPN …"
    }

    visible: root.modNordVpn
    implicitWidth: visible ? statusPill.implicitWidth : 0
    implicitHeight: 28
    property alias testClickHandler: widgetClick

    function activate() {
        var point = nordVpnWidget.mapToItem(null, nordVpnWidget.width / 2, 0)
        root.setPanelAnchor("vpn", point.x, root.activePopupScreenName)
        root.vpnVisible = true
    }

    Rectangle {
        id: statusPill
        anchors.centerIn: parent
        implicitWidth: statusLabel.implicitWidth + 14
        height: 22
        radius: nordVpnWidget.root.pillRadius
        color: nordVpnWidget.root.fillIdle
        border.color: nordVpnWidget.root.nordVpnStatus === "Connected"
            ? nordVpnWidget.root.seal : nordVpnWidget.root.pillBorder
        border.width: nordVpnWidget.root.pillBorderW

        Text {
            id: statusLabel
            anchors.centerIn: parent
            text: nordVpnWidget.nordVpnStatusText
            color: nordVpnWidget.root.nordVpnStatus === "Connected"
                ? nordVpnWidget.root.seal : nordVpnWidget.root.sumi
            font.family: nordVpnWidget.root.mono
            font.pixelSize: 9
        }
        MouseArea {
            id: widgetClick
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: nordVpnWidget.activate()
        }
    }
}
