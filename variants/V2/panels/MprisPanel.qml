pragma ComponentBehavior: Bound
import QtQuick
import "../../../shared/panels" as Shared
import "../modules" as Native

Shared.MprisPanel {
    id: panel
    barBottom: panel.root.v2BarHeight
    gap: 6
    frameRadius: panel.root.panelRadius
    frameColor: "transparent"
    frameBorderColor: panel.root.panelBorder
    frameBorderWidth: 0
    spectrumAttack: 0.72
    spectrumRelease: 0.24
    spectrumCommand: ["bash", "-c", "command -v cava >/dev/null 2>&1 || exit 0; " + "exec cava -p <(printf '%s\\n' " + "'[general]' 'bars = 12' 'framerate = 30' 'autosens = 1' 'sleep_timer = 0' " + "'[input]' 'method = pipewire' 'source = auto' " + "'[output]' 'method = raw' 'raw_target = /dev/stdout' " + "'data_format = ascii' 'ascii_max_range = 100' " + "'[smoothing]' 'monstercat = 0' 'waves = 0' 'noise_reduction = 20')" ]
    spectrumBarWidth: 5
    coverSource: panel.auxiliaryHost ? panel.auxiliaryHost.artSource : ""
    revealShift: 2 * (1 - panel.reveal)
    fallbackOnImageError: true
    cavaPalette: panel.auxiliaryHost ? panel.auxiliaryHost.cavaPalette : []
    auxiliaryComponent: Component {
        Item {
            property alias artSource: artwork.source
            property alias cavaPalette: paletteData.cavaPalette
            Native.MprisArtwork { id: artwork; player: panel.player }
            Native.MprisPanelPalette { id: paletteData; root: panel.root }
        }
    }
    surfaceComponent: Component {
        Item {
            Native.PillShadow { parent: panel.surfaceHost; theme: panel.root }
            Native.SidePanelPositioner { root: panel.root; target: panel.surfaceHost; anchorName: "mpris" }
            Native.ConnectedPanelSurface {
                parent: panel.surfaceHost
                z: -1
                root: panel.root
                ownerActive: panel.root.mprisVisible
                targetX: panel.root.mprisBarX
                reveal: panel.reveal
            }
        }
    }
}
