import QtQuick
import QtTest
import "../shared/components" as Shared

Item {
    id: testRoot
    width: 240
    height: 96

    QtObject {
        id: fakeTheme
        property bool modElsewhen: true
        property bool elsewhenVisible: false
        property bool barVertical: false
        property int pillH: 28
        property string mono: "monospace"
        property color ink: "#e6e6e6"
        property color seal: "#d8a657"
        property bool barUnlocked: false
        property var tooltipOwner: null
        property string tooltipText: ""
        property int tooltipShows: 0
        property int tooltipHides: 0
        property int refreshRequests: 0
        property int toggleRequests: 0
        function showTooltip(text, topX, topY, bottomY, owner) { tooltipShows++ }
        function hideTooltip(owner) { tooltipHides++ }
        function refreshElsewhen() { refreshRequests++ }
        function toggleElsewhen(screen, item) { toggleRequests++; elsewhenVisible = !elsewhenVisible }
    }

    Shared.ElsewhenWidget {
        id: widget
        anchors.centerIn: parent
        width: 40
        height: fakeTheme.pillH
        root: fakeTheme
        contentColor: fakeTheme.ink
    }

    TestCase {
        name: "ElsewhenWidget"
        when: windowShown

        function test_click_toggles_shared_popup_state() {
            fakeTheme.elsewhenVisible = false
            fakeTheme.toggleRequests = 0
            mouseClick(widget, widget.width / 2, widget.height / 2, Qt.LeftButton)
            compare(fakeTheme.elsewhenVisible, true)
            compare(fakeTheme.toggleRequests, 1)
            mouseClick(widget, widget.width / 2, widget.height / 2, Qt.LeftButton)
            compare(fakeTheme.elsewhenVisible, false)
            compare(fakeTheme.toggleRequests, 2)
        }

        function test_secondary_clicks_refresh_without_opening() {
            fakeTheme.elsewhenVisible = false
            fakeTheme.refreshRequests = 0
            mouseClick(widget, widget.width / 2, widget.height / 2, Qt.RightButton)
            mouseClick(widget, widget.width / 2, widget.height / 2, Qt.MiddleButton)
            compare(fakeTheme.refreshRequests, 2)
            compare(fakeTheme.elsewhenVisible, false)
        }

        function test_horizontal_and_vertical_keep_the_module_sized() {
            fakeTheme.modElsewhen = true
            fakeTheme.barVertical = false
            var horizontalWidth = widget.implicitWidth
            verify(horizontalWidth > 0)
            fakeTheme.barVertical = true
            compare(widget.implicitWidth, horizontalWidth)
        }

        function test_disabled_module_releases_its_slot() {
            fakeTheme.modElsewhen = false
            compare(widget.implicitWidth, 0)
            compare(widget.visible, false)
        }
    }
}
