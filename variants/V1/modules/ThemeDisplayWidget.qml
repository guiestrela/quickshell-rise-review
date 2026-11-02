import QtQuick

Item {
    id: rootMod
    required property var root
    property var screen: null

    implicitWidth: 22
    implicitHeight: 28

    IconText {
        anchors.centerIn: parent
        text: "palette"
        font.pixelSize: 14
        font.weight: Font.Normal
        color: rootMod.root.imagePickerVisible
            ? rootMod.root.seal
            : Qt.rgba(rootMod.root.ink.r, rootMod.root.ink.g, rootMod.root.ink.b, 0.65)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    TooltipMixin {
        id: tip; root: rootMod.root; owner: rootMod
        text: "L: Theme  R: Wallpaper  M: Next"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onEntered: tip.show()
        onExited:  tip.hide()
        onClicked: function(mouse) {
            tip.hide()
            if (mouse.button === Qt.MiddleButton) rootMod.root.shuffleWallpapers()
            else rootMod.root.toggleImagePicker(
                mouse.button === Qt.RightButton ? "wallpaper" : "theme",
                rootMod.screen)
        }
    }
}
