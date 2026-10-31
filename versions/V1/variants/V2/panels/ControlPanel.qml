pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../modules"
import "../../../modules" as Shared

PanelWindow {
    id: ctrlPanel
    required property var root

    screen: ctrlPanel.root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-control"
    // no mask → whole overlay is interactive (modal): click-outside + ESC work

    readonly property int barBottom: ctrlPanel.root.v2BarHeight
    readonly property int gap: 6

    // power sub-menu starts CLOSED — no destructive tile is ever pre-shown
    property bool powerOpen: false
    property bool wsOpen: false   // Workspaces collapsible inside the WW fly-out
    property string widgetColorMenuGid: ""
    property string widgetColorMenuLabel: ""
    readonly property string barctlPath: Quickshell.env("HOME") + "/.config/quickshell/bin/qs-barctl"

    function switchBar(version) {
        if (version !== "v1" && version !== "v2") return
        ctrlPanel.root.controlVisible = false
        if (ctrlPanel.root.variantHost)
            ctrlPanel.root.variantHost.requestSwitch(version)
        else
            Quickshell.execDetached([barctlPath, "switch", version])
    }

    function reloadBar() {
        ctrlPanel.root.controlVisible = false
        Quickshell.reload(false)
    }

    function runPowerAction(action) {
        var commands = {
            lock: ["omarchy", "system", "lock"],
            suspend: ["systemctl", "--no-ask-password", "suspend"],
            reboot: ["omarchy", "system", "reboot"],
            shutdown: ["omarchy", "system", "shutdown"]
        }
        if (!commands[action]) return
        Quickshell.execDetached(commands[action])
        ctrlPanel.root.controlVisible = false
    }

    property real reveal: ctrlPanel.root.controlVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: ctrlPanel.root.controlVisible ? 160 : 120
            easing.type: ctrlPanel.root.controlVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    onRevealChanged: if (reveal < 0.01) {
        powerOpen = false
        wsOpen = false
        widgetColorMenuGid = ""
        widgetColorMenuLabel = ""
        ctrlPanel.root.wwSubVisible = false
    }
    WlrLayershell.keyboardFocus: ctrlPanel.root.controlVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── reusable tile: neutral by default, highlights only on hover ──
    component Tile: Rectangle {
        id: tile
        property string label
        property color accent: ctrlPanel.root.seal
        property bool active: false
        signal activated()
        height: 25
        radius: ctrlPanel.root.panelButtonRadius
        opacity: enabled ? 1.0 : 0.4          // built-in `enabled` also blocks input
        color: active ? Qt.rgba(accent.r, accent.g, accent.b, ctrlPanel.root.fillActiveAlpha) : _ma.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, ctrlPanel.root.fillHoverAlpha) : ctrlPanel.root.fillIdle
        border.color: (active || _ma.containsMouse) ? accent : ctrlPanel.root.sep
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Text {
            anchors.centerIn: parent
            text: parent.label
            color: (parent.active || _ma.containsMouse) ? parent.accent : ctrlPanel.root.ink
            font.family: ctrlPanel.root.mono; font.pixelSize: 11
        }
        MouseArea {
            id: _ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.activated()
        }
    }

    // ── one quiet tile: body toggles visibility, trailing state toggles density ──
    component WidgetStateTile: Rectangle {
        id: widgetStateTile
        property string gid
        property string label
        property bool shown: true
        property bool canHide: true
        property bool supportsCompact: false
        property bool compact: false
        property string modeOffLabel: "Full"
        property string modeOnLabel: "Icon"
        signal visibilityToggled()
        signal modeToggled()

        readonly property bool hovered: bodyMa.containsMouse || colorMa.containsMouse
            || eyeMa.containsMouse || modeMa.containsMouse
        readonly property bool interactive: gid !== "" || canHide || (shown && supportsCompact)

        height: 27
        radius: ctrlPanel.root.panelButtonRadius
        opacity: interactive ? 1 : 0.4
        color: ctrlPanel.root.fillIdle
        border.color: hovered ? ctrlPanel.root.seal : ctrlPanel.root.sep
        border.width: 1

        UiText {
            id: widgetLabel
            anchors.left: parent.left; anchors.leftMargin: 8
            anchors.right: stateArea.left; anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: parent.shown ? ctrlPanel.root.ink : ctrlPanel.root.sumi
            font.family: ctrlPanel.root.mono
            font.pixelSize: 10
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Item {
            id: stateArea
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 88

            IconText {
                id: colorChip
                readonly property bool open:
                    ctrlPanel.widgetColorMenuGid === stateArea.parent.gid
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 25
                horizontalAlignment: Text.AlignHCenter
                text: "palette"
                color: ctrlPanel.root.widgetHasFill(stateArea.parent.gid)
                    ? ctrlPanel.root.widgetAssignedColor(stateArea.parent.gid)
                    : (colorMa.containsMouse || open ? ctrlPanel.root.seal : ctrlPanel.root.sumiHi)
                font.pixelSize: 15
                font.weight: Font.Normal
                scale: colorMa.containsMouse ? 1.04 : 1.0
                z: colorMa.containsMouse || open ? 1 : 0
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }

            IconText {
                id: eyeGlyph
                anchors.left: colorChip.right
                anchors.verticalCenter: parent.verticalCenter
                width: 25
                horizontalAlignment: Text.AlignHCenter
                text: stateArea.parent.shown ? "visibility" : "visibility_off"
                color: eyeMa.containsMouse ? ctrlPanel.root.seal : stateArea.parent.shown ? ctrlPanel.root.sumiHi : ctrlPanel.root.sumi
                font.pixelSize: 15
                opacity: stateArea.parent.canHide ? 1 : 0.4
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            UiText {
                id: modeLabel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                horizontalAlignment: Text.AlignHCenter
                visible: stateArea.parent.supportsCompact
                text: stateArea.parent.compact
                    ? stateArea.parent.modeOnLabel
                    : stateArea.parent.modeOffLabel
                color: modeMa.containsMouse || (stateArea.parent.shown && stateArea.parent.compact) ? ctrlPanel.root.seal : ctrlPanel.root.sumiHi
                font.family: ctrlPanel.root.mono; font.pixelSize: 10
                opacity: stateArea.parent.shown ? 1 : 0.4
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            MouseArea {
                id: colorMa
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 25
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (ctrlPanel.widgetColorMenuGid === stateArea.parent.gid) {
                        ctrlPanel.widgetColorMenuGid = ""
                        ctrlPanel.widgetColorMenuLabel = ""
                    } else {
                        ctrlPanel.widgetColorMenuGid = stateArea.parent.gid
                        ctrlPanel.widgetColorMenuLabel = stateArea.parent.label
                    }
                }
            }
            MouseArea {
                id: eyeMa
                anchors.left: colorMa.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 25
                enabled: stateArea.parent.canHide
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: stateArea.parent.visibilityToggled()
            }
            MouseArea {
                id: modeMa
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 38
                enabled: stateArea.parent.shown && stateArea.parent.supportsCompact
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: stateArea.parent.modeToggled()
            }
        }

        MouseArea {
            id: bodyMa
            anchors.left: parent.left
            anchors.right: stateArea.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            enabled: parent.canHide
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: parent.visibilityToggled()
        }
    }

    MouseArea { anchors.fill: parent; onClicked: ctrlPanel.root.controlVisible = false }

    Rectangle {
        id: card
        width: 240
        height: col.implicitHeight + 24
        radius: ctrlPanel.reveal > 0.001 ? ctrlPanel.root.panelRadius : 0
        color: "transparent"
        border.color: ctrlPanel.root.panelOuterBorderColor
        border.width: 0
        PillShadow { theme: ctrlPanel.root }
        ConnectedPanelSurface {
            root: ctrlPanel.root
            ownerActive: ctrlPanel.root.controlVisible
            targetX: ctrlPanel.root.launcherBarX
            reveal: ctrlPanel.reveal
        }

        SidePanelPositioner { root: ctrlPanel.root; target: parent; anchorName: "launcher" }
        x: Math.round(Math.max(6, Math.min(ctrlPanel.root.launcherBarX - width / 2, parent.width - width - 6)))
        y: ctrlPanel.root.barPosition === "bottom"
            ? (parent.height - ctrlPanel.barBottom - ctrlPanel.gap - height) + 2 * (1 - ctrlPanel.reveal)
            : (ctrlPanel.barBottom + ctrlPanel.gap) - 2 * (1 - ctrlPanel.reveal)
        opacity: ctrlPanel.reveal
        focus: ctrlPanel.root.controlVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { ctrlPanel.root.controlVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header ──
            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Control"
                    color: ctrlPanel.root.ink; font.family: ctrlPanel.root.mono; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? ctrlPanel.root.seal : ctrlPanel.root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ctrlPanel.root.controlVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: ctrlPanel.root.sep }

            // ── ACTIONS ──
            UiText {
                text: "ACTIONS"
                color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Grid {
                width: parent.width
                columns: 3
                columnSpacing: 6
                Tile {
                    width: ctrlPanel.root.evenW((col.width - 12) / 3)
                    label: "Reload"
                    onActivated: ctrlPanel.reloadBar()
                }
                Tile {
                    width: ctrlPanel.root.evenW((col.width - 12) / 3)
                    label: "V1"
                    active: ctrlPanel.root.variantHost ? ctrlPanel.root.variantHost.runningVariant === "v1" : false
                    enabled: ctrlPanel.root.variantHost ? !ctrlPanel.root.variantHost.switching && ctrlPanel.root.variantHost.runningVariant !== "v1" : true
                    opacity: active ? 1.0 : (enabled ? 1.0 : 0.4)
                    onActivated: ctrlPanel.switchBar("v1")
                }
                Tile {
                    width: ctrlPanel.root.evenW((col.width - 12) / 3)
                    label: "V2"
                    active: ctrlPanel.root.variantHost ? ctrlPanel.root.variantHost.runningVariant === "v2" : true
                    enabled: ctrlPanel.root.variantHost ? !ctrlPanel.root.variantHost.switching && ctrlPanel.root.variantHost.runningVariant !== "v2" : false
                    opacity: active ? 1.0 : (enabled ? 1.0 : 0.4)
                    onActivated: ctrlPanel.switchBar("v2")
                }
            }

            // ── POWER (collapsed sub-menu; nothing destructive pre-shown) ──
            Tile {
                width: parent.width
                label: ctrlPanel.powerOpen ? "Power  ▾" : "Power  ▸"
                accent: ctrlPanel.root.seal
                onActivated: ctrlPanel.powerOpen = !ctrlPanel.powerOpen
            }
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                visible: ctrlPanel.powerOpen
                Tile {
                    width: ctrlPanel.root.evenW((col.width - 8) / 2)
                    label: "Lock"
                    onActivated: ctrlPanel.runPowerAction("lock")
                }
                Tile {
                    width: ctrlPanel.root.evenW((col.width - 8) / 2)
                    label: "Suspend"
                    onActivated: ctrlPanel.runPowerAction("suspend")
                }
                Tile {
                    width: ctrlPanel.root.evenW((col.width - 8) / 2)
                    label: "Reboot"
                    accent: ctrlPanel.root.seal
                    onActivated: ctrlPanel.runPowerAction("reboot")
                }
                Tile {
                    width: ctrlPanel.root.evenW((col.width - 8) / 2)
                    label: "Shutdown"
                    accent: ctrlPanel.root.seal
                    onActivated: ctrlPanel.runPowerAction("shutdown")
                }
            }

            Rectangle { width: parent.width; height: 1; color: ctrlPanel.root.sep }

            // ── BAR COLOR: compact colors.toml palette ──
            UiText {
                text: "BAR COLOR"
                color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Grid {
                width: parent.width
                columns: 4
                columnSpacing: 6
                rowSpacing: 6
                Repeater {
                    model: ctrlPanel.root.barColorOptions
                    delegate: Rectangle {
                        id: entryDelegate3
                        required property string modelData
                        readonly property bool on: ctrlPanel.root.barColor === modelData
                        readonly property bool hovered: _cma.containsMouse
                        width: ctrlPanel.root.evenW((col.width - 18) / 4)
                        height: 24
                        radius: ctrlPanel.root.panelButtonRadius
                        color: ctrlPanel.root.paletteColor(modelData)
                        border.color: ctrlPanel.root.sep
                        border.width: 1
                        scale: hovered ? 1.04 : 1.0
                        z: hovered ? 1 : 0
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                        UiText {
                            anchors.centerIn: parent
                            text: entryDelegate3.modelData === "foreground" ? "FG" : entryDelegate3.modelData.slice(-2)
                            color: ctrlPanel.root.paletteContrastColor(entryDelegate3.modelData)
                            font.family: ctrlPanel.root.mono
                            font.pixelSize: 9
                            font.weight: Font.Medium
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            width: 18
                            height: 2
                            radius: 1
                            visible: parent.on
                            color: ctrlPanel.root.paletteContrastColor(entryDelegate3.modelData)
                        }
                        MouseArea {
                            id: _cma
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ctrlPanel.root.barColor = entryDelegate3.modelData
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: ctrlPanel.root.sep }

            // ── BAR FUNCTIONS (opens the fly-out sub-panel) ──
            UiText {
                text: "BAR FUNCTIONS"
                color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Tile {
                width: parent.width
                label: ctrlPanel.root.wwSubVisible ? "Bar Functions  ◂" : "Bar Functions  ▸"
                active: ctrlPanel.root.wwSubVisible
                onActivated: ctrlPanel.root.wwSubVisible = !ctrlPanel.root.wwSubVisible
            }

            Rectangle { width: parent.width; height: 1; color: ctrlPanel.root.sep }

            // ── PICKER style (theme/wallpaper/screenshot/video picker visual) ──
            UiText {
                text: "PICKER-STIL"
                color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Row {
                id: pickerRow
                width: parent.width
                spacing: 4
                readonly property var opts: [
                    { label: "Tanzaku",     mode: "tanzaku"     },
                    { label: "Hearthstone", mode: "hearthstone" },
                    { label: "Carousel",    mode: "carousel"    }
                ]
                // Tiles are sized to their label width (mono → length × charW)
                // plus an equal share of the leftover space, so every tile gets
                // the same side padding. Fixed 1/3-each made the long "Hearthstone"
                // label touch its borders while the short labels had slack.
                TextMetrics { id: pickMetrics; font.family: ctrlPanel.root.mono; font.pixelSize: 10; text: "0" }
                readonly property real charW: pickMetrics.advanceWidth
                readonly property real sumTextW: {
                    var n = 0;
                    for (var i = 0; i < opts.length; i++) n += opts[i].label.length;
                    return n * charW;
                }
                readonly property real padEach: Math.max(0, (width - spacing * (opts.length - 1) - sumTextW) / (opts.length * 2))
                Repeater {
                    model: pickerRow.opts
                    delegate: Rectangle {
                        id: pickTile
                        required property var modelData
                        readonly property bool on:      ctrlPanel.root.pickerStyle === modelData.mode
                        readonly property bool hovered: pickMa.containsMouse
                        width: ctrlPanel.root.evenW(modelData.label.length * pickerRow.charW + pickerRow.padEach * 2)
                        height: 25; radius: ctrlPanel.root.panelButtonRadius
                        color: on ? ctrlPanel.root.fillActive : hovered ? ctrlPanel.root.fillHover : ctrlPanel.root.fillIdle
                        border.color: (on || hovered) ? ctrlPanel.root.seal : ctrlPanel.root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        UiText {
                            anchors.centerIn: parent
                            text: pickTile.modelData.label
                            color: (pickTile.on || pickTile.hovered) ? ctrlPanel.root.seal : ctrlPanel.root.ink
                            font.family: ctrlPanel.root.mono; font.pixelSize: 10
                            font.weight: pickTile.on ? Font.Medium : Font.Normal
                        }
                        MouseArea {
                            id: pickMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ctrlPanel.root.pickerStyle = pickTile.modelData.mode
                        }
                    }
                }
            }

        }
    }

    // ── BAR FUNCTIONS sub-panel ──
    Rectangle {
        id: wwCard
        visible: ctrlPanel.root.controlVisible && ctrlPanel.root.wwSubVisible
        width: 320
        height: Math.min(wwCol.implicitHeight + 24, parent.height - 12)
        radius: (ctrlPanel.root.controlVisible && ctrlPanel.root.wwSubVisible) ? ctrlPanel.root.panelRadius : 0
        color: ctrlPanel.root.bg
        border.color: ctrlPanel.root.panelOuterBorderColor
        border.width: ctrlPanel.root.panelOuterBorderW
        PillShadow { theme: ctrlPanel.root }
        // open to the right of the card, or to the left if there is no room
        x: (card.x + card.width + ctrlPanel.gap + width <= parent.width - 6)
           ? card.x + card.width + ctrlPanel.gap
           : card.x - ctrlPanel.gap - width
        y: Math.max(6, Math.min(parent.height - height - 6,
            ctrlPanel.root.barPosition === "bottom" ? card.y + card.height - height : card.y))
        opacity: ctrlPanel.reveal

        MouseArea { anchors.fill: parent; onClicked: {} }

        Flickable {
            anchors.fill: parent
            anchors.margins: 12
            contentHeight: wwCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: wwCol
                width: parent.width
                spacing: 8

                UiText {
                    text: "LAYOUT"
                    color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
                }
                Row {
                    width: parent.width
                    spacing: 4
                    Tile {
                        width: ctrlPanel.root.evenW((wwCol.width - 4) / 2)
                        label: "Edit slots"
                        accent: ctrlPanel.root.seal
                        onActivated: {
                            ctrlPanel.root.controlVisible = false
                            ctrlPanel.root.barUnlocked = true
                        }
                    }
                    Tile {
                        width: ctrlPanel.root.evenW((wwCol.width - 4) / 2)
                        label: "Default layout"
                        onActivated: if (ctrlPanel.root.fnDefaultLayout) ctrlPanel.root.fnDefaultLayout()
                    }
                }
                Tile {
                    width: parent.width
                    label: "Protect layout"
                    active: ctrlPanel.root.layoutProtected
                    onActivated: { ctrlPanel.root.layoutProtected = !ctrlPanel.root.layoutProtected; ctrlPanel.root.barUnlocked = false }
                }
                Rectangle { width: parent.width; height: 1; color: ctrlPanel.root.sep }

                // ── WIDGETS: one tile per widget, two quiet interaction zones ──
                UiText {
                    text: "WIDGETS"
                    color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
                }
                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 4
                    rowSpacing: 4
                    WidgetStateTile { gid: "G1";  width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Launcher";      shown: true; canHide: false }
                    WidgetStateTile { gid: "G2";  width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Workspaces";    shown: true; canHide: false }
                    WidgetStateTile { gid: "G3";  width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Status";        shown: ctrlPanel.root.modStatus;          onVisibilityToggled: ctrlPanel.root.modStatus = !ctrlPanel.root.modStatus }
                    WidgetStateTile { gid: "G4";  width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Memory";        shown: ctrlPanel.root.modMemory;          supportsCompact: true; compact: ctrlPanel.root.iconOnly("G4");  onVisibilityToggled: ctrlPanel.root.modMemory = !ctrlPanel.root.modMemory; onModeToggled: ctrlPanel.root.toggleIconOnly("G4") }
                    WidgetStateTile { gid: "G5";  width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "CPU";           shown: ctrlPanel.root.modCpu;             supportsCompact: true; compact: ctrlPanel.root.iconOnly("G5");  onVisibilityToggled: ctrlPanel.root.modCpu = !ctrlPanel.root.modCpu; onModeToggled: ctrlPanel.root.toggleIconOnly("G5") }
                    WidgetStateTile { gid: "G6";  width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Volume";        shown: ctrlPanel.root.modVolume;          supportsCompact: true; compact: ctrlPanel.root.iconOnly("G6");  onVisibilityToggled: ctrlPanel.root.modVolume = !ctrlPanel.root.modVolume; onModeToggled: ctrlPanel.root.toggleIconOnly("G6") }
                    WidgetStateTile { gid: "G7";  width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "AI usage";      shown: ctrlPanel.root.modClaude;          supportsCompact: true; compact: ctrlPanel.root.iconOnly("G7");  onVisibilityToggled: ctrlPanel.root.modClaude = !ctrlPanel.root.modClaude; onModeToggled: ctrlPanel.root.toggleIconOnly("G7") }
                    WidgetStateTile { gid: "G8";  width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Clock/Weather"; shown: true; canHide: false }
                    WidgetStateTile { gid: "G9";  width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Now playing";   shown: ctrlPanel.root.modMpris; supportsCompact: true; compact: ctrlPanel.root.mprisBarStyle === "full"; modeOffLabel: "Def"; modeOnLabel: "Full"; onVisibilityToggled: ctrlPanel.root.modMpris = !ctrlPanel.root.modMpris; onModeToggled: ctrlPanel.root.mprisBarStyle = ctrlPanel.root.mprisBarStyle === "full" ? "default" : "full" }
                    WidgetStateTile { gid: "G10"; width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Quick tools";   shown: ctrlPanel.root.modQuick;           onVisibilityToggled: ctrlPanel.root.modQuick = !ctrlPanel.root.modQuick }
                    WidgetStateTile { gid: "G11"; width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Network";       shown: ctrlPanel.root.modNetwork || ctrlPanel.root.networkMode === "wifi"; canHide: ctrlPanel.root.networkMode !== "wifi"; supportsCompact: true; compact: ctrlPanel.root.iconOnly("G11"); onVisibilityToggled: ctrlPanel.root.modNetwork = !ctrlPanel.root.modNetwork; onModeToggled: ctrlPanel.root.toggleIconOnly("G11") }
                    WidgetStateTile { gid: "G19"; width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "NordVPN";       shown: ctrlPanel.root.modNordVpn; supportsCompact: true; compact: ctrlPanel.root.iconOnly("G19"); onVisibilityToggled: ctrlPanel.root.modNordVpn = !ctrlPanel.root.modNordVpn; onModeToggled: ctrlPanel.root.toggleIconOnly("G19") }
                    WidgetStateTile { objectName: "wallpaper-widget-toggle"; gid: "G20"; width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Wallpapers"; shown: ctrlPanel.root.modWallpapers; onVisibilityToggled: ctrlPanel.root.modWallpapers = !ctrlPanel.root.modWallpapers }
                    WidgetStateTile { gid: "G21"; width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Display Manager"; shown: ctrlPanel.root.modDisplayManager; onVisibilityToggled: ctrlPanel.root.modDisplayManager = !ctrlPanel.root.modDisplayManager }
                    WidgetStateTile { gid: "G12"; width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Battery";       shown: ctrlPanel.root.hasBattery; canHide: false; supportsCompact: true; compact: ctrlPanel.root.iconOnly("G12"); onModeToggled: ctrlPanel.root.toggleIconOnly("G12") }
                    WidgetStateTile { gid: "G13"; width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Brightness";    shown: ctrlPanel.root.hasBacklight && ctrlPanel.root.modBrightness; canHide: ctrlPanel.root.hasBacklight; supportsCompact: true; compact: ctrlPanel.root.iconOnly("G13"); onVisibilityToggled: ctrlPanel.root.modBrightness = !ctrlPanel.root.modBrightness; onModeToggled: ctrlPanel.root.toggleIconOnly("G13") }
                    WidgetStateTile { gid: "G14"; width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Power Prof.";   shown: ctrlPanel.root.modPower;           onVisibilityToggled: ctrlPanel.root.modPower = !ctrlPanel.root.modPower }
                    WidgetStateTile { gid: "G15"; width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Bluetooth";     shown: ctrlPanel.root.modBluetooth;       supportsCompact: true; compact: ctrlPanel.root.iconOnly("G15"); onVisibilityToggled: ctrlPanel.root.modBluetooth = !ctrlPanel.root.modBluetooth; onModeToggled: ctrlPanel.root.toggleIconOnly("G15") }
                    WidgetStateTile { gid: "G16"; width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Temperature";   shown: ctrlPanel.root.modCpuTemperature;  supportsCompact: true; compact: ctrlPanel.root.iconOnly("G16"); onVisibilityToggled: ctrlPanel.root.modCpuTemperature = !ctrlPanel.root.modCpuTemperature; onModeToggled: ctrlPanel.root.toggleIconOnly("G16") }
                    WidgetStateTile { gid: "G17"; width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "GPU load";      shown: ctrlPanel.root.modGpu;             supportsCompact: true; compact: ctrlPanel.root.iconOnly("G17"); onVisibilityToggled: ctrlPanel.root.modGpu = !ctrlPanel.root.modGpu; onModeToggled: ctrlPanel.root.toggleIconOnly("G17") }
                    WidgetStateTile { gid: "G18"; width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "HDD";           shown: ctrlPanel.root.modStorage;         supportsCompact: true; compact: ctrlPanel.root.iconOnly("G18"); onVisibilityToggled: ctrlPanel.root.modStorage = !ctrlPanel.root.modStorage; onModeToggled: ctrlPanel.root.toggleIconOnly("G18") }
                }

                Rectangle {
                    id: widgetColorMenu
                    width: parent.width
                    height: widgetMenuCol.implicitHeight + 16
                    radius: ctrlPanel.root.panelRadius
                    visible: ctrlPanel.widgetColorMenuGid !== ""
                    color: ctrlPanel.root.fillIdle
                    border.color: ctrlPanel.root.sep
                    border.width: 1

                    Column {
                        id: widgetMenuCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 7

                        Item {
                            width: parent.width
                            height: 18
                            UiText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: ctrlPanel.widgetColorMenuLabel.toUpperCase() + " COLOR"
                                color: ctrlPanel.root.sumiHi
                                font.family: ctrlPanel.root.mono
                                font.pixelSize: 9
                                font.letterSpacing: 0.7
                            }
                            UiText {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: ctrlPanel.root.widgetPaletteId(ctrlPanel.widgetColorMenuGid) === "inherit" ? "INHERIT" : "RESET"
                                color: resetColorMa.containsMouse ? ctrlPanel.root.seal : ctrlPanel.root.sumiHi
                                font.family: ctrlPanel.root.mono
                                font.pixelSize: 9
                            }
                            MouseArea {
                                id: resetColorMa
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 48
                                height: parent.height
                                enabled: ctrlPanel.root.widgetPaletteId(ctrlPanel.widgetColorMenuGid) !== "inherit"
                                hoverEnabled: enabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: ctrlPanel.root.resetWidgetColor(ctrlPanel.widgetColorMenuGid)
                            }
                        }

                        Grid {
                            width: parent.width
                            columns: 8
                            columnSpacing: 4
                            Repeater {
                                model: ctrlPanel.root.barColorOptions
                                delegate: Rectangle {
                                    id: entryDelegate4
                                    required property string modelData
                                    readonly property bool selected:
                                        ctrlPanel.root.widgetPaletteId(ctrlPanel.widgetColorMenuGid) === modelData
                                    width: ctrlPanel.root.evenW((widgetMenuCol.width - 28) / 8)
                                    height: 22
                                    radius: ctrlPanel.root.panelButtonRadius
                                    color: ctrlPanel.root.paletteColor(modelData)
                                    border.color: ctrlPanel.root.sep
                                    border.width: 1
                                    scale: widgetSwatchMa.containsMouse ? 1.04 : 1.0
                                    z: widgetSwatchMa.containsMouse ? 1 : 0
                                    Behavior on scale {
                                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                    }
                                    UiText {
                                        anchors.centerIn: parent
                                        text: entryDelegate4.modelData === "foreground" ? "F" : entryDelegate4.modelData.slice(-1)
                                        color: ctrlPanel.root.paletteContrastColor(entryDelegate4.modelData)
                                        font.family: ctrlPanel.root.mono
                                        font.pixelSize: 8
                                        font.weight: Font.Medium
                                    }
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 2
                                        width: 12
                                        height: 2
                                        radius: 1
                                        visible: parent.selected
                                        color: ctrlPanel.root.paletteContrastColor(entryDelegate4.modelData)
                                    }
                                    MouseArea {
                                        id: widgetSwatchMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (parent.selected)
                                                ctrlPanel.root.resetWidgetColor(ctrlPanel.widgetColorMenuGid)
                                            else
                                                ctrlPanel.root.setWidgetPaletteColor(ctrlPanel.widgetColorMenuGid, entryDelegate4.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: [
                                { key: "opacity", label: "Opacity", values: [1, 0.85, 0.68, 0.35] },
                                { key: "radius", label: "Corners", values: ["auto", "square", "soft", "round"] },
                                { key: "padding", label: "Padding", values: ["auto", "none", "compact", "roomy"] },
                                { key: "borderWidth", label: "Border width", values: [1, 1.5, 2, 0.5] },
                                { key: "borderColor", label: "Border color", values: ["inherit", "color01", "color02", "color03", "color04", "color05", "color06", "color07", "foreground"] }
                            ]
                            delegate: Tile {
                                id: entryDelegate5
                                required property var modelData
                                readonly property var value: ctrlPanel.root.widgetSurfaceStyle(ctrlPanel.widgetColorMenuGid)[modelData.key]
                                width: widgetMenuCol.width
                                height: 23
                                label: modelData.label + ": " + value
                                onActivated: {
                                    var values = modelData.values
                                    var next = values[(values.indexOf(value) + 1) % values.length]
                                    ctrlPanel.root.setWidgetSurfaceStyle(ctrlPanel.widgetColorMenuGid, modelData.key, next)
                                }
                            }
                        }
                        Tile {
                            width: parent.width
                            height: 23
                            label: "Reset surface"
                            onActivated: ctrlPanel.root.resetWidgetSurfaceStyle(ctrlPanel.widgetColorMenuGid)
                        }
                        Tile {
                            width: parent.width
                            height: 23
                            label: "Border"
                            active: ctrlPanel.root.widgetHasBorder(ctrlPanel.widgetColorMenuGid)
                            onActivated: ctrlPanel.root.setWidgetBorderEnabled(
                                ctrlPanel.widgetColorMenuGid,
                                !ctrlPanel.root.widgetHasBorder(ctrlPanel.widgetColorMenuGid))
                        }

                        Row {
                            width: parent.width
                            spacing: 4
                            visible: ctrlPanel.root.widgetHasFill(ctrlPanel.widgetColorMenuGid)
                            Repeater {
                                model: [
                                    { id: "auto", label: "Auto" },
                                    { id: "background", label: "BG" },
                                    { id: "foreground", label: "FG" }
                                ]
                                delegate: Rectangle {
                                    id: entryDelegate6
                                    required property var modelData
                                    readonly property bool selected:
                                        ctrlPanel.root.widgetTone(ctrlPanel.widgetColorMenuGid) === modelData.id
                                    width: ctrlPanel.root.evenW((widgetMenuCol.width - 8) / 3)
                                    height: 23
                                    radius: ctrlPanel.root.panelButtonRadius
                                    color: selected ? ctrlPanel.root.fillActive : toneColorMa.containsMouse ? ctrlPanel.root.fillHover : "transparent"
                                    border.color: selected || toneColorMa.containsMouse ? ctrlPanel.root.seal : ctrlPanel.root.sep
                                    border.width: 1
                                    UiText {
                                        anchors.centerIn: parent
                                        text: entryDelegate6.modelData.label
                                        color: entryDelegate6.selected ? ctrlPanel.root.seal : ctrlPanel.root.ink
                                        font.family: ctrlPanel.root.mono
                                        font.pixelSize: 9
                                    }
                                    MouseArea {
                                        id: toneColorMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ctrlPanel.root.setWidgetTone(ctrlPanel.widgetColorMenuGid, entryDelegate6.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: ctrlPanel.root.sep }

                // ── WORKSPACES (collapsible, like the old widgets group) ──
                Tile {
                    width: parent.width
                    label: ctrlPanel.wsOpen ? "Workspaces  ▾" : "Workspaces  ▸"
                    onActivated: ctrlPanel.wsOpen = !ctrlPanel.wsOpen
                }
                Column {
                    width: parent.width
                    spacing: 8
                    visible: ctrlPanel.wsOpen

                    // display mode: persist 10 / persist 5 / active
                    Row {
                        id: wsModeRow
                        width: parent.width
                        spacing: 4
                        readonly property var opts: [
                            { label: "Persist 10", mode: "10"     },
                            { label: "Persist 5",  mode: "5"      },
                            { label: "Active",     mode: "active" }
                        ]
                        Repeater {
                            model: wsModeRow.opts
                            delegate: Rectangle {
                                id: wsmTile
                                required property var modelData
                                readonly property bool on:      ctrlPanel.root.workspaceMode === modelData.mode
                                readonly property bool hovered: wsmMa.containsMouse
                                width: ctrlPanel.root.evenW((wsModeRow.width - wsModeRow.spacing * (wsModeRow.opts.length - 1)) / wsModeRow.opts.length)
                                height: 25; radius: ctrlPanel.root.panelButtonRadius
                                color: on ? ctrlPanel.root.fillActive : hovered ? ctrlPanel.root.fillHover : ctrlPanel.root.fillIdle
                                border.color: (on || hovered) ? ctrlPanel.root.seal : ctrlPanel.root.sep
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }
                                UiText {
                                    anchors.centerIn: parent
                                    text: wsmTile.modelData.label
                                    color: (wsmTile.on || wsmTile.hovered) ? ctrlPanel.root.seal : ctrlPanel.root.ink
                                    font.family: ctrlPanel.root.mono; font.pixelSize: 10
                                    font.weight: wsmTile.on ? Font.Medium : Font.Normal
                                }
                                MouseArea { id: wsmMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ctrlPanel.root.workspaceMode = wsmTile.modelData.mode }
                            }
                        }
                    }

                    // Six compact workspace treatments; three columns keep every
                    // label legible without widening the control fly-out.
                    Grid {
                        id: wsStyleRow
                        width: parent.width
                        columns: 3
                        spacing: 4
                        readonly property var opts: [
                            { label: "Default", mode: "default" },
                            { label: "Numbers", mode: "numbers" },
                            { label: "Magic",   mode: "magic"   },
                            { label: "Kanji",   mode: "kanji"   },
                            { label: "Frame",   mode: "rings"   },
                            { label: "Aurora",  mode: "aurora"  }
                        ]
                        Repeater {
                            model: wsStyleRow.opts
                            delegate: Rectangle {
                                id: wssTile
                                required property var modelData
                                readonly property bool on:      ctrlPanel.root.workspaceStyle === modelData.mode
                                readonly property bool hovered: wssMa.containsMouse
                                width: ctrlPanel.root.evenW((wsStyleRow.width
                                    - wsStyleRow.spacing * (wsStyleRow.columns - 1))
                                    / wsStyleRow.columns)
                                height: 25; radius: ctrlPanel.root.panelButtonRadius
                                color: on ? ctrlPanel.root.fillActive : hovered ? ctrlPanel.root.fillHover : ctrlPanel.root.fillIdle
                                border.color: (on || hovered) ? ctrlPanel.root.seal : ctrlPanel.root.sep
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }
                                UiText {
                                    anchors.centerIn: parent
                                    text: wssTile.modelData.label
                                    color: (wssTile.on || wssTile.hovered) ? ctrlPanel.root.seal : ctrlPanel.root.ink
                                    font.family: ctrlPanel.root.mono; font.pixelSize: 10
                                    font.weight: wssTile.on ? Font.Medium : Font.Normal
                                }
                                MouseArea { id: wssMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ctrlPanel.root.workspaceStyle = wssTile.modelData.mode }
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: ctrlPanel.root.sep }

                // ── BAR SHELL (full-width / floating / attached / winged notch) ──
                UiText {
                    text: "BAR STYLE"
                    color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
                }
                Row {
                    id: barStyleRow
                    width: parent.width
                    spacing: 4
                    readonly property var opts: [
                        { label: "Full",  mode: "full"  },
                        { label: "Fit",   mode: "fit"   },
                        { label: "Dock",  mode: "dock"  },
                        { label: "Notch", mode: "notch" }
                    ]
                    Repeater {
                        model: barStyleRow.opts
                        delegate: Shared.BarStylePreview {
                            required property var modelData
                            theme: ctrlPanel.root
                            width: (barStyleRow.width - barStyleRow.spacing * 3) / 4
                            mode: modelData.mode
                            label: modelData.label
                            selected: ctrlPanel.root.barShellStyle === modelData.mode
                            frost: ctrlPanel.root.barFrost
                            outline: ctrlPanel.root.barBorderEnabled
                            onChosen: ctrlPanel.root.barShellStyle = modelData.mode
                        }
                    }
                }
                Tile {
                    width: parent.width
                    label: "Frost"
                    active: ctrlPanel.root.barFrost
                    onActivated: ctrlPanel.root.barFrost = !ctrlPanel.root.barFrost
                }
                Tile {
                    width: parent.width
                    label: "Bar Border"
                    active: ctrlPanel.root.barBorderEnabled
                    onActivated: ctrlPanel.root.barBorderEnabled = !ctrlPanel.root.barBorderEnabled
                }
                Tile {
                    width: parent.width
                    label: "Panel & Tooltip Border"
                    active: ctrlPanel.root.panelTooltipBorderEnabled
                    onActivated: ctrlPanel.root.panelTooltipBorderEnabled = !ctrlPanel.root.panelTooltipBorderEnabled
                }

                Rectangle { width: parent.width; height: 1; color: ctrlPanel.root.sep }

                // ── POSITION (bar on top or bottom edge) ──
                UiText {
                    text: "POSITION"
                    color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
                }
                Row {
                    width: parent.width; spacing: 4
                    Tile { width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Top";    active: ctrlPanel.root.barPosition === "top";    onActivated: ctrlPanel.root.barPosition = "top" }
                    Tile { width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Bottom"; active: ctrlPanel.root.barPosition === "bottom"; onActivated: ctrlPanel.root.barPosition = "bottom" }
                }
                Row {
                    width: parent.width; spacing: 4
                    Tile { width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Left"; active: ctrlPanel.root.barPosition === "left"; onActivated: ctrlPanel.root.barPosition = "left" }
                    Tile { width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Right"; active: ctrlPanel.root.barPosition === "right"; onActivated: ctrlPanel.root.barPosition = "right" }
                }

                Rectangle { width: parent.width; height: 1; color: ctrlPanel.root.sep }

                // ── LOGO (launcher text/icon variant) ──
                UiText {
                    text: "LOGO"
                    color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
                }
                Row {
                    width: parent.width
                    spacing: 4
                    Tile {
                        width: ctrlPanel.root.evenW((wwCol.width - 4) / 2)
                        label: ctrlPanel.root.launcherLogoLabel(ctrlPanel.root.launcherLogoText)
                        active: ctrlPanel.root.launcherLogoMode === "text"
                        onActivated: {
                            if (ctrlPanel.root.launcherLogoMode === "text") ctrlPanel.root.nextLauncherLogoText()
                            else ctrlPanel.root.launcherLogoMode = "text"
                        }
                    }
                    Tile {
                        width: ctrlPanel.root.evenW((wwCol.width - 4) / 2)
                        label: ctrlPanel.root.launcherLogoLabel(ctrlPanel.root.launcherLogoIcon)
                        active: ctrlPanel.root.launcherLogoMode === "icon"
                        onActivated: {
                            if (ctrlPanel.root.launcherLogoMode === "icon") ctrlPanel.root.nextLauncherLogoIcon()
                            else ctrlPanel.root.launcherLogoMode = "icon"
                        }
                    }
                }
            }
        }
    }
}
