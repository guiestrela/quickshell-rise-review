pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../../components" as SharedComponents
import "Model.js" as Model
import "GlobeModel.js" as Globe
import "." as Elsewhen

Rectangle {
  id: row
  required property var modelData
  required property int index
  required property var panel
  property alias moveUpButton: moveUpButton
  property alias moveDownButton: moveDownButton
  property alias removeButton: removeButton
  property alias peopleEditButton: peopleButton
  property alias dragArea: rowDragArea

  readonly property var rowData: panel.displayRows && panel.displayRows[index]
    ? panel.displayRows[index] : modelData
  readonly property var people: modelData.people || []
  readonly property bool editingPeople: panel.peopleEditIndex === index
  readonly property bool hovered: rowHover.hovered
  readonly property bool removable: panel.displayRows ? panel.displayRows.length > 1 : true
  readonly property bool keyboardFocused: panel.keyboardFocusId !== undefined
    && String(panel.keyboardFocusId || "") !== ""
    && String(panel.keyboardFocusId) === String(modelData.id || "")
  readonly property color foreground: panel.root.ink
  readonly property color dim: panel.root.sumi !== undefined ? panel.root.sumi : Qt.darker(foreground, 1.55)
  readonly property color fainter: Qt.darker(foreground, 2.1)
  readonly property string fontFamily: panel.root.mono

  width: parent ? parent.width : 340
  height: 104
  radius: panel.root.tileRadius !== undefined ? panel.root.tileRadius : 7
  color: hovered ? panel.root.fillHover : panel.root.fillIdle
  border.color: keyboardFocused ? panel.root.seal : panel.root.sep
  border.width: 1
  clip: true

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
      }

      Row {
        width: parent.width
        height: 18
        visible: row.people.length > 0 && !row.editingPeople
        spacing: 6
        SharedComponents.UiText {
          objectName: "elsewhen-people-names"
          width: parent.width
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
          color: row.panel.root.bg
          border.color: peopleField.activeFocus ? row.panel.root.seal : row.panel.root.sep
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

      SharedComponents.UiText {
        objectName: "elsewhen-city-date"
        width: parent.width
        visible: !row.editingPeople
        text: row.rowData.ready === true
          ? String(row.rowData.date || "") + (row.rowData.dayLabel ? "  ·  " + row.rowData.dayLabel : "")
          : "…"
        color: row.fainter
        font.family: row.fontFamily
        font.pixelSize: 9
        elide: Text.ElideRight
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
    moonPhase: Globe.moonPhase(nowMs)
    foreground: row.foreground
    fainter: row.fainter
    daylightMarker: row.panel.root.seal
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
    width: 22
    height: 22
    radius: width / 2
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.top: parent.top
    anchors.topMargin: 6
    color: row.panel.root.bg
    border.color: row.panel.root.sep
    visible: row.removable && row.hovered
    Text {
      anchors.centerIn: parent
      text: "×"
      color: row.dim
      font.family: row.fontFamily
      font.pixelSize: 13
      renderType: Text.NativeRendering
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (typeof row.panel.removeCityAt === "function") row.panel.removeCityAt(row.index)
        else if (row.panel.service) row.panel.service.removeCity(row.index)
      }
    }
  }

  Rectangle {
    id: moveDownButton
    objectName: "elsewhen-city-move-down"
    width: 22
    height: 22
    radius: width / 2
    anchors.right: peopleButton.left
    anchors.rightMargin: 5
    anchors.top: parent.top
    anchors.topMargin: 6
    color: row.panel.root.bg
    border.color: row.panel.root.sep
    visible: row.hovered && row.index < (row.panel.displayRows ? row.panel.displayRows.length - 1 : 0)
    Text {
      anchors.centerIn: parent
      text: "↓"
      color: row.dim
      font.family: row.fontFamily
      font.pixelSize: 11
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: if (row.panel.service) row.panel.service.moveCity(row.index, row.index + 1)
    }
  }

  Rectangle {
    id: moveUpButton
    objectName: "elsewhen-city-move-up"
    width: 22
    height: 22
    radius: width / 2
    anchors.right: moveDownButton.left
    anchors.rightMargin: 5
    anchors.top: parent.top
    anchors.topMargin: 6
    color: row.panel.root.bg
    border.color: row.panel.root.sep
    visible: row.hovered && row.index > 0
    Text {
      anchors.centerIn: parent
      text: "↑"
      color: row.dim
      font.family: row.fontFamily
      font.pixelSize: 11
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: if (row.panel.service) row.panel.service.moveCity(row.index, row.index - 1)
    }
  }

  Rectangle {
    id: peopleButton
    objectName: "elsewhen-people-edit"
    width: removeButton.width
    height: width
    radius: width / 2
    anchors.right: removeButton.visible ? removeButton.left : parent.right
    anchors.rightMargin: removeButton.visible ? 5 : 8
    anchors.top: parent.top
    anchors.topMargin: 6
    color: row.panel.root.bg
    border.color: row.panel.root.sep
    visible: !row.editingPeople && row.hovered
    Text {
      anchors.centerIn: parent
      text: "＋"
      color: row.dim
      font.family: row.fontFamily
      font.pixelSize: 13
      renderType: Text.NativeRendering
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: row.panel.startPeopleEdit(row.index)
    }
  }
}
