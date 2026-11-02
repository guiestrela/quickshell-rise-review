pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules" as Native
import "../../../shared/components" as CommonComponents

// Reuse the controls/controller, but draw the exact connected V2 panel surface.
Shared.DisplayManagerPanel {
    id: panel
    connectedStyle: true
    headerComponent: Component {
        Item {
            implicitHeight: 24
            CommonComponents.UiText {
                objectName: "display-v2-title"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Display Manager"
                color: panel.root.ink
                font.family: panel.root.mono
                font.pixelSize: 13
                font.letterSpacing: 2
                font.weight: Font.Medium
            }
            CommonComponents.UiText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "✕"
                color: closeMouse.containsMouse ? panel.root.seal : panel.root.sumi
                font.pixelSize: 12
                MouseArea {
                    id: closeMouse
                    objectName: "display-v2-close"
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.root.displayManagerVisible = false
                }
            }
        }
    }
    Native.SidePanelPositioner { root: panel.root; target: panel.surfaceHost; anchorName: "displayManager" }
    Native.ConnectedPanelSurface {
        parent: panel.surfaceHost
        z: -1
        root: panel.root
        ownerActive: panel.root.displayManagerVisible
        targetX: panel.root.displayManagerBarX
        reveal: panel.root.panelInsetReveal
    }
}
