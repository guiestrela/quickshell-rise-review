import QtQuick
import Quickshell.Io

// V2 reads the current theme's CAVA gradient; V1 keeps its single accent.
Item {
    id: paletteHelper
    required property var root
    property var cavaPalette: []

    function fallbackCavaPalette() {
        cavaPalette = [
            paletteHelper.root.color06, paletteHelper.root.color04, paletteHelper.root.color05, paletteHelper.root.color07,
            paletteHelper.root.color03, paletteHelper.root.color01
        ]
    }

    function parseCavaTheme(raw) {
        var text = String(raw || "")
        var colors = []
        for (var i = 1; i <= 16; i++) {
            var re = new RegExp("^\\s*gradient_color_" + i
                + "\\s*=\\s*['\\\"]?\\s*(#[0-9a-fA-F]{6,8})", "m")
            var match = text.match(re)
            if (match) colors.push(match[1])
        }
        if (colors.length >= 2) cavaPalette = colors
        else fallbackCavaPalette()
    }

    Component.onCompleted: fallbackCavaPalette()

    FileView {
        id: cavaThemeFile
        path: paletteHelper.root.omarchyCurrentRoot + "/theme/cava_theme"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: paletteHelper.parseCavaTheme(cavaThemeFile.text())
        onLoadFailed: paletteHelper.fallbackCavaPalette()
    }

}
