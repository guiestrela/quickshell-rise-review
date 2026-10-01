import QtQuick
import QtQuick.Window
import QtQuick.Dialogs
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: panel
    required property var root
    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-rise-wallpaper-manager"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: root.wallpaperManagerVisible
    readonly property alias folderPicker: folderDialog
    function dismiss() {
        if (!folderDialog.visible) panel.root.wallpaperManagerVisible = false
    }
    readonly property var profile: root.wallpaperProfileFor(root.wallpaperManagerDisplay)

    onProfileChanged: {
        if (!folderInput.edited) folderInput.text = profile.folder
    }
    Connections {
        target: panel.root
        function onWallpaperManagerDisplayChanged() {
            // A former monitor draft must never be committed to the new one.
            folderInput.edited = false
            folderInput.text = panel.root.wallpaperProfileFor(panel.root.wallpaperManagerDisplay).folder
        }
    }

    component RiseButton: Rectangle {
        id: button
        property string label: ""
        property bool selected: false
        property bool leftAlign: false
        signal activated()
        implicitWidth: buttonText.implicitWidth + 24
        implicitHeight: 30
        width: implicitWidth
        height: implicitHeight
        radius: panel.root.tileRadius
        color: selected ? panel.root.fillActive : click.containsMouse ? panel.root.fillHover : panel.root.fillIdle
        border.color: selected || click.containsMouse ? panel.root.seal : panel.root.sep
        border.width: 1
        opacity: enabled ? 1 : 0.5
        Text {
            id: buttonText
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            horizontalAlignment: button.leftAlign ? Text.AlignLeft : Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: button.label; textFormat: Text.PlainText
            color: button.selected ? panel.root.seal : panel.root.ink
            font.family: panel.root.mono; font.pixelSize: 11
            elide: Text.ElideRight
        }
        MouseArea {
            id: click; anchors.fill: parent; hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.activated()
        }
    }

    component RiseToggle: Rectangle {
        id: toggle
        property string label: ""
        property string description: ""
        property bool checked: false
        signal activated()
        width: parent.width
        height: Math.max(54, toggleLabels.implicitHeight + 18)
        radius: panel.root.tileRadius
        color: panel.root.fillIdle; border.color: panel.root.sep
        Column {
            id: toggleLabels
            anchors.left: parent.left; anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 80; spacing: 4
            Text { width: parent.width; text: toggle.label; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: panel.root.ink; font.family: panel.root.mono; font.pixelSize: 12 }
            Text { width: parent.width; text: toggle.description; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: panel.root.muted; font.family: panel.root.mono; font.pixelSize: 10 }
        }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 50; height: 22; radius: height / 2
            color: toggle.checked ? panel.root.fillActive : toggleClick.containsMouse ? panel.root.fillHover : panel.root.fillIdle
            border.color: toggle.checked || toggleClick.containsMouse ? panel.root.seal : panel.root.sep
            Text { anchors.centerIn: parent; text: toggle.checked ? "ON" : "OFF"; color: toggle.checked ? panel.root.seal : panel.root.muted; font.family: panel.root.mono; font.pixelSize: 10 }
            MouseArea { id: toggleClick; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: toggle.activated() }
        }
    }
    component SectionLabel: Text {
        color: panel.root.muted; font.family: panel.root.mono; font.pixelSize: 10
        font.letterSpacing: 0.5; textFormat: Text.PlainText
    }

    MouseArea { anchors.fill: parent; onClicked: panel.dismiss() }
    Rectangle {
        id: card
        objectName: "wallpaper-card"
        x: Math.max(8, Math.min(panel.width - width - 8,
            panel.root.wallpaperManagerAnchorX - width / 2))
        y: Math.max(8, Math.min(panel.height - height - 8,
            panel.root.wallpaperManagerAnchorY + 8))
        width: Math.min(420, panel.width - 32)
        height: Math.min(content.implicitHeight + 28, panel.height - 32)
        color: panel.root.paper
        border.color: panel.root.pillBorder
        border.width: panel.root.pillBorderW
        radius: panel.root.pillRadius
        PillShadow { theme: panel.root }
        focus: panel.visible
        Keys.onEscapePressed: panel.dismiss()
        MouseArea { anchors.fill: parent; onClicked: {} }
        Flickable {
            id: viewport
            anchors.fill: parent; anchors.margins: 14
            contentWidth: width; contentHeight: content.implicitHeight
            clip: true; boundsBehavior: Flickable.StopAtBounds
            Column {
                id: content
                width: viewport.width; spacing: 12
                Row {
                    spacing: 8
                    Repeater {
                        model: [{key:"displays", label:"Displays"}, {key:"shuffling", label:"Shuffling"}]
                        delegate: RiseButton {
                            required property var modelData
                            objectName: "wallpaper-tab-" + modelData.key
                            label: modelData.label
                            selected: panel.root.wallpaperManagerTab === modelData.key
                            onActivated: panel.root.wallpaperManagerTab = modelData.key
                        }
                    }
                }
                Column {
                    id: displaysContent
                    objectName: "wallpaper-displays-content"
                    visible: panel.root.wallpaperManagerTab === "displays"
                    width: parent.width; spacing: 12
                    RiseToggle {
                        objectName: "wallpaper-per-display"
                        label: "Configure each display separately"
                        description: checked ? "On: each display keeps its own settings." : "Off: one configuration shared by every display."
                        checked: panel.root.wallpaperManagerSettings.perDisplayConfig
                        onActivated: panel.root.setWallpaperPerDisplay(!checked)
                    }
                    Row {
                        visible: panel.root.wallpaperManagerSettings.perDisplayConfig
                        spacing: 8
                        Repeater {
                            model: panel.root.wallpaperOutputs
                            delegate: RiseButton {
                                required property var modelData
                                objectName: "wallpaper-display-" + modelData.name
                                label: modelData.name
                                selected: panel.root.wallpaperManagerDisplay === modelData.name
                                onActivated: panel.root.wallpaperManagerDisplay = modelData.name
                            }
                        }
                    }
                    SectionLabel { visible: !panel.root.wallpaperManagerSettings.perDisplayConfig; text: "All displays" }
                    SectionLabel { text: "FOLDER" }
                    Row {
                        width: parent.width; spacing: 8
                        Rectangle {
                            width: parent.width - browseButton.width - 8; height: 32
                            radius: panel.root.tileRadius
                            color: panel.root.fillIdle; border.color: folderInput.activeFocus ? panel.root.seal : panel.root.sep
                            TextInput {
                                id: folderInput
                                objectName: "wallpaper-folder"
                                property bool edited: false
                                anchors.fill: parent; anchors.margins: 8
                                text: panel.profile.folder
                                color: panel.root.ink; selectionColor: panel.root.seal
                                font.family: panel.root.mono; font.pixelSize: 11; clip: true
                                onTextEdited: edited = true
                                onAccepted: { edited = false; panel.root.setWallpaperProfile({folder: text.trim()}) }
                                onEditingFinished: {
                                    if (!edited) return
                                    edited = false
                                    if (text.trim() !== panel.profile.folder) panel.root.setWallpaperProfile({folder: text.trim()})
                                }
                            }
                        }
                        RiseButton { id: browseButton; objectName: "wallpaper-browse"; label: "Browse…"; height: 32; onActivated: { folderDialog.targetDisplay = panel.root.wallpaperManagerDisplay; folderDialog.open() } }
                    }
                    SectionLabel { text: panel.root.wallpaperManagerServiceApi.countFor(panel.root.wallpaperManagerDisplay) + " images found." }
                    RiseButton {
                        objectName: "wallpaper-clear"
                        width: parent.width
                        visible: panel.profile.folder !== ""
                        label: "Clear folder (use default backgrounds)"
                        leftAlign: true
                        onActivated: { folderInput.edited = false; panel.root.setWallpaperProfile({folder: ""}) }
                    }
                    RiseToggle {
                        objectName: "wallpaper-recursive"
                        label: "Search subfolders"
                        description: "Include images nested below the chosen folder."
                        checked: panel.profile.recursive
                        onActivated: panel.root.setWallpaperProfile({recursive: !checked})
                    }
                    SectionLabel { text: "MODE" }
                    Row {
                        spacing: 8
                        Repeater {
                            model: [{key:"shuffle", label:"Shuffle"}, {key:"single", label:"Single"}]
                            delegate: RiseButton {
                                required property var modelData
                                objectName: "wallpaper-mode-" + modelData.key
                                label: modelData.label; selected: panel.profile.mode === modelData.key
                                onActivated: panel.root.setWallpaperProfile({mode: modelData.key})
                            }
                        }
                    }
                    SectionLabel { text: "SCALING" }
                    Row {
                        spacing: 8
                        Repeater {
                            model: [{key:"zoom", label:"Zoom"}, {key:"fitHeight", label:"Fit ↕"}, {key:"fitWidth", label:"Fit ↔"}, {key:"actual", label:"Actual"}]
                            delegate: RiseButton {
                                required property var modelData
                                readonly property string scalingKey: modelData.key === "actual" ? "zoom" : modelData.key === "zoom" ? "actual" : modelData.key
                                objectName: "wallpaper-scale-" + modelData.key
                                label: modelData.label; selected: panel.profile.scaling === scalingKey
                                onActivated: panel.root.setWallpaperProfile({scaling: scalingKey})
                            }
                        }
                    }
                }
                Column {
                    id: shufflingContent
                    visible: panel.root.wallpaperManagerTab === "shuffling"
                    width: parent.width; spacing: 12
                    SectionLabel { text: "Auto-shuffle every (seconds, 0 = off)" }
                    Controls.SpinBox {
                        id: intervalInput
                        objectName: "wallpaper-shuffle-interval"
                        from: 0; to: 86400; stepSize: 60; editable: true
                        width: 120; height: 30
                        value: panel.root.wallpaperShuffleInterval
                        font.family: panel.root.mono; font.pixelSize: 11
                        onValueModified: panel.root.setWallpaperShuffleSettings({intervalSec: value})
                        background: Rectangle { color: panel.root.fillIdle; radius: panel.root.tileRadius; border.width: 1; border.color: panel.root.sep }
                        contentItem: TextInput {
                            id: intervalText
                            objectName: "wallpaper-shuffle-interval-editor"
                            text: String(intervalInput.value)
                            color: panel.root.ink; selectionColor: panel.root.seal
                            font: intervalInput.font
                            verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
                            rightPadding: 24
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator { bottom: intervalInput.from; top: intervalInput.to }
                            onAccepted: {
                                if (acceptableInput) {
                                    intervalInput.value = Number(text)
                                    panel.root.setWallpaperShuffleSettings({intervalSec: intervalInput.value})
                                } else text = String(intervalInput.value)
                            }
                        }
                        up.indicator: Rectangle {
                            x: intervalInput.width - width; y: 0; width: 22; height: intervalInput.height / 2
                            color: intervalInput.up.pressed ? panel.root.fillActive : panel.root.fillIdle
                            Text { anchors.centerIn: parent; text: "▴"; color: panel.root.muted; font.pixelSize: 10 }
                        }
                        down.indicator: Rectangle {
                            x: intervalInput.width - width; y: intervalInput.height / 2; width: 22; height: intervalInput.height / 2
                            color: intervalInput.down.pressed ? panel.root.fillActive : panel.root.fillIdle
                            Text { anchors.centerIn: parent; text: "▾"; color: panel.root.muted; font.pixelSize: 10 }
                        }
                    }
                    RiseToggle {
                        objectName: "wallpaper-shuffle-wake"
                        label: "Shuffle on unlock or wake"
                        description: "Change wallpaper on unlock or screensaver exit rather than on a timer."
                        checked: panel.root.wallpaperShuffleOnWake
                        enabled: panel.root.wallpaperWakeAvailable
                        onActivated: panel.root.setWallpaperShuffleSettings({shuffleOnWake: !checked})
                    }
                    Text {
                        visible: !panel.root.wallpaperWakeAvailable
                        width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
                        text: "Unlock/wake events are unavailable in this host."
                        color: panel.root.muted; font.family: panel.root.mono; font.pixelSize: 10
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap; textFormat: Text.PlainText
                        text: "Displays set to Single keep their image and are left alone."
                        color: panel.root.muted; font.family: panel.root.mono; font.pixelSize: 10
                    }
                }
                Rectangle { width: parent.width; height: 1; color: panel.root.sep }
                Row {
                    spacing: 8
                    RiseButton { objectName: "wallpaper-next"; label: "Next image"; onActivated: panel.root.wallpaperManagerServiceApi.nextAll() }
                    RiseButton {
                        objectName: "wallpaper-rescan"
                        label: panel.root.wallpaperManagerServiceApi.scanInFlight ? "Scanning…" : "Rescan"
                        enabled: !panel.root.wallpaperManagerServiceApi.scanInFlight
                        onActivated: if (enabled) panel.root.wallpaperManagerServiceApi.scanFolder(panel.root.wallpaperManagerDisplay)
                    }
                }
                Text {
                    objectName: "wallpaper-scan-status"
                    width: parent.width
                    text: {
                        var service = panel.root.wallpaperManagerServiceApi
                        var name = panel.root.wallpaperManagerDisplay
                        if (service.scanInFlight) return "Scanning folders…"
                        var errors = service.outputNames(name).map(function(output) { return service.scanErrors[output] || "" }).filter(function(error) { return error !== "" })
                        if (errors.length > 0) return errors[0]
                        return service.countFor(name) + " images · Rescan keeps the current image"
                    }
                    color: panel.root.muted
                    font.family: panel.root.mono; font.pixelSize: 10
                    textFormat: Text.PlainText; wrapMode: Text.WordWrap
                }
                Column {
                    width: parent.width; spacing: 3
                    Repeater {
                        model: panel.root.wallpaperOutputs
                        delegate: Text {
                            required property var modelData
                            objectName: "wallpaper-output-status"
                            width: parent.width
                            readonly property string currentPath: panel.root.wallpaperManagerServiceApi.pathFor(modelData.name)
                            text: modelData.name + "  ·  " + (currentPath !== "" ? currentPath.substring(currentPath.lastIndexOf("/") + 1) : "No image selected")
                            textFormat: Text.PlainText; elide: Text.ElideMiddle
                            color: panel.root.muted; font.family: panel.root.mono; font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
    FolderDialog {
        id: folderDialog
        objectName: "wallpaper-folder-picker"
        options: FolderDialog.DontUseNativeDialog | FolderDialog.ReadOnly
        popupType: Controls.Popup.Item
        parentWindow: panel.contentItem.Window.window
        modality: Qt.WindowModal
        property string targetDisplay: "all"
        currentFolder: panel.profile.folder !== "" ? "file://" + panel.profile.folder.split("/").map(encodeURIComponent).join("/") : "file:///home"
        onAccepted: {
            if (targetDisplay === panel.root.wallpaperManagerDisplay) folderInput.edited = false
            panel.root.setWallpaperProfile({folder: decodeURIComponent(String(selectedFolder).replace(/^file:\/\//, ""))}, targetDisplay)
        }
    }
}
