pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../modules"

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

    readonly property int barBottom: 35
    readonly property int gap: 8

    // power sub-menu starts CLOSED — no destructive tile is ever pre-shown
    property bool powerOpen: false
    property bool wsOpen: false   // Workspaces collapsible inside the WW fly-out
    property bool compactOpen: false
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
    onRevealChanged: if (reveal < 0.01) { powerOpen = false; wsOpen = false; compactOpen = false; ctrlPanel.root.splitsSubVisible = false; ctrlPanel.root.wwSubVisible = false }  // reset when closed
    WlrLayershell.keyboardFocus: ctrlPanel.root.controlVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── reusable tile: neutral by default, highlights only on hover ──
    component Tile: Rectangle {
        id: tile
        property string label
        property color accent: ctrlPanel.root.seal
        property bool active: false
        signal activated()
        height: 25
        radius: ctrlPanel.root.tileRadius
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

    component CompactToggle: Item {
        id: compactToggle
        property string label
        property bool active: false
        signal toggled()

        height: 20
        UiText {
            id: toggleText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: parent.active || toggleMa.containsMouse ? ctrlPanel.root.seal : ctrlPanel.root.ink
            font.family: ctrlPanel.root.mono
            font.pixelSize: 11
            font.weight: parent.active ? Font.Medium : Font.Normal
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 16
            radius: 8
            color: parent.active ? ctrlPanel.root.fillActive : toggleMa.containsMouse ? ctrlPanel.root.fillHover : ctrlPanel.root.fillIdle
            border.color: (parent.active || toggleMa.containsMouse) ? ctrlPanel.root.seal : ctrlPanel.root.sep
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                width: 10
                height: 10
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                x: parent.parent.active ? parent.width - width - 3 : 3
                color: parent.parent.active ? ctrlPanel.root.seal : ctrlPanel.root.sumi
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
        MouseArea {
            id: toggleMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.toggled()
        }
    }

    MouseArea { anchors.fill: parent; onClicked: ctrlPanel.root.controlVisible = false }

    Rectangle {
        id: card
        width: 240
        height: col.implicitHeight + 24
        radius: ctrlPanel.reveal > 0.001 ? ctrlPanel.root.pillRadius : 0
        color: ctrlPanel.root.bg
        border.color: ctrlPanel.root.pillBorder
        border.width: ctrlPanel.root.pillBorderW
        PillShadow { theme: ctrlPanel.root }

        x: Math.round(Math.max(6, Math.min(ctrlPanel.root.launcherBarX - width / 2, parent.width - width - 6)))
        y: ctrlPanel.root.barPosition === "bottom" ? (parent.height - ctrlPanel.barBottom - ctrlPanel.gap - height) : (ctrlPanel.barBottom + ctrlPanel.gap)
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
                    active: ctrlPanel.root.variantHost ? ctrlPanel.root.variantHost.runningVariant === "v1" : true
                    enabled: ctrlPanel.root.variantHost ? !ctrlPanel.root.variantHost.switching && ctrlPanel.root.variantHost.runningVariant !== "v1" : false
                    opacity: active ? 1.0 : (enabled ? 1.0 : 0.4)
                    onActivated: ctrlPanel.switchBar("v1")
                }
                Tile {
                    width: ctrlPanel.root.evenW((col.width - 12) / 3)
                    label: "V2"
                    active: ctrlPanel.root.variantHost ? ctrlPanel.root.variantHost.runningVariant === "v2" : false
                    enabled: ctrlPanel.root.variantHost ? !ctrlPanel.root.variantHost.switching && ctrlPanel.root.variantHost.runningVariant !== "v2" : true
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
                        radius: ctrlPanel.root.tileRadius
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

            // ── SPLITS (opens the fly-out sub-panel) ──
            UiText {
                text: "SPLITS"
                color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Tile {
                width: parent.width
                label: ctrlPanel.root.splitsSubVisible ? "Splits  ◂" : "Splits  ▸"
                active: ctrlPanel.root.splitsSubVisible
                accent: ctrlPanel.root.seal
                onActivated: ctrlPanel.root.splitsSubVisible = !ctrlPanel.root.splitsSubVisible
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
                        height: 25; radius: ctrlPanel.root.tileRadius
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

    // ── SPLITS sub-panel (fly-out right of the ControlPanel) ──
    Rectangle {
        id: splitCard
        visible: ctrlPanel.root.controlVisible && ctrlPanel.root.splitsSubVisible
        width: 248
        height: splitCol.implicitHeight + 24
        radius: (ctrlPanel.root.controlVisible && ctrlPanel.root.splitsSubVisible) ? ctrlPanel.root.pillRadius : 0
        color: ctrlPanel.root.bg
        border.color: ctrlPanel.root.pillBorder
        border.width: ctrlPanel.root.pillBorderW
        PillShadow { theme: ctrlPanel.root }
        // open to the right of the card, or to the left if there's no room
        x: (card.x + card.width + ctrlPanel.gap + width <= parent.width - 6)
           ? card.x + card.width + ctrlPanel.gap
           : card.x - ctrlPanel.gap - width
        // bottom mode → bottom-align so a tall flyout grows UP, not into the bar
        y: ctrlPanel.root.barPosition === "bottom" ? (card.y + card.height - height) : card.y
        opacity: ctrlPanel.reveal

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: splitCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            UiText {
                text: "SPLITS"
                color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Tile { width: parent.width; label: "Split all";      accent: ctrlPanel.root.seal;   onActivated: { if (ctrlPanel.root.fnSplitAll) ctrlPanel.root.fnSplitAll() } }
            Tile { width: parent.width; label: "Merge all";                            onActivated: { if (ctrlPanel.root.fnMergeAll) ctrlPanel.root.fnMergeAll() } }
            Tile { width: parent.width; label: "Protect layout"; active: ctrlPanel.root.layoutProtected; onActivated: { ctrlPanel.root.layoutProtected = !ctrlPanel.root.layoutProtected; ctrlPanel.root.barUnlocked = false } }
            Tile { width: parent.width; label: "Edit slots"; onActivated: { ctrlPanel.root.controlVisible = false; ctrlPanel.root.barUnlocked = true } }
            Tile { width: parent.width; label: "Default layout"; accent: ctrlPanel.root.seal;   onActivated: { if (ctrlPanel.root.fnDefaultLayout) ctrlPanel.root.fnDefaultLayout() } }

            Rectangle { width: parent.width; height: 1; color: ctrlPanel.root.sep }
            UiText {
                text: "GAP ANIM"
                color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Row {
                id: animRow
                width: parent.width
                spacing: 4
                // every tile cycles base → "<label> 2" (alt mode) → off
                readonly property var opts: [
                    { label: "Stream", mode: 1, alt: 5 },
                    { label: "Surge",  mode: 2, alt: 6 },
                    { label: "Bolt",   mode: 3, alt: 4 }
                ]
                Repeater {
                    model: animRow.opts
                    delegate: Rectangle {
                        id: animTile
                        required property var modelData
                        readonly property bool on:      ctrlPanel.root.barAnim === modelData.mode || ctrlPanel.root.barAnim === modelData.alt
                        readonly property bool hovered: animMa.containsMouse
                        width: ctrlPanel.root.evenW((animRow.width - animRow.spacing * (animRow.opts.length - 1)) / animRow.opts.length)
                        height: 25; radius: ctrlPanel.root.tileRadius
                        color: on ? ctrlPanel.root.fillActive : hovered ? ctrlPanel.root.fillHover : ctrlPanel.root.fillIdle
                        border.color: (on || hovered) ? ctrlPanel.root.seal : ctrlPanel.root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        UiText {
                            anchors.centerIn: parent
                            text: ctrlPanel.root.barAnim === animTile.modelData.alt ? animTile.modelData.label + " 2"
                                                                          : animTile.modelData.label
                            color: (animTile.on || animTile.hovered) ? ctrlPanel.root.seal : ctrlPanel.root.ink
                            font.family: ctrlPanel.root.mono; font.pixelSize: 11
                            font.weight: animTile.on ? Font.Medium : Font.Normal
                        }
                        MouseArea {
                            id: animMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var n = ctrlPanel.root.barAnim                           // base → alt → off
                                ctrlPanel.root.barAnim = (n === animTile.modelData.mode ? animTile.modelData.alt
                                              : n === animTile.modelData.alt  ? 0
                                              : animTile.modelData.mode)
                            }
                        }
                    }
                }
            }
            Tile {
                width: parent.width
                // Separate event-reactor mode; not part of the Surge 1→2 cycle.
                label: "Reactor"
                active: ctrlPanel.root.barAnim === 7
                onActivated: ctrlPanel.root.barAnim = ctrlPanel.root.barAnim === 7 ? 0 : 7
            }
            Tile {
                width: parent.width
                label: "Quotes"
                active: ctrlPanel.root.barAnim === 8
                onActivated: ctrlPanel.root.barAnim = ctrlPanel.root.barAnim === 8 ? 0 : 8
            }
        }
    }

    // ── WIDGETS & WORKSPACES sub-panel (fly-out; stacks below SPLITS if both open) ──
    Rectangle {
        id: wwCard
        visible: ctrlPanel.root.controlVisible && ctrlPanel.root.wwSubVisible
        width: 248
        height: wwCol.implicitHeight + 24
        radius: (ctrlPanel.root.controlVisible && ctrlPanel.root.wwSubVisible) ? ctrlPanel.root.pillRadius : 0
        color: ctrlPanel.root.bg
        border.color: ctrlPanel.root.pillBorder
        border.width: ctrlPanel.root.pillBorderW
        PillShadow { theme: ctrlPanel.root }
        // same side as splitCard; if SPLITS is also open, stack below it
        x: (card.x + card.width + ctrlPanel.gap + width <= parent.width - 6)
           ? card.x + card.width + ctrlPanel.gap
           : card.x - ctrlPanel.gap - width
        y: (ctrlPanel.root.controlVisible && ctrlPanel.root.splitsSubVisible)
           ? (ctrlPanel.root.barPosition === "bottom" ? splitCard.y - ctrlPanel.gap - height
                                            : splitCard.y + splitCard.height + ctrlPanel.gap)
           : (ctrlPanel.root.barPosition === "bottom" ? card.y + card.height - height : card.y)
        opacity: ctrlPanel.reveal

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: wwCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── WIDGETS toggle grid (moved here from the main card) ──
            UiText {
                text: "WIDGETS"
                color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Memory";      active: ctrlPanel.root.modMemory;    onActivated: ctrlPanel.root.modMemory = !ctrlPanel.root.modMemory }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Brightness";  visible: ctrlPanel.root.hasBacklight; active: ctrlPanel.root.modBrightness; onActivated: ctrlPanel.root.modBrightness = !ctrlPanel.root.modBrightness }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "AI usage";    active: ctrlPanel.root.modClaude;    onActivated: ctrlPanel.root.modClaude = !ctrlPanel.root.modClaude }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Power Prof."; active: ctrlPanel.root.modPower;     onActivated: ctrlPanel.root.modPower = !ctrlPanel.root.modPower }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Bluetooth";   active: ctrlPanel.root.modBluetooth; onActivated: ctrlPanel.root.modBluetooth = !ctrlPanel.root.modBluetooth }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Network";     active: ctrlPanel.root.modNetwork; enabled: ctrlPanel.root.networkMode !== "wifi"; onActivated: ctrlPanel.root.modNetwork = !ctrlPanel.root.modNetwork }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "NordVPN";    active: ctrlPanel.root.modNordVpn; onActivated: ctrlPanel.root.modNordVpn = !ctrlPanel.root.modNordVpn }
                Tile { objectName: "wallpaper-widget-toggle"; width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Wallpapers"; active: ctrlPanel.root.modWallpapers; onActivated: ctrlPanel.root.modWallpapers = !ctrlPanel.root.modWallpapers }
                Tile { objectName: "display-manager-widget-toggle"; width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Display Manager"; active: ctrlPanel.root.modDisplayManager; onActivated: ctrlPanel.root.modDisplayManager = !ctrlPanel.root.modDisplayManager }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Quick tools"; active: ctrlPanel.root.modQuick;   onActivated: ctrlPanel.root.modQuick = !ctrlPanel.root.modQuick }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Status";      active: ctrlPanel.root.modStatus;  onActivated: ctrlPanel.root.modStatus = !ctrlPanel.root.modStatus }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "CPU";         active: ctrlPanel.root.modCpu;     onActivated: ctrlPanel.root.modCpu = !ctrlPanel.root.modCpu }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "GPU";         active: ctrlPanel.root.modGpu;     onActivated: ctrlPanel.root.modGpu = !ctrlPanel.root.modGpu }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Volume";      active: ctrlPanel.root.modVolume;  onActivated: ctrlPanel.root.modVolume = !ctrlPanel.root.modVolume }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Now playing"; active: ctrlPanel.root.modMpris;   onActivated: ctrlPanel.root.modMpris = !ctrlPanel.root.modMpris }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Battery";     visible: ctrlPanel.root.hasBattery; active: true; enabled: false }
            }

            Rectangle { width: parent.width; height: 1; color: ctrlPanel.root.sep }

            Tile {
                width: parent.width
                label: ctrlPanel.compactOpen ? "Compact Display  ▾" : "Compact Display  ▸"
                active: ctrlPanel.compactOpen
                onActivated: ctrlPanel.compactOpen = !ctrlPanel.compactOpen
            }
            Grid {
                visible: ctrlPanel.compactOpen
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 6
                CompactToggle { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Network";    active: ctrlPanel.root.compactNetwork;    onToggled: ctrlPanel.root.compactNetwork = !ctrlPanel.root.compactNetwork }
                CompactToggle { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Battery";    visible: ctrlPanel.root.hasBattery; active: ctrlPanel.root.compactBattery;    onToggled: ctrlPanel.root.compactBattery = !ctrlPanel.root.compactBattery }
                CompactToggle { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Brightness"; visible: ctrlPanel.root.hasBacklight; active: ctrlPanel.root.compactBrightness; onToggled: ctrlPanel.root.compactBrightness = !ctrlPanel.root.compactBrightness }
                CompactToggle { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Bluetooth";  active: ctrlPanel.root.compactBluetooth;  onToggled: ctrlPanel.root.compactBluetooth = !ctrlPanel.root.compactBluetooth }
                CompactToggle { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Power";      active: ctrlPanel.root.compactPower;      onToggled: ctrlPanel.root.compactPower = !ctrlPanel.root.compactPower }
                CompactToggle { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "CPU";        active: ctrlPanel.root.compactCpu;        onToggled: ctrlPanel.root.compactCpu = !ctrlPanel.root.compactCpu }
                CompactToggle { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "GPU";        active: ctrlPanel.root.compactGpu;        onToggled: ctrlPanel.root.compactGpu = !ctrlPanel.root.compactGpu }
                CompactToggle { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Memory";     active: ctrlPanel.root.compactMemory;     onToggled: ctrlPanel.root.compactMemory = !ctrlPanel.root.compactMemory }
                CompactToggle { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Volume";     active: ctrlPanel.root.compactVolume;     onToggled: ctrlPanel.root.compactVolume = !ctrlPanel.root.compactVolume }
                CompactToggle { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "Now playing"; active: ctrlPanel.root.compactMpris;      onToggled: ctrlPanel.root.compactMpris = !ctrlPanel.root.compactMpris }
                CompactToggle { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "NordVPN"; active: ctrlPanel.root.compactNordVpn; onToggled: ctrlPanel.root.compactNordVpn = !ctrlPanel.root.compactNordVpn }
                CompactToggle { width: ctrlPanel.root.evenW((wwCol.width - 8) / 2); label: "AI usage"; active: ctrlPanel.root.compactAi; onToggled: ctrlPanel.root.compactAi = !ctrlPanel.root.compactAi }
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
                            height: 25; radius: ctrlPanel.root.tileRadius
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

                // display style: default / numbers / magic
                Row {
                    id: wsStyleRow
                    width: parent.width
                    spacing: 4
                    readonly property var opts: [
                        { label: "Default", mode: "default" },
                        { label: "Numbers", mode: "numbers" },
                        { label: "Magic",   mode: "magic"   }
                    ]
                    Repeater {
                        model: wsStyleRow.opts
                        delegate: Rectangle {
                            id: wssTile
                            required property var modelData
                            readonly property bool on:      ctrlPanel.root.workspaceStyle === modelData.mode
                            readonly property bool hovered: wssMa.containsMouse
                            width: ctrlPanel.root.evenW((wsStyleRow.width - wsStyleRow.spacing * (wsStyleRow.opts.length - 1)) / wsStyleRow.opts.length)
                            height: 25; radius: ctrlPanel.root.tileRadius
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

            // ── STYLE (bar pill style; paint-only, width-invariant) ──
            UiText {
                text: "STYLE"
                color: ctrlPanel.root.sumiHi; font.family: ctrlPanel.root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Row {
                width: parent.width; spacing: 4
                // independent toggles: each highlights when ON, click flips it (Border+Frost+Shadow combinable)
                BarStylePreview { width: (wwCol.width - 8) / 3; theme: ctrlPanel.root; mode: "islands"; label: "Border"; selected: ctrlPanel.root.styleBorder; outline: ctrlPanel.root.styleBorder; onChosen: ctrlPanel.root.styleBorder = !ctrlPanel.root.styleBorder }
                BarStylePreview { width: (wwCol.width - 8) / 3; theme: ctrlPanel.root; mode: "islands"; label: "Frost"; selected: ctrlPanel.root.styleFrost; frost: ctrlPanel.root.styleFrost; onChosen: ctrlPanel.root.styleFrost = !ctrlPanel.root.styleFrost }
                BarStylePreview { width: (wwCol.width - 8) / 3; theme: ctrlPanel.root; mode: "islands"; label: "Shadow"; selected: ctrlPanel.root.styleShadow; shadow: ctrlPanel.root.styleShadow; onChosen: ctrlPanel.root.styleShadow = !ctrlPanel.root.styleShadow }
            }
            Row {
                width: parent.width; spacing: 4
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Radius 12"; active: !ctrlPanel.root.styleRadiusSmall; onActivated: ctrlPanel.root.styleRadiusSmall = false }
                Tile { width: ctrlPanel.root.evenW((wwCol.width - 4) / 2); label: "Radius 6";  active: ctrlPanel.root.styleRadiusSmall;  onActivated: ctrlPanel.root.styleRadiusSmall = true }
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
    SidePanelPositioner { root: ctrlPanel.root; target: card; anchorName: "launcher" }
}
