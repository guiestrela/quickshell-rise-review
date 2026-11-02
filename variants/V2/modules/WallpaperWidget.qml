import QtQuick

// Rise-only control: uses the existing wallpaper owner and picker.
Item {
    id: rootMod
    required property var root
    property var screen: null
    readonly property bool configured: String(root.wallpaperManagerFolder || "") !== ""
    readonly property string tooltipText: configured
        ? "Wallpapers · click to choose · next to shuffle"
        : "Wallpapers · choose a folder"
    readonly property color contentColor: root.widgetContentColor("G20", root.widgetIconColor)
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
        height: rootMod.root.pillH
        radius: rootMod.root.pillRadius
        color: rootMod.root.pill
        border.color: "transparent"
        border.width: rootMod.root.pillBorderW
        PillShadow { theme: rootMod.root }
    }
    Row {
        id: buttons
        anchors.centerIn: parent
        spacing: 4
        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.configured ? "WALL" : "WALL +"
            color: rootMod.contentColor
            font.family: rootMod.root.mono
            font.pixelSize: 10
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: rootMod.openPicker()
            }
        }
        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: rootMod.contentColor
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
