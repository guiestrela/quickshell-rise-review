pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: overlay
    required property var root

    screen: overlay.root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // "quickshell" (not "omarchy-tooltip") so the theme's match:namespace quickshell
    // blur rule frosts the tooltip too — same ride-the-theme mechanism as the bar.
    WlrLayershell.namespace: "quickshell"
    mask: Region {}

    readonly property int barBottom: overlay.root.v2BarHeight
    readonly property int gap: 6

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
            if (overlay.root.barVertical) return overlay.root.barPosition === "left" ? overlay.root.verticalBarWidth + overlay.gap : parent.width - overlay.root.verticalBarWidth - width - overlay.gap
            var cx = overlay.root.tooltipX;
            return Math.max(4, Math.min(parent.width - width - 4, cx - width / 2));
        }
        // Follow the actual owner, including freely rearranged widgets and panel
        // row actions. Prefer the inward side of the bar, then flip when the
        // preferred side would leave the screen.
        y: {
            if (overlay.root.barVertical) return Math.max(4, Math.min(parent.height - height - 4, overlay.root.tooltipY - height / 2))
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

        color: overlay.root.bg
        border.color: overlay.root.panelOuterBorderColor
        border.width: overlay.root.panelOuterBorderW
        radius: overlay.root.panelRadius
        opacity: overlay.reveal

        PillShadow { theme: overlay.root }

        UiText {
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
