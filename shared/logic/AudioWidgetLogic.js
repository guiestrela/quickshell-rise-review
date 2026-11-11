// Common behavior for variant-specific presentations.
.pragma library

function volumeCommand(riseOwner, riseEnvironment, steps) {
    var riseState = riseOwner;

        var amount = Math.min(100, Math.abs(steps) * 5)
        var up = steps > 0
        var direction = up ? "+" : "-"
        var fallback = "wpctl set-volume " + (up ? "-l 1.0 " : "") + "@DEFAULT_AUDIO_SINK@ " + amount + "%" + direction + " || " +
            "pamixer " + (up ? "--increase " : "--decrease ") + amount
        // Omarchy's helper resolves DSP sinks, clamps to 0–100, unmutes on
        // adjustment, and displays its native OSD. Keep the fallback for
        // standalone Rise installs outside Omarchy.
        return "if command -v omarchy-audio-output-volume >/dev/null 2>&1; then " +
            "omarchy-audio-output-volume " + direction + amount + "; else " + fallback + "; fi"
    }

function runPendingVolumeCommand(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (riseEnvironment.volumeRunner.running || riseState.pendingVolumeSteps === 0) return
        var steps = riseState.pendingVolumeSteps
        riseState.pendingVolumeSteps = 0
        riseEnvironment.volumeRunner.action = steps > 0 ? "Volume up" : "Volume down"
        riseEnvironment.volumeRunner.command = ["bash", "-c", riseState.volumeCommand(steps)]
        riseEnvironment.volumeRunner.running = true
    }

function queueVolumeStep(riseOwner, riseEnvironment, step) {
    var riseState = riseOwner;

        riseState.pendingVolumeSteps += step
        riseState.runPendingVolumeCommand()
    }

function notifyAudioError(riseOwner, riseEnvironment, action, exitCode) {
    var riseState = riseOwner;

        if (exitCode === 0 || riseState.audioErrorNotified) return
        riseState.audioErrorNotified = true
        riseEnvironment.audioErrNotify.command = ["bash", "-c",
            "notify-send -a 'QS-Shell' 'Audio command failed' '" + action + " failed; audio backend unavailable.' 2>/dev/null || true"]
        riseEnvironment.audioErrNotify.running = false
        riseEnvironment.audioErrNotify.running = true
    }
