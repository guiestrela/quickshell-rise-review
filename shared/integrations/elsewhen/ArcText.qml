// Adapted from omacom/omarchy shell/plugins/panels/elsewhen/ArcText.qml (MIT).
// Copyright (c) David Heinemeier Hansson; see NOTICE.md for the license text.
pragma ComponentBehavior: Bound
import QtQuick
import "Arc.js" as Arc

Item {
    id: root

    property string text: ""
    property real rise: 6
    property string fontFamily: "monospace"
    property int pixelSize: 9
    property color color: "#ffffff"

    FontMetrics {
        id: metrics
        font.family: root.fontFamily
        font.pixelSize: root.pixelSize
    }

    // Arc only single-code-unit Latin glyphs; render other scripts and clusters as shaped text.
    readonly property bool flat: /[^\u0000-\u024F\u1E00-\u1EFF]/.test(text)
    readonly property var glyphs: flat ? [] : text.split("")
    readonly property var placed: {
        var fontDependency = metrics.font.family + metrics.font.pixelSize
        var widths = []
        for (var i = 0; i < glyphs.length; i++) widths.push(metrics.advanceWidth(glyphs[i]))
        return Arc.layout(widths, rise, false)
    }
    readonly property real slack: Math.round(metrics.height / 2)
    readonly property real originX: (width - placed.width) / 2

    implicitWidth: flat ? Math.ceil(flatText.implicitWidth) + 2 * slack : Math.ceil(placed.width) + 2 * slack
    implicitHeight: flat ? Math.ceil(flatText.implicitHeight) : Math.ceil(placed.height + metrics.height)

    Text {
        id: flatText
        objectName: "elsewhen-arc-flat-text"
        visible: root.flat
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: root.flat ? root.text : ""
        color: root.color
        font.family: root.fontFamily
        font.pixelSize: root.pixelSize
    }

    Repeater {
        model: root.glyphs.length

        Text {
            required property int index
            readonly property string glyph: root.glyphs[index] || ""
            readonly property var spot: root.placed.chars[index] || ({ x: 0, y: 0, rotation: 0 })

            objectName: "elsewhen-arc-glyph"
            width: metrics.advanceWidth(glyph)
            height: metrics.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            x: root.originX + spot.x
            y: spot.y
            rotation: spot.rotation
            transformOrigin: Item.Center
            textFormat: Text.PlainText
            text: glyph
            color: root.color
            font.family: root.fontFamily
            font.pixelSize: root.pixelSize
            renderType: Text.QtRendering
        }
    }
}
