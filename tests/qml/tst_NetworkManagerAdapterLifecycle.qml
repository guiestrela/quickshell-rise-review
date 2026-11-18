import QtQuick
import QtTest
import "./" as Fake
import "FakeTypes.js" as FakeTypes

Item {
    id: host
    width: 400
    height: 300
    property var adapter: null

    QtObject {
        id: firstDevice
        property int type: FakeTypes.Wifi
        property string name: "first"
        property var networks: ({ values: [] })
        property bool connected: false
        property bool known: false
        property int signalStrength: 0
        property int security: FakeTypes.Open
        property bool scannerEnabled: false
    }
    QtObject {
        id: secondDevice
        property int type: FakeTypes.Wifi
        property string name: "second"
        property var networks: ({ values: [] })
        property bool connected: false
        property bool known: false
        property int signalStrength: 0
        property int security: FakeTypes.Open
        property bool scannerEnabled: false
    }
    Component {
        id: adapterComponent
        Fake.NetworkManagerAdapter { panelOpen: true }
    }

    TestCase {
        name: "WifiScanLeaseLifecycle"
        when: windowShown

        function init() {
            firstDevice.scannerEnabled = false
            secondDevice.scannerEnabled = false
            Fake.Networking.wifiEnabled = true
            Fake.Networking.devices = ({ values: [firstDevice] })
            host.adapter = adapterComponent.createObject(host)
            verify(host.adapter !== null)
            wait(30)
            compare(firstDevice.scannerEnabled, true)
        }

        function cleanup() {
            if (host.adapter) {
                host.adapter.destroy()
                host.adapter = null
            }
            Fake.Networking.devices = ({ values: [] })
            firstDevice.scannerEnabled = false
            secondDevice.scannerEnabled = false
            wait(20)
        }

        function test_replacing_selected_device_releases_previous_scan() {
            Fake.Networking.devices = ({ values: [secondDevice, firstDevice] })
            wait(30)
            compare(secondDevice.scannerEnabled, true)
            compare(firstDevice.scannerEnabled, false,
                    "previously selected Wi-Fi device must not keep scanning")
        }

        function test_close_releases_all_scan_started_by_adapter() {
            Fake.Networking.devices = ({ values: [secondDevice, firstDevice] })
            wait(30)
            host.adapter.panelOpen = false
            wait(30)
            compare(secondDevice.scannerEnabled, false)
            compare(firstDevice.scannerEnabled, false,
                    "close must not leave an old device scanner enabled")
        }

        function test_destroy_releases_owned_scan() {
            host.adapter.destroy()
            host.adapter = null
            wait(30)
            compare(firstDevice.scannerEnabled, false,
                    "destroy must release the selected device's scanner request")
        }

        function test_preexisting_scan_is_preserved_on_close() {
            host.adapter.destroy()
            host.adapter = null
            firstDevice.scannerEnabled = true
            host.adapter = adapterComponent.createObject(host)
            verify(host.adapter !== null)
            wait(30)
            host.adapter.panelOpen = false
            wait(30)
            compare(firstDevice.scannerEnabled, true,
                    "adapter must restore the scanner state it did not start")
        }
    }
}
