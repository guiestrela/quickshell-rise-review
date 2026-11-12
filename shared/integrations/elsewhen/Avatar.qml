import QtQuick
import QtQuick.Effects
import "Model.js" as Model

Item {
    id: avatar
    objectName: "elsewhen-person-avatar"

    property string name: ""
    property string source: ""
    property double stamp: 0
    property real size: 15
    property color foreground: "#ebdbb2"
    property color ground: "#282828"
    property string fontFamily: "monospace"

    readonly property bool pictured: picture.status === Image.Ready
    readonly property real edge: Math.max(1, Math.round(size / 12))

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        anchors.margins: -avatar.edge
        radius: width / 2
        color: avatar.ground
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Model.mix(avatar.ground, avatar.foreground, 0.28)
        visible: !avatar.pictured

        Text {
            objectName: "elsewhen-person-avatar-initial"
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: Model.initialOf(avatar.name)
            color: avatar.foreground
            font.family: avatar.fontFamily
            font.pixelSize: Math.round(avatar.size * 0.55)
            font.weight: Font.DemiBold
        }
    }

    Image {
        id: picture
        objectName: "elsewhen-person-avatar-image"
        anchors.fill: parent
        visible: false
        source: avatar.source === "" ? "" : "file://" + avatar.source + "?v=" + avatar.stamp
        sourceSize.width: Math.ceil(avatar.size * Screen.devicePixelRatio)
        sourceSize.height: Math.ceil(avatar.size * Screen.devicePixelRatio)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "black"
        }
    }

    MultiEffect {
        anchors.fill: parent
        visible: avatar.pictured
        source: picture
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
