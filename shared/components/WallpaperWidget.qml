import QtQuick
import "../logic/WallpaperWidgetValuesLogic.js" as WallpaperWidgetValuesLogic
import "../logic/WallpaperWidgetLogic.js" as WallpaperWidgetLogic
import "../components" as CommonComponents

// Rise-only control: uses the existing wallpaper owner and picker.
Item {
    id: rootMod
    required property var root
    required property color openColor
    required property color nextColor
    property Component backgroundComponent
    property var screen: null
    readonly property bool configured: String(root.wallpaperManagerFolder || "") !== ""
    readonly property string tooltipText: configured
        ? "Wallpapers · click to choose · next to shuffle"
        : "Wallpapers · choose a folder"
    implicitWidth: root.modWallpapers ? buttons.implicitWidth + 16 : 0
    implicitHeight: 28

    function openPicker() { return WallpaperWidgetValuesLogic.openPicker(rootMod, {}) }
    function nextWallpaper() { return WallpaperWidgetLogic.nextWallpaper(rootMod, {}) }

    Loader {
        anchors.verticalCenter: parent.verticalCenter
        width: buttons.implicitWidth + 16
        height: rootMod.root.pillH
        sourceComponent: rootMod.backgroundComponent
    }
    Row {
        id: buttons
        anchors.centerIn: parent
        spacing: 4
        CommonComponents.UiText {
            id: openLabel
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.configured ? "WALL" : "WALL +"
            color: rootMod.openColor
            font.family: rootMod.root.mono
            font.pixelSize: 10
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: rootMod.openPicker()
            }
        }
        CommonComponents.UiText {
            id: nextLabel
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: rootMod.nextColor
            font.pixelSize: 16
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: rootMod.nextWallpaper()
            }
        }
    }
    CommonComponents.TooltipMixin { root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }
}
