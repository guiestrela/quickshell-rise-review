// Common behavior for variant-specific presentations.
.pragma library

function tileX(riseOwner, riseEnvironment) {
    var riseState = riseOwner;
 return Math.floor((riseState.longitude + 180) / 360 * Math.pow(2, riseState.tileZoom)) }
