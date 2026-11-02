// Common behavior for variant-specific presentations.
.pragma library

function runBrightnessStep(riseOwner, riseEnvironment, up) {
    var riseState = riseOwner;

        var runner = up ? riseEnvironment.briUp : riseEnvironment.briDown
        if (runner.running) return
        runner.running = true
    }
