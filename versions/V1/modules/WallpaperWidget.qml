import QtQuick
import Quickshell

// Rise-only control: uses the existing wallpaper owner and picker.
Item {
    id: rootMod
    required property var root
    property var screen: null
    readonly property bool configured: String(root.wallpaperManagerFolder || "") !== ""
    readonly property string tooltipText: configured
        ? "Wallpapers · click to choose · next to shuffle"
        : "Wallpapers · choose a folder"
    implicitWidth: root.modWallpapers ? buttons.implicitWidth + 16 : 0
    implicitHeight: 28

    function openPicker() { rootMod.root.toggleImagePicker("wallpaper", rootMod.screen) }
    function nextWallpaper() {
        if (rootMod.configured) rootMod.root.shuffleWallpapers()
        else rootMod.openPicker()
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: buttons.implicitWidth + 16
        height: root.pillH
        radius: root.pillRadius
        color: root.pill
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
    }
    Row {
        id: buttons
        anchors.centerIn: parent
        spacing: 4
        UiText {
            id: openLabel
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.configured ? "WALL" : "WALL +"
            color: root.seal
            font.family: root.mono
            font.pixelSize: 10
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: rootMod.openPicker()
            }
        }
        UiText {
            id: nextLabel
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: root.ink
            font.pixelSize: 16
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: rootMod.nextWallpaper()
            }
        }
    }
    TooltipMixin { root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }
}
