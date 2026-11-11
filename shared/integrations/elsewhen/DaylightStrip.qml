pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Model.js" as Model
import "GlobeModel.js" as Solar
import "Sun.js" as Sun

// Rise adaptation of Elsewhen's 24-hour daylight track. The panel supplies
// city-local time and receives scrub gestures; this component owns the solar
// band, event markers and moon/day marker presentation.
Item {
  id: strip
  objectName: "elsewhen-daylight-strip"

  property bool ready: false
  property int offsetMinutes: 0
  property real progress: 0
  property bool fallbackLit: false
  property var place: null
  property double nowMs: 0
  property bool hovered: false
  property bool hour24: false
  property var words: ({})
  property real moonPhase: 0
  property color foreground: "#dedede"
  property color fainter: Qt.darker(foreground, 2.1)
  property color daylightMarker: foreground
  property int animationDuration: 400
  property int shownChip: Model.NO_CHIP

  readonly property int trackHeight: 3
  readonly property bool mirrored: LayoutMirroring.enabled
  readonly property double dayMs: ready ? Sun.localMidnightMs(nowMs, offsetMinutes) : 0
  readonly property var sun: {
    if (!ready || !place || place.lat === undefined || place.lon === undefined) return null
    return Sun.sunTimes(place.lat, place.lon, dayMs + 43200000, offsetMinutes)
  }
  readonly property var sunMarks: {
    if (!sun || sun.kind !== "normal") return []
    var out = []
    var up = Sun.eventMark(sun.riseMinutes)
    var down = Sun.eventMark(sun.setMinutes)
    if (up !== null) out.push({ x: up, minutes: sun.riseMinutes, rising: true })
    if (down !== null) out.push({ x: down, minutes: sun.setMinutes, rising: false })
    return out
  }
  readonly property bool litNow: sun ? Sun.litAt(sun, ready ? progress * 1440 : 0)
                                     : (ready && fallbackLit)
  property alias scrubArea: scrubArea

  signal scrubStarted(real fraction)
  signal scrubMoved(real fraction)
  signal scrubEnded()
  signal moonShowRequested()

  height: 18

  function stripFraction(fraction) {
    var value = Math.max(0, Math.min(1, Number(fraction)))
    return mirrored ? 1 - value : value
  }

  function eventLabel(mark) {
    var key = mark.rising ? "elsewhen.sunriseAt" : "elsewhen.sunsetAt"
    var fallback = mark.rising ? "Sunrise %1" : "Sunset %1"
    var template = words && typeof words.t === "function" ? words.t(key) : fallback
    return String(template).replace("%1", Model.formatMinuteOfDay(mark.minutes, hour24, words))
  }

  function dismissChips() { shownChip = Model.NO_CHIP }
  function dismissUnlessChanged(atPress) { shownChip = Model.chipAfterRelease(shownChip, atPress) }

  onHoveredChanged: if (!hovered) dismissChips()
  onMoonPhaseChanged: moonCanvas.requestPaint()
  onForegroundChanged: moonCanvas.requestPaint()

  Rectangle {
    id: track
    objectName: "elsewhen-daylight-track"
    visible: strip.ready
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: strip.trackHeight
    radius: height / 2
    color: Qt.rgba(strip.foreground.r, strip.foreground.g, strip.foreground.b, 0.10)

    Repeater {
      model: strip.sun ? Sun.litSpans(strip.sun)
                       : [{ x0: Model.daylightStart(), x1: Model.daylightEnd() }]
      Rectangle {
        required property var modelData
        x: track ? track.width * (strip.mirrored ? 1 - modelData.x1 : modelData.x0) : 0
        width: track ? Math.max(1, track.width * (modelData.x1 - modelData.x0)) : 0
        height: track ? track.height : 0
        radius: track ? track.radius : 0
        color: Qt.rgba(strip.foreground.r, strip.foreground.g, strip.foreground.b, 0.28)
      }
    }

    Rectangle {
      id: nowMarker
      objectName: "elsewhen-daylight-marker"
      width: 10
      height: width
      radius: width / 2
      x: Math.round(parent.width * strip.stripFraction(strip.ready ? strip.progress : 0) - width / 2)
      y: (parent.height - height) / 2
      color: strip.litNow ? strip.daylightMarker : "transparent"

      Canvas {
        id: moonCanvas
        anchors.fill: parent
        visible: !strip.litNow
        renderStrategy: Canvas.Cooperative
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var radius = Math.min(width, height) / 2
          if (radius <= 0) return
          ctx.translate(width / 2, height / 2)
          ctx.beginPath()
          ctx.arc(0, 0, radius, 0, Math.PI * 2)
          ctx.fillStyle = Qt.rgba(strip.foreground.r, strip.foreground.g, strip.foreground.b, 0.22)
          ctx.fill()
          var outline = Solar.moonLitOutline(strip.moonPhase, radius, 28)
          if (outline && outline.length > 2) {
            ctx.beginPath()
            ctx.moveTo(outline[0].x, outline[0].y)
            for (var i = 1; i < outline.length; i++) ctx.lineTo(outline[i].x, outline[i].y)
            ctx.closePath()
            ctx.fillStyle = strip.foreground.toString()
            ctx.fill()
          }
        }
      }

      Behavior on x {
        NumberAnimation { duration: strip.animationDuration; easing.type: Easing.OutCubic }
      }
    }
  }

  MouseArea {
    id: scrubArea
    objectName: "elsewhen-daylight-scrub-area"
    anchors.fill: parent
    cursorShape: Qt.SizeHorCursor
    preventStealing: true
    enabled: strip.ready
    property bool showing: false
    property int chipAtPress: Model.NO_CHIP

    function onMoon(mouse) {
      if (strip.litNow) return false
      return Math.abs(mouse.x - (nowMarker.x + nowMarker.width / 2)) <= nowMarker.width
    }
    function finish() {
      if (!showing) strip.scrubEnded()
      strip.dismissUnlessChanged(chipAtPress)
      showing = false
    }
    onPressed: function(mouse) {
      showing = (mouse.modifiers & Qt.ShiftModifier) !== 0 && onMoon(mouse)
      chipAtPress = strip.shownChip
      if (showing) strip.moonShowRequested()
      else strip.scrubStarted(strip.stripFraction(mouse.x / width))
    }
    onPositionChanged: function(mouse) {
      if (pressed && !showing) strip.scrubMoved(strip.stripFraction(mouse.x / width))
    }
    onReleased: finish()
    onCanceled: finish()
  }

  Repeater {
    model: strip.sunMarks
    Item {
      id: arrow
      required property var modelData
      required property int index
      readonly property bool rising: modelData.rising
      readonly property bool covered: {
        if (!strip.ready) return false
        return Model.arrowCovered(arrow.x, arrow.width, nowMarker.x + nowMarker.width / 2,
                                  nowMarker.width, 4)
      }
      width: 14
      height: 16
      anchors.verticalCenter: strip.verticalCenter
      x: Model.arrowBox(strip.stripFraction(modelData.x), strip.width, width, 3,
                        strip.mirrored ? !rising : rising)
      opacity: strip.hovered && !covered ? 1 : 0
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: 160 } }
      onCoveredChanged: if (covered && strip.shownChip === index) strip.dismissChips()

      Text {
        anchors.centerIn: parent
        text: arrow.rising ? "\u2191" : "\u2193"
        color: arrowHover.hovered || strip.shownChip === arrow.index ? strip.foreground : strip.fainter
        font.pixelSize: 10
        renderType: Text.NativeRendering
      }
      HoverHandler { id: arrowHover; cursorShape: Qt.PointingHandCursor }
      TapHandler {
        property int atPress: Model.NO_CHIP
        onPressedChanged: if (pressed) atPress = strip.shownChip
        onTapped: strip.shownChip = Model.chipAfterTap(atPress, arrow.index)
      }
      ToolTip.visible: strip.shownChip === arrow.index
      ToolTip.delay: 0
      ToolTip.text: strip.eventLabel(arrow.modelData)
    }
  }
}
