pragma ComponentBehavior: Bound
import QtQuick
import "../../components" as CommonComponents
import QtQuick.Controls
import QtQuick.Layouts
import "ui"
import "Model.js" as Model

Item {
  id: root
  required property var theme
  Binding {
    target: Style
    property: "theme"
    value: root.theme
    restoreMode: Binding.RestoreBindingOrValue
  }
  required property var service
  readonly property var oneDrive: service
  readonly property var settings: service.settings
  readonly property bool opened: theme.oneDriveVisible
  readonly property var bar: null
  property var controller: QtObject {
    function show() { root.theme.oneDriveVisible = true }
    function hide() { root.theme.oneDriveVisible = false }
  }
  readonly property real contentHeight: content.implicitHeight
  signal dismissRequested()


  property var anchorItem: null
  property var hostWidget: null
  property bool preferencesVisible: false
  property bool cursorActive: false
  property var cursorItem: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: theme.ink
  readonly property color urgent: theme.sealRaw
  readonly property color dim: theme.sumi
  readonly property color faint: Util.alpha(theme.sumi, 0.65)
  readonly property string fontFamily: theme.mono
  readonly property color iconColor: root.oneDrive.authenticated && root.oneDrive.active ? foreground : dim
  readonly property string toggleHint: root.oneDrive.active ? "Pause syncing" : "Resume syncing"
  readonly property string panelStyle: String(root.settings && root.settings.panelStyle
    ? root.settings.panelStyle : "full").toLowerCase() === "compact" ? "compact" : "full"
  readonly property var activityRows: Model.activityRows(oneDrive)
  readonly property bool storageSevere: Model.usageSevere(
    root.oneDrive.usedBytes, root.oneDrive.quotaBytes, root.oneDrive.quotaKnown)
  readonly property bool headerHasCursor: cursorActive && cursorItem === headerItem

  function navigationItems() {
    var items = []
    collectNavigationItems(content, items)
    return items
  }

  // Walks the content tree in declaration (= visual) order, so new rows join
  // keyboard navigation by defining keyboardEnabled + keyboardActivate.
  function collectNavigationItems(item, items) {
    if (!item || item.visible !== true) return
    if (item.keyboardEnabled !== undefined && typeof item.keyboardActivate === "function") {
      if (item.keyboardEnabled === true) items.push(item)
      return
    }
    var children = item.children
    if (!children) return
    for (var index = 0; index < children.length; index++)
      collectNavigationItems(children[index], items)
  }

  function setCursor(item) {
    if (!item || item.keyboardEnabled !== true) return
    cursorActive = true
    cursorItem = item
    scrollItemIntoView(item)
  }

  function ensureCursor() {
    if (!cursorActive) return
    var items = navigationItems()
    if (items.length === 0) {
      cursorItem = null
      return
    }
    if (items.indexOf(cursorItem) < 0) cursorItem = items[0]
    scrollItemIntoView(cursorItem)
  }

  function moveCursor(dx, dy) {
    var items = navigationItems()
    if (items.length === 0) return
    var step = dy !== 0 ? dy : dx
    if (step === 0) return
    if (!cursorActive || items.indexOf(cursorItem) < 0) {
      setCursor(step < 0 ? items[items.length - 1] : items[0])
      return
    }
    var next = Math.max(0, Math.min(items.length - 1, items.indexOf(cursorItem) + (step < 0 ? -1 : 1)))
    setCursor(items[next])
  }

  function activateCursor() {
    if (!cursorActive || !cursorItem || cursorItem.keyboardEnabled !== true) return
    cursorItem.keyboardActivate()
  }

  function scrollItemIntoView(item) {
    if (!panelScroll || !item) return
    Qt.callLater(function() {
      if (!item) return
      var margin = Style.space(6)
      var point = item.mapToItem(panelScroll.contentItem, 0, 0)
      var top = point.y
      var bottom = top + item.height
      var viewTop = panelScroll.contentY
      var viewBottom = viewTop + panelScroll.height
      var maxY = Math.max(0, panelScroll.contentHeight - panelScroll.height)
      if (top < viewTop + margin) panelScroll.contentY = Math.max(0, top - margin)
      else if (bottom > viewBottom - margin)
        panelScroll.contentY = Math.min(maxY, bottom + margin - panelScroll.height)
    })
  }

  function open(accountTarget) {
    root.controller.show()
    var fromNotification = typeof accountTarget === "string" && accountTarget !== ""
    if (fromNotification) root.oneDrive.openFromNotification(accountTarget)
    else root.oneDrive.selectBadgedAccount()
    root.oneDrive.refreshSelected()
    if (!fromNotification) root.oneDrive.retryStaleQuotaOnOpen()
    Qt.callLater(function() {
      if (root.opened) {
        root.setCenterHoverRevealSuppressed(true)
        keyCatcher.forceActiveFocus()
      }
    })
  }

  // Hide first: a throw anywhere in the bar-facade call must never leave the
  // panel mapped, because every dismissal route ends up here.
  function close() {
    root.controller.hide()
    root.dismissRequested()
    setCenterHoverRevealSuppressed(false)
  }

  function toggle() {
    if (root.opened) close()
    else open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Omarchy 4.0 hands third-party plugins the PluginBarApi facade, where this
  // is readonly and writable only through the setter; the `in` probe alone
  // still matches it and the bare assignment throws. Fall back for older hosts.
  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function closeForPopoutSwitch() {
    root.close()
  }

  implicitWidth: 390
  implicitHeight: Math.min(640, content.implicitHeight)

  onOpenedChanged: {
    cursorActive = false
    cursorItem = null
    if (opened && panelScroll) panelScroll.contentY = 0
  }
  onPanelStyleChanged: ensureCursor()

  // Switching account changes which rows exist and whether they are enabled, so
  // the keyboard cursor is revalidated and the view returns to the top rather
  // than leaving the reader halfway down a different account's activity list.
  function selectAccount(service) {
    if (!service || service === root.oneDrive.selectedService) return
    root.oneDrive.selectAccount(service)
    if (panelScroll) panelScroll.contentY = 0
    ensureCursor()
  }



  Connections {
    target: root.oneDrive
    function onAuthenticatedChanged() { root.ensureCursor() }
    function onActivityChanged() { root.ensureCursor() }
    function onQuotaKnownChanged() { root.ensureCursor() }
    function onBusyChanged() { root.ensureCursor() }
    function onResumeAtChanged() { root.ensureCursor() }
    function onActiveChanged() { root.ensureCursor() }
    function onSelectedServiceChanged() { root.ensureCursor() }
    function onAccountCountChanged() { root.ensureCursor() }
  }



  Item {
    id: panel
    anchors.fill: parent

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dy === 0 && root.cursorItem && typeof root.cursorItem.adjust === "function") root.cursorItem.adjust(dx)
        else root.moveCursor(dx, dy)
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: root.activateCursor()
      onTextKey: function(value) {
        if (value === "r" || value === "R") root.oneDrive.checkQuota()
        else if (value === "f" || value === "F") root.oneDrive.checkFullStatus()
        else if (value === "p" || value === "P") root.oneDrive.toggleRunning()
        else if (value === "o" || value === "O") root.oneDrive.openFolder()
        else if (value === "l" || value === "L") root.oneDrive.login()
        else if (value === "w" || value === "W") root.oneDrive.openWeb()
      }

      Flickable {
        id: panelScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }

        Column {
          id: content
          width: panelScroll.width
          spacing: Style.space(8)

          // Account selector. Hidden entirely for a single account, where it
          // contributes no height and no spacing, so both panel styles keep
          // their current layout. The hero title stays "OneDrive" either way --
          // the selected segment already carries identity.
          Flickable {
            id: accountTabsScroll
            visible: root.oneDrive.accountCount > 1
            width: parent.width
            height: visible ? accountTabs.implicitHeight : 0
            contentWidth: accountTabs.implicitWidth
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            // Only this row scrolls sideways when the labels do not fit; the
            // panel itself never widens.
            interactive: contentWidth > width

            Row {
              id: accountTabs
              spacing: Style.space(4)
              readonly property real segmentWidth: {
                var count = Math.max(1, root.oneDrive.accountCount)
                var available = accountTabsScroll.width - spacing * (count - 1)
                return Math.max(Style.space(88), available / count)
              }

              Repeater {
                model: root.oneDrive.accounts
                delegate: AccountTab {
                  required property var modelData
                  account: modelData
                  width: accountTabs.segmentWidth
                  selected: modelData && modelData.service === root.oneDrive.selectedService
                  onActivated: root.selectAccount(modelData.service)
                }
              }
            }
          }

          CommonComponents.UiText {
            objectName: "onedrive-title"
            width: parent.width
            height: 24
            verticalAlignment: Text.AlignVCenter
            text: "OneDrive"
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.weight: Font.Medium
            font.letterSpacing: Style.titleLetterSpacing
          }

          PanelSeparator { foreground: root.foreground }

          Item {
            id: headerItem
            visible: root.oneDrive.authenticated
            width: parent.width
            implicitHeight: Math.max(syncMeta.implicitHeight, powerSwitch.implicitHeight)
            readonly property bool keyboardEnabled: root.oneDrive.installed
              && root.oneDrive.serviceAvailable && root.oneDrive.authenticated && !root.oneDrive.busy
            readonly property bool ringVisible: root.headerHasCursor
            readonly property string switchHint: root.toggleHint
            function keyboardActivate() { root.oneDrive.toggleRunning() }
            function focusHero() { root.setCursor(headerItem) }

            CommonComponents.UiText {
              id: syncMeta
              anchors.left: parent.left
              anchors.right: powerSwitch.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              text: Model.heroMeta(root.oneDrive)
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
            ToggleSwitch {
              id: powerSwitch
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              checked: root.oneDrive.active
              busy: root.oneDrive.busy
              hasCursor: headerItem.ringVisible
              foreground: root.foreground
              onHovered: function(on) { if (on) headerItem.focusHero() }
              onToggled: root.oneDrive.toggleRunning()
              PanelToolTip {
                visible: powerSwitch.containsMouse
                text: headerItem.switchHint
                fontFamily: root.fontFamily
              }
            }
          }

          CommonComponents.UiText {

            textFormat: Text.PlainText
            visible: root.oneDrive.actionStatus !== "" || root.oneDrive.lastError !== ""
            width: parent.width
            text: root.oneDrive.actionStatus !== "" ? root.oneDrive.actionStatus : root.oneDrive.lastError
            color: root.oneDrive.lastError !== "" && root.oneDrive.actionStatus === "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          ActionRow {
            visible: !root.oneDrive.installed
            width: parent.width
            title: "OneDrive CLI is not installed"
            subtitle: "Install the abraunegg OneDrive client first"
            icon: "󰅟"
            actionIcon: ""
            actionEnabled: false
          }

          ActionRow {
            id: loginAction
            visible: root.oneDrive.installed && !root.oneDrive.authenticated
            width: parent.width
            title: "Login to OneDrive"
            subtitle: "Open the CLI authentication flow"
            icon: "󰌋"
            actionIcon: "󰐕"
            onActivated: root.oneDrive.login()
          }

          ActionRow {
            id: reauthAction
            visible: root.oneDrive.authenticated && root.oneDrive.reauthRequired
            width: parent.width
            title: root.oneDrive.running ? "Pause sync to reauthenticate" : "Reauthenticate OneDrive"
            subtitle: "Open the CLI's Microsoft authorization flow"
            icon: "󰌋"
            actionIcon: root.oneDrive.running ? "" : "󰐕"
            actionEnabled: !root.oneDrive.running
            onActivated: root.oneDrive.reauthenticate()
          }

          ActionRow {
            id: resyncAction
            visible: root.oneDrive.authenticated && root.oneDrive.resyncRequired
            width: parent.width
            title: root.oneDrive.running ? "Pause sync to run resync" : "Run resync repair"
            subtitle: "Opens a terminal · asks to confirm first"
            icon: "󰑐"
            actionIcon: root.oneDrive.running ? "" : "󰐊"
            actionEnabled: !root.oneDrive.running && !root.oneDrive.busy
            onActivated: root.oneDrive.repairResync()
          }

          CommonComponents.UiText {

            textFormat: Text.PlainText
            visible: root.oneDrive.authenticated && root.oneDrive.serviceAvailable && !root.oneDrive.enabled
            width: parent.width
            text: root.oneDrive.running
              ? "Automatic startup is disabled; syncing will not resume after reboot."
              : "Automatic startup is disabled; Resume starts syncing for this session only."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          ActionRow {
            id: timedResumeAction
            visible: root.oneDrive.authenticated && !root.oneDrive.active
              && root.oneDrive.resumeAt > Date.now() / 1000
            width: parent.width
            title: "Resume syncing now"
            subtitle: root.oneDrive.statusText
            icon: "󰏤"
            actionIcon: "󰐊"
            actionEnabled: !root.oneDrive.busy
            onActivated: root.oneDrive.resume()
          }

          CursorSurface {
            id: storageBlock
            readonly property bool keyboardEnabled: storageMouse.enabled
            function keyboardActivate() { root.oneDrive.checkQuota() }
            visible: root.oneDrive.authenticated
            width: parent.width
            foreground: root.foreground
            hasCursor: (storageMouse.containsMouse || root.cursorItem === storageBlock)
              && storageMouse.enabled
            implicitHeight: storageContent.implicitHeight + Style.space(8)
            height: implicitHeight

            Column {
              id: storageContent
              width: parent.width - Style.space(8)
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Item {
                width: parent.width
                implicitHeight: Math.max(storageHeader.implicitHeight, storageValue.implicitHeight)

                PanelSectionHeader {

                  textFormat: Text.PlainText
                  id: storageHeader
                  text: "STORAGE"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }

                CommonComponents.UiText {

                  textFormat: Text.PlainText
                  id: storageValue
                  text: Model.usageShort(root.oneDrive.usedBytes, root.oneDrive.quotaBytes, root.oneDrive.quotaKnown)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Rectangle {
                id: storageTrack
                width: parent.width
                height: Style.usageBarHeight
                radius: Style.usageBarRadius
                color: root.theme.sep
                opacity: root.oneDrive.quotaKnown ? 1.0 : 0.5

                Rectangle {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  visible: root.oneDrive.quotaKnown
                  width: storageTrack.width * Model.usageFraction(
                    root.oneDrive.usedBytes, root.oneDrive.quotaBytes, root.oneDrive.quotaKnown)
                  height: storageTrack.height
                  radius: Style.usageBarRadius
                  color: root.storageSevere ? root.urgent : root.theme.seal
                }
              }

              Item {
                width: parent.width
                implicitHeight: Math.max(storageFree.implicitHeight, storageChecked.implicitHeight)

                CommonComponents.UiText {

                  textFormat: Text.PlainText
                  id: storageFree
                  text: root.oneDrive.quotaKnown
                    ? Model.freeText(root.oneDrive.usedBytes, root.oneDrive.quotaBytes, root.oneDrive.quotaKnown)
                      + (root.storageSevere ? " · almost full" : "")
                    : "Refresh for exact usage"
                  color: root.storageSevere ? root.urgent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }

                CommonComponents.UiText {

                  textFormat: Text.PlainText
                  id: storageChecked
                  text: Model.checkedText(root.oneDrive.quotaCheckedTs)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              CommonComponents.UiText {

                textFormat: Text.PlainText
                id: quotaWarning
                visible: root.oneDrive.quotaChecking || root.oneDrive.quotaError !== ""
                width: parent.width
                text: root.oneDrive.quotaChecking
                  ? "Refreshing storage… may take up to " + String(root.oneDrive.cloudTimeoutSec) + "s"
                  : root.oneDrive.quotaError + " · " + Model.checkedText(root.oneDrive.quotaCheckedTs) + " · Retry"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.underline: quotaWarningMouse.containsMouse && !root.oneDrive.quotaChecking
                wrapMode: Text.Wrap

                MouseArea {
                  id: quotaWarningMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  enabled: !root.oneDrive.busy && !root.oneDrive.quotaChecking
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: root.oneDrive.checkQuota()
                }
              }
            }

            MouseArea {
              id: storageMouse
              anchors.fill: parent
              hoverEnabled: true
              enabled: !root.oneDrive.quotaKnown
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onEntered: root.setCursor(storageBlock)
              onClicked: root.oneDrive.checkQuota()
            }
          }

          Column {
            id: activityBlock
            visible: root.oneDrive.authenticated && root.panelStyle === "full"
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(activityHeader.implicitHeight, activityMeta.implicitHeight)

              PanelSectionHeader {

                textFormat: Text.PlainText
                id: activityHeader
                text: "ACTIVITY"
                foreground: root.foreground
                fontFamily: root.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              CommonComponents.UiText {

                textFormat: Text.PlainText
                id: activityMeta
                text: Model.syncMeta(root.oneDrive.lastSyncTs) || Model.activityMeta(root.activityRows)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            CommonComponents.UiText {

              textFormat: Text.PlainText
              visible: root.activityRows.length === 0
              width: parent.width
              text: "No recent OneDrive activity."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
            }

            Column {
              id: activityColumn
              visible: root.activityRows.length > 0
              width: parent.width
              spacing: Style.space(3)

              Repeater {
                id: activityRepeater
                model: root.activityRows

                ActivityRow {
                  required property var modelData
                  width: activityColumn.width
                  rowData: modelData
                }
              }
            }
          }

          Column {
            id: pausePresets
            visible: root.oneDrive.authenticated && root.oneDrive.serviceAvailable
              && !root.oneDrive.serviceFailed && !root.oneDrive.resyncRequired && !root.oneDrive.reauthRequired
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {

              textFormat: Text.PlainText
              text: root.oneDrive.active ? "PAUSE FOR" : "RESUME IN"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              ActionChip {
                id: pause15Chip
                width: (parent.width - parent.spacing * 2) / 3
                text: "15 min"
                icon: "󰔛"
                enabled: !root.oneDrive.busy
                onActivated: root.oneDrive.pauseFor(15)
              }

              ActionChip {
                id: pause60Chip
                width: (parent.width - parent.spacing * 2) / 3
                text: "1 hour"
                icon: "󰔛"
                enabled: !root.oneDrive.busy
                onActivated: root.oneDrive.pauseFor(60)
              }

              ActionChip {
                id: pause240Chip
                width: (parent.width - parent.spacing * 2) / 3
                text: "4 hours"
                icon: "󰔛"
                enabled: !root.oneDrive.busy
                onActivated: root.oneDrive.pauseFor(240)
              }
            }
          }

          ActionRow {
            id: fullStatusAction
            visible: root.panelStyle === "full" && root.oneDrive.installed && root.oneDrive.authenticated
            width: parent.width
            title: root.oneDrive.fullStatusChecking ? "Verifying sync…" : "Verify sync"
            subtitle: root.oneDrive.fullStatusChecking
              ? "Scanning your drive · may take up to " + String(root.oneDrive.cloudTimeoutSec) + "s"
              : (root.oneDrive.syncStatusError !== ""
                ? root.oneDrive.syncStatusError + " · " + Model.checkedText(root.oneDrive.syncStatusCheckedTs) + " · Retry"
                : (root.oneDrive.remoteStatus === "Not checked"
                  ? "Compares every file with the cloud · may take a while"
                  : root.oneDrive.remoteStatus + " · " + Model.checkedText(root.oneDrive.syncStatusCheckedTs)))
            icon: "󰍉"
            actionIcon: root.oneDrive.fullStatusChecking ? "" : "󰑐"
            spinning: root.oneDrive.fullStatusChecking
            actionEnabled: !root.oneDrive.busy
            onActivated: root.oneDrive.checkFullStatus()
          }

          Row {
            id: chipRow
            visible: root.panelStyle === "full" && root.oneDrive.installed && root.oneDrive.authenticated
            width: parent.width
            spacing: Style.space(6)
            readonly property int chipCount: folderChip.visible ? 3 : 2
            readonly property real chipWidth: (width - spacing * (chipCount - 1)) / chipCount

            ActionChip {
              id: checkChip
              width: chipRow.chipWidth
              text: root.oneDrive.quotaChecking ? "Refreshing…" : "Storage"
              icon: "󰑓"
              spinning: root.oneDrive.quotaChecking
              enabled: !root.oneDrive.busy
              onActivated: root.oneDrive.checkQuota()
            }

            ActionChip {
              id: folderChip
              visible: root.oneDrive.syncDir !== ""
              width: chipRow.chipWidth
              text: "Folder"
              icon: "󰉋"
              onActivated: root.oneDrive.openFolder()
            }

            ActionChip {
              id: webChip
              width: chipRow.chipWidth
              text: "Web"
              icon: "󰖟"
              onActivated: root.oneDrive.openWeb()
            }
          }

          Column {
            id: compactActions
            visible: root.oneDrive.authenticated && root.panelStyle === "compact"
            width: parent.width
            spacing: Style.space(5)

            CompactActionRow {
              id: compactCheck
              width: parent.width
              title: root.oneDrive.quotaChecking ? "Refreshing storage…" : "Refresh storage"
              icon: "󰑓"
              meta: root.oneDrive.quotaChecking ? "up to " + String(root.oneDrive.cloudTimeoutSec) + "s"
                : Model.relativeTime(root.oneDrive.quotaCheckedTs)
              spinning: root.oneDrive.quotaChecking
              actionEnabled: !root.oneDrive.busy
              onActivated: root.oneDrive.checkQuota()
            }

            CompactActionRow {
              id: compactFullStatus
              width: parent.width
              title: root.oneDrive.fullStatusChecking ? "Verifying sync…" : "Verify sync"
              icon: "󰍉"
              meta: root.oneDrive.fullStatusChecking ? "up to " + String(root.oneDrive.cloudTimeoutSec) + "s"
                : (root.oneDrive.syncStatusError !== "" ? "retry"
                  : (root.oneDrive.remoteStatus === "Not checked" ? "may be slow"
                    : Model.relativeTime(root.oneDrive.syncStatusCheckedTs)))
              spinning: root.oneDrive.fullStatusChecking
              actionEnabled: !root.oneDrive.busy
              onActivated: root.oneDrive.checkFullStatus()
            }

            CompactActionRow {
              id: compactFolder
              width: parent.width
              title: "Open OneDrive folder"
              icon: "󰉋"
              actionEnabled: root.oneDrive.syncDir !== ""
              onActivated: root.oneDrive.openFolder()
            }

            CompactActionRow {
              id: compactWeb
              width: parent.width
              title: "Open OneDrive on the web"
              icon: "󰖟"
              onActivated: root.oneDrive.openWeb()
            }
          }
          ActionChip {
            width: parent.width
            text: root.preferencesVisible ? "Hide preferences" : "Preferences"
            onActivated: {
              root.preferencesVisible = !root.preferencesVisible
            }
          }
          Column {
            id: preferencesSection
            objectName: "onedrive-preferences"
            width: parent.width
            visible: root.preferencesVisible
            spacing: 8
            PanelSectionHeader { text: "PANEL LAYOUT"; foreground: root.foreground; fontFamily: root.fontFamily }
            Row {
              width: parent.width
              spacing: 6
              ActionChip {
                objectName: "onedrive-layout-full"
                width: (parent.width - parent.spacing) / 2
                text: "Full"
                current: root.panelStyle === "full"
                onActivated: root.oneDrive.updateSetting("panelStyle", "Full")
              }
              ActionChip {
                objectName: "onedrive-layout-compact"
                width: (parent.width - parent.spacing) / 2
                text: "Compact"
                current: root.panelStyle === "compact"
                onActivated: root.oneDrive.updateSetting("panelStyle", "Compact")
              }
            }
            PreferenceStepper {
              objectName: "onedrive-refresh-setting"
              label: "Local refresh"
              settingKey: "refreshIntervalSec"
              fallback: 30
              minimum: 10
              maximum: 3600
              step: 10
              suffix: " s"
            }
            PreferenceStepper {
              objectName: "onedrive-files-setting"
              label: "Recent files"
              settingKey: "recentFileLimit"
              fallback: 20
              minimum: 5
              maximum: 50
              step: 5
            }
            CursorSurface {
              id: notificationsSetting
              objectName: "onedrive-notifications-setting"
              width: parent.width
              height: 38
              foreground: root.foreground
              bordered: true
              hasCursor: notificationMouse.containsMouse || root.cursorItem === notificationsSetting
              readonly property bool keyboardEnabled: true
              function keyboardActivate() { root.oneDrive.updateSetting("notifications", root.oneDrive.settings.notifications === false) }
              MouseArea {
                id: notificationMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.setCursor(notificationsSetting)
                onClicked: notificationsSetting.keyboardActivate()
              }
              CommonComponents.UiText {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "Desktop notifications"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              ToggleSwitch {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                checked: root.oneDrive.settings.notifications !== false
                interactive: false
                cursorRing: false
                trackHeight: 18
                foreground: root.foreground
                accent: root.theme.seal
              }
            }
          }
          Item { width: 1; height: 6; visible: root.preferencesVisible }
        }
      }
    }
  }

  component PreferenceStepper: CursorSurface {
    id: preference
    required property string label
    required property string settingKey
    required property int fallback
    required property int minimum
    required property int maximum
    required property int step
    property string suffix: ""
    readonly property int value: Math.max(minimum, Math.min(maximum,
      Number(root.oneDrive.settings[settingKey] === undefined ? fallback : root.oneDrive.settings[settingKey])))
    readonly property bool keyboardEnabled: true
    function adjust(direction) {
      root.oneDrive.updateSetting(settingKey, Math.max(minimum, Math.min(maximum, value + direction * step)))
    }
    function keyboardActivate() { adjust(1) }
    width: parent.width
    height: 38
    foreground: root.foreground
    bordered: true
    hasCursor: preferenceMouse.containsMouse || root.cursorItem === preference
    MouseArea {
      id: preferenceMouse
      anchors.fill: parent
      hoverEnabled: true
      onEntered: root.setCursor(preference)
    }
    CommonComponents.UiText {
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.right: stepControls.left
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: preference.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
    Row {
      id: stepControls
      anchors.right: parent.right
      anchors.rightMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4
      PanelActionButton {
        objectName: "setting-decrease"
        iconText: "−"
        size: 24
        fontSize: 14
        foreground: root.foreground
        enabled: preference.value > preference.minimum
        onHovered: function(on) { if (on) root.setCursor(preference) }
        onClicked: preference.adjust(-1)
      }
      CommonComponents.UiText {
        width: 54
        height: 24
        text: preference.value + preference.suffix
        color: root.theme.seal
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
      PanelActionButton {
        objectName: "setting-increase"
        iconText: "+"
        size: 24
        fontSize: 14
        foreground: root.foreground
        enabled: preference.value < preference.maximum
        onHovered: function(on) { if (on) root.setCursor(preference) }
        onClicked: preference.adjust(1)
      }
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow

    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property string actionIcon: "󰐕"
    property bool actionEnabled: true
    property bool spinning: false
    readonly property bool keyboardEnabled: actionEnabled
    signal activated()
    function keyboardActivate() { if (actionEnabled) activated() }
    onSpinningChanged: { if (!spinning) actionRowGlyph.rotation = 0 }

    foreground: root.foreground
    hasCursor: (actionMouse.containsMouse || root.cursorItem === actionRow) && actionEnabled
    implicitHeight: Math.max(Style.space(54), row.implicitHeight + Style.spacing.rowPaddingX)
    height: implicitHeight

    MouseArea {
      id: actionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: actionRow.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: actionRow.actionEnabled
      onEntered: root.setCursor(actionRow)
      onClicked: actionRow.activated()
    }

    RowLayout {
      id: row
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(9)

      CommonComponents.UiText {

        textFormat: Text.PlainText
        id: actionRowGlyph
        text: actionRow.icon
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter

        RotationAnimation on rotation {
          running: actionRow.spinning
          from: 0
          to: 360
          duration: 900
          loops: Animation.Infinite
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        CommonComponents.UiText {

          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: actionRow.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        CommonComponents.UiText {

          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: actionRow.subtitle
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideMiddle
        }
      }

      PanelActionButton {
        visible: actionRow.actionIcon !== ""
        iconText: actionRow.actionIcon
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: actionRow.actionEnabled
        Layout.alignment: Qt.AlignVCenter
        onClicked: actionRow.activated()
      }
    }
  }

  component ActivityRow: CursorSurface {
    id: activityRow
    property var rowData: null
    readonly property string kind: String(rowData && rowData.kind || "")
    readonly property bool fileRow: kind === "file"
    readonly property bool recovered: rowData && rowData.recovered === true
    readonly property bool keyboardEnabled: fileRow
    readonly property string title: String(rowData && rowData.title || "")
    readonly property string detail: String(rowData && rowData.detail || "")

    foreground: root.foreground
    hasCursor: (activityMouse.containsMouse || root.cursorItem === activityRow) && fileRow
    implicitHeight: Math.max(Style.space(32), activityContent.implicitHeight + Style.space(6))
    height: implicitHeight

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.topMargin: Style.space(5)
      anchors.bottomMargin: Style.space(5)
      width: Style.space(2)
      radius: width / 2
      color: activityRow.fileRow ? root.dim : root.theme.seal
    }

    MouseArea {
      id: activityMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: activityRow.fileRow
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: root.setCursor(activityRow)
      onClicked: root.oneDrive.openFile({
        path: activityRow.rowData && activityRow.rowData.path || "",
        name: activityRow.title
      })
    }

    function keyboardActivate() {
      if (!fileRow) return
      root.oneDrive.openFile({
        path: rowData && rowData.path || "",
        name: title
      })
    }

    RowLayout {
      id: activityContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(7)

      CommonComponents.UiText {

        textFormat: Text.PlainText
        text: Model.activityGlyph(activityRow.rowData)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        CommonComponents.UiText {

          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: activityRow.title
          color: activityRow.kind === "error" && !activityRow.recovered
            ? root.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        CommonComponents.UiText {

          textFormat: Text.PlainText
          visible: activityRow.detail !== ""
          Layout.fillWidth: true
          text: activityRow.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideMiddle
        }
      }

      CommonComponents.UiText {

        textFormat: Text.PlainText
        text: Model.relativeTime(activityRow.rowData && activityRow.rowData.ts || 0)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
        Layout.alignment: Qt.AlignTop | Qt.AlignRight
      }
    }
  }

  component AccountTab: CursorSurface {
    id: accountTab
    property var account: null
    property bool selected: false
    readonly property bool keyboardEnabled: true
    signal activated()
    function keyboardActivate() { activated() }

    // No glyph until this account has reported: its default values would
    // otherwise render as the missing-client mark, which is the same drift the
    // bar's checking gate exists to prevent.
    readonly property string stateKind: account && account.initialized
      ? Model.badgeKind(Model.accountStateKind(account)) : ""

    foreground: root.foreground
    // The selected segment carries the border; the rest read as quiet labels.
    bordered: accountTab.selected
    hasCursor: (accountTabMouse.containsMouse || root.cursorItem === accountTab)
    implicitHeight: Style.space(30)
    height: implicitHeight

    Row {
      anchors.centerIn: parent
      spacing: Style.space(5)

      CommonComponents.UiText {

        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        visible: accountTab.stateKind !== ""
        text: Model.badgeGlyph(accountTab.stateKind)
        color: accountTab.stateKind === "attention" || accountTab.stateKind === "login"
          ? root.urgent
          : (accountTab.stateKind === "syncing" ? root.theme.seal : root.dim)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      CommonComponents.UiText {

        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: accountTab.account
          ? Model.accountName(accountTab.account.instance, accountTab.account.description)
          : ""
        color: accountTab.selected ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        width: Math.min(implicitWidth, Math.max(0, accountTab.width - Style.space(22)))
      }
    }

    MouseArea {
      id: accountTabMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: accountTab.activated()
    }
  }

  component ActionChip: CursorSurface {
    id: actionChip
    property string text: ""
    property string icon: ""
    property bool spinning: false
    readonly property bool keyboardEnabled: enabled
    signal activated()
    function keyboardActivate() { if (enabled) activated() }
    onSpinningChanged: { if (!spinning) actionChipGlyph.rotation = 0 }

    foreground: root.foreground
    bordered: true
    hasCursor: (chipMouse.containsMouse || root.cursorItem === actionChip) && actionChip.enabled
    implicitHeight: Style.space(34)
    height: implicitHeight
    opacity: enabled ? 1.0 : 0.5

    Row {
      id: actionChipContent
      anchors.centerIn: parent
      spacing: Style.space(6)

      CommonComponents.UiText {

        textFormat: Text.PlainText
        id: actionChipGlyph
        anchors.verticalCenter: parent.verticalCenter
        text: actionChip.icon
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall

        RotationAnimation on rotation {
          running: actionChip.spinning
          from: 0
          to: 360
          duration: 900
          loops: Animation.Infinite
        }
      }

      CommonComponents.UiText {

        textFormat: Text.PlainText
        // Keep the label inside the chip border: give it only the width the
        // chip can spare, shrinking the font slightly before eliding.
        readonly property real availableWidth: actionChip.width - Style.space(16)
          - (actionChip.icon !== "" ? actionChipGlyph.width + actionChipContent.spacing : 0)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, Math.max(0, availableWidth))
        text: actionChip.text
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: Style.font.bodySmall - 3
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: actionChip.enabled
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: root.setCursor(actionChip)
      onClicked: actionChip.activated()
    }
  }

  component CompactActionRow: CursorSurface {
    id: compactRow
    property string title: ""
    property string icon: ""
    property string meta: ""
    property bool selected: false
    property bool actionEnabled: true
    property bool spinning: false
    readonly property bool keyboardEnabled: actionEnabled
    signal activated()
    function keyboardActivate() { if (actionEnabled) activated() }
    onSpinningChanged: { if (!spinning) compactActionGlyph.rotation = 0 }

    foreground: root.foreground
    current: selected
    currentFill: Style.selectedFillFor(root.foreground, root.theme.seal)
    hasCursor: (compactMouse.containsMouse || root.cursorItem === compactRow) && actionEnabled
    implicitHeight: Style.space(34)
    height: implicitHeight
    opacity: actionEnabled ? 1.0 : 0.5

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      CommonComponents.UiText {

        textFormat: Text.PlainText
        id: compactActionGlyph
        text: compactRow.icon
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        Layout.alignment: Qt.AlignVCenter

        RotationAnimation on rotation {
          running: compactRow.spinning
          from: 0
          to: 360
          duration: 900
          loops: Animation.Infinite
        }
      }

      CommonComponents.UiText {

        textFormat: Text.PlainText
        Layout.fillWidth: true
        text: compactRow.title
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }

      CommonComponents.UiText {

        textFormat: Text.PlainText
        visible: compactRow.meta !== ""
        text: compactRow.meta
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
      }
    }

    MouseArea {
      id: compactMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: compactRow.actionEnabled
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: root.setCursor(compactRow)
      onClicked: compactRow.activated()
    }
  }
}
