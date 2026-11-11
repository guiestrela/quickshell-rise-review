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
    property Component shadowComponent: null
    property Component positionerComponent: null

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-traymenu"

    // drill-down stack of menu handles (root menu + any opened submenus)
    property var menuStack: []
    readonly property var currentHandle: menuStack.length > 0 ? menuStack[menuStack.length - 1] : null

    function strip(t) { return TrayMenuValuesLogic.strip(trayMenu, {}, t) }   // drop GTK mnemonic underscore

    // DBusMenu providers often populate submenu children only after receiving
    // the entry's opened event. Emit it explicitly, then render its children
    // in this themed panel instead of opening a native popup behind the overlay.
    function openSubmenu(entryHandle) { return TrayMenuLogic.openSubmenu(trayMenu, {}, entryHandle) }

    function goBack() { return TrayMenuLogic.goBack(trayMenu, {}) }

    Connections {
        target: trayMenu.root
        function onTrayMenuVisibleChanged() {
            trayMenu.menuStack = trayMenu.root.trayMenuVisible && trayMenu.root.trayMenuHandle ? [trayMenu.root.trayMenuHandle] : []
        }
    }

    QsMenuOpener {
        id: opener
        menu: trayMenu.currentHandle
    }

    property real reveal: trayMenu.root.trayMenuVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: trayMenu.root.trayMenuVisible ? 140 : 100; easing.type: Easing.OutCubic }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: trayMenu.root.trayMenuVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: trayMenu.root.trayMenuVisible = false }

    Rectangle {
        id: card
        width: 220
        height: col.implicitHeight + 16
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
                visible: trayMenu.menuStack.length > 1
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
                width: parent.width; height: 1; color: trayMenu.root.sep
                visible: trayMenu.menuStack.length > 1
            }

            Repeater {
                model: opener.children

                delegate: Item {
                    id: entry
                    required property var modelData
                    width: col.width
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
    Loader {
        sourceComponent: trayMenu.positionerComponent
    }
}
