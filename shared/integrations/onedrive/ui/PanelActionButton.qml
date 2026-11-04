import QtQuick
import "../../../components" as CommonComponents
import "." as Tokens
import "Border.js" as Border

// Small (22×22 by default) icon button used at the right edge of panel rows
// for inline actions — forget network, confirm passphrase, unpair device,
// etc. Two visual modes are supported via `hoverColor`:
//   - default: hoverColor === foreground → subtle foreground-tint hover
//   - urgent:  hoverColor === bar.urgent → red-tint hover for destructive
//              actions like forget/unpair
//
// `enabled` gates clicks and dims the icon. The component owns its own
// hover state visuals; mouse hover does NOT update any panel cursor state
// here because action buttons are not cursor targets — the row they live
// in is.
//
// Set `focusable: true` to make the button keyboard-tabbable with the
// shared hover-cursor/focus tokens. Use this
// in form contexts where Tab walks a list
// of controls; leave it false for the right-edge actions on panel rows
// where the row's CursorSurface owns the keyboard cursor.
//
// Set `hasCursor: true` to have the button render the same hover state as
// mouse hover — so a panel's keyboard cursor lands on it identically.
// Use this when a PanelActionButton is itself the cursor target (rather
// than living inside a CursorSurface row). Emits `hovered(bool)` on
// pointer enter/leave so the panel can update its cursor state to match.
Tokens.BorderSurface {
  id: root

  property string iconText: ""
  property string tooltipText: ""
  property color foreground: Tokens.Color.foreground
  property color hoverColor: foreground
  property string fontFamily: Tokens.Style.font.family
  property real fontSize: Tokens.Style.font.icon
  property real size: Math.max(Tokens.Style.space(22), fontSize + Tokens.Style.spacing.sm * 2)

  property bool focusable: false
  property bool hasCursor: false
  property bool bordered: false

  signal clicked()
  signal hovered(bool isHovered)

  activeFocusOnTab: focusable
  Keys.onReturnPressed: if (focusable) root.clicked()
  Keys.onEnterPressed: if (focusable) root.clicked()
  Keys.onSpacePressed: if (focusable) root.clicked()

  implicitWidth: size
  implicitHeight: size
  radius: Tokens.Style.cornerRadius

  readonly property bool _showFocusRing: focusable && activeFocus
  readonly property bool _hot: (mouse.containsMouse || root.hasCursor) && root.enabled
  readonly property var _borderSpec: _showFocusRing
    ? Tokens.Style.controlSpec("focus", hoverColor, hoverColor)
    : (_hot && bordered
      ? Tokens.Style.controlSpec("hover-cursor", hoverColor, hoverColor)
      : (bordered ? Tokens.Style.controlSpec("normal", foreground, Tokens.Color.accent) : Border.none()))

  color: _showFocusRing
    ? Tokens.Style.focusFillFor(hoverColor, hoverColor)
    : (_hot
      ? Tokens.Style.hoverFillFor(hoverColor, hoverColor)
      : "transparent")
  borderSpec: _borderSpec

  Behavior on color { ColorAnimation { duration: 60 } }

  CommonComponents.UiText {
    textFormat: Text.PlainText
    anchors.centerIn: parent
    text: root.iconText
    color: root.enabled
      ? (root._hot ? root.hoverColor : root.foreground)
      : Qt.darker(root.foreground, 2.0)
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: root.enabled
    onContainsMouseChanged: root.hovered(containsMouse)
    onClicked: {
      if (root.focusable) root.forceActiveFocus()
      root.clicked()
    }
  }

  Tokens.PanelToolTip {
    visible: root.tooltipText !== "" && mouse.containsMouse
    text: root.tooltipText
    fontFamily: root.fontFamily
  }
}
