import QtQuick
import Quickshell.Io

// One capture lifecycle for either presentation; the audio backend and visual
// response remain explicit choices of the variant.
Item {
    id: spectrum
    required property bool enabled
    required property bool playing
    required property bool active
    required property var captureCommand
    property real attack: 0.7
    property real release: 0.7
    readonly property int bands: 12
    property var levels: []
    property var targets: []
    property real phase: 0
    Component.onCompleted: {
        var a = [], b = []
        for (var i = 0; i < bands; i++) { a.push(0.06); b.push(0) }
        levels = a; targets = b
    }
    function applySamples(line) {
        if (!playing) return
        var parts = String(line).split(";"), previous = levels, out = []
        for (var i = 0; i < bands; i++) {
            var value = parseInt(parts[i])
            value = isNaN(value) ? 0 : Math.min(1, value / 100)
            var current = previous[i] === undefined ? 0 : previous[i]
            var response = value >= current ? attack : release
            out.push(current + (value - current) * response)
        }
        levels = out
    }
    Process {
        running: spectrum.enabled && spectrum.playing
        command: spectrum.captureCommand
        stdout: SplitParser { splitMarker: "\n"; onRead: line => spectrum.applySamples(line) }
    }
    Timer {
        interval: 33; repeat: true
        running: spectrum.enabled && spectrum.active && !spectrum.playing
        onTriggered: {
            spectrum.phase += 0.12
            var out = [], previous = spectrum.levels
            for (var i = 0; i < spectrum.bands; i++) {
                var goal = spectrum.active ? 0.05
                    : 0.10 + 0.09 * (0.5 + 0.5 * Math.sin(spectrum.phase - i * 0.55))
                        * (1 - Math.abs(i - (spectrum.bands - 1) / 2) / spectrum.bands)
                var current = previous[i] === undefined ? 0.06 : previous[i]
                out.push(current + (goal - current) * 0.25)
            }
            spectrum.levels = out
        }
    }
}
