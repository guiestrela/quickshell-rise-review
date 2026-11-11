// Common behavior for variant-specific presentations.
.pragma library

function formatSpeed(riseOwner, riseEnvironment, bps) {
    var riseState = riseOwner;

        var mb = bps / 1048576
        var s = mb < 10 ? mb.toFixed(2) : mb.toFixed(1)
        return s.padStart(5) + "M"  // always 6 chars: " 0.00M" … "100.0M"
    }
