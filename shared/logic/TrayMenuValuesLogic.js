// Common behavior for variant-specific presentations.
.pragma library

function strip(riseOwner, riseEnvironment, t) {
    var riseState = riseOwner;
 return (t || "").replace(/_([^_])/, "$1") }
