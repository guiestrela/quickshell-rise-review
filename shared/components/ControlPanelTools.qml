pragma ComponentBehavior: Bound
import QtQuick
import "../logic/ControlPanelTools.js" as ToolsLogic

Item {
    id: tools
    required property var theme
    required property string variantName
    property bool open: false
    property bool startInHealth: false
    property real anchorOffset: 35
    property real gap: 8
    property var healthRows: []
    property var focusReturnRoot: null
    property var focusReturnTarget: null

    signal closeRequested()
    signal destinationRequested(string target)

    readonly property var searchEntries: ToolsLogic.entriesForVariant(variantName)
    readonly property var filteredEntries: ToolsLogic.filterEntries(searchEntries, searchInput.text, 12)

    property int selectedIndex: filteredEntries.length > 0 ? 0 : -1

    visible: open
    anchors.fill: parent
    z: 1000

    function selectResult(entry) {
        if (!entry) return
        destinationRequested(entry.target)
        closeRequested()
    }

    onOpenChanged: {
        if (open) {
            healthTab.selected = startInHealth
            Qt.callLater(function() {
                if (!tools.open) return
                if (healthTab.selected) card.forceActiveFocus()
                else searchInput.forceActiveFocus()
            })
        } else {
            searchInput.text = ""
            healthTab.selected = false
            selectedIndex = 0
            const returnRoot = tools.focusReturnRoot
            const returnTarget = tools.focusReturnTarget
            Qt.callLater(function() {
                if (!tools.open && returnRoot && returnRoot.controlVisible === true
                        && returnTarget && returnTarget.visible && returnTarget.enabled)
                    returnTarget.forceActiveFocus()
            })
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: tools.closeRequested()
    }

    Rectangle {
        id: card
        objectName: "control-panel-tools"
        width: Math.min(340, Math.max(220, parent.width - 24))
        height: Math.min(440, Math.max(300, parent.height - 24))
        x: Math.round(Math.max(12, Math.min(tools.theme.launcherBarX - width / 2, parent.width - width - 12)))
        y: tools.theme.barPosition === "bottom"
            ? Math.max(12, parent.height - tools.anchorOffset - tools.gap - height)
            : Math.min(parent.height - height - 12, tools.anchorOffset + tools.gap)
        radius: tools.theme.panelRadius !== undefined ? tools.theme.panelRadius : tools.theme.pillRadius
        color: tools.theme.bg
        border.color: tools.theme.panelOuterBorderColor !== undefined
            ? tools.theme.panelOuterBorderColor : tools.theme.pillBorder
        border.width: tools.theme.panelOuterBorderW !== undefined
            ? tools.theme.panelOuterBorderW : tools.theme.pillBorderW
        focus: tools.open
        activeFocusOnTab: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape && healthTab.selected) {
                tools.closeRequested()
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Row {
                width: parent.width
                height: 26
                spacing: 6

                Rectangle {
                    id: searchTab
                    objectName: "control-panel-search-tab"
                    width: (parent.width - 44 - parent.spacing) / 2
                    height: parent.height
                    radius: tools.theme.panelButtonRadius !== undefined ? tools.theme.panelButtonRadius : tools.theme.tileRadius
                    property bool selected: !healthTab.selected
                    color: selected ? tools.theme.fillActive : tools.theme.fillIdle
                    border.color: selected ? tools.theme.seal : tools.theme.sep
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Search controls"
                    Accessible.checkable: true
                    Accessible.checked: selected
                    Keys.onReturnPressed: { healthTab.selected = false; searchInput.forceActiveFocus() }
                    Keys.onSpacePressed: { healthTab.selected = false; searchInput.forceActiveFocus() }
                    Text { anchors.centerIn: parent; text: "Search"; color: parent.selected ? tools.theme.seal : tools.theme.ink; font.family: tools.theme.mono; font.pixelSize: 11 }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            healthTab.selected = false
                            searchInput.forceActiveFocus()
                        }
                    }
                }

                Rectangle {
                    id: healthTab
                    objectName: "control-panel-health-tab"
                    width: searchTab.width
                    height: parent.height
                    radius: tools.theme.panelButtonRadius !== undefined ? tools.theme.panelButtonRadius : tools.theme.tileRadius
                    property bool selected: false
                    color: selected ? tools.theme.fillActive : tools.theme.fillIdle
                    border.color: selected ? tools.theme.seal : tools.theme.sep
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Read-only health"
                    Accessible.checkable: true
                    Accessible.checked: selected
                    Keys.onReturnPressed: { selected = true; card.forceActiveFocus() }
                    Keys.onSpacePressed: { selected = true; card.forceActiveFocus() }
                    Text { anchors.centerIn: parent; text: "Health"; color: parent.selected ? tools.theme.seal : tools.theme.ink; font.family: tools.theme.mono; font.pixelSize: 11 }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            healthTab.selected = true
                            card.forceActiveFocus()
                        }
                    }
                }

                Rectangle {
                    objectName: "control-panel-tools-close"
                    width: 32
                    height: parent.height
                    radius: tools.theme.panelButtonRadius !== undefined ? tools.theme.panelButtonRadius : tools.theme.tileRadius
                    color: closeMouse.containsMouse ? tools.theme.fillHover : "transparent"
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Close search and health"
                    Keys.onReturnPressed: tools.closeRequested()
                    Keys.onSpacePressed: tools.closeRequested()
                    Text { anchors.centerIn: parent; text: "✕"; color: closeMouse.containsMouse ? tools.theme.seal : tools.theme.sumi; font.pixelSize: 12 }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tools.closeRequested()
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: tools.theme.sep }

            Rectangle {
                visible: !healthTab.selected
                width: parent.width
                height: 34
                radius: tools.theme.panelButtonRadius !== undefined ? tools.theme.panelButtonRadius : tools.theme.tileRadius
                color: tools.theme.fillIdle
                border.color: searchInput.activeFocus ? tools.theme.seal : tools.theme.sep
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text.length === 0
                    text: "Search settings…"
                    color: tools.theme.sumi
                    font.family: tools.theme.mono
                    font.pixelSize: 11
                }
                TextInput {
                    id: searchInput
                    objectName: "control-panel-search-input"
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    color: tools.theme.ink
                    selectionColor: tools.theme.seal
                    selectedTextColor: tools.theme.bg
                    font.family: tools.theme.mono
                    font.pixelSize: 11
                    verticalAlignment: TextInput.AlignVCenter
                    maximumLength: 100
                    activeFocusOnTab: true
                    Accessible.role: Accessible.EditableText
                    Accessible.name: "Search Control Panel settings"
                    onTextChanged: tools.selectedIndex = tools.filteredEntries.length > 0 ? 0 : -1
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            if (text.length > 0) {
                                text = ""
                                tools.selectedIndex = 0
                            } else {
                                tools.closeRequested()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down && tools.filteredEntries.length > 0) {
                            tools.selectedIndex = Math.min(tools.filteredEntries.length - 1, tools.selectedIndex + 1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up && tools.filteredEntries.length > 0) {
                            tools.selectedIndex = Math.max(0, tools.selectedIndex - 1)
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && tools.selectedIndex >= 0) {
                            tools.selectResult(tools.filteredEntries[tools.selectedIndex])
                            event.accepted = true
                        }
                    }
                }
            }

            Text {
                objectName: "control-panel-health-disclaimer"
                visible: healthTab.selected
                width: parent.width
                text: "LOCAL STATE ONLY · NO EXTERNAL PROBES"
                color: tools.theme.sumiHi
                font.family: tools.theme.mono
                font.pixelSize: 9
                font.letterSpacing: 0.4
                wrapMode: Text.Wrap
            }

            ListView {
                id: resultsView
                objectName: "control-panel-tools-results"
                width: parent.width
                height: Math.max(60, parent.height - y - 34)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: tools.selectedIndex
                model: healthTab.selected ? tools.healthRows : tools.filteredEntries
                spacing: 5

                delegate: Rectangle {
                    id: resultRow
                    required property var modelData
                    required property int index
                    width: resultsView.width
                    height: healthTab.selected ? 48 : 58
                    radius: tools.theme.panelButtonRadius !== undefined ? tools.theme.panelButtonRadius : tools.theme.tileRadius
                    color: !healthTab.selected && index === tools.selectedIndex ? tools.theme.fillHover : tools.theme.fillIdle
                    border.color: !healthTab.selected && index === tools.selectedIndex ? tools.theme.seal : tools.theme.sep
                    Accessible.role: healthTab.selected ? Accessible.StaticText : Accessible.Button
                    Accessible.name: healthTab.selected
                        ? modelData.label + ": " + modelData.value
                        : modelData.title + ", " + modelData.category
                    objectName: healthTab.selected
                        ? "control-panel-health-row-" + resultRow.modelData.label.toLowerCase().replace(/ /g, "-")
                        : "control-panel-search-result-" + resultRow.modelData.id

                    Column {
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 2
                        Text {
                            width: parent.width
                            text: healthTab.selected
                                ? resultRow.modelData.label + "  ·  " + resultRow.modelData.value
                                : resultRow.modelData.title + "  ·  " + resultRow.modelData.category
                            color: tools.theme.ink
                            font.family: tools.theme.mono
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: resultRow.modelData.detail
                            color: tools.theme.sumiHi
                            font.family: tools.theme.mono
                            font.pixelSize: 9
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            maximumLineCount: 2
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !healthTab.selected
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: tools.selectedIndex = resultRow.index
                        onClicked: tools.selectResult(resultRow.modelData)
                    }
                }
            }

            Text {
                objectName: "control-panel-tools-no-results"
                visible: !healthTab.selected && tools.filteredEntries.length === 0
                width: parent.width
                text: "No matching controls."
                color: tools.theme.sumiHi
                font.family: tools.theme.mono
                font.pixelSize: 10
            }

            Text {
                width: parent.width
                text: healthTab.selected ? "READ-ONLY · NO ACCOUNTS OR NETWORK CALLS" : "↑ ↓ SELECT · ENTER OPEN · ESC CLEAR/BACK"
                color: tools.theme.sumi
                font.family: tools.theme.mono
                font.pixelSize: 8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }
}
