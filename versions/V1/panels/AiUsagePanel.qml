pragma ComponentBehavior: Bound
import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// AI usage panel: shows Claude Code, OpenAI Codex, and OpenCode usage and lets the user
// switch which tool's icon the bar pill displays (root.aiTool). Opened from the
// combined AI pill (ClaudeWidget). Reads the same caches the bar widget reads.
PanelWindow {
    id: aiPanel
    required property var root

    screen: aiPanel.root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-ai-usage"

    readonly property int barBottom: 35
    readonly property int gap: 8
    readonly property int contentPadding: 16

    // ── usage data: rendered from root.ai* — the single shared parse in Theme.qml
    //    that the bar pill uses too, so the two views can never drift apart. ──
    readonly property int    clPct5h:     aiPanel.root.aiClPct5h
    readonly property int    clPct7d:     aiPanel.root.aiClPct7d
    readonly property int    clReset5hTs: aiPanel.root.aiClReset5hTs
    readonly property int    clReset7dTs: aiPanel.root.aiClReset7dTs
    readonly property string clTokens:    aiPanel.root.aiClTokens
    readonly property string clRate:      aiPanel.root.aiClRate
    readonly property int    clToday:     aiPanel.root.aiClToday
    readonly property bool   clFresh:     aiPanel.root.aiClFresh
    readonly property bool   clHas:       aiPanel.root.aiClHas

    readonly property int    cxPct5h:     aiPanel.root.aiCxPct5h
    readonly property int    cxPct7d:     aiPanel.root.aiCxPct7d
    readonly property int    cxReset5hTs: aiPanel.root.aiCxReset5hTs
    readonly property int    cxReset7dTs: aiPanel.root.aiCxReset7dTs
    readonly property string cxPlan:      aiPanel.root.aiCxPlan
    readonly property string cxTokens:    aiPanel.root.aiCxTokens
    readonly property string cxRate:      aiPanel.root.aiCxRate
    readonly property int    cxToday:     aiPanel.root.aiCxToday
    readonly property bool   cxFresh:     aiPanel.root.aiCxFresh
    readonly property bool   cxHas:       aiPanel.root.aiCxHas
    readonly property var    cxWindows:   aiPanel.root.aiCxWindows || []
    readonly property string cxLimitStatus: aiPanel.root.aiCxLimitStatus
    readonly property string cxLimitReachedType: aiPanel.root.aiCxLimitReachedType
    readonly property var    cxWin0:      cxWindows.length > 0 ? cxWindows[0] : null
    readonly property var    cxWin1:      cxWindows.length > 1 ? cxWindows[1] : null
    readonly property bool   cxHasGeneral5h: {
        for (var i = 0; i < cxWindows.length; i++) {
            if ((cxWindows[i] || {}).minutes === 300) return true
        }
        return false
    }

    readonly property int    ocPct5h:     aiPanel.root.aiOcPct5h
    readonly property int    ocPct7d:     aiPanel.root.aiOcPct7d
    readonly property string ocPlan:      aiPanel.root.aiOcPlan
    readonly property string ocTokens:    aiPanel.root.aiOcTokens
    readonly property string ocRate:      aiPanel.root.aiOcRate
    readonly property string ocModel:     aiPanel.root.aiOcModel
    readonly property int    ocToday:     aiPanel.root.aiOcToday
    readonly property bool   ocFresh:     aiPanel.root.aiOcFresh
    readonly property bool   ocHas:       aiPanel.root.aiOcHas
    readonly property var    ocModels:    aiPanel.root.aiOcModels

    readonly property int    cpPct:       aiPanel.root.aiCpPct
    readonly property string cpLabel:     aiPanel.root.aiCpLabel
    readonly property int    cpResetTs:   aiPanel.root.aiCpResetTs
    readonly property string cpPlan:      aiPanel.root.aiCpPlan
    readonly property bool   cpUnlimited: aiPanel.root.aiCpUnlimited
    readonly property int    cpUsed:      aiPanel.root.aiCpCreditsUsed
    readonly property int    cpEntitlement: aiPanel.root.aiCpCreditsEntitlement
    readonly property bool   cpFresh:     aiPanel.root.aiCpFresh
    readonly property bool   cpHas:       aiPanel.root.aiCpHas

    property var availableTools: []
    property bool authChecked: false
    function applyAuthStatus(states) {
        var tools = [ { id: "claude", label: "Claude" }, { id: "codex", label: "Codex" }, { id: "opencode", label: "OpenCode" }, { id: "copilot", label: "Copilot" } ]
        // Keep OpenCode and Copilot accessible even without a detected CLI login.
        availableTools = tools.filter(function(tool) { return tool.id === "opencode" || tool.id === "copilot" || (states && states[tool.id] === true) })
        authChecked = true
        if (availableTools.length > 0 && !availableTools.some(function(tool) { return tool.id === aiPanel.root.aiTool }))
            aiPanel.root.aiTool = availableTools[0].id
    }
    Process {
        id: authStatusProcess
        command: ["python3", decodeURIComponent(String(Qt.resolvedUrl("../../../scripts/rise-ai-auth-status")).replace(/^(file|qs):\/\//, ""))]
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                authStatusWatchdog.stop()
                aiPanel.applyAuthStatus({})
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                authStatusWatchdog.stop()
                try { aiPanel.applyAuthStatus(JSON.parse(this.text)) }
                catch (e) { aiPanel.applyAuthStatus({}) }
            }
        }
    }
    // Start the deadline before launching: a missing interpreter/helper may
    // fail to start without producing stdout or an exited signal.
    function refreshAuthStatus() {
        if (authStatusProcess.running) return
        authStatusWatchdog.restart()
        authStatusProcess.running = true
    }
    Timer {
        id: authStatusWatchdog
        interval: 15000
        onTriggered: {
            authStatusProcess.running = false
            aiPanel.applyAuthStatus({})
        }
    }
    Timer {
        interval: 60000; repeat: true; triggeredOnStart: true
        running: aiPanel.root.aiUsageVisible
        onTriggered: aiPanel.refreshAuthStatus()
    }

    readonly property bool   showClaude:  availableTools.length > 0 && aiPanel.root.aiTool === "claude"
    readonly property bool   showCodex:   availableTools.length > 0 && aiPanel.root.aiTool === "codex"
    readonly property bool   showOpenCode: availableTools.length > 0 && aiPanel.root.aiTool === "opencode"
    readonly property bool   showCopilot: availableTools.length > 0 && aiPanel.root.aiTool === "copilot"

    property real reveal: aiPanel.root.aiUsageVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: aiPanel.root.aiUsageVisible ? 160 : 120
            easing.type: aiPanel.root.aiUsageVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: aiPanel.root.aiUsageVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: aiPanel.root.aiUsageVisible = false
    }

    // ── reusable label · bar · % row ──
    component UsageRow: Item {
        id: usageRow
        property string label: ""
        property int pct: 0
        property bool dim: false
        width: parent ? parent.width : 0
        height: 16
        UiText {
            id: rowLbl
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: usageRow.label; color: aiPanel.root.sumiHi
            font.family: aiPanel.root.mono; font.pixelSize: 11; font.letterSpacing: 1
        }
        UiText {
            id: rowVal
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: usageRow.pct + "%"
            color: usageRow.dim ? aiPanel.root.sumi : aiPanel.root.seal
            font.family: aiPanel.root.mono; font.pixelSize: 11; font.weight: Font.Medium
        }
        Rectangle {
            anchors.left: rowLbl.right; anchors.leftMargin: 8
            anchors.right: rowVal.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 8; radius: 4
            color: Qt.rgba(aiPanel.root.seal.r, aiPanel.root.seal.g, aiPanel.root.seal.b, 0.15)
            Rectangle {
                width: parent.width * Math.min(100, parent ? usageRow.pct : 0) / 100
                height: parent.height; radius: 4
                color: usageRow.pct >= 90 ? aiPanel.root.sealRaw : aiPanel.root.seal
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }
    }

    // ── reusable key/value detail row ──
    component DetailRow: Row {
        id: detailRow
        property string k: ""
        property string v: ""
        width: parent ? parent.width : 0
        spacing: 8
        UiText {
            text: detailRow.k; color: aiPanel.root.sumiHi
            font.family: aiPanel.root.mono; font.pixelSize: 11
            width: Math.max(0, (parent.width - parent.spacing) * 0.45)
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }
        UiText {
            text: detailRow.v; color: aiPanel.root.ink
            font.family: aiPanel.root.mono; font.pixelSize: 11
            width: Math.max(0, (parent.width - parent.spacing) * 0.55); horizontalAlignment: Text.AlignRight
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }
    }

    // ── compact OpenCode per-model usage row ──
    component ModelUsageRow: Item {
        id: modelUsageRow
        property string name: ""
        property string totalLabel: ""
        property string inputLabel: ""
        property string outputLabel: ""
        property string reasoningLabel: ""
        property string cacheReadLabel: ""
        property string cacheWriteLabel: ""
        property string todayLabel: ""
        property int pct: 0

        width: parent ? parent.width : 0
        height: 42

        UiText {
            id: modelName
            anchors.left: parent.left; anchors.top: parent.top
            width: parent.width * 0.68
            text: modelUsageRow.name
            elide: Text.ElideRight
            color: aiPanel.root.ink
            font.family: aiPanel.root.mono; font.pixelSize: 10; font.weight: Font.Medium
        }
        UiText {
            anchors.right: parent.right; anchors.top: parent.top
            text: modelUsageRow.totalLabel
            color: aiPanel.root.seal
            font.family: aiPanel.root.mono; font.pixelSize: 10; font.weight: Font.Medium
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: modelName.bottom; anchors.topMargin: 5
            height: 6; radius: 3
            color: Qt.rgba(aiPanel.root.seal.r, aiPanel.root.seal.g, aiPanel.root.seal.b, 0.14)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, modelUsageRow.pct)) / 100
                height: parent.height; radius: 3
                color: aiPanel.root.seal
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }
        UiText {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            text: "I " + modelUsageRow.inputLabel + "  O " + modelUsageRow.outputLabel
                + (modelUsageRow.reasoningLabel !== "0" ? "  R " + modelUsageRow.reasoningLabel : "")
                + (modelUsageRow.cacheReadLabel !== "0" ? "  CR " + modelUsageRow.cacheReadLabel : "")
                + (modelUsageRow.cacheWriteLabel !== "0" ? "  CW " + modelUsageRow.cacheWriteLabel : "")
                + (modelUsageRow.todayLabel !== "0" ? "  today " + modelUsageRow.todayLabel : "")
            elide: Text.ElideRight
            color: aiPanel.root.sumiHi
            font.family: aiPanel.root.mono; font.pixelSize: 9
        }
    }

    Rectangle {
        id: card
        width: Math.min(360, parent.width - 12)
        height: Math.min(col.implicitHeight + 2 * aiPanel.contentPadding, parent.height - 2 * (aiPanel.barBottom + aiPanel.gap))
        radius: aiPanel.reveal > 0.001 ? aiPanel.root.pillRadius : 0
        color: aiPanel.root.bg
        border.color: aiPanel.root.pillBorder
        border.width: aiPanel.root.pillBorderW
        PillShadow { theme: aiPanel.root }

        x: Math.round(Math.max(6, Math.min(aiPanel.root.aiBarX - width / 2, parent.width - width - 6)))
        y: aiPanel.root.barPosition === "bottom" ? (parent.height - aiPanel.barBottom - aiPanel.gap - height) : (aiPanel.barBottom + aiPanel.gap)
        opacity: aiPanel.reveal
        focus: aiPanel.root.aiUsageVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                aiPanel.root.aiUsageVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: aiPanel.contentPadding
            contentWidth: width
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                width: scroller.width
                spacing: 8

                // ── header ──
                Item {
                    width: parent.width
                    height: 24
                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "AI USAGE"
                        color: aiPanel.root.ink
                        font.family: aiPanel.root.mono
                        font.pixelSize: 13
                        font.letterSpacing: 2
                        font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        color: closeMa.containsMouse ? aiPanel.root.seal : aiPanel.root.sumi
                        font.pixelSize: 12
                        Behavior on color { ColorAnimation { duration: 120 } }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: aiPanel.root.aiUsageVisible = false
                        }
                    }
                }

                UiText {
                    visible: aiPanel.availableTools.length === 0
                    width: parent.width
                    text: aiPanel.authChecked ? "No AI service logged in" : "Checking login…"
                    color: aiPanel.root.sumiHi
                    font.family: aiPanel.root.mono; font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
                // ── segmented switch: which tool the bar shows ──
                Row {
                    width: parent.width
                    height: 32
                    spacing: 6
                    Repeater {
                        model: aiPanel.availableTools
                        Rectangle {
                            id: toolOption
                            required property var modelData
                            width: (parent.width - Math.max(0, aiPanel.availableTools.length - 1) * 6) / Math.max(1, aiPanel.availableTools.length)
                            height: 32; radius: aiPanel.root.tileRadius
                            readonly property bool active: aiPanel.root.aiTool === modelData.id
                            color: active ? aiPanel.root.fillActive
                                  : segMa.containsMouse ? aiPanel.root.fillHover : aiPanel.root.fillIdle
                            border.color: (active || segMa.containsMouse) ? aiPanel.root.seal : aiPanel.root.sep
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            UiText {
                                anchors.centerIn: parent
                                text: toolOption.modelData.label
                                color: (parent.active || segMa.containsMouse) ? aiPanel.root.seal : aiPanel.root.ink
                                font.family: aiPanel.root.mono; font.pixelSize: 11
                                font.weight: parent.active ? Font.Medium : Font.Normal
                            }
                            MouseArea {
                                id: segMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: aiPanel.root.aiTool = parent.modelData.id
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: aiPanel.root.sep }

                // ── Claude Code ──
                Item {
                    visible: aiPanel.showClaude
                    width: parent.width; height: 16
                    UiText {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "Claude Code"; color: aiPanel.root.ink
                        font.family: aiPanel.root.mono; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: aiPanel.clFresh ? "live" : "stale"
                        color: aiPanel.clFresh ? aiPanel.root.sumi : aiPanel.root.sealRaw
                        font.family: aiPanel.root.mono; font.pixelSize: 10
                    }
                }
                UiText {
                    visible: aiPanel.showClaude && !aiPanel.clHas
                    width: parent.width
                    text: "no data — run claude"
                    color: aiPanel.root.sumiHi; font.family: aiPanel.root.mono; font.pixelSize: 11
                }
                UsageRow { visible: aiPanel.showClaude && aiPanel.clHas; label: "5h"; pct: aiPanel.clPct5h; dim: !aiPanel.clFresh }
                UsageRow { visible: aiPanel.showClaude && aiPanel.clHas; label: "7d"; pct: aiPanel.clPct7d; dim: !aiPanel.clFresh }
                DetailRow { visible: aiPanel.showClaude && aiPanel.clHas; k: "5h resets in"; v: aiPanel.root.aiFmtResetDetail(aiPanel.clReset5hTs) || "—" }
                DetailRow { visible: aiPanel.showClaude && aiPanel.clHas; k: "7d resets in"; v: aiPanel.root.aiFmtResetDetail(aiPanel.clReset7dTs) || "—" }
                DetailRow { visible: aiPanel.showClaude && aiPanel.clHas && aiPanel.clTokens !== ""; k: "Tokens"; v: aiPanel.clTokens }
                DetailRow { visible: aiPanel.showClaude && aiPanel.clHas && aiPanel.clRate !== "";   k: "Rate"; v: aiPanel.clRate }
                DetailRow { visible: aiPanel.showClaude && aiPanel.clHas && aiPanel.clToday > 0; k: "Today"; v: (aiPanel.clToday / 1e6).toFixed(2) + "M tok" }

                Rectangle { visible: false; width: parent.width; height: 1; color: aiPanel.root.sep }

                // ── OpenAI Codex ──
                Item {
                    visible: aiPanel.showCodex
                    width: parent.width; height: 16
                    UiText {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "OpenAI Codex" + (aiPanel.cxPlan ? "  · " + aiPanel.cxPlan : "")
                        color: aiPanel.root.ink
                        font.family: aiPanel.root.mono; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: aiPanel.cxFresh ? "live" : "stale"
                        color: aiPanel.cxFresh ? aiPanel.root.sumi : aiPanel.root.sealRaw
                        font.family: aiPanel.root.mono; font.pixelSize: 10
                    }
                }
                UiText {
                    visible: aiPanel.showCodex && !aiPanel.cxHas
                    width: parent.width
                    text: "no data — run codex"
                    color: aiPanel.root.sumiHi; font.family: aiPanel.root.mono; font.pixelSize: 11
                }
                UsageRow { visible: aiPanel.showCodex && aiPanel.cxWin0 !== null; label: aiPanel.cxWin0 ? aiPanel.cxWin0.label : ""; pct: aiPanel.cxWin0 ? aiPanel.cxWin0.pct : 0; dim: !aiPanel.cxFresh }
                UsageRow { visible: aiPanel.showCodex && aiPanel.cxWin1 !== null; label: aiPanel.cxWin1 ? aiPanel.cxWin1.label : ""; pct: aiPanel.cxWin1 ? aiPanel.cxWin1.pct : 0; dim: !aiPanel.cxFresh }
                DetailRow { visible: aiPanel.showCodex && aiPanel.cxWin0 !== null; k: (aiPanel.cxWin0 ? aiPanel.cxWin0.label : "") + " resets in"; v: aiPanel.root.aiFmtResetDetail(aiPanel.cxWin0 ? aiPanel.cxWin0.resetTs : 0) || "—" }
                DetailRow { visible: aiPanel.showCodex && aiPanel.cxWin1 !== null; k: (aiPanel.cxWin1 ? aiPanel.cxWin1.label : "") + " resets in"; v: aiPanel.root.aiFmtResetDetail(aiPanel.cxWin1 ? aiPanel.cxWin1.resetTs : 0) || "—" }
                DetailRow { visible: aiPanel.showCodex && aiPanel.cxHas; k: "General limit"; v: aiPanel.root.aiCodexStatusLabel(aiPanel.cxLimitStatus, aiPanel.cxLimitReachedType) }
                DetailRow { visible: aiPanel.showCodex && aiPanel.cxHas && aiPanel.cxRate !== "";   k: "Local activity (1h, incl. cached)"; v: aiPanel.cxRate }
                DetailRow { visible: aiPanel.showCodex && aiPanel.cxHas && aiPanel.cxToday > 0; k: "Today"; v: (aiPanel.cxToday / 1e6).toFixed(2) + "M tok" }

                Rectangle { visible: false; width: parent.width; height: 1; color: aiPanel.root.sep }

                // ── OpenCode ──
                Item {
                    visible: aiPanel.showOpenCode
                    width: parent.width; height: 16
                    UiText {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "OpenCode" + (aiPanel.ocPlan ? "  · " + aiPanel.ocPlan : "")
                        color: aiPanel.root.ink
                        font.family: aiPanel.root.mono; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    UiText {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: aiPanel.ocFresh ? "live" : "stale"
                        color: aiPanel.ocFresh ? aiPanel.root.sumi : aiPanel.root.sealRaw
                        font.family: aiPanel.root.mono; font.pixelSize: 10
                    }
                }
                UiText {
                    visible: aiPanel.showOpenCode && !aiPanel.ocHas
                    width: parent.width
                    text: "no data — run opencode"
                    color: aiPanel.root.sumiHi; font.family: aiPanel.root.mono; font.pixelSize: 11
                }
                UsageRow { visible: aiPanel.showOpenCode && aiPanel.ocHas; label: "5h"; pct: aiPanel.ocPct5h; dim: !aiPanel.ocFresh }
                UsageRow { visible: aiPanel.showOpenCode && aiPanel.ocHas; label: "7d"; pct: aiPanel.ocPct7d; dim: !aiPanel.ocFresh }
                DetailRow { visible: aiPanel.showOpenCode && aiPanel.ocHas && aiPanel.ocTokens !== ""; k: "Tokens"; v: aiPanel.ocTokens }
                DetailRow { visible: aiPanel.showOpenCode && aiPanel.ocHas && aiPanel.ocRate !== "";   k: "Rate"; v: aiPanel.ocRate }
                DetailRow { visible: aiPanel.showOpenCode && aiPanel.ocHas && aiPanel.ocToday > 0; k: "Today"; v: (aiPanel.ocToday / 1e6).toFixed(2) + "M tok" }
                DetailRow { visible: aiPanel.showOpenCode && aiPanel.ocHas && aiPanel.ocModel !== ""; k: "Latest"; v: aiPanel.ocModel }

                Item {
                    visible: aiPanel.showOpenCode && aiPanel.ocHas && aiPanel.ocModels.length > 0
                    width: parent.width; height: 16
                    UiText {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "MODELS"
                        color: aiPanel.root.sumiHi
                        font.family: aiPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
                    }
                    UiText {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "recent"
                        color: aiPanel.root.sumi
                        font.family: aiPanel.root.mono; font.pixelSize: 10
                    }
                }
                Repeater {
                    model: (aiPanel.showOpenCode && aiPanel.ocHas) ? aiPanel.ocModels : []
                    ModelUsageRow {
                        required property var modelData
                        width: col.width
                        name: modelData.name || ""
                        totalLabel: modelData.totalLabel || ""
                        inputLabel: modelData.inputLabel || "0"
                        outputLabel: modelData.outputLabel || "0"
                        reasoningLabel: modelData.reasoningLabel || "0"
                        cacheReadLabel: modelData.cacheReadLabel || "0"
                        cacheWriteLabel: modelData.cacheWriteLabel || "0"
                        todayLabel: modelData.todayLabel || "0"
                        pct: parseInt(modelData.pct) || 0
                    }
                }

                // ── GitHub Copilot ──
                Item {
                    visible: aiPanel.showCopilot
                    width: parent.width; height: Math.max(16, copilotTitle.implicitHeight)
                    UiText {
                        id: copilotTitle
                        anchors.left: parent.left; anchors.right: copilotFreshness.left; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                        text: "GitHub Copilot" + (aiPanel.cpPlan ? "  · " + aiPanel.cpPlan : "")
                        color: aiPanel.root.ink
                        font.family: aiPanel.root.mono; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    UiText {
                        id: copilotFreshness
                        anchors.right: parent.right; anchors.top: parent.top
                        text: aiPanel.cpFresh ? "live" : "stale"
                        color: aiPanel.cpFresh ? aiPanel.root.sumi : aiPanel.root.sealRaw
                        font.family: aiPanel.root.mono; font.pixelSize: 10
                    }
                }
                UiText {
                    visible: aiPanel.showCopilot && !aiPanel.cpHas
                    width: parent.width
                    text: "no data — run gh auth login"
                    color: aiPanel.root.sumiHi; font.family: aiPanel.root.mono; font.pixelSize: 11
                }
                UsageRow {
                    visible: aiPanel.showCopilot && aiPanel.cpHas && !aiPanel.cpUnlimited
                    label: aiPanel.cpLabel || "30d"
                    pct: aiPanel.cpPct
                    dim: !aiPanel.cpFresh
                }
                DetailRow {
                    visible: aiPanel.showCopilot && aiPanel.cpHas && aiPanel.cpUnlimited
                    k: "Premium requests"; v: "unlimited"
                }
                DetailRow {
                    visible: aiPanel.showCopilot && aiPanel.cpHas && !aiPanel.cpUnlimited
                    k: (aiPanel.cpLabel || "30d") + " resets in"
                    v: aiPanel.root.aiFmtResetDetail(aiPanel.cpResetTs) || "—"
                }
                DetailRow {
                    visible: aiPanel.showCopilot && aiPanel.cpHas && aiPanel.cpEntitlement > 0
                    k: "Premium requests"; v: aiPanel.cpUsed + " / " + aiPanel.cpEntitlement
                }
            }
        }
    }

    // Usage data + polling live in Theme.qml (shared with the bar pill); this panel
    // only renders from root.ai* and bumps the refresh cadence via root.aiUsageVisible.
    SidePanelPositioner { root: aiPanel.root; target: card; anchorName: "ai" }
}
