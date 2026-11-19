pragma ComponentBehavior: Bound
import QtQuick

// Local, read-only Health presentation. No search or action routing.
Item {
    id: tools
    required property var theme
    required property string variantName
    property bool open: false
    property real anchorOffset: 35
    property real gap: 8
    property var healthRows: []
    property var focusReturnRoot: null
    property var focusReturnTarget: null
    signal closeRequested()

    visible: open
    anchors.fill: parent
    z: 1000

    onOpenChanged: {
        if (open) {
            Qt.callLater(function() {
                if (tools.open) card.forceActiveFocus()
            })
        } else {
            const returnRoot = tools.focusReturnRoot
            const returnTarget = tools.focusReturnTarget
            Qt.callLater(function() {
                if (!tools.open && returnRoot && returnRoot.controlVisible === true
                        && returnTarget && returnTarget.visible && returnTarget.enabled)
                    returnTarget.forceActiveFocus()
            })
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: tools.closeRequested()
    }

    Rectangle {
        id: card
        objectName: "control-panel-tools"
        width: Math.min(340, Math.max(220, parent.width - 24))
        height: Math.min(440, Math.max(300, parent.height - 24))
        x: Math.round(Math.max(12, Math.min(tools.theme.launcherBarX - width / 2, parent.width - width - 12)))
        y: tools.theme.barPosition === "bottom"
            ? Math.max(12, parent.height - tools.anchorOffset - tools.gap - height)
            : Math.min(parent.height - height - 12, tools.anchorOffset + tools.gap)
        radius: tools.theme.panelRadius !== undefined ? tools.theme.panelRadius : tools.theme.pillRadius
        color: tools.theme.bg
        border.color: tools.theme.panelOuterBorderColor !== undefined
            ? tools.theme.panelOuterBorderColor : tools.theme.pillBorder
        border.width: tools.theme.panelOuterBorderW !== undefined
            ? tools.theme.panelOuterBorderW : tools.theme.pillBorderW
        focus: tools.open
        activeFocusOnTab: true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                tools.closeRequested()
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Row {
                width: parent.width
                height: 26
                spacing: 6
                Text {
                    width: parent.width - 38
                    height: parent.height
                    text: "Health"
                    textFormat: Text.PlainText
                    color: tools.theme.ink
                    font.family: tools.theme.mono
                    font.pixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                }
                Rectangle {

                    objectName: "control-panel-tools-close"
                    width: 32
                    height: parent.height
                    radius: tools.theme.panelButtonRadius !== undefined ? tools.theme.panelButtonRadius : tools.theme.tileRadius
                    color: closeMouse.containsMouse ? tools.theme.fillHover : "transparent"
                    activeFocusOnTab: true

                    Accessible.role: Accessible.Button
                    Accessible.name: "Close Health"
                    Keys.onReturnPressed: tools.closeRequested()
                    Keys.onSpacePressed: tools.closeRequested()
                    Text { anchors.centerIn: parent; text: "✕"; color: closeMouse.containsMouse ? tools.theme.seal : tools.theme.sumi; font.pixelSize: 12 }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tools.closeRequested()
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: tools.theme.sep }
            Text {
                objectName: "control-panel-health-disclaimer"
                width: parent.width
                text: "LOCAL STATE ONLY · NO EXTERNAL PROBES"
                color: tools.theme.sumiHi
                font.family: tools.theme.mono
                font.pixelSize: 9
                font.letterSpacing: 0.4
                wrapMode: Text.Wrap
            }
            ListView {
                id: resultsView
                objectName: "control-panel-tools-results"
                width: parent.width
                height: Math.max(60, parent.height - y - 34)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: tools.healthRows
                spacing: 5
                delegate: Rectangle {
                    id: resultRow
                    required property var modelData
                    width: resultsView.width
                    height: 48
                    radius: tools.theme.panelButtonRadius !== undefined ? tools.theme.panelButtonRadius : tools.theme.tileRadius
                    color: tools.theme.fillIdle
                    border.color: tools.theme.sep
                    Accessible.role: Accessible.StaticText
                    Accessible.name: modelData.label + ": " + modelData.value
                    objectName: "control-panel-health-row-" + modelData.label.toLowerCase().replace(/ /g, "-")
                    Column {
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 2
                        Text {
                            width: parent.width
                            text: resultRow.modelData.label + "  ·  " + resultRow.modelData.value
                            textFormat: Text.PlainText
                            color: tools.theme.ink
                            font.family: tools.theme.mono
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: resultRow.modelData.detail
                            textFormat: Text.PlainText
                            color: tools.theme.sumiHi
                            font.family: tools.theme.mono
                            font.pixelSize: 9
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                        }
                    }
                }
            }
            Text {
                width: parent.width
                text: "READ-ONLY · NO ACCOUNTS OR NETWORK CALLS"
                color: tools.theme.sumi
                font.family: tools.theme.mono
                font.pixelSize: 8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }
}
