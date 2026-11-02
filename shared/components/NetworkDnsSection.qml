pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

// System provider, not the effective DNS of a VPN. Use Omarchy's own privilege flow.
Column {
    id: dns
    required property var theme
    property bool panelOpen: false
    readonly property var providers: ["DHCP", "Cloudflare", "Google"]
    property string provider: ""
    property bool ready: false
    property string error: ""
    property string pendingProvider: ""
    property string expectedProvider: ""
    property bool actionFailed: false
    property bool querying: false
    readonly property bool busy: pendingProvider !== "" || querying || action.running || query.running
    spacing: 4

    function refresh(afterAction) {
        if (querying || query.running || action.running || (pendingProvider !== "" && !afterAction)) return false
        querying = true
        query.command = ["/usr/bin/omarchy-dns"]
        query.running = true
        return true
    }

    function choose(name) {
        if (!ready || busy || providers.indexOf(name) < 0 || provider === name) return false
        pendingProvider = name
        expectedProvider = name
        actionFailed = false
        error = ""
        ready = false
        action.command = ["/usr/bin/omarchy-dns", name]
        action.running = true
        return true
    }

    onPanelOpenChanged: if (panelOpen) refresh()
    Component.onCompleted: if (panelOpen) refresh()

    Process {
        id: query
        stdout: StdioCollector { id: queryOutput; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: (exitCode) => {
            var value = queryOutput.text.trim()
            if (exitCode === 0 && (dns.providers.indexOf(value) >= 0 || value === "Custom")) {
                dns.provider = value
                dns.ready = true
                if (!dns.actionFailed) {
                    dns.error = dns.expectedProvider !== "" && value !== dns.expectedProvider
                        ? "DNS change could not be verified." : ""
                }
            } else {
                dns.ready = false
                dns.error = "Cannot read the system DNS provider."
            }
            dns.expectedProvider = ""
            dns.pendingProvider = ""
            dns.querying = false
        }
    }

    Process {
        id: action
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: (exitCode) => {
            deadline.stop()
            if (exitCode !== 0) {
                dns.actionFailed = true
                dns.error = "DNS change failed or authorization was cancelled."
            }
            Qt.callLater(() => dns.refresh(true))
        }
    }

    Timer {
        id: deadline
        interval: 60000
        running: action.running
        onTriggered: {
            // Do not kill a privileged operation or allow a second write over it.
            // This is a waiting notice, not a terminal failure: the job remains active.
            dns.error = "DNS change is still pending. Check the authorization prompt."
        }
    }

    Timer {
        interval: 10000
        running: dns.panelOpen
        repeat: true
        onTriggered: dns.refresh()
    }

    Item {
        width: parent.width
        height: 16
        UiText {
            anchors.left: parent.left
            text: "DNS"
            color: dns.theme.sumiHi
            font.family: dns.theme.mono
            font.pixelSize: 10
            font.letterSpacing: 1
        }
        UiText {
            anchors.right: parent.right
            text: dns.busy ? (dns.pendingProvider !== "" ? "changing…" : "reading…")
                          : (dns.ready ? dns.provider : "unavailable")
            color: dns.theme.sumiHi
            font.family: dns.theme.mono
            font.pixelSize: 10
        }
    }

    Row {
        width: parent.width
        spacing: 4
        Repeater {
            model: dns.providers
            delegate: Rectangle {
                required property string modelData
                objectName: "dns-choice-" + modelData
                width: (dns.width - 8) / 3
                height: 28
                radius: dns.theme.tileRadius
                enabled: dns.ready && !dns.busy
                readonly property bool active: dns.ready && dns.provider === modelData
                readonly property bool labelFits: label.implicitWidth <= width - 8
                color: active ? dns.theme.fillActive : hit.containsMouse ? dns.theme.fillHover : dns.theme.fillIdle
                border.color: active || hit.containsMouse || activeFocus ? dns.theme.seal : dns.theme.sep
                border.width: 1
                opacity: enabled ? 1 : 0.55
                activeFocusOnTab: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData + " system DNS"
                Accessible.checkable: true
                Accessible.checked: active
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        dns.choose(modelData)
                        event.accepted = true
                    }
                }
                UiText {
                    id: label
                    anchors.centerIn: parent
                    text: parent.modelData
                    color: parent.active ? dns.theme.seal : dns.theme.ink
                    font.family: dns.theme.mono
                    font.pixelSize: 10
                }
                MouseArea {
                    id: hit
                    objectName: "dns-hit-" + parent.modelData
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        parent.forceActiveFocus()
                        dns.choose(parent.modelData)
                    }
                }
            }
        }
    }

    UiText {
        width: parent.width
        text: "System DNS · VPN DNS may differ"
        color: dns.theme.sumiHi
        font.family: dns.theme.mono
        font.pixelSize: 10
        wrapMode: Text.Wrap
    }

    UiText {
        width: parent.width
        visible: dns.error !== ""
        text: dns.error
        textFormat: Text.PlainText
        color: dns.theme.seal
        font.family: dns.theme.mono
        font.pixelSize: 10
        wrapMode: Text.Wrap
    }
}
