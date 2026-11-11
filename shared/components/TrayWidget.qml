pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import "../logic/TrayWidgetValuesLogic.js" as TrayWidgetValuesLogic
import "../components" as CommonComponents

Item {
    id: rootMod
    required property var root
    required property color contentColor
    required property color badgeColor
    required property color badgeTextColor
    // V1 Row reserved space only for visible cells; V2 Grid reserves model columns.
    required property bool reserveHiddenColumns
    required property bool verticalLayout
    required property real cellWidth
    required property real toggleWidth
    required property real cellSpacing
    property string screenName: rootMod.root.activePopupScreenName

    implicitWidth: trayRow.implicitWidth
    implicitHeight: rootMod.verticalLayout ? trayRow.implicitHeight : 28
    visible: trayRow.implicitWidth > 0

    function toggleHide(item) { return TrayWidgetValuesLogic.toggleHide(rootMod, {}, item) }

    Grid {
        id: trayRow
        columns: rootMod.verticalLayout ? 1 : rootMod.reserveHiddenColumns ? trayItems.count + 1 : Math.max(1, visibleCellCount)
        readonly property int visibleCellCount: {
            var count = toggleBtn.hasDrawer ? 1 : 0
            var values = SystemTray.items.values
            for (var i = 0; i < values.length; i++)
                if (rootMod.root.trayPinned.indexOf(values[i].id) >= 0) count++
            return count
        }
        anchors.centerIn: parent
        spacing: rootMod.cellSpacing

        Repeater {
            id: trayItems
            model: SystemTray.items

            delegate: Item {
                id: trayDelegate
                required property SystemTrayItem modelData

                // System-tray actions share the bar's compact 24px centre pitch:
                // 22px action cell plus the surrounding Row's 2px cluster gap.
                implicitWidth: rootMod.cellWidth
                implicitHeight: 28
                visible: rootMod.root.trayPinned.indexOf(modelData.id) >= 0

                Image {
                    anchors.centerIn: parent
                    source: modelData.icon
                    sourceSize.width: 14
                    sourceSize.height: 14
                    width: 14
                    height: 14
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (e) => {
                        if (e.button === Qt.LeftButton)
                            modelData.activate()
                        else if (e.button === Qt.RightButton)
                            rootMod.toggleHide(modelData)
                    }
                }
            }
        }

        // ── toggle: more_horiz icon + seal count badge ──
        Item {
            id: toggleBtn
            implicitWidth: rootMod.toggleWidth
            implicitHeight: 28
            visible: hasDrawer

            // count CURRENTLY-EXISTING tray items that are not pinned (= hidden behind this
            // button), iterating SystemTray.items so stale pinned IDs can't inflate the count
            readonly property int hiddenCount: {
                var n = 0, vals = SystemTray.items.values
                for (var i = 0; i < vals.length; i++) if (rootMod.root.trayPinned.indexOf(vals[i].id) < 0) n++
                return n
            }
            readonly property int drawerWidgetCount: rootMod.root.trayWidgets.length
            readonly property bool hasDrawer: hiddenCount > 0 || drawerWidgetCount > 0
            readonly property int totalCount:  SystemTray.items.values.length
            readonly property string tooltipText: totalCount + (totalCount === 1 ? " app" : " apps")
                                                  + (hiddenCount > 0 ? " · " + hiddenCount + " hidden" : "")
                                                  + (drawerWidgetCount > 0 ? " · " + drawerWidgetCount + " widgets" : "")
                                                  + (hasDrawer ? " · hover to open" : "")

            CommonComponents.TooltipMixin { id: tip; root: rootMod.root; owner: toggleBtn; text: toggleBtn.tooltipText }

            CommonComponents.IconText {
                id: moreIcon
                anchors.centerIn: parent
                text: "\uE5D3"   // more_horiz
                font.pixelSize: 16
                color: toggleMa.containsMouse
                    ? rootMod.contentColor
                    : Qt.rgba(rootMod.contentColor.r, rootMod.contentColor.g, rootMod.contentColor.b, 0.7)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // count badge — top-right
            Rectangle {
                id: toggleBadge
                visible: toggleBtn.hasDrawer
                width: Math.max(12, toggleBadgeTxt.implicitWidth + 6)
                height: 12
                radius: 6
                color: rootMod.badgeColor
                anchors.verticalCenter: moreIcon.verticalCenter
                anchors.verticalCenterOffset: -6
                anchors.horizontalCenter: moreIcon.horizontalCenter
                anchors.horizontalCenterOffset: 7
                Text {
                    id: toggleBadgeTxt
                    anchors.centerIn: parent
                    text: toggleBtn.hiddenCount + toggleBtn.drawerWidgetCount
                    color: rootMod.badgeTextColor
                    font.family: rootMod.root.mono
                    font.pixelSize: 7
                    font.weight: Font.Bold
                }
            }

            MouseArea {
                id: toggleMa
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    if (rootMod.root.barUnlocked) {
                        tip.hide()
                        rootMod.root.trayHovering = false
                        return
                    }
                    // The drawer is click-to-open. Hover only tracks pointer
                    // presence so an already-open drawer can remain available.
                    rootMod.root.trayHovering = true
                }
                onExited: {
                    tip.hide()
                    rootMod.root.trayHovering = false
                }
                onClicked: (event) => {
                    tip.hide()
                    if (event.button === Qt.RightButton)
                        rootMod.root.trayVisible = true
                    else
                        rootMod.root.trayVisible = !rootMod.root.trayVisible
                }
            }
        }
    }
}
