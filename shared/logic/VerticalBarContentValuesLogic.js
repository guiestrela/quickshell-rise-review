// Common behavior for variant-specific presentations.
.pragma library

function regionHeight(riseOwner, riseEnvironment, region) {
    var riseState = riseOwner;

        return riseState.regionColumns[region].implicitHeight
    }
