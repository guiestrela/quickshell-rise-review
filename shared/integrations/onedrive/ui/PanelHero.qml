import QtQuick
import "../../../components" as CommonComponents
import "." as Tokens
import "Border.js" as Border

Item {
  id: root

  property Component iconComponent: null
  property string title: ""
  property string meta: ""
  property string detail: ""
  property color foreground: Tokens.Color.foreground
  property string fontFamily: Tokens.Style.font.family
  property real iconSize: Tokens.Style.font.display
  property real iconOpacity: 1.0
  property alias metaOpacity: metaText.opacity

  // Optional control pinned to the trailing edge of the hero — a ToggleSwitch,
  // a small button. The hero centers it against the labels and reserves the
  // space itself, so callers never do the geometry.
  property Component trailingControl: null

  readonly property color dim: Tokens.Style.mutedColor(foreground)
  readonly property real trailingInset: trailingLoader.item && trailingLoader.item.visible ? trailingLoader.width + Tokens.Style.space(12) : 0

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(iconLoader.implicitHeight, heroLabels.implicitHeight, trailingLoader.implicitHeight)

  Loader {
    id: iconLoader
    sourceComponent: root.iconComponent
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    opacity: root.iconOpacity
  }

  Column {
    id: heroLabels
    anchors.left: iconLoader.right
    anchors.leftMargin: Tokens.Style.space(14)
    anchors.right: parent.right
    anchors.rightMargin: root.trailingInset
    anchors.verticalCenter: parent.verticalCenter
    spacing: Tokens.Style.space(2)

    Row {
      id: titleRow
      visible: root.title !== "" || detailPill.visible
      width: parent.width

      CommonComponents.UiText {
        textFormat: Text.PlainText
        visible: root.title !== ""
        text: root.title.toUpperCase()
        width: Math.min(implicitWidth, Math.max(0, parent.width - (detailPill.visible ? detailPill.implicitWidth + Tokens.Style.space(8) : 0)))
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Tokens.Style.font.title
        font.weight: Font.Medium
        font.letterSpacing: Tokens.Style.titleLetterSpacing
        elide: Text.ElideRight
      }

      Item {
        width: Math.max(0, parent.width - parent.children[0].width - detailPill.implicitWidth)
        height: 1
      }

      Tokens.BorderSurface {
        id: detailPill
        visible: root.detail !== ""
        implicitWidth: detailText.implicitWidth + Tokens.Style.space(10)
        implicitHeight: detailText.implicitHeight + Tokens.Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        color: "transparent"
        borderSpec: Tokens.Style.controlSpec("normal", root.foreground, Tokens.Color.accent)
        radius: Tokens.Style.cornerRadius

        CommonComponents.UiText {
          id: detailText
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: root.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Tokens.Style.font.body
          font.bold: true
        }
      }
    }

    CommonComponents.UiText {
      id: metaText
      textFormat: Text.PlainText
      width: parent.width
      text: root.meta.toUpperCase()
      visible: text !== ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Tokens.Style.font.caption
      font.weight: Font.Normal
      font.letterSpacing: Tokens.Style.captionLetterSpacing
      elide: Text.ElideRight
    }
  }

  Loader {
    id: trailingLoader
    sourceComponent: root.trailingControl
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
  }
}
