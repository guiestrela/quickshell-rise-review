// Common behavior for variant-specific presentations.
.pragma library

function resetMuseLevels(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var rest = []
        for (var i = 0; i < riseState.museBands; i++) rest.push(0.04)
        riseState.museLevels = rest
    }
