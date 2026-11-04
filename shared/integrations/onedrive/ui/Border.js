.pragma library
function none() { return {width:0,color:"transparent"} }
function controlSpec(state, foreground, accent) {
    return {width: state === "selected" ? 0 : 1, color: Qt.rgba(foreground.r,foreground.g,foreground.b,0.25)}
}
function localOrSurfaceSpec(surface, role, color, fallback, width) { return {width:width,color:color} }
function left(spec) { return spec.width || 0 }
function right(spec) { return left(spec) }
function top(spec) { return left(spec) }
function bottom(spec) { return left(spec) }
