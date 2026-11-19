import QtQuick
import QtTest

Item {
    id: host
    width: 100
    height: 100
    property var currentRoot: null

    QtObject {
        id: observer
        property var root: host.currentRoot
        property bool visibleFlag: root ? root.controlVisible : false
    }

    function makeRoot() {
        return Qt.createQmlObject("import QtQuick\nQtObject { property bool controlVisible: false }",
                                  host, "ControlPanelNativeRoot")
    }

    TestCase {
        name: "ControlPanelNativeRootNotification"
        when: windowShown

        function test_control_visible_notifies_existing_binding() {
            host.currentRoot = host.makeRoot()
            wait(20)
            compare(observer.visibleFlag, false)
            host.currentRoot.controlVisible = true
            wait(50)
            compare(host.currentRoot.controlVisible, true)
            compare(observer.visibleFlag, true,
                    "changing controlVisible must notify composed QML bindings")
        }
    }
}
