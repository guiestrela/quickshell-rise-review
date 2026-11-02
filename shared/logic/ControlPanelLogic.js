// Common behavior for variant-specific presentations.
.pragma library

function switchBar(riseOwner, riseEnvironment, version) {
    var riseState = riseOwner;

        if (version !== "v1" && version !== "v2") return
        riseOwner.root.controlVisible = false
        if (riseOwner.root.variantHost)
            riseOwner.root.variantHost.requestSwitch(version)
        else
            riseEnvironment.Quickshell.execDetached([riseState.barctlPath, "switch", version])
    }

function reloadBar(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        riseOwner.root.controlVisible = false
        riseEnvironment.Quickshell.reload(false)
    }

function runPowerAction(riseOwner, riseEnvironment, action) {
    var riseState = riseOwner;

        var commands = {
            lock: ["omarchy", "system", "lock"],
            suspend: ["systemctl", "--no-ask-password", "suspend"],
            reboot: ["omarchy", "system", "reboot"],
            shutdown: ["omarchy", "system", "shutdown"]
        }
        if (!commands[action]) return
        riseEnvironment.Quickshell.execDetached(commands[action])
        riseOwner.root.controlVisible = false
    }
