pragma ComponentBehavior: Bound
import QtQuick
import "." as CommonComponents

// Preference-only picker. The owner supplies the commit callback; this control
// never connects a VPN or applies auto-connect settings.
FocusScope {
    id: selector
    required property var palette
    property var countries: []
    property string selectedCountry: ""
    property var selectCountry: function(country) { return false }
    property string namePrefix: "vpn-country"
    property string optionPrefix: namePrefix + "-option-"
    property real buttonRadius: 0
    property int pixelSize: 10
    property int rowHeight: 26
    property int maximumListHeight: 112
    property bool showArrow: true
    property bool expanded: false
    property string query: ""
    property Item listHost: selector
    readonly property alias mouseHandler: fieldMouse
    readonly property alias input: editor
    readonly property alias optionsView: options
    readonly property var filteredCountries: {
        const needle = normalize(query)
        return countries.filter(function(country) { return normalize(country).indexOf(needle) >= 0 })
    }
    readonly property real popupHeight: expanded ? Math.max(rowHeight, Math.min(filteredCountries.length * rowHeight, maximumListHeight)) : 0
    height: 28
    activeFocusOnTab: true

    function normalize(value) { return String(value).replace(/_/g, " ").toLowerCase() }
    function resetHighlight() {
        const selected = filteredCountries.indexOf(selectedCountry)
        options.currentIndex = selected >= 0 ? selected : (filteredCountries.length ? 0 : -1)
        Qt.callLater(function() {
            if (options.currentIndex >= 0) options.positionViewAtIndex(options.currentIndex, ListView.Contain)
        })
    }
    function open() {
        if (!enabled) return
        query = ""
        editor.text = ""
        expanded = true
        editor.forceActiveFocus()
        resetHighlight()
    }
    function cancel() { expanded = false; query = ""; editor.text = "" }
    function confirm(country) {
        if (!enabled || countries.indexOf(country) < 0) return
        if (selectCountry(country)) cancel()
    }
    onFilteredCountriesChanged: resetHighlight()
    onExpandedChanged: {
        if (expanded) { query = ""; editor.text = ""; resetHighlight() }
        else { query = ""; editor.text = "" }
    }
    onActiveFocusChanged: if (!activeFocus && expanded) cancel()
    onEnabledChanged: if (!enabled) cancel()

    Rectangle {
        anchors.fill: parent
        radius: selector.buttonRadius
        color: fieldMouse.containsMouse ? selector.palette.fillHover : selector.palette.fillIdle
        border.color: selector.expanded || selector.activeFocus ? selector.palette.seal : selector.palette.sep
        CommonComponents.UiText {
            anchors.left: parent.left; anchors.leftMargin: selector.showArrow ? 9 : 8
            anchors.right: parent.right; anchors.rightMargin: selector.showArrow ? 24 : 8
            anchors.verticalCenter: parent.verticalCenter
            visible: !selector.expanded
            text: selector.selectedCountry || "Choose country"
            color: selector.palette.ink; font.family: selector.palette.mono; font.pixelSize: selector.pixelSize
            elide: Text.ElideRight
        }
        TextInput {
            id: editor
            objectName: selector.namePrefix + "-input"
            anchors.left: parent.left; anchors.leftMargin: selector.showArrow ? 9 : 8
            anchors.right: parent.right; anchors.rightMargin: selector.showArrow ? 24 : 8
            anchors.verticalCenter: parent.verticalCenter
            focus: true; activeFocusOnTab: false
            z: selector.expanded ? 1 : 0
            color: selector.expanded ? selector.palette.ink : "transparent"
            font.family: selector.palette.mono; font.pixelSize: selector.pixelSize
            selectionColor: selector.palette.seal
            clip: true; selectByMouse: true
            onTextEdited: selector.query = text
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape && selector.expanded) {
                    selector.cancel(); event.accepted = true
                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    selector.cancel() // Let native focus traversal continue, never commit.
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (!selector.expanded) selector.open()
                    else if (options.currentIndex >= 0 && options.currentIndex < selector.filteredCountries.length)
                        selector.confirm(selector.filteredCountries[options.currentIndex])
                    event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                    if (!selector.expanded) selector.open()
                    else if (selector.filteredCountries.length) {
                        options.currentIndex = Math.max(0, Math.min(selector.filteredCountries.length - 1,
                            options.currentIndex + (event.key === Qt.Key_Down ? 1 : -1)))
                        options.positionViewAtIndex(options.currentIndex, ListView.Contain)
                    }
                    event.accepted = true
                } else if (event.text && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    if (!selector.expanded) selector.open()
                }
            }
        }
        CommonComponents.UiText {
            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            visible: selector.showArrow
            text: selector.expanded ? "▴" : "▾"; color: selector.palette.sumiHi; font.pixelSize: 10
        }
        MouseArea {
            id: fieldMouse
            objectName: selector.namePrefix + "-select"
            anchors.fill: parent; hoverEnabled: true
            onClicked: { selector.forceActiveFocus(); if (selector.expanded) selector.cancel(); else selector.open() }
        }
    }
    ListView {
        id: options
        objectName: selector.namePrefix + "-options"
        parent: selector.listHost
        y: parent === selector ? selector.height : 0
        width: parent.width; height: selector.popupHeight
        visible: selector.expanded; clip: true
        model: selector.filteredCountries
        boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
            id: entry
            required property string modelData
            required property int index
            width: options.width; height: selector.rowHeight
            color: optionMouse.containsMouse || options.currentIndex === index ? selector.palette.fillHover : selector.palette.fillIdle
            CommonComponents.UiText {
                anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.replace(/_/g, " ")
                color: selector.palette.ink; font.family: selector.palette.mono; font.pixelSize: selector.pixelSize
            }
            MouseArea {
                id: optionMouse
                objectName: selector.optionPrefix + entry.modelData
                anchors.fill: parent; hoverEnabled: true
                onClicked: selector.confirm(entry.modelData)
            }
        }
        CommonComponents.UiText {
            objectName: selector.namePrefix + "-no-results"
            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
            visible: selector.filteredCountries.length === 0
            text: "No countries found"
            color: selector.palette.sumiHi; font.family: selector.palette.mono; font.pixelSize: selector.pixelSize
        }
    }
}
