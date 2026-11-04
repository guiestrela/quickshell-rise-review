import QtQuick
import Quickshell
import Quickshell.Io
import "../integrations/onedrive" as OneDrive
import "../integrations/onedrive/Model.js" as Model

OneDrive.Service {
    id: service
    required property var owner
    onExternalActionRequested: owner.oneDriveVisible = false
    settings: preferencesData
    property var preferencesData: ({})
    function updateSetting(name, value) {
        var next = Object.assign({}, preferencesData)
        next[name] = value
        preferencesData = next
        preferences.setText(JSON.stringify(next))
    }
    FileView {
        id: preferences
        path: Quickshell.env("HOME") + "/.cache/quickshell-rise-onedrive.json"
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text())
                if (data && typeof data === "object" && !Array.isArray(data)) service.preferencesData = data
            } catch (error) { /* Invalid preferences retain defaults. */ }
        }
    }
    function openPanel(target) {
        owner.activateFocusedPopupScreen()
        owner.oneDriveOpenTarget = target || ""
        if (target) openFromNotification(target)
        owner.oneDriveVisible = true
    }
    IpcHandler {
        target: "io.github.salemsayed.omaonedrive"
        function open(): void { service.openPanel("") }
        function show(): void { service.openPanel("") }
        function close(): void { service.owner.oneDriveVisible = false }
        function hide(): void { service.owner.oneDriveVisible = false }
        function toggle(): void { service.owner.activateFocusedPopupScreen(); service.owner.oneDriveVisible = !service.owner.oneDriveVisible }
        function refresh(): void { service.refresh(false) }
        function check(): void { service.checkQuota() }
        function fullStatus(): void { service.checkFullStatus() }
        function pause(): string { return service.pause() }
        function pauseFor(minutes: int): string { return service.pauseFor(minutes) }
        function resume(): string { return service.resume() }
        function toggleSync(): string { return service.toggleRunning() }
        function folder(): void { service.openFolder() }
        function web(): void { service.openWeb() }
        function resync(): void { service.repairResync() }
        function status(): string { return service.statusText }
        function accounts(): string { return JSON.stringify(Model.accountRows(service.accounts, service.selectedService)) }
        function selectAccount(target: string): string {
            var found = Model.resolveAccountTarget(service.accounts, target)
            if (!found) return "unknown account: " + target
            service.selectAccount(found, false)
            return "ok"
        }
        function openAccount(target: string): void { service.openPanel(target) }
        function repairAccount(target: string): void { service.repairFromNotification(target) }
    }
}
