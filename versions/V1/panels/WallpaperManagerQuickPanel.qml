import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel
    required property var root
    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-rise-wallpaper-manager"
    WlrLayershell.keyboardFocus: panel.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: root.wallpaperManagerVisible

    readonly property var profile: root.wallpaperProfileFor(root.wallpaperManagerDisplay)
    readonly property string displayLabel: root.wallpaperManagerDisplay === "all"
        ? "All displays" : root.wallpaperManagerDisplay

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(400, panel.width - 32)
        height: Math.min(596, panel.height - 32)
        color: panel.root.paper
        border.color: panel.root.seal
        border.width: 2
        radius: panel.root.panelRadius

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Row {
                spacing: 8
                Repeater {
                    model: [{key:"displays", label:"Displays"}, {key:"shuffling", label:"Shuffling"}]
                    delegate: Rectangle {
                        required property var modelData
                        width: tabText.implicitWidth + 22; height: 30
                        color: panel.root.wallpaperManagerTab === modelData.key ? panel.root.fillActive : "transparent"
                        border.color: panel.root.wallpaperManagerTab === modelData.key ? panel.root.seal : panel.root.sep
                        Text { id: tabText; anchors.centerIn: parent; text: modelData.label; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; onClicked: panel.root.wallpaperManagerTab = modelData.key }
                    }
                }
                Item { width: 1; height: 1 }
                Text { text: "×"; color: panel.root.ink; font.pixelSize: 20
                    MouseArea { anchors.fill: parent; onClicked: panel.root.wallpaperManagerVisible = false }
                }
            }

            Column {
                visible: panel.root.wallpaperManagerTab === "displays"
                width: parent.width; spacing: 9

                Rectangle {
                    width: parent.width; height: 48
                    color: panel.root.fillIdle; border.color: panel.root.sep
                    Row {
                        anchors.fill: parent; anchors.margins: 9; spacing: 10
                        Column {
                            width: parent.width - 56
                            Text { text: "Configure each display separately"; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 12 }
                            Text { text: panel.root.wallpaperManagerSettings.perDisplayConfig ? "On: each display keeps its own settings." : "Off: one configuration is shared by every display."; color: panel.root.muted; font.family: panel.root.mono; font.pixelSize: 9; elide: Text.ElideRight }
                        }
                        Rectangle {
                            width: 46; height: 22; anchors.verticalCenter: parent.verticalCenter
                            color: panel.root.wallpaperManagerSettings.perDisplayConfig ? panel.root.fillActive : panel.root.fillIdle
                            border.color: panel.root.seal
                            Rectangle { x: panel.root.wallpaperManagerSettings.perDisplayConfig ? 24 : 2; y: 2; width: 18; height: 18; color: panel.root.ink }
                            MouseArea { anchors.fill: parent; onClicked: panel.root.setWallpaperPerDisplay(!panel.root.wallpaperManagerSettings.perDisplayConfig) }
                        }
                    }
                }

                Row {
                    spacing: 6
                    Repeater {
                        model: panel.root.wallpaperManagerSettings.perDisplayConfig ? panel.root.wallpaperOutputs : [{name:"all"}]
                        delegate: Rectangle {
                            required property var modelData
                            width: displayText.implicitWidth + 20; height: 29
                            color: panel.root.wallpaperManagerDisplay === modelData.name ? panel.root.fillActive : "transparent"
                            border.color: panel.root.wallpaperManagerDisplay === modelData.name ? panel.root.seal : panel.root.sep
                            Text { id: displayText; anchors.centerIn: parent; text: modelData.name; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: panel.root.wallpaperManagerDisplay = modelData.name }
                        }
                    }
                }

                Text { text: "FOLDER"; color: panel.root.muted; font.family: panel.root.mono; font.pixelSize: 9 }
                Row {
                    width: parent.width; spacing: 6
                    Rectangle {
                        width: parent.width - clearButton.width - 6; height: 32
                        color: panel.root.fillIdle; border.color: panel.root.sep
                        TextInput {
                            id: folderInput
                            anchors.fill: parent; anchors.margins: 8
                            text: panel.profile.folder
                            color: panel.root.ink; selectionColor: panel.root.seal
                            font.family: panel.root.mono; font.pixelSize: 11
                            clip: true
                            onEditingFinished: panel.root.setWallpaperProfile({folder: text})
                        }
                    }
                    Rectangle {
                        id: clearButton
                        width: 64; height: 32; color: panel.root.fillIdle; border.color: panel.root.sep
                        Text { anchors.centerIn: parent; text: "Clear"; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; onClicked: { folderInput.text = ""; panel.root.setWallpaperProfile({folder: ""}) } }
                    }
                }
                Text { text: panel.root.wallpaperManagerServiceApi.pool.length + " images found."; color: panel.root.muted; font.family: panel.root.mono; font.pixelSize: 9 }
                Rectangle {
                    width: parent.width; height: 32; color: panel.root.fillIdle; border.color: panel.root.sep
                    Text { anchors.centerIn: parent; text: "Search subfolders"; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 11 }
                    Rectangle { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 18; color: panel.profile.recursive ? panel.root.fillActive : panel.root.fillIdle; border.color: panel.root.sep
                        Text { anchors.centerIn: parent; text: panel.profile.recursive ? "ON" : "OFF"; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 8 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: panel.root.setWallpaperProfile({recursive: !panel.profile.recursive}) }
                }
            }

            Column {
                visible: panel.root.wallpaperManagerTab === "shuffling"
                width: parent.width; spacing: 10
                Text { text: "SHUFFLING · " + panel.displayLabel; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 12 }
                Text { text: "MODE"; color: panel.root.muted; font.family: panel.root.mono; font.pixelSize: 9 }
                Row {
                    spacing: 7
                    Repeater {
                        model: [{key:"shuffle", label:"Shuffle"}, {key:"single", label:"Single"}]
                        delegate: Rectangle {
                            required property var modelData
                            width: modeText.implicitWidth + 20; height: 30
                            color: panel.profile.mode === modelData.key ? panel.root.fillActive : "transparent"
                            border.color: panel.profile.mode === modelData.key ? panel.root.seal : panel.root.sep
                            Text { id: modeText; anchors.centerIn: parent; text: modelData.label; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: panel.root.setWallpaperProfile({mode: modelData.key}) }
                        }
                    }
                }
                Text { text: "SCALING"; color: panel.root.muted; font.family: panel.root.mono; font.pixelSize: 9 }
                Row {
                    spacing: 6
                    Repeater {
                        model: [{key:"zoom", label:"Zoom"}, {key:"fitHeight", label:"Fit ↕"}, {key:"fitWidth", label:"Fit ↔"}, {key:"actual", label:"Actual"}]
                        delegate: Rectangle {
                            required property var modelData
                            width: scaleText.implicitWidth + 16; height: 30
                            color: panel.profile.scaling === modelData.key ? panel.root.fillActive : "transparent"
                            border.color: panel.profile.scaling === modelData.key ? panel.root.seal : panel.root.sep
                            Text { id: scaleText; anchors.centerIn: parent; text: modelData.label; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 10 }
                            MouseArea { anchors.fill: parent; onClicked: panel.root.setWallpaperProfile({scaling: modelData.key}) }
                        }
                    }
                }
                Item { width: 1; height: 1 }
                Row {
                    spacing: 8
                    Repeater {
                        model: ["Next image", "Rescan"]
                        delegate: Rectangle {
                            required property string modelData
                            width: actionText.implicitWidth + 20; height: 30
                            color: "transparent"; border.color: panel.root.sep
                            Text { id: actionText; anchors.centerIn: parent; text: modelData; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 11 }
                            MouseArea { anchors.fill: parent; onClicked: modelData === "Next image" ? panel.root.shuffleWallpapers() : panel.root.wallpaperManagerServiceApi.scanFolder() }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: panel.root.sep }
            Text {
                width: parent.width
                text: "Rise controls the wallpaper renderer. Changes are per display only when enabled."
                wrapMode: Text.Wrap; color: panel.root.muted; font.family: panel.root.mono; font.pixelSize: 9
            }
        }
    }
}
