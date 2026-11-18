import QtQuick
import QtTest

Item {
    id: host
    width: 800; height: 1500
    property var panel
    QtObject {
        id: theme
        property bool vpnVisible: true
        property var activePopupScreen: null
        property int vpnBarX: 400
        property string barPosition: "top"
        property int barBottom: 0
        property int v2BarHeight: 0
        property int pillRadius: 8
        property int panelRadius: 14
        property int tileRadius: 5
        property int panelButtonRadius: 5
        property color bg: "#202020"
        property color pillBorder: "#505050"
        property int pillBorderW: 1
        property color panelBorder: "#505050"
        property color ink: "#eeeeee"
        property color sumi: "#858585"
        property color sumiHi: "#b5b5b5"
        property color seal: "#ff5b35"
        property color sep: "#454545"
        property color fillActive: "#40251e"
        property color fillHover: "#383838"
        property color fillIdle: "#242424"
        property color color01: "#ff5b35"
        property string mono: "monospace"
    }
    QtObject {
        id: fakeController
        property string preferredCountry: "Brazil"
        property string preferredAutoCountry: "Japan"
        property var countryOptions: ["Brazil", "Canada", "Japan", "United_Kingdom", "United_States"]
        property string countriesState: "Ready"
        property bool canMutate: true
        property bool vpnConnected: false
        property string vpnState: "Disconnected"
        property string vpnCountry: ""
        property string vpnActiveProtocol: ""
        property string vpnActionMessage: ""
        property string vpnMessage: ""
        property var vpnSettings: ({technology: "NORDLYNX", "auto-connect": "disabled"})
        property var selections: []
        property int mutations: 0
        property bool reject: false
        function selectPreferredCountry(country, auto) {
            selections = selections.concat([[country, auto]])
            if (reject) { vpnMessage = "Selection rejected"; return false }
            if (auto) preferredAutoCountry = country
            else preferredCountry = country
            return true
        }
        function connectVpnCountry(country) { mutations++ }
        function connectVpn() { mutations++ }
        function disconnectVpn() { mutations++ }
        function setAutoConnect(value, country) { mutations++; return true }
    }
    Component { id: v1; PanelV1 { width: host.width; height: host.height; root: theme; controller: fakeController } }
    Component { id: v2; PanelV2 { width: host.width; height: host.height; root: theme; controller: fakeController } }
    Component {
        id: standalone
        CountrySelector {
            width: 222; x: 100; y: 100
            palette: theme; countries: fakeController.countryOptions
            selectedCountry: fakeController.preferredCountry
            selectCountry: function(country) { return fakeController.selectPreferredCountry(country, false) }
        }
    }
    TestCase {
        name: "NordVpnCountryKeyboard"
        when: windowShown
        function init() {
            fakeController.preferredCountry = "Brazil"; fakeController.preferredAutoCountry = "Japan"
            fakeController.selections = []; fakeController.mutations = 0; fakeController.reject = false
            fakeController.countryOptions = ["Brazil", "Canada", "Japan", "United_Kingdom", "United_States"]
            fakeController.countriesState = "Ready"; fakeController.canMutate = true
            fakeController.vpnMessage = ""; theme.vpnVisible = true
        }
        function cleanup() { if (host.panel) { host.panel.destroy(); host.panel = null }; host.height = 1500; wait(20) }
        function cases() { return [{tag:"V1", variant:v1}, {tag:"V2", variant:v2}] }
        function test_filter_confirm_data() { return cases() }
        function test_cancel_focus_and_buttons_data() { return cases() }
        function load(data) { host.panel = data.variant.createObject(host); verify(host.panel !== null); wait(200) }
        function clickField(prefix) {
            var field = findChild(host.panel, prefix + "-select")
            verify(field !== null); mouseClick(field, field.width / 2, field.height / 2); wait(20)
            return findChild(host.panel, prefix + "-input")
        }
        function typeText(text) { for (var ch of text) keyClick(ch) }
        function test_cancel_focus_and_buttons(data) {
            load(data)
            var input = clickField("vpn-country")
            typeText("can")
            keyClick(Qt.Key_Escape); wait(20)
            compare(theme.vpnVisible, true); compare(host.panel.countryChooserExpanded, false)
            compare(fakeController.preferredCountry, "Brazil"); compare(fakeController.selections.length, 0)
            keyClick(Qt.Key_Escape); compare(theme.vpnVisible, false)
            theme.vpnVisible = true; wait(180)
            input = clickField("vpn-country"); typeText("can")
            keyClick(Qt.Key_Tab); wait(20)
            compare(host.panel.countryChooserExpanded, false)
            var connect = findChild(host.panel, "vpn-country-connect")
            verify(connect.parent.activeFocus, "Tab must reach Connect without committing the draft")
            compare(connect.parent.border.color, theme.seal, "Keyboard focus must be visible")
            compare(fakeController.selections.length, 0); compare(fakeController.mutations, 0)
            keyClick(Qt.Key_Backtab); wait(20); verify(input.activeFocus)
            keyClick(Qt.Key_Tab); keyClick(Qt.Key_Return); compare(fakeController.mutations, 1)
            fakeController.mutations = 0
            clickField("vpn-autoconnect-country"); typeText("can")
            keyClick(Qt.Key_Tab); wait(20)
            var toggle = findChild(host.panel, "vpn-autoconnect-toggle")
            verify(toggle.parent.activeFocus); compare(toggle.parent.border.color, theme.seal)
            keyClick(Qt.Key_Tab); wait(20)
            var apply = findChild(host.panel, "vpn-autoconnect-apply")
            verify(apply.parent.activeFocus, "Tab must reach Apply")
            compare(apply.parent.border.color, theme.seal)
            compare(fakeController.selections.length, 0); compare(fakeController.mutations, 0)
            keyClick(Qt.Key_Return); compare(fakeController.mutations, 1)
        }
        function pickerCases() {
            var result = []
            for (var sample of cases()) for (var auto of [false, true])
                result.push({tag:sample.tag + (auto ? "-auto" : "-country"), variant:sample.variant, auto:auto,
                    prefix:auto ? "vpn-autoconnect-country" : "vpn-country"})
            return result
        }
        function test_edge_cases_data() { return pickerCases() }
        function test_edge_cases(data) {
            load(data)
            var input = clickField(data.prefix)
            var list = findChild(host.panel, data.prefix + "-options")
            typeText("nItEd_stAt"); wait(20)
            compare(list.count, 1); compare(list.currentIndex, 0)
            keyClick(Qt.Key_Return); wait(20)
            compare(fakeController.selections.length, 1)
            compare(fakeController.selections[0][0], "United_States")
            compare(fakeController.selections[0][1], data.auto)
            compare(fakeController.mutations, 0)
            input = clickField(data.prefix); compare(list.count, 5)
            typeText("zzzz"); wait(20)
            compare(list.count, 0); compare(list.currentIndex, -1)
            verify(findChild(host.panel, data.prefix + "-no-results").visible)
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Up); keyClick(Qt.Key_Return)
            compare(fakeController.selections.length, 1); compare(fakeController.mutations, 0)
            keyClick(Qt.Key_Escape); compare(theme.vpnVisible, true)
            clickField(data.prefix); compare(list.count, 5)
            compare(list.currentIndex, 4)
            fakeController.reject = true
            typeText("can"); keyClick(Qt.Key_Return); wait(20)
            compare(fakeController.selections.length, 2)
            compare(fakeController.vpnMessage, "Selection rejected")
            compare(data.auto ? fakeController.preferredAutoCountry : fakeController.preferredCountry, "United_States")
            compare(data.auto ? host.panel.autoCountryChooserExpanded : host.panel.countryChooserExpanded, true)
            keyClick(Qt.Key_Escape); fakeController.reject = false
            fakeController.countryOptions = []
            clickField(data.prefix); compare(list.count, 0)
            keyClick(Qt.Key_Down); keyClick(Qt.Key_Return); keyClick(Qt.Key_Escape)
            compare(fakeController.selections.length, 2); compare(fakeController.mutations, 0)
            fakeController.countriesState = "Loading"
            var field = findChild(host.panel, data.prefix + "-select")
            mouseClick(field, field.width / 2, field.height / 2)
            compare(data.auto ? host.panel.autoCountryChooserExpanded : host.panel.countryChooserExpanded, false)
            compare(fakeController.selections.length, 2); compare(fakeController.mutations, 0)
        }
        function test_filter_scroll_pointer_data() { return pickerCases() }
        function test_filter_scroll_pointer(data) {
            var countries = []
            for (var i = 0; i < 40; ++i) countries.push("Country_" + (i < 10 ? "0" : "") + i)
            fakeController.countryOptions = countries
            load(data); clickField(data.prefix)
            var list = findChild(host.panel, data.prefix + "-options")
            typeText("country_"); wait(20); compare(list.count, 40)
            for (var i = 0; i < 25; ++i) keyClick(Qt.Key_Down)
            wait(30); compare(list.currentIndex, 25); verify(list.contentY > 0)
            verify(list.currentItem.y >= list.contentY)
            verify(list.currentItem.y + list.currentItem.height <= list.contentY + list.height + 1)
            keyClick(Qt.Key_Up); compare(list.currentIndex, 24)
            keyClick(Qt.Key_Return); wait(20)
            compare(fakeController.selections[0][0], "Country_24")
            compare(fakeController.selections[0][1], data.auto); compare(fakeController.mutations, 0)
            clickField(data.prefix); wait(30)
            var option = findChild(host.panel, (data.auto ? "vpn-autoconnect-country-" : "vpn-country-option-") + "Country_24")
            verify(option !== null); mouseClick(option, option.width / 2, option.height / 2); wait(20)
            compare(fakeController.selections.length, 2); compare(fakeController.mutations, 0)
        }
        function test_exclusive_and_focus_loss_data() { return cases() }
        function test_exclusive_and_focus_loss(data) {
            load(data)
            clickField("vpn-country"); typeText("can")
            clickField("vpn-autoconnect-country")
            compare(host.panel.countryChooserExpanded, false); compare(host.panel.autoCountryChooserExpanded, true)
            typeText("can"); keyClick(Qt.Key_Backtab); wait(20)
            compare(host.panel.autoCountryChooserExpanded, false)
            compare(fakeController.selections.length, 0); compare(fakeController.mutations, 0)
            keyClick(Qt.Key_Tab); wait(20)
            verify(findChild(host.panel, "vpn-autoconnect-country-input").activeFocus)
            keyClick(Qt.Key_Down); wait(20)
            compare(findChild(host.panel, "vpn-autoconnect-country-options").count, 5)
            keyClick(Qt.Key_Escape); compare(theme.vpnVisible, true)
        }
        function test_panel_hide_discards_draft_data() { return cases() }
        function test_panel_hide_discards_draft(data) {
            load(data); clickField("vpn-country"); typeText("can")
            theme.vpnVisible = false
            compare(host.panel.countryChooserExpanded, false, "Closing the panel must discard picker drafts even during the reveal animation")
            theme.vpnVisible = true; wait(180)
            clickField("vpn-autoconnect-country"); typeText("can")
            theme.vpnVisible = false
            compare(host.panel.autoCountryChooserExpanded, false)
            compare(fakeController.selections.length, 0); compare(fakeController.mutations, 0)
        }
        function test_small_panel_focus_visibility_data() { return cases() }
        function test_small_panel_focus_visibility(data) {
            host.height = 350; load(data)
            clickField("vpn-country"); keyClick(Qt.Key_Tab); keyClick(Qt.Key_Tab); wait(30)
            var input = findChild(host.panel, "vpn-autoconnect-country-input")
            verify(input.activeFocus)
            var card = findChild(host.panel, "nordvpn-panel-card")
            var point = input.mapToItem(card, 0, 0)
            verify(point.y >= 0 && point.y + input.height <= card.height, "Tab focus must scroll the field into the panel viewport")
            keyClick(Qt.Key_Down); wait(30)
            var list = findChild(host.panel, "vpn-autoconnect-country-options")
            var bottom = list.mapToItem(card, 0, list.height).y
            verify(bottom <= card.height, "The expanded picker must remain in the panel viewport")
            compare(fakeController.selections.length, 0); compare(fakeController.mutations, 0)
        }
        function test_standalone_edit_with_pointer() {
            host.panel = standalone.createObject(host); wait(50)
            var field = findChild(host.panel, "vpn-country-select")
            mouseClick(field, 30, field.height / 2); typeText("united")
            wait(20); compare(host.panel.optionsView.count, 2)
            var input = host.panel.input
            mouseClick(input, 10, input.height / 2); wait(20)
            verify(host.panel.expanded, "Clicking the open editor must allow editing, not cancel the draft")
            keyClick(Qt.Key_A, Qt.ControlModifier); typeText("can"); wait(20)
            compare(input.text, "can"); compare(host.panel.optionsView.count, 1)
            keyClick(Qt.Key_Return); compare(fakeController.preferredCountry, "Canada")
            compare(fakeController.selections.length, 1); compare(fakeController.mutations, 0)
            compare(host.panel.expanded, false)
        }
        function test_filter_confirm(data) {
            host.panel = data.variant.createObject(host); verify(host.panel !== null); wait(200)
            var field = findChild(host.panel, "vpn-country-select")
            verify(field !== null)
            mouseClick(field, field.width / 2, field.height / 2)
            for (var ch of "united states") keyClick(ch)
            keyClick(Qt.Key_Return); wait(20)
            compare(fakeController.preferredCountry, "United_States", "Typing and Enter must select the canonical country, not connect")
            compare(fakeController.selections.length, 1)
            compare(fakeController.mutations, 0)
        }
    }
}
