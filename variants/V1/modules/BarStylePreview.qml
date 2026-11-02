import QtQuick

Rectangle {
    id: preview
    required property var theme
    property string mode: "full"
    property string label: ""
    property bool selected: false
    property bool frost: false
    property bool outline: true
    property bool shadow: false
    signal chosen()
    height: 58
    radius: 6
    color: pointer.containsMouse ? theme.fillHover : theme.fillIdle
    border.width: selected || activeFocus ? 1 : 0
    border.color: theme.seal
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.description: selected ? "Selected" : "Not selected"
    Keys.onReturnPressed: chosen()
    Keys.onSpacePressed: chosen()

    Canvas {
        id: drawing
        x: 6; y: 5; width: parent.width - 12; height: 30
        onWidthChanged: requestPaint()
        Connections {
            target: preview
            function onModeChanged() { drawing.requestPaint() }
            function onFrostChanged() { drawing.requestPaint() }
            function onOutlineChanged() { drawing.requestPaint() }
            function onShadowChanged() { drawing.requestPaint() }
        }
        Connections {
            target: preview.theme
            function onPaperChanged() { drawing.requestPaint() }
            function onInkChanged() { drawing.requestPaint() }
            function onSealChanged() { drawing.requestPaint() }
        }
        onPaint: {
            var c = getContext("2d")
            c.reset()
            c.fillStyle = preview.theme.seal
            c.globalAlpha = 0.18
            c.fillRect(0, 0, width, height)
            c.globalAlpha = preview.frost ? 0.68 : 1
            c.fillStyle = preview.theme.paper
            c.strokeStyle = preview.theme.ink
            c.lineWidth = 1
            var left = preview.mode === "full" ? 0 : width * 0.13
            var right = width - left
            var top = preview.mode === "fit" || preview.mode === "islands" ? 6 : 0
            function surface(x, w) {
                c.beginPath()
                c.roundedRect(x, top, w, 20, 4, 4)
                if (preview.shadow) {
                    c.shadowColor = "#99000000"
                    c.shadowBlur = 4
                    c.shadowOffsetY = 2
                }
                c.fill()
                c.shadowBlur = 0
                c.shadowOffsetY = 0
                if (preview.outline) c.stroke()
            }
            if (preview.mode === "islands") {
                surface(1, width * 0.25)
                surface(width * 0.34, width * 0.30)
                surface(width * 0.72, width * 0.27 - 1)
            } else if (preview.mode === "notch") {
                c.beginPath()
                c.moveTo(left - 7, 0)
                c.bezierCurveTo(left, 0, left, 20, left + 7, 20)
                c.lineTo(right - 7, 20)
                c.bezierCurveTo(right, 20, right, 0, right + 7, 0)
                c.closePath()
                c.fill()
                if (preview.outline) c.stroke()
            } else surface(left, right - left)
            c.globalAlpha = 1
            c.fillStyle = preview.theme.seal
            for (var i = 0; i < 3; i++) c.fillRect(width * (0.21 + i * 0.25), top + 8, width * 0.08, 3)
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        text: preview.label
        font.family: preview.theme.mono
        font.pixelSize: 10
        color: preview.selected ? preview.theme.seal : preview.theme.ink
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: preview.chosen()
    }
}
