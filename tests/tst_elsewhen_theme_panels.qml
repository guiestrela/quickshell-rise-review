import QtQuick
import QtTest
import "../shared/logic/ThemePanels.js" as Panels

Item {
    id: testRoot
    width: 800
    height: 600

    QtObject {
        id: state
        property var activePopupScreen: null
        property string activePopupScreenName: ""
        property real elsewhenBarX: 0
        property bool elsewhenVisible: false
        property int closeCalls: 0
        property string lastCloseExcept: ""
        function activatePopupScreen(screen) {
            activePopupScreen = screen
            activePopupScreenName = screen.name
        }
        function closePopups(except) {
            closeCalls++
            lastCloseExcept = except
        }
    }

    Rectangle {
        id: anchor
        x: 150
        y: 20
        width: 28
        height: 28
    }

    TestCase {
        name: "ElsewhenThemePanels"
        when: windowShown

        function init() {
            state.activePopupScreen = null
            state.activePopupScreenName = ""
            state.elsewhenBarX = 0
            state.elsewhenVisible = false
            state.closeCalls = 0
            state.lastCloseExcept = ""
        }

        function test_toggle_routes_screen_anchor_and_exclusivity() {
            var screen = { name: "DP-1", width: 800, height: 600 }
            var expected = anchor.mapToItem(null, anchor.width / 2, anchor.height).x
            verify(Panels.toggleElsewhen(state, {}, screen, anchor))
            verify(state.elsewhenVisible)
            compare(state.activePopupScreenName, "DP-1")
            compare(state.elsewhenBarX, expected)
            compare(state.closeCalls, 1)
            compare(state.lastCloseExcept, "elsewhenVisible")
            verify(Panels.toggleElsewhen(state, {}, screen, anchor))
            verify(!state.elsewhenVisible)
            compare(state.closeCalls, 1)
        }

        function test_missing_screen_is_rejected_without_side_effects() {
            verify(!Panels.toggleElsewhen(state, {}, null, anchor))
            verify(!Panels.toggleElsewhen(state, {}, { name: "" }, anchor))
            verify(!state.elsewhenVisible)
            compare(state.closeCalls, 0)
        }
    }
}
