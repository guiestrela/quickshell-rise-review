pragma ComponentBehavior: Bound
import QtQuick
import "../logic/TrayMenuValuesLogic.js" as TrayMenuValuesLogic
import "../logic/TrayMenuLogic.js" as TrayMenuLogic
import Quickshell
import Quickshell.Wayland
import "../components" as CommonComponents

// Themed system-tray context menu, rendered from the DBusMenu model so it
// matches the bar and keeps submenu navigation inside the Rise overlay.
PanelWindow {
    id: trayMenu
    required property var root

    screen: trayMenu.root.activePopupScreen
    property alias cardTarget: card
    property int barBottom: 35
    property int gap: 8
    property real cardRadius: trayMenu.root.pillRadius
    property color cardBorderColor: trayMenu.root.pillBorder
    property int cardBorderWidth: trayMenu.root.pillBorderW
    property real rowRadius: trayMenu.root.tileRadius
    readonly property int maxCardHeight: Math.max(160,
        Math.min(500, trayMenu.height - trayMenu.barBottom - trayMenu.gap - 12))
    readonly property int maxListHeight: Math.max(80, trayMenu.maxCardHeight - 96)
    property Component shadowComponent: null
    property Component positionerComponent: null

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-traymenu"

    // Keep one live opener per submenu level. A child entry belongs to the
    // parent's children model, so replacing the single root opener destroys
    // the entry before its submenu can populate.
    property var menuStack: []
    readonly property var currentChildren: menuStack.length > 0
        ? menuStack[menuStack.length - 1].opener.children : opener.children

    function strip(t) { return TrayMenuValuesLogic.strip(trayMenu, {}, t) }   // drop GTK mnemonic underscore

    function openSubmenu(entryHandle) {
        menuFlick.contentY = 0
        return TrayMenuLogic.openSubmenu(trayMenu, {}, entryHandle, submenuOpenerComponent)
    }

    function goBack() {
        menuFlick.contentY = 0
        return TrayMenuLogic.goBack(trayMenu, {})
    }
    function resetSubmenus() { return TrayMenuLogic.resetSubmenus(trayMenu, {}) }

    Connections {
        target: trayMenu.root
        function onTrayMenuVisibleChanged() {
            if (trayMenu.root.trayMenuVisible) trayMenu.resetSubmenus()
        }
        function onTrayMenuHandleChanged() { trayMenu.resetSubmenus() }
    }

    Component { id: submenuOpenerComponent; QsMenuOpener {} }

    QsMenuOpener {
        id: opener
        menu: trayMenu.root.trayMenuHandle
    }

    property real reveal: trayMenu.root.trayMenuVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: trayMenu.root.trayMenuVisible ? 140 : 100; easing.type: Easing.OutCubic }
    }
    visible: reveal > 0.001
    onVisibleChanged: if (!visible) trayMenu.resetSubmenus()
    WlrLayershell.keyboardFocus: trayMenu.root.trayMenuVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: trayMenu.root.trayMenuVisible = false }

    Rectangle {
        id: card
        width: 220
        height: Math.min(col.implicitHeight + 16, trayMenu.maxCardHeight)
        radius: trayMenu.reveal > 0.001 ? trayMenu.cardRadius : 0
        color: trayMenu.root.bg
        border.color: trayMenu.cardBorderColor
        border.width: trayMenu.cardBorderWidth
        Loader {
            anchors.fill: parent
            sourceComponent: trayMenu.shadowComponent
        }

        x: parent ? Math.max(6, Math.min(trayMenu.root.trayMenuX, parent.width - width - 6)) : 6
        y: trayMenu.root.barPosition === "bottom" ? (parent.height - trayMenu.barBottom - trayMenu.gap - height) : (trayMenu.barBottom + trayMenu.gap)
        opacity: trayMenu.reveal
        focus: trayMenu.root.trayMenuVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { trayMenu.root.trayMenuVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 8
            spacing: 1

            // App identity stays visible while navigating its DBusMenu tree.
            Item {
                width: parent.width
                height: 28

                Image {
                    id: appIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    visible: trayMenu.root.trayMenuIcon !== ""
                    source: trayMenu.root.trayMenuIcon
                    sourceSize.width: 16
                    sourceSize.height: 16
                    width: visible ? 16 : 0
                    height: 16
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                CommonComponents.UiText {
                    anchors.left: appIcon.right
                    anchors.leftMargin: appIcon.visible ? 8 : 0
                    anchors.right: closeX.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: trayMenu.root.trayMenuTitle !== "" ? trayMenu.root.trayMenuTitle : "App Menu"
                    color: trayMenu.root.ink
                    font.family: trayMenu.root.mono
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                CommonComponents.UiText {
                    id: closeX
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2715"
                    color: closeMa.containsMouse ? trayMenu.root.seal : trayMenu.root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: trayMenu.root.trayMenuVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: trayMenu.root.sep }

            // back row (only when inside a submenu)
            Rectangle {
                width: parent.width; height: 24; radius: trayMenu.rowRadius
                visible: trayMenu.menuStack.length > 0
                color: backMa.containsMouse ? trayMenu.root.fillHover : "transparent"
                CommonComponents.UiText {
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹  back"; color: trayMenu.root.sumiHi
                    font.family: trayMenu.root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: backMa
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: trayMenu.goBack()
                }
            }
            Rectangle {
                width: parent.width; height: visible ? 1 : 0; color: trayMenu.root.sep
                visible: trayMenu.menuStack.length > 0
            }

            Flickable {
                id: menuFlick
                width: parent.width
                height: Math.min(menuRows.implicitHeight, trayMenu.maxListHeight)
                contentWidth: width
                contentHeight: menuRows.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: menuRows
                    width: menuFlick.width

                    Repeater {
                        model: trayMenu.currentChildren

                        delegate: Item {
                            id: entry
                            required property var modelData
                            width: menuRows.width
                            height: modelData.isSeparator ? 7 : 26

                            // separator
                            Rectangle {
                                visible: entry.modelData.isSeparator
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 1
                                color: trayMenu.root.sep
                            }

                            // entry row
                            Rectangle {
                                visible: !entry.modelData.isSeparator
                                anchors.fill: parent
                                radius: trayMenu.rowRadius
                                color: (entryMa.containsMouse && entry.modelData.enabled)
                                    ? trayMenu.root.fillActive : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                // check / radio indicator
                                CommonComponents.UiText {
                                    id: check
                                    anchors.left: parent.left; anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 12
                                    text: entry.modelData.checkState === Qt.Checked ? "✓" : ""
                                    color: trayMenu.root.seal
                                    font.family: trayMenu.root.mono; font.pixelSize: 11
                                }

                                Image {
                                    id: entryIcon
                                    anchors.left: check.right; anchors.leftMargin: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: (entry.modelData.icon || "") !== ""
                                    source: entry.modelData.icon || ""
                                    sourceSize.width: 14; sourceSize.height: 14
                                    width: visible ? 14 : 0; height: 14
                                    fillMode: Image.PreserveAspectFit; smooth: true
                                }

                                CommonComponents.UiText {
                                    anchors.left: entryIcon.right; anchors.leftMargin: 6
                                    anchors.right: arrow.left; anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: trayMenu.strip(entry.modelData.text)
                                    color: entry.modelData.enabled ? trayMenu.root.ink
                                         : Qt.rgba(trayMenu.root.ink.r, trayMenu.root.ink.g, trayMenu.root.ink.b, 0.35)
                                    font.family: trayMenu.root.mono; font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                // submenu arrow
                                CommonComponents.UiText {
                                    id: arrow
                                    anchors.right: parent.right; anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: entry.modelData.hasChildren
                                    text: "›"; color: trayMenu.root.sumiHi
                                    font.family: trayMenu.root.mono; font.pixelSize: 13
                                }

                                MouseArea {
                                    id: entryMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: entry.modelData.enabled
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (entry.modelData.hasChildren) {
                                            trayMenu.openSubmenu(entry.modelData)
                                        } else {
                                            entry.modelData.triggered()
                                            trayMenu.root.trayMenuVisible = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Loader {
        sourceComponent: trayMenu.positionerComponent
    }
}
