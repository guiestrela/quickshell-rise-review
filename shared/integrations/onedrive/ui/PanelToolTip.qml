import QtQuick
import "../../../components" as CommonComponents
import "." as Tokens
import "Border.js" as Border
import QtQuick.Controls

// Styled wrapper around Qt Quick Controls ToolTip. Drop-in: declare inside
// the hovered item and bind `visible` to the hover state, e.g.
//   Tokens.PanelToolTip {
//     visible: mouse.containsMouse
//     text: "Forget network"
//   }
//
// Defaults pull from [tooltip] in shell.toml via Tokens.Color.tooltip.*. Override
// the panel* properties per-instance only when you need a tooltip that
// intentionally diverges from the theme.
//
// Property names are prefixed `panel*` to avoid clashing with ToolTip's
// built-in `background`/`font` properties.
ToolTip {
  id: root

  property color panelForeground: Tokens.Color.tooltip.text
  property color panelBackground: Tokens.Color.tooltip.background
  property color panelBorder: Tokens.Color.tooltip.border
  property string fontFamily: Tokens.Style.font.family
  property real fontSize: Tokens.Style.font.bodySmall

  readonly property var panelBorderSpec: Border.localOrSurfaceSpec("tooltip", "border", panelBorder, Tokens.Color.tooltip.border, Tokens.Style.tooltipBorderWidth)

  delay: 400
  padding: 0

  background: Tokens.BorderSurface {
    color: root.panelBackground
    borderSpec: root.panelBorderSpec
    radius: Tokens.Style.tooltipRadius
  }

  contentItem: CommonComponents.UiText {
    textFormat: Text.PlainText
    text: root.text
    color: root.panelForeground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    leftPadding: Border.left(root.panelBorderSpec) + Tokens.Style.spacing.controlPaddingX
    rightPadding: Border.right(root.panelBorderSpec) + Tokens.Style.spacing.controlPaddingX
    topPadding: Border.top(root.panelBorderSpec) + Tokens.Style.spacing.controlPaddingY
    bottomPadding: Border.bottom(root.panelBorderSpec) + Tokens.Style.spacing.controlPaddingY
  }
}
