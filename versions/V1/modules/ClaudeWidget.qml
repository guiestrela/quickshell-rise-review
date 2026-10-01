import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Combined AI-usage pill (Claude Code + OpenAI Codex + OpenCode + GitHub Copilot). The bar
// shows ONE tool (root.aiTool) as a themed-tinted SVG with a bottom-up usage fill; the tooltip
// shows all tracked tools; clicking opens the AiUsagePanel where the tool can be switched.
// Gating is unchanged: root.modClaude is the on/off toggle for the whole pill.
Item {
    id: rootMod
    required property var root

    // ── which tool the bar pill displays ──
    readonly property bool isCodex: root.aiTool === "codex"
    readonly property bool isOpenCode: root.aiTool === "opencode"
    readonly property bool isCopilot: root.aiTool === "copilot"
    readonly property bool isLogo: isCodex || isOpenCode || isCopilot
    readonly property url  logoSource: Qt.resolvedUrl(
        isCopilot  ? "../assets/copilot-white.svg"
      : isOpenCode ? "../assets/opencode-mark.svg"
      : "../assets/codex.svg")
    readonly property var  logoSourceSize: isOpenCode ? Qt.size(20, 12) : Qt.size(56, 56)
    readonly property int  codexMarkSize: 14
    readonly property int  ocMarkW: 20
    readonly property int  ocMarkH: 12
    readonly property int  cpMarkSize: 15

    // ── Claude: process detection is local (drives the pill's visibility); all
    //    usage data comes from root.ai* — the single shared parse in Theme.qml that
    //    AiUsagePanel renders from too, so the two views can't drift apart. ──
    property bool clActive: false
    readonly property bool   clFresh:     root.aiClFresh
    readonly property int    clPct5h:     root.aiClPct5h
    readonly property int    clPct7d:     root.aiClPct7d
    readonly property bool   clBlocked:   root.aiClBlocked
    readonly property string clTokens:    root.aiClTokens
    readonly property string clRate:      root.aiClRate
    readonly property int    clReset5hTs: root.aiClReset5hTs
    readonly property int    clReset7dTs: root.aiClReset7dTs
    readonly property int    clToday:     root.aiClToday
    readonly property bool   clHas:       root.aiClHas

    // ── Codex ──
    property bool cxActive: false
    readonly property bool   cxFresh:     root.aiCxFresh
    readonly property int    cxPct5h:     root.aiCxPct5h
    readonly property int    cxPct7d:     root.aiCxPct7d    // weekly
    readonly property string cxPlan:      root.aiCxPlan
    readonly property string cxTokens:    root.aiCxTokens
    readonly property string cxRate:      root.aiCxRate
    readonly property int    cxReset5hTs: root.aiCxReset5hTs
    readonly property int    cxReset7dTs: root.aiCxReset7dTs
    readonly property bool   cxHas:       root.aiCxHas
    readonly property var    cxBuckets:   root.aiCxBuckets || []
    readonly property var    cxWindows:   root.aiCxWindows || []
    readonly property string cxLimitStatus: root.aiCxLimitStatus
    readonly property string cxLimitReachedType: root.aiCxLimitReachedType
    readonly property int    cxPrimaryPct: root.aiCxPrimaryPct
    readonly property string cxPrimaryLabel: root.aiCxPrimaryLabel
    readonly property bool   cxHasGeneral5h: {
        for (var i = 0; i < cxWindows.length; i++) {
            if ((cxWindows[i] || {}).minutes === 300) return true
        }
        return false
    }

    // ── OpenCode ──
    property bool ocActive: false
    readonly property bool   ocFresh:     root.aiOcFresh
    readonly property int    ocPct5h:     root.aiOcPct5h
    readonly property int    ocPct7d:     root.aiOcPct7d
    readonly property string ocPlan:      root.aiOcPlan
    readonly property string ocTokens:    root.aiOcTokens
    readonly property string ocRate:      root.aiOcRate
    readonly property string ocModel:     root.aiOcModel
    readonly property int    ocToday:     root.aiOcToday
    readonly property bool   ocHas:       root.aiOcHas

    // ── Copilot: one monthly premium-request window, not a 5h/7d pair ──
    property bool cpActive: false
    readonly property bool   cpFresh:     root.aiCpFresh
    readonly property int    cpPct:       root.aiCpPct
    readonly property string cpLabel:     root.aiCpLabel
    readonly property int    cpResetTs:   root.aiCpResetTs
    readonly property string cpPlan:      root.aiCpPlan
    readonly property bool   cpUnlimited: root.aiCpUnlimited
    readonly property int    cpUsed:      root.aiCpCreditsUsed
    readonly property int    cpEntitlement: root.aiCpCreditsEntitlement
    readonly property bool   cpHas:       root.aiCpHas
    readonly property string cpCredits:   (root.aiCpCreditsUsed || 0) + " / " + (root.aiCpCreditsEntitlement || 0) + " premium requests"

    // ── per-tool signal (active OR fresh non-zero usage) ──
    readonly property bool clSignal: clActive || (clPct5h > 0 && clFresh)
    readonly property bool cxSignal: cxActive || (cxPrimaryPct > 0 && cxFresh)
    readonly property bool ocSignal: ocActive || ((ocPct5h > 0 || ocToday > 0) && ocFresh)
    // an unlimited Copilot plan has nothing to chart, so only "running" counts
    readonly property bool cpSignal: cpActive || (!cpUnlimited && cpPct > 0 && cpFresh)

    // ── selected-tool display values ──
    readonly property int  pct5h:   isCopilot ? cpPct
                                : isOpenCode ? ocPct5h
                                : isCodex ? cxPrimaryPct : clPct5h
    readonly property int  pct5hStep: Math.round(pct5h / 5) * 5
    readonly property bool selHas: isCopilot ? cpHas
                               : isOpenCode ? ocHas
                               : isCodex ? cxHas : clHas
    readonly property bool selFresh: isCopilot ? cpFresh
                                 : isOpenCode ? ocFresh
                                 : isCodex ? cxFresh : clFresh
    readonly property bool selSignal: isCopilot ? cpSignal
                                  : isOpenCode ? ocSignal
                                  : isCodex ? cxSignal : clSignal
    readonly property bool blocked:  (isCodex || isOpenCode || isCopilot) ? false : clBlocked

    // show whenever the gate is on AND any tool has a signal — the pill stays
    // reachable (to open the panel + switch) even if the selected tool is idle
    readonly property bool shown: (selHas || clSignal || cxSignal || ocSignal || cpSignal) && root.modClaude

    readonly property string tooltipText: {
        var lines = []
        if (selHas && !selFresh) lines.push("Last known usage · stale")
        if (clHas || clActive) {
            lines.push("Claude Code")
            var cr = root.aiFmtReset(clReset5hTs)
            lines.push("5h: " + clPct5h + "%" + (cr ? "  (reset in " + cr + ")" : ""))
            var c7 = root.aiFmtReset(clReset7dTs)
            if (clPct7d > 0) lines.push("7d: " + clPct7d + "%" + (c7 ? "  (reset in " + c7 + ")" : ""))
            if (clTokens)    lines.push(clTokens + " tokens" + (clRate ? "  · " + clRate : ""))
            if (clToday > 0) lines.push("today: " + (clToday / 1e6).toFixed(2) + "M tok")
        }
        if (cxHas || cxActive) {
            if (lines.length) lines.push("")
            lines.push("OpenAI Codex" + (cxPlan ? "  (" + cxPlan + ")" : ""))
            for (var i = 0; i < cxWindows.length; i++) {
                var xw = cxWindows[i] || {}
                var xr = root.aiFmtReset(xw.resetTs || 0)
                lines.push(String(xw.label || "window") + ": " + (xw.pct || 0) + "%" + (xr ? "  (reset in " + xr + ")" : ""))
            }
            if (!cxHasGeneral5h) lines.push("5h: not reported by Codex RPC")
            lines.push("General limit: " + root.aiCodexStatusLabel(cxLimitStatus, cxLimitReachedType))
            if (cxRate) lines.push("Local activity (1h, incl. cached): " + cxRate)
        }
        if (ocHas || ocActive) {
            if (lines.length) lines.push("")
            lines.push("OpenCode" + (ocPlan ? "  (" + ocPlan + ")" : ""))
            lines.push("5h: " + ocPct5h + "%  ·  7d: " + ocPct7d + "%")
            if (ocTokens) lines.push(ocTokens + " tokens" + (ocRate ? "  · " + ocRate : ""))
            if (ocToday > 0) lines.push("today: " + (ocToday / 1e6).toFixed(2) + "M tok")
            if (ocModel) lines.push(ocModel)
        }
        if (cpHas || cpActive) {
            if (lines.length) lines.push("")
            lines.push("GitHub Copilot" + (cpPlan ? "  (" + cpPlan + ")" : ""))
            if (cpUnlimited) {
                lines.push("Premium requests: unlimited")
            } else {
                var cpr = root.aiFmtReset(cpResetTs)
                lines.push((cpLabel || "30d") + ": " + cpPct + "%" + (cpr ? "  (resets in " + cpr + ")" : ""))
                if (cpEntitlement > 0) lines.push(cpCredits)
            }
        }
        return lines.length ? lines.join("\n") : "AI usage"
    }

    // keep rendered until the collapse animation finishes
    visible: implicitWidth > 0.5
    implicitWidth: shown ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: shown ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    // ── process detection ──
    Process {
        id: detectClaude
        command: ["bash", "-c", "pgrep -x claude >/dev/null 2>&1 && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: { rootMod.clActive = (this.text.trim() === "1") } }
    }
    Process {
        id: detectCodex
        // exact process-name match (comm == "codex") so the cache readers / poller
        // (python codex-usage, bash on codex-usage.json) never count as "active";
        // drop the short-lived `codex … app-server` our own backend spawns
        command: ["bash", "-c", "pgrep -xa codex 2>/dev/null | grep -vq app-server && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: { rootMod.cxActive = (this.text.trim() === "1") } }
    }
    Process {
        id: detectOpenCode
        command: ["bash", "-c", "ps -eo args | grep -E '(^|/| )opencode( |$)|opencode-ai' | grep -vE 'grep|opencode-usage' >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: { rootMod.ocActive = (this.text.trim() === "1") } }
    }
    Process {
        id: detectCopilot
        // exclude our own poller (`copilot-usage`, a python script) and the grep itself
        command: ["bash", "-c", "pgrep -xa copilot 2>/dev/null | grep -vq copilot-usage && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: { rootMod.cpActive = (this.text.trim() === "1") } }
    }
    Timer {
        interval: 5000; running: root.modClaude || root.aiUsageVisible; repeat: true; triggeredOnStart: true
        onTriggered: {
            detectClaude.running = false; detectClaude.running = true
            detectCodex.running = false;  detectCodex.running = true
            detectOpenCode.running = false; detectOpenCode.running = true
            detectCopilot.running = false; detectCopilot.running = true
        }
    }

    // ── background pill ──
    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: root.pillH; radius: root.pillRadius
        color: root.pill
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        // icon with bottom-to-top usage fill. Claude keeps its nerd-font glyph;
// Codex/OpenCode/Copilot use vector marks themed via the shared logo tint shader.
        Item {
            id: iconItem
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: rootMod.isOpenCode ? rootMod.ocMarkW
                : (rootMod.isCodex ? rootMod.codexMarkSize
                : (rootMod.isCopilot ? rootMod.cpMarkSize : 15))
            implicitHeight: rootMod.isOpenCode ? rootMod.ocMarkH
                : (rootMod.isCodex ? rootMod.codexMarkSize
                : (rootMod.isCopilot ? rootMod.cpMarkSize : 15))
            width: implicitWidth
            height: implicitHeight

            // ── Claude: nerd-font glyph (original look) ──
            Item {
                anchors.centerIn: parent
                visible: !rootMod.isLogo
                implicitWidth: glyphBase.implicitWidth
                implicitHeight: glyphBase.implicitHeight

                UiText {
                    id: glyphBase
                    text: String.fromCodePoint(0xF167A)
                    renderType: Text.QtRendering
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25)
                    font.family: root.mono
                    font.pixelSize: 14
                }
                Item {
                    clip: true
                    width: parent.width
                    anchors.bottom: parent.bottom
                    height: rootMod.pct5hStep > 0
                        ? Math.min(parent.height, Math.max(parent.height * rootMod.pct5hStep / 100, parent.height * 0.25))
                        : 0
                    Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    UiText {
                        anchors.bottom: parent.bottom
                        text: String.fromCodePoint(0xF167A)
                        renderType: Text.QtRendering
                        color: root.seal
                        font.family: root.mono
                        font.pixelSize: 14
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            // ── Logo tools: tinted SVG ──
            Item {
                anchors.fill: parent
                visible: rootMod.isLogo

                Image {
                    id: codexBase
                    anchors.fill: parent
                    source: rootMod.logoSource
                    sourceSize: rootMod.logoSourceSize
                    fillMode: Image.PreserveAspectFit
                    smooth: !rootMod.isOpenCode
                    mipmap: !rootMod.isOpenCode
                    // thinner-stroked than the Claude glyph → needs more presence
                    // than the glyph's 0.25 faint base to stay recognizable
                    opacity: rootMod.isCodex ? 0.65 : 0.5
                    layer.enabled: true
                    layer.smooth: !rootMod.isCodex
                    layer.effect: ShaderEffect {
                        property color tintColor: root.ink
                        fragmentShader: Qt.resolvedUrl("../shaders/logo-tint.frag.qsb")
                    }
                }
                Item {
                    clip: true
                    width: parent.width
                    anchors.bottom: parent.bottom
                    height: rootMod.pct5hStep > 0
                        ? Math.min(parent.height, Math.max(parent.height * rootMod.pct5hStep / 100, parent.height * 0.22))
                        : 0
                    Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    Image {
                        width: iconItem.width; height: iconItem.height
                        anchors.bottom: parent.bottom
                        source: rootMod.logoSource
                        sourceSize: rootMod.logoSourceSize
                        fillMode: Image.PreserveAspectFit
                        smooth: !rootMod.isOpenCode
                        mipmap: !rootMod.isOpenCode
                        layer.enabled: true
                        layer.smooth: !rootMod.isCodex
                        layer.effect: ShaderEffect {
                            property color tintColor: root.seal
                            fragmentShader: Qt.resolvedUrl("../shaders/logo-tint.frag.qsb")
                        }
                    }
                }
            }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.blocked
                ? "BLK"
                : (rootMod.selHas ? String(rootMod.pct5h).padStart(2, "0") + "%" : "··")
            color: rootMod.blocked
                ? root.seal
                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.85)
            font.family: root.mono
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: if (shown) { root.refreshAiUsage(); tip.show() }
        onExited: { tip.hide() }
        onClicked: { tip.hide(); root.aiUsageVisible = !root.aiUsageVisible }
    }
}
