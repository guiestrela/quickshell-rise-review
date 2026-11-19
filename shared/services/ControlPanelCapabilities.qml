import QtQuick
import "../logic/ControlPanelCapabilities.js" as CapabilitiesLogic

QtObject {
    id: facade
    property var hostRoot: null

    readonly property var report: CapabilitiesLogic.readHostCapabilities(hostRoot)
    readonly property var healthRows: report.healthRows
    readonly property var diagnostics: report.diagnostics
}
