import QtQuick
import QtTest
import "../shared/integrations/elsewhen" as Elsewhen

Item {
    id: testRoot
    width: 420
    height: 140

    QtObject {
        id: fakeTheme
        property color bg: "#1d2021"
        property color ink: "#ebdbb2"
        property color seal: "#d79921"
        property color sep: "#504945"
        property color fillIdle: "#282828"
        property color fillHover: "#3c3836"
        property string mono: "monospace"
        property int tileRadius: 7
    }

    QtObject {
        id: fakePanel
        property var root: fakeTheme
        property var modelRows: [
            { label: "Paris", id: "Europe/Paris", ready: true, time: "1:00", meridiem: "PM",
              abbr: "CET", date: "Wed Mar 20", dayLabel: "", offsetMinutes: 60,
              relative: "+1h", progress: 0.5, lit: true }
        ]
        property var displayRows: modelRows
        property var profiles: ({})
        property int profileStamp: 0
        property bool hour24: false
        property string keyboardFocusId: ""
        property int peopleEditIndex: -1
        property int startedPeopleEdit: -1
        property int finishedPeopleEdit: -1
        property int cancelledPeopleEdit: 0
        property string submittedPeople: ""
        property int dragStartCount: 0
        property int dragMoveCount: 0
        property int dragReleaseCount: 0
        property int dragCancelCount: 0
        property int draggedIndex: -1
        property real dragOffset: 0
        function startPeopleEdit(index) { startedPeopleEdit = index; peopleEditIndex = index }
        function finishPeopleEdit(index, text) { finishedPeopleEdit = index; submittedPeople = text; peopleEditIndex = -1 }
        function cancelPeopleEdit() { cancelledPeopleEdit++; peopleEditIndex = -1 }
        function toggleHour24() {}
        function toggleOffsetMode() {}
        function toggleUnits() {}
        function offsetTextFor(rowData) { return rowData.relative }
        function weatherGlyph(rowData) { return "" }
        function beginScrub(rowData, fraction) {}
        function scrubTo(rowData, fraction) {}
        function endScrub() {}
        function focusOn(index) {}
        function beginRowDrag(index, pitch) { dragStartCount++; draggedIndex = index }
        function moveRowDrag(offset) { dragMoveCount++; dragOffset = offset }
        function releaseRowDrag() { dragReleaseCount++ }
        function cancelRowDrag() { dragCancelCount++ }
        function removeCityAt(index) {}
        function startMoonShow() {}
    }

    Elsewhen.CityRow {
        id: cityRow
        anchors.fill: parent
        panel: fakePanel
        modelData: ({ label: "Paris", id: "Europe/Paris", people: ["Alice", "@alice"] })
        index: 0
    }

    TestCase {
        name: "ElsewhenCityRow"
        when: windowShown

        function init() {
            fakePanel.peopleEditIndex = -1
            fakePanel.startedPeopleEdit = -1
            fakePanel.finishedPeopleEdit = -1
            fakePanel.cancelledPeopleEdit = 0
            fakePanel.submittedPeople = ""
        }

        function openPeopleEditor() {
            mouseMove(cityRow, cityRow.width / 2, cityRow.height / 2)
            wait(40)
            var button = findChild(cityRow, "elsewhen-people-edit")
            verify(button !== null)
            verify(button.visible)
            mouseClick(button, button.width / 2, button.height / 2)
            tryCompare(fakePanel, "peopleEditIndex", 0)
            var field = findChild(cityRow, "elsewhen-people-field")
            tryCompare(field, "visible", true)
            tryCompare(field, "activeFocus", true)
            return field
        }

        function test_keyboard_focus_has_visible_row_accent() {
            fakePanel.keyboardFocusId = "Europe/Paris"
            compare(cityRow.border.color, fakeTheme.seal)
            fakePanel.keyboardFocusId = "Asia/Tokyo"
            compare(cityRow.border.color, fakeTheme.sep)
        }

        function test_hovered_people_action_opens_prefilled_editor() {
            var field = openPeopleEditor()
            verify(field !== null)
            tryCompare(field, "visible", true)
            compare(field.text, "Alice, @alice")
            compare(fakePanel.startedPeopleEdit, 0)
        }

        function test_body_drag_routes_row_reorder() {
            fakePanel.dragStartCount = 0
            fakePanel.dragMoveCount = 0
            fakePanel.dragReleaseCount = 0
            fakePanel.dragCancelCount = 0
            var area = findChild(cityRow, "elsewhen-city-drag-area")
            verify(area !== null)
            mouseDrag(area, 35, 38, 0, 24, Qt.LeftButton)
            compare(fakePanel.dragStartCount, 1)
            verify(fakePanel.dragMoveCount > 0)
            compare(fakePanel.dragReleaseCount, 1)
            compare(fakePanel.dragOffset, 24)
        }

        function test_enter_commits_people_notes() {
            var field = openPeopleEditor()
            verify(field !== null)
            tryCompare(field, "visible", true)
            field.text = "Alice, Bob"
            keyClick(Qt.Key_Return)
            compare(fakePanel.finishedPeopleEdit, 0)
            compare(fakePanel.submittedPeople, "Alice, Bob")
        }

        function test_escape_cancels_people_notes() {
            var field = openPeopleEditor()
            verify(field !== null)
            tryCompare(field, "visible", true)
            field.text = "discard me"
            keyClick(Qt.Key_Escape)
            compare(fakePanel.cancelledPeopleEdit, 1)
            compare(fakePanel.peopleEditIndex, -1)
        }
    }
}
