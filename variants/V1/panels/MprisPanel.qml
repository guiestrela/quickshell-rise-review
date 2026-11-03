pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules" as Native

Shared.MprisPanel {
    id: panel
    barBottom: 35
    gap: 8
    frameRadius: panel.root.pillRadius
    frameColor: panel.root.bg
    frameBorderColor: panel.root.pillBorder
    frameBorderWidth: panel.root.pillBorderW
    spectrumAttack: 0.7
    spectrumRelease: 0.7
    spectrumCommand: ["bash", "-c", "command -v cava >/dev/null 2>&1 || exit 0; " + "sink=$(pactl get-default-sink 2>/dev/null); " + "src=auto; [ -n \"$sink\" ] && src=\"${sink}.monitor\"; " + "exec cava -p <(printf '%s\\n' " + "'[general]' 'bars = 12' 'framerate = 60' " + "'[input]' 'method = pulse' \"source = $src\" " + "'[output]' 'method = raw' 'raw_target = /dev/stdout' " + "'data_format = ascii' 'ascii_max_range = 100')" ]
    spectrumBarWidth: 4
    coverSource: panel.player ? (panel.player.trackArtUrl || "") : ""
    surfaceComponent: Component {
        Item {
            Native.PillShadow { parent: panel.surfaceHost; theme: panel.root }
            Native.SidePanelPositioner { root: panel.root; target: panel.surfaceHost; anchorName: "mpris" }
        }
    }
}
