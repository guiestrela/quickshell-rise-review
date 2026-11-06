import QtQuick
import Quickshell
import QtQml.Models
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Single source of truth for "which player is active".
// The bar widget and the panel both instantiate this, so they can never
// disagree about the current player.
//
// playerctld (and the dead apps it proxies) can leave ghost entries that
// report Stopped or carry no metadata. Treat those as "no player".
Item {
    id: sel
    visible: false
    width: 0
    height: 0

    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var playbackStreams: {
        var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
        var out = []
        for (var i = 0; i < nodes.length; i++) {
            var node = nodes[i]
            if (!node || !node.isStream) continue
            var kind = String(node.type || "")
            if (node.isSink === true || kind.indexOf("Stream/Output/Audio") >= 0
                    || kind.indexOf("AudioOutStream") >= 0 || kind.indexOf("Output") >= 0)
                out.push(node)
        }
        return out
    }
    property var playerStartedAt: ({})
    property int playSerial: 0

    PwObjectTracker { objects: sel.playbackStreams }

    function playerKey(p) {
        return p ? String(p.dbusName || p.desktopEntry || p.identity || "") : ""
    }

    function syncPlayingOrder() {
        var next = {}, serial = playSerial
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            var key = playerKey(p)
            if (!key) continue
            if (!p.isPlaying) continue
            if (playerStartedAt[key] === undefined) next[key] = ++serial
            else next[key] = playerStartedAt[key]
        }
        playerStartedAt = next
        playSerial = serial
    }

    // playerctld is an aggregator proxy: it mirrors the last player and
    // freezes its state (often "Playing") once that player quits, leaving a
    // ghost entry. Real players always appear under their own bus name too,
    // so skip the proxy entirely and let the real entry win.
    function isProxy(p) {
        var n = (p.dbusName || "") + " " + (p.identity || "") + " " + (p.desktopEntry || "")
        return /playerctld/i.test(n)
    }

    function isReal(p) {
        if (!p) return false
        if (isProxy(p)) return false
        if (p.playbackState === MprisPlaybackState.Stopped) return false
        var hasMeta = (p.trackTitle && p.trackTitle.length > 0)
        return hasMeta || p.playbackState === MprisPlaybackState.Playing
    }

    function streamKey(label) {
        return String(label || "").toLowerCase()
            .replace(/^pipewire alsa \[/, "").replace(/\]$/, "")
            .replace(/^alsa playback \[/, "").replace(/[^a-z0-9]+/g, "")
    }

    function hasPlaybackStream(p) {
        var app = String(p.desktopEntry || p.identity || p.dbusName || "")
            .replace(/^org\.mpris\.MediaPlayer2\./, "").replace(/\.instance[0-9]+$/, "")
        var key = streamKey(app)
        if (!key) return false
        for (var i = 0; i < playbackStreams.length; i++) {
            var node = playbackStreams[i]
            var props = node && node.ready && node.properties ? node.properties : {}
            var label = props["application.name"] || node.description || props["media.name"] || props["node.name"] || node.name
            var other = streamKey(label)
            if (other && (other === key || other.indexOf(key) >= 0 || key.indexOf(other) >= 0)) return true
        }
        return false
    }

    function oldestPlayingPlayer(requirePlaybackStream) {
        var oldest = null, oldestOrder = 0
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            if (!p || !p.isPlaying || isProxy(p)) continue
            if (requirePlaybackStream && !hasPlaybackStream(p)) continue
            var key = playerKey(p)
            var order = playerStartedAt[key] === undefined ? i + 1000 : playerStartedAt[key]
            if (!oldest || order < oldestOrder) { oldest = p; oldestOrder = order }
        }
        return oldest
    }

    Component.onCompleted: syncPlayingOrder()
    onPlayersChanged: syncPlayingOrder()

    Instantiator {
        model: sel.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() { sel.syncPlayingOrder() }
        }
    }

    readonly property bool canGoPrevious: !!player && !!player.canGoPrevious
    readonly property bool canGoNext: !!player && !!player.canGoNext
    readonly property bool canTogglePlayback: !!player && (player.canTogglePlaying
        || (playing ? !!player.canPause : !!player.canPlay))

    function togglePlayback() {
        if (!player) return false
        if (playing && player.canPause) { player.pause(); return true }
        if (!playing && player.canPlay) { player.play(); return true }
        if (player.canTogglePlaying) { player.togglePlaying(); return true }
        return false
    }

    readonly property var player: {
        var vals = players
        var candidate = oldestPlayingPlayer(true) || oldestPlayingPlayer(false)
        if (candidate) return candidate
        var paused = null
        for (var i = 0; i < vals.length; i++) {
            var p = vals[i]
            if (!isReal(p)) continue
            if (p.playbackState === MprisPlaybackState.Playing) return p
            if (p.playbackState === MprisPlaybackState.Paused && paused === null) paused = p
        }
        return paused
    }

    readonly property bool active:  player !== null
    readonly property bool playing: player !== null && player.playbackState === MprisPlaybackState.Playing
}
