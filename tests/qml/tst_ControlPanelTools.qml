import QtQuick
import QtTest
import "../../shared/components" as Shared
import "../../shared/services" as SharedServices

Item {
    id: host
    width: 800
    height: 600
    property var tools: null
    property string selectedTarget: ""
    property int closeRequests: 0
    property int externalCalls: 0
    property var probeHost: ({})

    QtObject {
        id: fakeHost
        property var variantHost: ({ runningVariant: "v2", switching: false })
        property string activePopupScreenName: "DP-1"
        property bool hasBattery: true
        property bool hasBacklight: false
        property string networkMode: "wifi"
    }
    SharedServices.ControlPanelCapabilities {
        id: healthCapabilities
        hostRoot: fakeHost
    }
    SharedServices.ControlPanelCapabilities {
        id: probeCapabilities
        hostRoot: host.probeHost
    }

    QtObject {
        id: fakeTheme
        property int launcherBarX: 400
        property string barPosition: "top"
        property int panelRadius: 12
        property int panelButtonRadius: 5
        property color panelOuterBorderColor: "#555555"
        property int panelOuterBorderW: 1
        property int tileRadius: 5
        property color bg: "#202020"
        property color pillBorder: "#555555"
        property int pillBorderW: 1
        property color fillActive: "#40251e"
        property color fillHover: "#303030"
        property color fillIdle: "#242424"
        property color sep: "#454545"
        property color seal: "#ff5b35"
        property color ink: "#eeeeee"
        property color sumi: "#858585"
        property color sumiHi: "#b5b5b5"
        property string mono: "monospace"
    }

    Component {
        id: toolsComponent
        Shared.ControlPanelTools {
            anchors.fill: host
            theme: fakeTheme
            variantName: "V2"
            open: false
            healthRows: healthCapabilities.healthRows
            onDestinationRequested: function(target) { host.selectedTarget = target }
            onCloseRequested: host.closeRequests++
        }
    }

    TestCase {
        name: "ControlPanelTools"
        when: windowShown
        function loadTools() {
            host.tools = toolsComponent.createObject(host)
            verify(host.tools !== null)
            host.selectedTarget = ""
            host.closeRequests = 0
            host.externalCalls = 0
            host.tools.open = true
            wait(30)
        }
        function clearTools() {
            if (host.tools) {
                host.tools.destroy()
                host.tools = null
            }
            wait(20)
        }
        function typeText(value) {
            for (var ch of value) {
                if (/[a-z]/i.test(ch)) {
                    var key = Qt.Key_A + ch.toUpperCase().charCodeAt(0) - 65
                    keyClick(key, ch === ch.toUpperCase() ? Qt.ShiftModifier : Qt.NoModifier)
                } else if (ch === " ") keyClick(Qt.Key_Space)
                else if (ch === "-") keyClick(Qt.Key_Minus)
            }
        }
        function init() { loadTools() }
        function cleanup() { clearTools() }

        function test_search_keyboard_and_routes_without_actions() {
            var input = findChild(host.tools, "control-panel-search-input")
            verify(input !== null)
            verify(input.activeFocus, "Search input should take keyboard focus when opened")
            typeText("nordvpn countries")
            wait(30)
            var results = findChild(host.tools, "control-panel-tools-results")
            compare(results.count, 1)
            keyClick(Qt.Key_Return)
            compare(host.selectedTarget, "widgets")
            compare(host.closeRequests, 1)
            compare(host.externalCalls, 0, "Searching must not query network/accounts or call services")
        }

        function test_qml_search_normalizes_accents() {
            var input = findChild(host.tools, "control-panel-search-input")
            input.text = "BAR POSIÇÃO"
            wait(20)
            var results = findChild(host.tools, "control-panel-tools-results")
            compare(results.count, 1)
            compare(results.itemAtIndex(0).modelData.id, "position")
        }

        function test_escape_clears_then_closes_and_no_match_is_honest() {
            var input = findChild(host.tools, "control-panel-search-input")
            typeText("not-a-control")
            wait(20)
            compare(findChild(host.tools, "control-panel-tools-results").count, 0)
            verify(findChild(host.tools, "control-panel-tools-no-results").visible)
            keyClick(Qt.Key_Escape)
            compare(input.text, "")
            compare(host.closeRequests, 0)
            keyClick(Qt.Key_Escape)
            compare(host.closeRequests, 1)
            compare(host.selectedTarget, "")
        }

        function test_health_is_read_only_and_labels_local_observations() {
            var tab = findChild(host.tools, "control-panel-health-tab")
            verify(tab !== null)
            mouseClick(tab, tab.width / 2, tab.height / 2)
            wait(20)
            var results = findChild(host.tools, "control-panel-tools-results")
            compare(results.count, 8)
            var first = results.itemAtIndex(0)
            verify(first !== null)
            compare(first.modelData.label, "Variant")
            compare(first.modelData.value, "V2")
            verify(findChild(host.tools, "control-panel-health-row-variant").visible)
            verify(findChild(host.tools, "control-panel-health-disclaimer").visible)
            compare(host.externalCalls, 0)
            verify(host.tools.visible)
        }

        function test_capability_facade_tracks_host_property_changes() {
            compare(healthCapabilities.healthRows[5].value, "Wi-Fi")
            fakeHost.networkMode = "ethernet"
            wait(20)
            compare(healthCapabilities.healthRows[5].value, "Ethernet")
            fakeHost.networkMode = "wifi"
            wait(20)
            compare(healthCapabilities.healthRows[5].value, "Wi-Fi")
        }

        function test_capability_facade_distinguishes_missing_and_temporary() {
            host.probeHost = {
                variantHost: { runningVariant: "", switching: true },
                activePopupScreenName: "", hasBattery: false,
                hasBacklight: false, networkMode: "none"
            }
            wait(20)
            var temporaryRows = probeCapabilities.healthRows
            compare(temporaryRows[0].value, "Not reported")
            compare(temporaryRows[1].value, "In progress")
            compare(temporaryRows[2].value, "Not selected")
            compare(probeCapabilities.diagnostics.length, 0)

            host.probeHost = { variantHost: { runningVariant: "v1" } }
            wait(20)
            var unsupportedRows = probeCapabilities.healthRows
            compare(unsupportedRows[1].value, "Unsupported")
            verify(probeCapabilities.diagnostics.length >= 4)
            verify(unsupportedRows[7].detail.indexOf("switching-missing") >= 0)
            compare(unsupportedRows[6].value, "Not run")
        }
    }
}
