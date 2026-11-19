// Actual-event Health regression checks after removal of ControlPanel Search.
import QtQuick
import QtTest
import "../../shared/components" as Shared

FocusScope {
    id: host
    width: 800; height: 600
    property var tools: null
    property int closed: 0
    Rectangle {
        id: healthOpener
        x: 8; y: 8; width: 120; height: 28
        focus: true
        activeFocusOnTab: true
    }
    QtObject { id: focusRoot; property bool controlVisible: true }
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
            focusReturnTarget: healthOpener
            healthRows: [{label:"State",value:"Local",detail:"Read-only"}]
            onCloseRequested: { host.closed++; open = false }
        }
    }
    TestCase {
        name: "IndependentHealthTools"
        when: windowShown
        function variants() { return [{tag:"V1",variant:"V1"},{tag:"V2",variant:"V2"}] }
        function init() {
            host.width=800; host.height=600
            fakeTheme.launcherBarX=400; fakeTheme.barPosition="top"
            focusRoot.controlVisible=true; host.closed=0
            host.tools=component.createObject(host)
            verify(host.tools!==null)
        }
        function cleanup() { host.tools.destroy(); host.tools=null; wait(20) }
        function show(variant) {
            healthOpener.forceActiveFocus()
            verify(healthOpener.activeFocus)
            host.tools.variantName=variant
            host.tools.open=true
            wait(30) // Flush the deferred initial-focus callback before sending keys.
            tryVerify(function(){return findChild(host.tools,"control-panel-tools").activeFocus})
        }
        function child(name) { var item=findChild(host.tools,name); verify(item!==null,name); return item }
        function verifyClosed() {
            compare(host.closed,1)
            verify(!host.tools.open)
            tryVerify(function(){return healthOpener.activeFocus})
        }
        function test_search_removed_data() { return variants() }
        function test_search_removed(data) {
            show(data.variant)
            compare(findChild(host.tools,"control-panel-search-tab"),null)
            compare(findChild(host.tools,"control-panel-search-input"),null)
            compare(findChild(host.tools,"control-panel-search-result-nordvpn"),null)
            compare(child("control-panel-tools-results").count,1)
        }
        function test_escape_data() { return variants() }
        function test_escape(data) { show(data.variant); keyClick(Qt.Key_Escape); verifyClosed() }
        function test_header_escape_data() { return variants() }
        function test_header_escape(data) {
            show(data.variant)
            var close=child("control-panel-tools-close")
            keyClick(Qt.Key_Tab)

            tryVerify(function(){return close.activeFocus})
            keyClick(Qt.Key_Escape)
            verifyClosed()
        }
        function test_close_enter_data() { return variants() }
        function test_close_enter(data) {
            show(data.variant)
            child("control-panel-tools-close").forceActiveFocus()
            keyClick(Qt.Key_Return)
            verifyClosed()
        }
        function test_reopen_data() { return variants() }
        function test_reopen(data) {
            show(data.variant); keyClick(Qt.Key_Escape); verifyClosed()
            host.tools.open=true
            tryVerify(function(){return child("control-panel-tools").activeFocus})
            keyClick(Qt.Key_Escape)
            compare(host.closed,2)
            tryVerify(function(){return healthOpener.activeFocus})
        }
        function test_narrow_pointer_close_data() {
            return [{tag:"V1-top",variant:"V1",position:"top"},{tag:"V1-bottom",variant:"V1",position:"bottom"},
                    {tag:"V2-top",variant:"V2",position:"top"},{tag:"V2-bottom",variant:"V2",position:"bottom"}]
        }
        function test_narrow_pointer_close(data) {
            host.width=320; host.height=480; fakeTheme.launcherBarX=160
            fakeTheme.barPosition=data.position
            show(data.variant)
            var card=child("control-panel-tools")
            verify(card.x>=0 && card.y>=0)
            verify(card.x+card.width<=host.width)
            verify(card.y+card.height<=host.height)
            var close=child("control-panel-tools-close")
            mouseClick(close,close.width/2,close.height/2)
            verifyClosed()
        }
    }
}
