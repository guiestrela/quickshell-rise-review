pragma Singleton
import QtQuick
QtObject {
    property var theme: null
    readonly property real cornerRadius: theme ? (theme.panelButtonRadius !== undefined ? theme.panelButtonRadius : theme.tileRadius) : 6
    readonly property real tooltipRadius: theme ? (theme.panelRadius !== undefined ? theme.panelRadius : theme.pillRadius) : 6
    readonly property real tooltipBorderWidth: theme ? (theme.panelOuterBorderW !== undefined ? theme.panelOuterBorderW : theme.pillBorderW) : 1
    readonly property color tooltipBorderColor: theme ? (theme.panelOuterBorderColor !== undefined ? theme.panelOuterBorderColor : theme.pillBorder) : "#555555"
    readonly property int normalBorderWidth: 1
    readonly property real titleLetterSpacing: 2
    readonly property real captionLetterSpacing: 1
    readonly property int usageBarHeight: 6
    readonly property int usageBarRadius: 3
    readonly property var font: ({family: theme ? theme.mono : "JetBrainsMono Nerd Font", body: 11, bodySmall: 10, caption: 9, display: 20, title: 13, icon: 15})
    readonly property var spacing: ({rowPaddingX: 12, sm: 4, controlPaddingX: 8, controlPaddingY: 5, controlHeight: 32})
    function mutedColor(c) { return theme ? theme.sumi : Qt.darker(c, 1.4) }
    function controlSpec(state, foreground, accent) {
        return {width: state === "selected" ? 0 : normalBorderWidth,
            color: theme ? theme.sep : Qt.rgba(foreground.r,foreground.g,foreground.b,0.25)}
    }
    function space(n) { return n }
    function normalFillFor(c, a) { return theme ? theme.fillIdle : Qt.rgba(c.r,c.g,c.b,0.04) }
    function hoverFillFor(c, a) { return theme ? theme.fillHover : Qt.rgba(c.r,c.g,c.b,0.08) }
    function selectedFillFor(c, a) { return theme ? theme.fillActive : Qt.rgba(a.r,a.g,a.b,0.18) }
    function focusFillFor(c, a) { return hoverFillFor(c,a) }
    function selectedStateColor(c, a) { return a }
}
