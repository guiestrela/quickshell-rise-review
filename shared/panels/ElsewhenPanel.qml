pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import "../services" as Services

PanelWindow {
    id: panel
    required property var root
    required property int barBottom
    required property int gap
    required property real frameRadius
    required property color frameColor
    required property color frameBorderColor
    required property real frameBorderWidth
    required property real buttonRadius
    property real revealShift: 0
    property Component surfaceComponent
    readonly property Item surfaceHost: card
    readonly property var service: root.elsewhenService
    readonly property var clockWords: {
        var locale = Qt.locale(Commons.I18n.formatLocale)
        return {
            t: function(key, fallback) { return Commons.I18n.t(key, fallback) },
            tn: function(key, count, fallback) { return Commons.I18n.tn(key, count, fallback) },
            fmt: function(value, decimals) { return Commons.I18n.formatNumber(value, decimals) },
            am: locale.amText,
            pm: locale.pmText,
            date: function(parts) {
                return new Date(parts.year, parts.month, parts.day, 12)
                    .toLocaleString(locale, Commons.I18n.t("elsewhen.dateFormat", "ddd MMM d"))
            }
        }
    }
    Binding {
        target: panel.service && panel.service.formatLocale !== undefined ? panel.service : null
        property: "formatLocale"
        value: Commons.I18n.formatLocale
    }
    Binding {
        target: panel.service && panel.service.words !== undefined ? panel.service : null
        property: "words"
        value: panel.clockWords
    }
    readonly property real reveal: root.elsewhenVisible ? 1 : 0
    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rise-elsewhen"
    WlrLayershell.keyboardFocus: root.elsewhenVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: root.elsewhenVisible
    onVisibleChanged: {
        if (!visible || !service || typeof service.requestProfiles !== "function") return
        Qt.callLater(function() {
            if (panel.visible && panel.service && typeof panel.service.requestProfiles === "function")
                panel.service.requestProfiles()
        })
    }

    Services.ElsewhenIpcHandler {
        service: panel.service
        owner: panel.root
        content: body
    }

    function close() { root.elsewhenVisible = false }
    MouseArea { anchors.fill: parent; onClicked: panel.close() }

    Rectangle {
        id: card
        width: Math.min(340, parent.width - 16)
        height: Math.min(body.contentHeight + 24, Math.min(680, Math.max(220, parent.height - panel.barBottom - panel.gap - 16)))
        x: Math.round(Math.max(8, Math.min(panel.root.elsewhenBarX - width / 2, parent.width - width - 8)))
        y: panel.root.barPosition === "bottom"
            ? parent.height - panel.barBottom - panel.gap - height + panel.revealShift
            : panel.barBottom + panel.gap - panel.revealShift
        radius: panel.frameRadius
        color: panel.frameColor
        border.color: panel.frameBorderColor
        border.width: panel.frameBorderWidth
        Loader { anchors.fill: parent; sourceComponent: panel.surfaceComponent }
        MouseArea { anchors.fill: parent; onClicked: {} }
        ElsewhenPanelContent {
            id: body
            anchors.fill: parent
            anchors.margins: 12
            root: panel.root
            service: panel.service
            globeStageHeight: Commons.Style.space(378)
            titleFontSize: Commons.Style.font.title
            captionFontSize: Commons.Style.font.caption
            motionDuration: function(ms) { return Commons.Style.duration(ms) }
            notificationSink: function(message) {
                Quickshell.execDetached(["omarchy-notification-send", String(message)])
            }
            notificationFormatter: function(succeeded, location, zone) {
                return succeeded
                    ? Commons.I18n.t("elsewhen.timezoneChanged").arg(location).arg(zone)
                    : Commons.I18n.t("elsewhen.timezoneFailed").arg(zone)
            }
        }
    }
}
