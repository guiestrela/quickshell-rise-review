// Common behavior for variant-specific presentations.
.pragma library

function refreshBrightness(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        riseEnvironment.briProc.running = false
        riseEnvironment.briProc.running = true
    }

function notifyBrightnessError(riseOwner, riseEnvironment, action, exitCode) {
    var riseState = riseOwner;

        if (exitCode === 0 || riseState.brightnessErrorNotified) return
        riseState.brightnessErrorNotified = true
        riseEnvironment.brightnessErrNotify.command = ["bash", "-c",
            "notify-send -a 'QS-Shell' 'Brightness command failed' '" + action + " failed; brightness backend unavailable.' 2>/dev/null || true"]
        riseEnvironment.brightnessErrNotify.running = false
        riseEnvironment.brightnessErrNotify.running = true
    }
