// Common behavior for variant-specific presentations.
.pragma library

function finishCheck(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        if (!riseState.checkFinished || !riseState.checkOutputReady) return
        riseEnvironment.refreshWatchdog.stop()
        if (riseState.checkTimedOut) {
            riseEnvironment.root.archScanError = "Update check timed out. Previous results retained."
        } else if (riseState.checkExitCode !== 0 || !riseState.parseOutput(riseEnvironment.checkStdout.text)) {
            riseEnvironment.root.archScanError = "Update check failed. Previous results retained."
        } else {
            riseEnvironment.root.archScanError = ""
        }
        riseState.refreshing = false
    }

function parseOutput(riseOwner, riseEnvironment, text) {
    var riseState = riseOwner;

        var lines = text.trim().split("\n")
        var updates = []
        var sysCount = 0; var aCount = 0
        var scan = null
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("|")
            if (parts.length >= 4) {
                var src = parts[0]
                if (src === "M") {
                    scan = { id: parts[1] || "", checked: parseInt(parts[2] || "0"),
                        hash: parts[3] || "", count: parseInt(parts[4] || "0") }
                    continue
                }
                if (src !== "S" && src !== "A") continue
                var entry = {name: parts[1], oldVer: parts[2], newVer: parts[3], source: src === "S" ? "system" : "aur"}
                updates.push(entry)
                if (src === "S") sysCount++
                else if (src === "A") aCount++
            }
        }
        // An empty successful scan still includes M metadata. Empty/malformed
        // stdout is not evidence that the machine has no available updates.
        if (!scan || !scan.id || !scan.hash || !isFinite(scan.checked)
                || scan.checked <= 0 || !isFinite(scan.count) || scan.count !== sysCount)
            return false
        riseEnvironment.root.archScanId = scan.id
        riseEnvironment.root.archScanCheckedEpoch = scan.checked
        riseEnvironment.root.archScanHash = scan.hash
        riseEnvironment.root.archScanSystemCount = scan.count
        riseOwner.systemCount = sysCount
        riseOwner.aurCount = aCount
        riseOwner.updateCount = sysCount + aCount
        riseEnvironment.root.archUpdates = updates
        return true
    }
