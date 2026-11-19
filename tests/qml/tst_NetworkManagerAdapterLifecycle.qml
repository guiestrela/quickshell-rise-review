import QtQuick
import QtTest
import "./" as Fake
import "FakeTypes.js" as FakeTypes

Item {
    id: host
    width: 400
    height: 300
    property var adapter: null
    property var secondAdapter: null

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
            if (host.secondAdapter) {
                host.secondAdapter.destroy()
                host.secondAdapter=null
                wait(30)
            }

            if (host.adapter) {
                host.adapter.destroy()
                host.adapter = null
                wait(30)
            }
            Fake.Networking.devices = ({ values: [] })
            firstDevice.scannerEnabled = false
            secondDevice.scannerEnabled = false
            wait(20)
        }


        function openSecond() {
            host.secondAdapter=adapterComponent.createObject(host)
            verify(host.secondAdapter!==null)
            wait(40)
            verify(host.secondAdapter.panelOpen)
            compare(firstDevice.scannerEnabled,true)
        }
        function test_two_consumers_A_close_must_keep_B_scanning() {
            openSecond()
            host.adapter.panelOpen=false
            wait(40)
            verify(host.secondAdapter.panelOpen)
            compare(firstDevice.scannerEnabled,true,"A close must not disable scanning still required by open B")
        }
        function test_two_consumers_A_then_B_close_must_release_final_scan() {
            openSecond()
            host.adapter.panelOpen=false
            wait(40)
            host.secondAdapter.panelOpen=false
            wait(40)
            compare(firstDevice.scannerEnabled,false,"Last close must not restore stale true without a consumer")
        }
        function test_two_consumers_B_then_A_close_control() {
            openSecond()
            host.secondAdapter.panelOpen=false
            wait(40)
            compare(firstDevice.scannerEnabled,true)
            host.adapter.panelOpen=false
            wait(40)
            compare(firstDevice.scannerEnabled,false)
        }
        function test_two_consumers_preserve_preexisting_true_after_last_release() {
            host.adapter.destroy()
            host.adapter=null
            wait(40)
            firstDevice.scannerEnabled=true
            host.adapter=adapterComponent.createObject(host)
            verify(host.adapter!==null)
            wait(40)
            openSecond()
            host.adapter.panelOpen=false
            wait(40)
            compare(firstDevice.scannerEnabled,true,"A close must preserve pre-existing scanner state while B is open")
            host.secondAdapter.panelOpen=false
            wait(40)
            compare(firstDevice.scannerEnabled,true,"Last consumer must restore pre-existing true")
        }
        function test_repeated_refresh_and_release_are_idempotent() {
            host.adapter.refresh()
            host.adapter.refresh()
            host.adapter.panelOpen=false
            wait(40)
            compare(firstDevice.scannerEnabled,false,"Repeated refresh must not create duplicate request ownership")
            host.adapter.refresh()
            wait(20)
            compare(firstDevice.scannerEnabled,false,"Repeated release while closed must not restore a phantom request")
        }
        function test_destroy_A_must_keep_open_B_scanning() {
            openSecond()
            host.adapter.destroy()
            host.adapter=null
            wait(40)
            verify(host.secondAdapter.panelOpen)
            compare(firstDevice.scannerEnabled,true,"Destroying A must preserve open B scan demand")
        }
        function test_destroy_B_then_A_control() {
            openSecond()
            host.secondAdapter.destroy()
            host.secondAdapter=null
            wait(40)
            compare(firstDevice.scannerEnabled,true)
            host.adapter.destroy()
            host.adapter=null
            wait(40)
            compare(firstDevice.scannerEnabled,false)
        }
        function test_two_consumers_device_replacement_releases_old_device() {
            openSecond()
            Fake.Networking.devices=({values:[secondDevice,firstDevice]})
            wait(60)
            compare(secondDevice.scannerEnabled,true)
            compare(firstDevice.scannerEnabled,false,"Old device must have no scan demand after both adapters switched")
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
            wait(40)
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
