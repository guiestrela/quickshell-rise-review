pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: rootMod
    required property var root

    implicitWidth: logoContentWidth + logoPadding
    implicitHeight: 28

    readonly property string tooltipText: "Control center"
    readonly property bool logoIconMode: rootMod.root.barVertical === true || rootMod.root.launcherLogoMode === "icon"
    readonly property bool hyprlandLogo: !logoIconMode && rootMod.root.launcherLogoText === "hyprland"
    readonly property bool archTextLogo: !logoIconMode && rootMod.root.launcherLogoText === "arch"
    readonly property bool omacomTextLogo: !logoIconMode && rootMod.root.launcherLogoText === "omacom"
    readonly property url logoSource: omacomTextLogo ? Qt.resolvedUrl("../assets/omacom-text.png") : hyprlandLogo ? Qt.resolvedUrl("../assets/bob3.png") : Qt.resolvedUrl("../assets/bob2.png")
    readonly property real logoAspect: omacomTextLogo ? (550 / 112) : archTextLogo ? (86 / 17) : hyprlandLogo ? (948 / 154) : (656 / 192)
    readonly property real logoHeight: logoIconMode ? 18 : hyprlandLogo ? 16 : omacomTextLogo ? 14 : archTextLogo ? 17 : 20
    readonly property real logoPadding: logoIconMode ? 8 : hyprlandLogo ? 10 : omacomTextLogo ? 12 : archTextLogo ? 8 : 12
    readonly property real archWordHeight: 13
    readonly property real archWordLogoWidth: 15
    readonly property real archWordLeftPad: 1
    readonly property real archWordRightPad: 3
    readonly property real archWordGap: 3
    readonly property real archWordJoinGap: 3
    readonly property real archWordArchWidth: Math.round(archWordHeight * 605 / 231)
    readonly property real archWordLinuxWidth: Math.round(archWordHeight * 549 / 230)
    readonly property real archWordmarkWidth: archWordLeftPad + archWordRightPad + archWordLogoWidth + archWordGap + archWordArchWidth + archWordJoinGap + archWordLinuxWidth
    readonly property real logoImageWidth: archTextLogo ? archWordmarkWidth : Math.round(logoHeight * logoAspect)
    readonly property real logoIconSlotWidth: 16
    readonly property real logoContentWidth: logoIconMode ? logoIconSlotWidth : logoImageWidth
    readonly property color archBrandTextColor: rootMod.root.barColorIsAccent ? rootMod.root.sealRaw : rootMod.root.accentHint

    // animated wave phase
    property real phase: 0
    NumberAnimation on phase {
        from: 0; to: 2 * Math.PI
        duration: 2600; loops: Animation.Infinite
        // gate: only animate while hovered or control panel open — otherwise the
        // Canvas repainted 24/7 via onPhaseChanged even when nobody looks
        running: ma.containsMouse || rootMod.root.controlVisible
    }

    // shadow as a SIBLING of the pill (the pill itself clips, for the wave —
    // a shadow child would be clipped away). rootMod doesn't clip, so this shows.
    RectangularShadow {
        anchors.fill: pill
        radius: pill.radius
        visible: rootMod.root.styleShadow
        blur: 8
        spread: 0
        offset: Qt.vector2d(0, rootMod.root.barPosition === "bottom" ? -1 : 1)
        color: rootMod.root.pillShadow
        z: -1
    }

    // ── pill background (same style as other widgets) with the wave inside ──
    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: rootMod.logoContentWidth + rootMod.logoPadding
        height: rootMod.root.pillH
        radius: rootMod.root.pillRadius
        color: rootMod.root.pill
        border.color: rootMod.root.pillBorder
        border.width: rootMod.root.pillBorderW
        clip: true

        Canvas {
            id: wave
            anchors.fill: parent
            // only present while active (hovered or control panel open); fully
            // gone when idle. Fades so it appears/disappears smoothly.
            opacity: (ma.containsMouse || rootMod.root.controlVisible) ? 0.55 : 0
            visible: opacity > 0.001
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var vertical = rootMod.root.barVertical === true
                var length = vertical ? height : width
                var cy = (vertical ? width : height) / 2
                var amp = 3.0
                var k = (2 * Math.PI) / Math.max(1, length) * 2   // two cycles across the width

                function drawWave(phaseOff, alpha) {
                    ctx.beginPath()
                    for (var x = 0; x <= length; x += 2) {
                        var y = cy + Math.sin(x * k + rootMod.phase + phaseOff) * amp
                        var px = vertical ? y : x, py = vertical ? x : y
                        if (x === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py)
                    }
                    ctx.strokeStyle = Qt.rgba(rootMod.root.seal.r, rootMod.root.seal.g, rootMod.root.seal.b, alpha)
                    ctx.lineWidth = 1.5
                    ctx.lineCap = "round"
                    ctx.stroke()
                }

                drawWave(0,       0.45)
                drawWave(Math.PI, 0.22)
            }

            Connections {
                target: rootMod
                function onPhaseChanged() { wave.requestPaint() }
            }
            Connections {
                target: rootMod.root
                function onSealChanged() { wave.requestPaint() }
                function onBarPositionChanged() { wave.requestPaint() }
            }
            Component.onCompleted: requestPaint()
        }
    }

    // ── launcher logo: flat-color tint shader — exact seal color, keeps alpha ──
    Item {
        id: logoStack
        visible: !rootMod.logoIconMode
        anchors.centerIn: parent
        width: rootMod.logoImageWidth
        height: rootMod.logoHeight

        Item {
            id: archBrand
            visible: rootMod.archTextLogo
            anchors.centerIn: parent
            width: parent.width
            height: parent.height

            UiText {
                id: archBrandLogo
                anchors.left: parent.left
                anchors.leftMargin: rootMod.archWordLeftPad
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0.5
                width: rootMod.archWordLogoWidth
                horizontalAlignment: Text.AlignHCenter
                text: ""
                color: rootMod.root.seal
                renderType: Text.QtRendering
                font.family: rootMod.root.mono
                font.pixelSize: 15
            }

            Image {
                id: archBrandArch
                anchors.left: archBrandLogo.right
                anchors.leftMargin: rootMod.archWordGap
                anchors.verticalCenter: parent.verticalCenter
                width: rootMod.archWordArchWidth
                height: rootMod.archWordHeight
                source: Qt.resolvedUrl("../assets/arch-header-arch.png")
                fillMode: Image.PreserveAspectFit
                cache: false
                smooth: true
                mipmap: true
                layer.enabled: visible
                layer.smooth: true
                layer.textureSize: Qt.size(Math.max(1, Math.round(width * 3)), Math.max(1, Math.round(height * 3)))
                layer.effect: ShaderEffect {
                    property color tintColor: rootMod.archBrandTextColor
                    fragmentShader: Qt.resolvedUrl("../shaders/logo-tint.frag.qsb")
                }
            }

            Image {
                anchors.left: archBrandArch.right
                anchors.leftMargin: rootMod.archWordJoinGap
                anchors.verticalCenter: parent.verticalCenter
                width: rootMod.archWordLinuxWidth
                height: rootMod.archWordHeight
                source: Qt.resolvedUrl("../assets/arch-header-linux.png")
                fillMode: Image.PreserveAspectFit
                cache: false
                smooth: true
                mipmap: true
                layer.enabled: visible
                layer.smooth: true
                layer.textureSize: Qt.size(Math.max(1, Math.round(width * 3)), Math.max(1, Math.round(height * 3)))
                layer.effect: ShaderEffect {
                    property color tintColor: rootMod.root.seal
                    fragmentShader: Qt.resolvedUrl("../shaders/logo-tint.frag.qsb")
                }
            }
        }

        Image {
            id: logo
            visible: !rootMod.archTextLogo
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            source: rootMod.logoSource
            fillMode: Image.PreserveAspectFit
            cache: false
            smooth: true
            mipmap: true
            layer.enabled: !rootMod.logoIconMode
            layer.smooth: true
            layer.textureSize: Qt.size(Math.max(1, Math.round(width * 3)), Math.max(1, Math.round(height * 3)))   // supersample → crisp
            layer.effect: ShaderEffect {
                property color tintColor: rootMod.root.seal
                fragmentShader: Qt.resolvedUrl("../shaders/logo-tint.frag.qsb")
            }
        }
    }

    Item {
        id: logoIconSlot
        visible: rootMod.logoIconMode
        anchors.centerIn: parent
        width: rootMod.logoIconSlotWidth
        height: rootMod.root.pillH

        UiText {
            id: logoIcon
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: rootMod.root.launcherLogoIconXOffset(rootMod.root.launcherLogoIcon)
            anchors.verticalCenterOffset: rootMod.root.launcherLogoIconYOffset(rootMod.root.launcherLogoIcon)
            text: rootMod.root.launcherLogoIconGlyph(rootMod.root.launcherLogoIcon)
            color: rootMod.root.seal
            renderType: Text.QtRendering
            font.family: rootMod.root.launcherLogoIconFont(rootMod.root.launcherLogoIcon)
            font.pixelSize: rootMod.root.launcherLogoIconSize(rootMod.root.launcherLogoIcon)
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  { tip.hide() }
        onClicked: {
            tip.hide()
            rootMod.root.controlVisible = !rootMod.root.controlVisible
        }
    }
}
