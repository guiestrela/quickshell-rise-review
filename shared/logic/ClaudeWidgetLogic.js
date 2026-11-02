// Common behavior for variant-specific presentations.
.pragma library

function openSelectedAgent(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var command = riseEnvironment.root.aiTool === "codex" ? "codex"
                    : riseEnvironment.root.aiTool === "opencode" ? "opencode"
                    : riseEnvironment.root.aiTool === "copilot" ? "copilot" : "claude"
        riseEnvironment.launchAgent.command = ["bash", "-lc", "omarchy-launch-floating-terminal-with-presentation " + command]
        riseEnvironment.launchAgent.running = false
        riseEnvironment.launchAgent.running = true
    }
