import QtQuick
import "." as Tokens
import "Border.js" as Border

// Shared visual chrome for keyboard-and-mouse-navigable items inside a panel.
// Contract: items must NOT read `containsMouse` for color/border. Mouse
// hover updates the panel's cursor state at the root; visuals derive from
// `hasCursor` / `current`. That's what guarantees a single highlight on
// screen at any time across both keyboard and mouse interaction.
//
// Cursor paint is always the shared hover-cursor fill plus optional
// hover-cursor border. `outline` remains as a compatibility flag for
// callers that used to request border-only rows, but slider rows still
// receive the same hover-cursor background as every other row.
Tokens.BorderSurface {
  id: root

  property bool hasCursor: false
  property bool current: false
  property bool outline: false
  property bool bordered: false

  property color foreground: Tokens.Color.foreground
  property color accent: Tokens.Color.accent
  property color fill: Tokens.Style.hoverFillFor(foreground, accent)
  property color currentFill: Tokens.Style.selectedFillFor(foreground, accent)

  radius: Tokens.Style.cornerRadius

  color: hasCursor ? fill : (current ? currentFill : "transparent")
  borderSpec: root.hasCursor
    ? Tokens.Style.controlSpec("hover-cursor", root.foreground, root.accent)
    : (root.current
      ? Tokens.Style.controlSpec("selected", root.foreground, root.accent)
      : (root.bordered
        ? Tokens.Style.controlSpec("normal", root.foreground, root.accent)
        : Border.none()))

  Behavior on color {
    ColorAnimation { duration: 60 }
  }
}
