import QtQuick
import QtQuick.Window
import "../../versions/V1/modules"
import "../../versions/V1/modules/NordVpnLayout.js" as NordVpnLayout

Window {
    id: harness
    visible: true
    width: 280
    height: 40
    property bool modNordVpn: true
    property string nordVpnStatus: "Unknown"
    property bool networkVisible: false
    property color seal: "#d75f5f"
    property color fillIdle: "#202020"
    property color pill: "#303030"
    property color sep: "#606060"
    property color pillBorder: "#505050"
    property int pillBorderW: 1
    property int pillRadius: 8
    property string mono: "monospace"
    property color sumi: "#dedede"
    property color ink: "#dedede"

    ListModel { id: dragLeft; ListElement { gid: "G19"; extra: true } }
    ListModel { id: dragRight; ListElement { gid: "G11"; extra: false } }

    NordVpnStatus {
        id: vpnStatus
        enabled: true
        refreshInterval: 5000
        command: ["node", "tests/fixtures/nordvpn-cli-stub.mjs", "status"]
    }
    NordVpnStatus {
        id: disabledStatus
        enabled: false
        refreshInterval: 5000
        command: ["node", "tests/fixtures/nordvpn-cli-stub.mjs", "status"]
    }
    NordVPNWidget { id: vpnWidget; root: harness }
    Binding { target: harness; property: "nordVpnStatus"; value: vpnStatus.status }

    Timer {
        interval: 400
        running: true
        onTriggered: {
            var oldV1Left = ["G1", "G2", "G3", "G4", "G5", "G6", "G7"]
            var oldV1Right = ["G9", "G10", "G11", "G14", "G12", "G13", "G15"]
            var migratedV1 = NordVpnLayout.migrateV1Order(oldV1Left, ["G8"], oldV1Right)
            if (!migratedV1 || migratedV1.right[7] !== "G16") {
                console.error("QR04N_QML_FAIL V1 layout migration")
                Qt.exit(1)
                return
            }
            var oldV2Left = [], oldV2Right = []
            for (var n = 1; n <= 7; n++) oldV2Left.push({ gid: "G" + n, extra: false })
            for (var r = 9; r <= 18; r++) oldV2Right.push({ gid: "G" + r, extra: r > 15 })
            oldV2Right.push({ gid: "", extra: true })
            var migratedV2 = NordVpnLayout.migrateV2Entries(oldV2Left, [{ gid: "G8", extra: false }], oldV2Right)
            if (!migratedV2 || migratedV2.right[10].gid !== "G19" || migratedV2.right[10].extra !== true) {
                console.error("QR04N_QML_FAIL V2 layout migration")
                Qt.exit(1)
                return
            }
            if (vpnStatus.completedCount !== 1 || vpnStatus.status !== "Connected") {
                console.error("QR04N_QML_FAIL status/poll", vpnStatus.status, vpnStatus.completedCount)
                Qt.exit(1)
                return
            }
            if (disabledStatus.completedCount !== 0 || disabledStatus.status !== "Unknown") {
                console.error("QR04N_QML_FAIL disabled polling ran", disabledStatus.status, disabledStatus.completedCount)
                Qt.exit(1)
                return
            }
            if (!NordVpnLayout.swapModels(dragLeft, dragRight, 0, 0)
                    || dragLeft.get(0).gid !== "G11" || dragLeft.get(0).extra !== true
                    || dragRight.get(0).gid !== "G19" || dragRight.get(0).extra !== false) {
                console.error("QR04N_QML_FAIL real ListModel reorder")
                Qt.exit(1)
                return
            }
            if (!vpnWidget.visible || vpnWidget.nordVpnStatusText.indexOf("ON") < 0) {
                console.error("QR04N_QML_FAIL widget visibility/status")
                Qt.exit(1)
                return
            }
            harness.modNordVpn = false
            if (vpnWidget.visible || vpnWidget.implicitWidth !== 0) {
                console.error("QR04N_QML_FAIL WIDGETS toggle did not collapse widget")
                Qt.exit(1)
                return
            }
            harness.modNordVpn = true
            vpnWidget.activate()
            if (!harness.networkVisible) {
                console.error("QR04N_QML_FAIL click did not open native panel")
                Qt.exit(1)
                return
            }
            console.log("QR04N_QML_PASS: stub status, one poll, shared widget, panel callback")
            Qt.exit(0)
        }
    }
}
