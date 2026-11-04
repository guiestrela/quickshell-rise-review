pragma Singleton
import QtQuick
import "." as Tokens
QtObject {
    readonly property color foreground: Tokens.Style.theme ? Tokens.Style.theme.ink : "#dedede"
    readonly property color background: Tokens.Style.theme ? Tokens.Style.theme.bg : "#202020"
    readonly property color accent: Tokens.Style.theme ? Tokens.Style.theme.seal : "#89b4fa"
    readonly property color urgent: Tokens.Style.theme ? Tokens.Style.theme.sealRaw : "#e06c75"
    readonly property var tooltip: ({text: foreground, background: background, border: Tokens.Style.tooltipBorderColor})
}
