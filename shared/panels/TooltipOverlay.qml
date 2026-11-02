pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../components" as CommonComponents

PanelWindow {
    id: overlay
    required property var root

    screen: overlay.root.activePopupScreen
    property int barBottom: 35
    property int gap: 6
    property bool useTooltipYForVertical: false
    property color surfaceColor: overlay.root.barBg
    property color surfaceBorderColor: overlay.root.pillBorder
    property int surfaceBorderWidth: overlay.root.pillBorderW
    property real surfaceRadius: overlay.root.pillRadius
    property Component shadowComponent: null

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // "quickshell" (not "omarchy-tooltip") so the theme's match:namespace quickshell
    // blur rule frosts the tooltip too — same ride-the-theme mechanism as the bar.
    WlrLayershell.namespace: "quickshell"
    mask: Region {}

    property real reveal: overlay.root.tooltipShown ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: overlay.root.tooltipShown ? 160 : 120
            easing.type: overlay.root.tooltipShown ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001

    Rectangle {
        id: tip
        readonly property int padH: 10
        readonly property int padV: 4

        width: tipLabel.implicitWidth + padH * 2
        height: tipLabel.implicitHeight + padV * 2

        x: {
            if (overlay.root.barVertical === true) return overlay.root.barPosition === "left" ? overlay.root.verticalBarWidth + overlay.gap : parent.width - overlay.root.verticalBarWidth - width - overlay.gap
            var cx = overlay.root.tooltipX;
            return Math.max(4, Math.min(parent.width - width - 4, cx - width / 2));
        }
        // Follow the actual owner, including freely rearranged widgets and panel
        // row actions. Prefer the inward side of the bar, then flip when the
        // preferred side would leave the screen.
        y: {
            if (overlay.root.barVertical) {
                var verticalY = overlay.useTooltipYForVertical
                    ? overlay.root.tooltipY - height / 2
                    : (overlay.root.tooltipTopY + overlay.root.tooltipBottomY - height) / 2
                return Math.max(4, Math.min(parent.height - height - 4, verticalY))
            }
            var above = overlay.root.tooltipTopY - overlay.gap - height
            var below = overlay.root.tooltipBottomY + overlay.gap
            var maxY = parent.height - height - 4
            var candidate = overlay.root.barPosition === "bottom" ? above : below

            if (candidate < 4 && below <= maxY)
                candidate = below
            else if (candidate > maxY && above >= 4)
                candidate = above

            return Math.max(4, Math.min(maxY, candidate))
        }

        // Match the bar's surface recipe so the tooltip responds to the same
        // border, frost and corner-radius controls as its trigger.
        color: overlay.surfaceColor
        border.color: overlay.surfaceBorderColor
        border.width: overlay.surfaceBorderWidth
        radius: overlay.surfaceRadius
        opacity: overlay.reveal

        Loader {
            anchors.fill: parent
            sourceComponent: overlay.shadowComponent
        }

        CommonComponents.UiText {
            id: tipLabel
            anchors.centerIn: parent
            text: overlay.root.tooltipText
            color: overlay.root.ink
            font.family: overlay.root.mono
            font.pixelSize: 12
            font.letterSpacing: 1
        }
    }
}
