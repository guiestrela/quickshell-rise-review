// Independent actual-event tests; imports production component without edits.
import QtQuick
import QtTest
import "../../shared/components" as Shared

FocusScope {
    id: host
    width: 800; height: 600
    property var tools: null
    property string target: ""
    property int closed: 0
    Rectangle {
        id: searchOpener
        objectName: "search-tools-opener"
        x: 8; y: 8; width: 120; height: 28
        focus: true
        activeFocusOnTab: true
    }
    Rectangle {
        id: healthOpener
        objectName: "health-tools-opener"
        x: 136; y: 8; width: 120; height: 28
        activeFocusOnTab: true
    }
    QtObject {
        id: focusRoot
        property bool controlVisible: true
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
        id: component
        Shared.ControlPanelTools {
            theme: fakeTheme
            variantName: "V2"
            focusReturnRoot: focusRoot
            focusReturnTarget: host.tools && host.tools.startInHealth ? healthOpener : searchOpener
            onDestinationRequested: function(value) { host.target = value }
            onCloseRequested: { host.closed++; open = false }
        }
    }
    TestCase {
        name: "IndependentControlTools"
        when: windowShown
        function variants() { return [{tag:"V1",variant:"V1"},{tag:"V2",variant:"V2"}] }
        function init() {
            host.width=800; host.height=600; fakeTheme.launcherBarX=400
            host.closed=0; host.target=""
            host.tools=component.createObject(host)
            verify(host.tools!==null)
        }
        function cleanup() { host.tools.destroy(); host.tools=null; wait(20) }
        function show(variant,health) {
            var opener = health ? healthOpener : searchOpener
            opener.forceActiveFocus()
            verify(opener.activeFocus, "selected opener receives focus before opening tools")
            host.tools.variantName=variant
            host.tools.startInHealth=health
            host.tools.open=true
            wait(100)
        }
        function child(name) { var item=findChild(host.tools,name); verify(item!==null,name); return item }
        function typeQuery(value) {
            for(var ch of value) keyClick(Qt.Key_A+ch.toUpperCase().charCodeAt(0)-65)
            wait(50)
        }
        function test_health_escape_data() { return variants() }
        function test_health_escape(data) {
            show(data.variant,true)
            verify(child("control-panel-tools").activeFocus)
            keyClick(Qt.Key_Escape)
            compare(host.closed,1,"Escape must dismiss Health, not remain trapped")
        }
        function test_health_escape_restores_opener_data() { return variants() }
        function test_health_escape_restores_opener(data) {
            show(data.variant,true)
            keyClick(Qt.Key_Escape)
            compare(host.closed,1)
            wait(100)
            verify(healthOpener.activeFocus, "closing Health must return focus to the Health opener")
        }
        function test_health_escape_from_header_focus_data() { return variants() }
        function test_health_escape_from_header_focus(data) {
            show(data.variant,true)
            var close=child("control-panel-tools-close")
            close.forceActiveFocus()
            verify(close.activeFocus, "header close control should receive focus")
            keyClick(Qt.Key_Escape)
            compare(host.closed,1)
            wait(100)
            verify(healthOpener.activeFocus, "Escape from a Health header control returns to its opener")
        }
        function test_health_escape_reopen_preserves_focus_return_data() { return variants() }
        function test_health_escape_reopen_preserves_focus_return(data) {
            show(data.variant,true)
            keyClick(Qt.Key_Escape)
            compare(host.closed,1)
            wait(100)
            verify(healthOpener.activeFocus)
            host.tools.startInHealth=true
            host.tools.open=true
            wait(100)
            verify(child("control-panel-tools").activeFocus)
            keyClick(Qt.Key_Escape)
            compare(host.closed,2)
            wait(100)
            verify(healthOpener.activeFocus, "reopened Health must restore focus to the original opener")
        }
        function test_health_tab_escape_data() { return variants() }
        function test_health_tab_escape(data) {
            show(data.variant,false)
            var tab=child("control-panel-health-tab")
            mouseClick(tab,tab.width/2,tab.height/2)
            wait(50)
            keyClick(Qt.Key_Escape)
            compare(host.closed,1,"Escape after switching to Health must dismiss")
        }
        function test_second_click_edits_caret_data() { return variants() }
        function test_second_click_edits_caret(data) {
            show(data.variant,false)
            var input=child("control-panel-search-input")
            typeQuery("network")
            compare(input.text,"network")
            mouseClick(input,2,input.height/2)
            wait(30)
            keyClick(Qt.Key_Home)
            keyClick(Qt.Key_X)
            compare(input.text,"xnetwork")
            compare(host.target,"")
        }
        function test_search_route_and_escape_data() { return variants() }
        function test_search_route_and_escape(data) {
            show(data.variant,false)
            typeQuery("nordvpn")
            compare(child("control-panel-tools-results").count,1)
            keyClick(Qt.Key_Return)
            compare(host.target,"widgets")
            compare(host.closed,1)
            wait(100)
            verify(searchOpener.activeFocus, "opening a destination must return focus to Search")
        }
        function test_narrow_card_bounds_data() { return variants() }
        function test_narrow_card_bounds(data) {
            host.width=320; host.height=480; fakeTheme.launcherBarX=160
            show(data.variant,false)
            var card=child("control-panel-tools")
            verify(card.x>=0 && card.y>=0,"top/left must stay in viewport")
            verify(card.x+card.width<=host.width,"right edge")
            verify(card.y+card.height<=host.height,"bottom edge")
            var close=child("control-panel-tools-close")
            mouseClick(close,close.width/2,close.height/2)
            compare(host.closed,1)
            wait(100)
            verify(searchOpener.activeFocus, "pointer close must restore focus to the Search opener")
        }
    }
}
