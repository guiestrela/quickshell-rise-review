pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons as Commons
import "../../components" as SharedComponents
import "Model.js" as Model
import "GlobeModel.js" as Globe
import "Greetings.js" as Greet
import "." as Elsewhen

Rectangle {
  id: row
  required property var modelData
  required property int index
  required property var panel
  property alias removeButton: removeButton
  property alias peopleEditButton: peopleButton
  property alias dragArea: rowDragArea

  readonly property var rowData: panel.displayRows && panel.displayRows[index]
    ? panel.displayRows[index] : modelData
  readonly property var people: modelData.people || []
  readonly property bool editingPeople: panel.peopleEditIndex === index
  readonly property bool hovered: rowHover.hovered
  readonly property bool greetingVisible: hovered && row.rowData.ready === true && !editingPeople
  readonly property var greeting: Greet.greeting(row.rowData.id || modelData.id, row.rowData.ready === true ? row.rowData.hour : 0)
  readonly property bool removable: panel.displayRows ? panel.displayRows.length > 1 : true
  readonly property bool keyboardFocused: panel.keyboardFocusId !== undefined
    && String(panel.keyboardFocusId || "") !== ""
    && String(panel.keyboardFocusId) === String(modelData.id || "")
  readonly property color foreground: panel.palette.ink
  readonly property color dim: panel.palette.sumi !== undefined ? panel.palette.sumi : Qt.darker(foreground, 1.55)
  readonly property color fainter: Qt.darker(foreground, 2.1)
  readonly property string fontFamily: panel.palette.mono
  readonly property real dayFill: 0.10
  readonly property real phaseFill: {
    var phase = row.rowData.phase || "day"
    if (phase === "night") return 0.035
    if (phase === "day") return dayFill
    return 0.07
  }
  readonly property real hoverLift: 0.05
  readonly property real actionSize: Commons.Style.font.bodySmall
    + (Commons.Style.space(22) - Commons.Style.font.bodySmall) * 0.85
  readonly property real actionCenterOffset: -Commons.Style.space(22) * 5 / 24
  readonly property color surfaceBase: panel.palette.bg !== undefined ? panel.palette.bg : panel.palette.fillIdle
  readonly property bool picked: keyboardFocused

  width: parent ? parent.width : 340
  height: 89
  radius: panel.palette.tileRadius !== undefined ? panel.palette.tileRadius : 7
  color: Model.mix(surfaceBase, foreground,
    picked ? dayFill + hoverLift : hovered ? phaseFill + hoverLift : phaseFill)
  border.color: keyboardFocused ? panel.palette.seal : panel.palette.sep
  border.width: keyboardFocused ? 1 : 0
  clip: false

  HoverHandler { id: rowHover }

  Row {
    id: rowContent
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    anchors.topMargin: 10
    anchors.bottomMargin: 22
    spacing: 8

    Column {
      width: parent.width - timeBlock.width - parent.spacing
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3

      Row {
        width: parent.width
        spacing: 6

        SharedComponents.UiText {
          width: Math.max(0, parent.width - 82)
          text: row.rowData.label || row.modelData.label
          color: row.foreground
          font.family: row.fontFamily
          font.pixelSize: 13
          font.bold: true
          elide: Text.ElideRight
        }

        Item { width: Math.max(0, parent.width - parent.children[0].width - 82); height: 1 }

        Item {
          id: temperatureControl
          objectName: "elsewhen-weather-temperature-control"
          width: 48
          height: 14
          visible: row.panel.temperatureFor !== undefined && row.panel.temperatureFor(row.rowData) !== ""
          SharedComponents.UiText {
            objectName: "elsewhen-weather-temperature"
            anchors.fill: parent
            text: row.panel.temperatureFor !== undefined ? row.panel.temperatureFor(row.rowData) : ""
            color: row.dim
            font.family: row.fontFamily
            font.pixelSize: 9
            horizontalAlignment: Text.AlignRight
          }
        }

        Item {
          width: 18
          height: 14
          visible: row.panel.weatherGlyphFor !== undefined
            && row.panel.weatherGlyphFor(row.rowData) !== ""
          SharedComponents.UiText {
            objectName: "elsewhen-weather-glyph"
            anchors.fill: parent
            text: row.panel.weatherGlyphFor !== undefined ? row.panel.weatherGlyphFor(row.rowData) : ""
            color: row.dim
            font.family: row.fontFamily
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }

      Row {
        objectName: "elsewhen-people-row"
        width: parent.width
        height: 18
        visible: row.people.length > 0 && !row.editingPeople
        spacing: 6
        Row {
          id: peopleAvatars
          objectName: "elsewhen-people-avatars"
          spacing: -4
          width: Math.min(row.people.length, 4) * 15 + Math.max(0, Math.min(row.people.length, 4) - 1) * spacing
          height: parent.height

          Repeater {
            model: row.people.slice(0, 4)
            Elsewhen.Avatar {
              required property var modelData
              name: Model.personName(modelData, row.panel.profiles || ({}))
              source: {
                var profiles = row.panel.profiles || ({})
                var profile = profiles[Model.personHandle(modelData)]
                return profile ? profile.avatar : ""
              }
              stamp: Number(row.panel.profileStamp || 0)
              size: 15
              foreground: row.foreground
              ground: row.color
              fontFamily: row.fontFamily
            }
          }
        }
        SharedComponents.UiText {
          objectName: "elsewhen-people-names"
          width: Math.max(0, parent.width - peopleAvatars.width - parent.spacing)
          text: row.people.map(function(person) { return Model.personName(person, row.panel.profiles || ({})) }).join(", ")
          color: row.dim
          font.family: row.fontFamily
          font.pixelSize: 10
          elide: Text.ElideRight
        }
      }

      TextField {
        id: peopleField
        objectName: "elsewhen-people-field"
        width: parent.width
        height: 22
        visible: row.editingPeople
        selectByMouse: true
        text: ""
        placeholderText: "Names or @GitHub handles"
        color: row.foreground
        placeholderTextColor: row.dim
        font.family: row.fontFamily
        font.pixelSize: 10
        leftPadding: 7
        rightPadding: 7
        background: Rectangle {
          radius: 5
          color: row.panel.palette.bg
          border.color: peopleField.activeFocus ? row.panel.palette.seal : row.panel.palette.sep
          border.width: 1
        }
        onVisibleChanged: if (visible) {
          text = Model.peopleText(row.people)
          cursorPosition = text.length
          Qt.callLater(function() { if (peopleField.visible) peopleField.forceActiveFocus() })
        }
        function commit() {
          if (row.editingPeople) row.panel.finishPeopleEdit(row.index, text)
        }
        onAccepted: commit()
        onEditingFinished: commit()
        Keys.onEscapePressed: row.panel.cancelPeopleEdit()
      }

      Item {
        objectName: "elsewhen-city-date-slot"
        width: parent.width
        height: dateLine.implicitHeight
        implicitHeight: dateLine.implicitHeight
        visible: !row.editingPeople
        Row {
          id: dateLine
          objectName: "elsewhen-city-date-line"
          width: parent.width
          opacity: row.greetingVisible ? 0 : 1
          visible: opacity > 0
          Behavior on opacity { NumberAnimation { duration: 110 } }
          SharedComponents.UiText {
            objectName: "elsewhen-city-date"
            width: parent.width
            text: row.rowData.ready === true
              ? String(row.rowData.date || "") + (row.rowData.dayLabel ? "  ·  " + row.rowData.dayLabel : "")
              : "…"
            color: row.fainter
            font.family: row.fontFamily
            font.pixelSize: 9
            elide: Text.ElideRight
          }
        }
        Row {
          id: greetingLine
          objectName: "elsewhen-city-greeting-line"
          width: parent.width
          spacing: 4
          opacity: row.greetingVisible ? 1 : 0
          visible: opacity > 0
          Behavior on opacity { NumberAnimation { duration: 110 } }
          SharedComponents.UiText {
            objectName: "elsewhen-city-greeting-text"
            text: row.greeting.text
            color: row.foreground
            font.family: row.fontFamily
            font.pixelSize: 9
            elide: Text.ElideRight
          }
          SharedComponents.UiText {
            objectName: "elsewhen-city-greeting-roman"
            text: row.greeting.roman
            visible: text !== ""
            color: row.fainter
            font.family: row.fontFamily
            font.pixelSize: 9
          }
        }
      }
    }

    Column {
      id: timeBlock
      width: 112
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1

      Row {
        anchors.right: parent.right
        spacing: 4
        SharedComponents.UiText {
          objectName: "elsewhen-city-time"
          text: row.rowData.ready === true ? (row.rowData.time || "··:··") : "··:··"
          color: row.foreground
          font.family: row.fontFamily
          font.pixelSize: 18
          font.bold: true
          horizontalAlignment: Text.AlignRight
        }
        SharedComponents.UiText {
          anchors.baseline: parent.children[0].baseline
          text: row.rowData.meridiem || ""
          visible: text !== ""
          color: row.hovered ? row.foreground : row.dim
          font.family: row.fontFamily
          font.pixelSize: 9
        }
        TapHandler {
          onTapped: {
            if (typeof row.panel.toggleHour24 === "function") row.panel.toggleHour24()
            else if (row.panel.service) row.panel.service.updateSetting("hour24", !row.panel.hour24)
          }
        }
      }

      Row {
        anchors.right: parent.right
        spacing: 4
        SharedComponents.UiText {
          text: row.rowData.abbr || ""
          visible: text !== ""
          color: row.dim
          font.family: row.fontFamily
          font.pixelSize: 9
        }
        SharedComponents.UiText {
          objectName: "elsewhen-city-offset"
          text: typeof row.panel.offsetTextFor === "function"
            ? row.panel.offsetTextFor(row.rowData) : (row.rowData.relative || "")
          visible: text !== ""
          color: row.fainter
          font.family: row.fontFamily
          font.pixelSize: 9
        }
        TapHandler {
          onTapped: {
            if (typeof row.panel.toggleOffsetMode === "function") row.panel.toggleOffsetMode()
            else if (row.panel.service) {
              const mode = row.panel.service.preferenceData.offsetMode === "utc" ? "home" : "utc"
              row.panel.service.updateSetting("offsetMode", mode)
            }
          }
        }
      }
    }
  }

  Elsewhen.DaylightStrip {
    id: daylightStrip
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 2
    ready: row.rowData.ready === true
    offsetMinutes: row.rowData.offsetMinutes !== undefined ? row.rowData.offsetMinutes : 0
    progress: row.rowData.progress !== undefined ? row.rowData.progress : 0
    fallbackLit: row.rowData.lit === true
    place: row.panel.placeForCity(row.rowData)
    nowMs: row.panel.effectiveMs !== undefined ? row.panel.effectiveMs : Date.now()
    hovered: row.hovered
    hour24: row.panel.hour24 === true
    moonPhase: row.panel.moonPhase !== undefined ? row.panel.moonPhase : Globe.moonPhase(nowMs)
    foreground: row.foreground
    fainter: row.fainter
    daylightMarker: row.panel.daylightMarker !== undefined ? row.panel.daylightMarker : row.panel.palette.seal
    onScrubStarted: function(fraction) { if (typeof row.panel.beginScrub === "function") row.panel.beginScrub(row.rowData, fraction) }
    onScrubMoved: function(fraction) { if (typeof row.panel.scrubTo === "function") row.panel.scrubTo(row.rowData, fraction) }
    onScrubEnded: if (typeof row.panel.endScrub === "function") row.panel.endScrub()
    onMoonShowRequested: if (typeof row.panel.startMoonShow === "function") row.panel.startMoonShow()
  }

  MouseArea {
    id: rowDragArea
    objectName: "elsewhen-city-drag-area"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: daylightStrip.top
    z: -1
    preventStealing: true
    property real startY: 0
    property bool moved: false
    onPressed: function(mouse) {
      startY = mouse.y
      moved = false
      if (typeof row.panel.beginRowDrag === "function") row.panel.beginRowDrag(row.index, row.height)
    }
    onPositionChanged: function(mouse) {
      if (!pressed) return
      const offset = mouse.y - startY
      if (!moved && Math.abs(offset) < 8) return
      moved = true
      if (typeof row.panel.moveRowDrag === "function") row.panel.moveRowDrag(offset)
    }
    onReleased: {
      if (moved) {
        if (typeof row.panel.releaseRowDrag === "function") row.panel.releaseRowDrag()
      } else if (typeof row.panel.cancelRowDrag === "function") row.panel.cancelRowDrag()
    }
    onCanceled: {
      if (typeof row.panel.cancelRowDrag === "function") row.panel.cancelRowDrag()
      moved = false
    }
    onClicked: function(mouse) {
      if (moved) return
      if (temperatureControl.visible) {
        const point = temperatureControl.mapToItem(row, 0, 0)
        if (mouse.x >= point.x && mouse.x <= point.x + temperatureControl.width
                && mouse.y >= point.y && mouse.y <= point.y + temperatureControl.height) {
          row.panel.toggleUnits()
          daylightStrip.dismissChips()
          return
        }
      }
      if (typeof row.panel.focusCity === "function") row.panel.focusCity(row.index)
    }
  }

  Rectangle {
    id: removeButton
    objectName: "elsewhen-city-remove"
    width: row.actionSize
    height: row.actionSize
    radius: width / 2
    anchors.horizontalCenter: parent.right
    anchors.horizontalCenterOffset: row.actionCenterOffset
    anchors.verticalCenter: parent.top
    color: Model.mix(row.panel.palette.bg, row.foreground,
      removePointer.containsMouse ? 0.24 : 0.14)
    border.color: Model.mix(row.panel.palette.bg, row.foreground,
      removePointer.containsMouse ? 0.65 : 0.35)
    border.width: Commons.Style.space(1)
    visible: row.removable && (row.hovered || removePointer.containsMouse)
    Accessible.role: Accessible.Button
    Accessible.name: "Remove " + String(row.rowData.label || row.modelData.label)
    Text {
      anchors.centerIn: parent
      text: "×"
      color: removePointer.containsMouse ? row.foreground : row.dim
      font.family: row.fontFamily
      font.pixelSize: Commons.Style.font.bodySmall
      renderType: Text.NativeRendering
    }
    MouseArea {
      id: removePointer
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (typeof row.panel.removeCityAt === "function") row.panel.removeCityAt(row.index)
        else if (row.panel.service) row.panel.service.removeCity(row.index)
      }
    }
  }

  Rectangle {
    id: peopleButton
    objectName: "elsewhen-people-edit"
    width: row.actionSize
    height: row.actionSize
    radius: width / 2
    anchors.horizontalCenter: parent.right
    anchors.horizontalCenterOffset: row.actionCenterOffset - removeButton.width - Commons.Style.space(5)
    anchors.verticalCenter: parent.top
    color: Model.mix(row.panel.palette.bg, row.foreground,
      peoplePointer.containsMouse ? 0.24 : 0.14)
    border.color: Model.mix(row.panel.palette.bg, row.foreground,
      peoplePointer.containsMouse ? 0.65 : 0.35)
    border.width: Commons.Style.space(1)
    visible: !row.editingPeople && (row.hovered || peoplePointer.containsMouse)
    Accessible.role: Accessible.Button
    Accessible.name: "Edit people for " + String(row.rowData.label || row.modelData.label)
    Text {
      anchors.centerIn: parent
      text: "\udb80\udc14"
      color: peoplePointer.containsMouse ? row.foreground : row.dim
      font.family: row.fontFamily
      font.pixelSize: Commons.Style.font.caption
      renderType: Text.NativeRendering
    }
    MouseArea {
      id: peoplePointer
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.panel.startPeopleEdit(row.index)
    }
  }
}
