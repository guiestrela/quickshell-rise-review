import Quickshell.Bluetooth
import QtQuick

QtObject {
    Component.onCompleted: {
        console.log("QR_BT_BATTERY_IMPORT", Bluetooth.devices.values.length)
        Qt.quit()
    }
}
