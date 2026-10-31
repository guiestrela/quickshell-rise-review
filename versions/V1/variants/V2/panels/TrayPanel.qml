pragma ComponentBehavior: Bound
import Quickshell
import "../modules"
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: trayPanel
    required property var root

    screen: trayPanel.root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-tray"
    // no mask → whole overlay is interactive (modal): click-outside + ESC work

    readonly property int barBottom: trayPanel.root.v2BarHeight
    readonly property int gap: 6
    readonly property int popupW: 328
    readonly property int maxListH: 320

    property real reveal: trayPanel.root.trayVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: trayPanel.root.trayVisible ? 160 : 120
            easing.type: trayPanel.root.trayVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: trayPanel.root.trayVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // auto-close when there are no hidden (unpinned) items left to show
    readonly property int hiddenCount: {
        var n = 0, vals = SystemTray.items.values
        for (var i = 0; i < vals.length; i++)
            if (trayPanel.root.trayPinned.indexOf(vals[i].id) < 0) n++
        return n
    }
    readonly property int attentionCount: {
        var n = 0, vals = SystemTray.items.values
        for (var i = 0; i < vals.length; i++)
            if (trayPanel.root.trayPinned.indexOf(vals[i].id) < 0 && vals[i].status === Status.NeedsAttention) n++
        return n
    }
    onHiddenCountChanged: if (trayPanel.root.trayVisible && hiddenCount === 0) trayPanel.root.trayVisible = false

    // click-outside-to-close: full-overlay dismiss area behind the card
    MouseArea { anchors.fill: parent; onClicked: trayPanel.root.trayVisible = false }

    Rectangle {
        id: card
        width: trayPanel.popupW
        height: col.implicitHeight + 24
        radius: trayPanel.reveal > 0.001 ? trayPanel.root.panelRadius : 0
        color: "transparent"
        border.color: trayPanel.root.panelBorder
        border.width: 0
        PillShadow { theme: trayPanel.root }
        ConnectedPanelSurface {
            root: trayPanel.root
            ownerActive: trayPanel.root.trayVisible
            targetX: trayPanel.root.trayCaretBarX
            reveal: trayPanel.reveal
        }

        SidePanelPositioner { root: trayPanel.root; target: parent; anchorName: "tray" }
        x: Math.round(Math.max(6, Math.min(trayPanel.root.trayBarX, parent.width - width - 6)))
        y: trayPanel.root.barPosition === "bottom"
            ? (parent.height - trayPanel.barBottom - trayPanel.gap - height) + 2 * (1 - trayPanel.reveal)
            : (trayPanel.barBottom + trayPanel.gap) - 2 * (1 - trayPanel.reveal)
        opacity: trayPanel.reveal
        focus: trayPanel.root.trayVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                trayPanel.root.trayVisible = false
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Match the updater's restrained title/count/close hierarchy.
            Item {
                width: parent.width
                height: 24

                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Tray Apps"
                    color: trayPanel.root.ink
                    font.family: trayPanel.root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }

                UiText {
                    anchors.right: closeX.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: trayPanel.hiddenCount + (trayPanel.hiddenCount === 1 ? " APP" : " APPS")
                        + (trayPanel.attentionCount > 0 ? "  ·  " + trayPanel.attentionCount + " ATTENTION" : "")
                    color: trayPanel.attentionCount > 0 ? trayPanel.root.seal : trayPanel.root.sumiHi
                    font.family: trayPanel.root.mono
                    font.pixelSize: 10
                }

                UiText {
                    id: closeX
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2715"
                    color: closeMa.containsMouse ? trayPanel.root.seal : trayPanel.root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: trayPanel.root.trayVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: trayPanel.root.sep }

            Item {
                width: parent.width
                height: Math.min(trayRows.implicitHeight, trayPanel.maxListH)

                Flickable {
                    id: appsFlick
                    anchors.fill: parent
                    contentHeight: trayRows.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: trayRows
                        width: appsFlick.width
                        spacing: 6

                        Repeater {
                            model: SystemTray.items

                            delegate: Item {
                                id: appRow
                                required property SystemTrayItem modelData
                                required property int index

                                readonly property string appName: trayPanel.root.trayDisplayName(modelData)
                                readonly property string appDescription: trayPanel.root.trayDescription(modelData, appName)
                                readonly property bool needsAttention: modelData.status === Status.NeedsAttention
                                readonly property string statusDescription: needsAttention
                                    ? "\u26a0 " + (appDescription !== "" ? appDescription : "Needs attention")
                                    : appDescription
                                readonly property int cellWidth: 96

                                width: trayRows.width
                                height: visible ? 28 : 0
                                visible: trayPanel.root.trayPinned.indexOf(modelData.id) < 0

                                function openAppMenu() {
                                    if (!modelData.hasMenu) return
                                    var gp = menuButton.mapToItem(null, 0, 0)
                                    trayPanel.root.openTrayMenu(modelData.menu,
                                                      gp.x + menuButton.width / 2 - 110,
                                                      appName, modelData.icon)
                                }

                                function activateApp() {
                                    var item = modelData
                                    trayPanel.root.trayVisible = false
                                    // Release the layer-shell keyboard focus before asking
                                    // the application to surface/focus its primary window.
                                    Qt.callLater(function() {
                                        if (item) item.activate()
                                    })
                                }

                                Rectangle {
                                    id: appButton
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: appRow.cellWidth
                                    height: 28
                                    radius: trayPanel.root.panelButtonRadius
                                    color: activateMa.containsMouse ? trayPanel.root.fillHover : trayPanel.root.fillIdle
                                    border.color: activateMa.containsMouse ? trayPanel.root.seal : trayPanel.root.sep
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Image {
                                        id: appIcon
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: appRow.modelData.icon
                                        sourceSize.width: 16
                                        sourceSize.height: 16
                                        width: 16
                                        height: 16
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }

                                    UiText {
                                        anchors.left: appIcon.right
                                        anchors.leftMargin: 6
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (appRow.needsAttention ? "\u26a0 " : "") + appRow.appName
                                        color: appRow.needsAttention ? trayPanel.root.seal
                                            : (activateMa.containsMouse ? trayPanel.root.seal : trayPanel.root.ink)
                                        font.family: trayPanel.root.mono
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    TooltipMixin {
                                        id: appTip
                                        root: trayPanel.root
                                        owner: appButton
                                        text: appRow.statusDescription !== ""
                                            ? appRow.appName + "\n" + appRow.statusDescription
                                            : appRow.appName
                                    }

                                    MouseArea {
                                        id: activateMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: appTip.show()
                                        onExited: appTip.hide()
                                        onClicked: {
                                            appTip.hide()
                                            if (appRow.modelData.onlyMenu && appRow.modelData.hasMenu)
                                                appRow.openAppMenu()
                                            else
                                                appRow.activateApp()
                                        }
                                    }
                                }

                                Rectangle {
                                    id: pinButton
                                    anchors.left: appButton.right
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: appRow.cellWidth
                                    height: 28
                                    radius: trayPanel.root.panelButtonRadius
                                    color: pinMa.containsMouse ? trayPanel.root.fillHover : trayPanel.root.fillIdle
                                    border.color: pinMa.containsMouse ? trayPanel.root.seal : trayPanel.root.sep
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    UiText {
                                        anchors.centerIn: parent
                                        text: "Pin"
                                        color: pinMa.containsMouse ? trayPanel.root.seal : trayPanel.root.ink
                                        font.family: trayPanel.root.mono
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: pinMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: trayPanel.root.trayToggleHide(appRow.modelData)
                                    }
                                }

                                Rectangle {
                                    id: menuButton
                                    anchors.left: pinButton.right
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: appRow.cellWidth
                                    height: 28
                                    radius: trayPanel.root.panelButtonRadius
                                    color: appRow.modelData.hasMenu
                                        ? (menuMa.containsMouse ? trayPanel.root.fillHover : trayPanel.root.fillIdle)
                                        : "transparent"
                                    border.color: appRow.modelData.hasMenu
                                        ? (menuMa.containsMouse ? trayPanel.root.seal : trayPanel.root.sep)
                                        : Qt.rgba(trayPanel.root.ink.r, trayPanel.root.ink.g, trayPanel.root.ink.b, 0.10)
                                    border.width: 1
                                    opacity: appRow.modelData.hasMenu ? 1.0 : 0.42
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    UiText {
                                        anchors.centerIn: parent
                                        text: appRow.modelData.hasMenu ? "AppMenu" : "No Menu"
                                        color: menuMa.containsMouse && appRow.modelData.hasMenu ? trayPanel.root.seal : trayPanel.root.ink
                                        font.family: trayPanel.root.mono
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: menuMa
                                        anchors.fill: parent
                                        enabled: appRow.modelData.hasMenu
                                        hoverEnabled: enabled
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: appRow.openAppMenu()
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
