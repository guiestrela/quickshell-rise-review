// Shared behavior; owner is the active variant, environment supplies QML services.
.pragma library

function registerBarLayoutController(riseOwner, riseEnvironment, screenName, controller) {
    var riseState = riseOwner;

        if (!screenName || !controller) return

        var next = {}
        for (var screen in riseState.barLayoutControllers) next[screen] = riseState.barLayoutControllers[screen]
        next[screenName] = controller
        riseState.barLayoutControllers = next
    }

function unregisterBarLayoutController(riseOwner, riseEnvironment, screenName, controller) {
    var riseState = riseOwner;

        if (!screenName) return
        if (controller && riseState.barLayoutControllers[screenName] !== controller) return

        var next = {}
        for (var screen in riseState.barLayoutControllers) {
            if (screen !== screenName) next[screen] = riseState.barLayoutControllers[screen]
        }
        riseState.barLayoutControllers = next
    }

function applyToBarLayoutControllers(riseOwner, riseEnvironment, actionName) {
    var riseState = riseOwner;

        var keys = riseState.barLayoutControllerKeys()

        riseState._barLayoutSyncing = true
        try {
            for (var i = 0; i < keys.length; i++) {
                var controller = riseState.barLayoutControllers[keys[i]]
                if (controller && controller[actionName]) controller[actionName]()
            }
        } finally {
            riseState._barLayoutSyncing = false
        }
    }

function syncBarOrder(riseOwner, riseEnvironment, sourceScreenName, serialized) {
    var riseState = riseOwner;

        if (riseState._barLayoutSyncing || !serialized) return

        riseState._barLayoutSyncing = true
        try {
            var keys = riseState.barLayoutControllerKeys()
            for (var i = 0; i < keys.length; i++) {
                if (keys[i] === sourceScreenName) continue
                var controller = riseState.barLayoutControllers[keys[i]]
                if (controller && controller.applyOrder) controller.applyOrder(serialized)
            }
        } finally {
            riseState._barLayoutSyncing = false
        }
    }

function activatePopupScreen(riseOwner, riseEnvironment, screen) {
    var riseState = riseOwner;

        if (!screen || screen.name === "") return

        riseState.activePopupScreen = screen
        riseState.activePopupScreenName = screen.name
        riseState.applyActiveBarAnchors()
    }

function activateFocusedPopupScreen(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var monitor = riseEnvironment.Hyprland.focusedMonitor
        var targetName = monitor ? monitor.name : ""

        for (var i = 0; i < riseEnvironment.Quickshell.screens.length; i++) {
            var candidate = riseEnvironment.Quickshell.screens[i]
            if (candidate.name === targetName
                    && candidate.width > 0
                    && candidate.height > 0) {
                riseState.activatePopupScreen(candidate)
                return true
            }
        }

        if (riseState.activePopupScreenName !== "") return true

        for (var j = 0; j < riseEnvironment.Quickshell.screens.length; j++) {
            var fallback = riseEnvironment.Quickshell.screens[j]
            if (fallback.name !== ""
                    && fallback.width > 0
                    && fallback.height > 0) {
                riseState.activatePopupScreen(fallback)
                return true
            }
        }

        return false
    }

function activatePopupScreenByName(riseOwner, riseEnvironment, screenName) {
    var riseState = riseOwner;

        if (screenName) {
            for (var i = 0; i < riseEnvironment.Quickshell.screens.length; i++) {
                var candidate = riseEnvironment.Quickshell.screens[i]
                if (candidate.name === screenName
                        && candidate.width > 0
                        && candidate.height > 0) {
                    riseState.activatePopupScreen(candidate)
                    return true
                }
            }
        }

        return riseState.activateFocusedPopupScreen()
    }

function isActivePopupScreenName(riseOwner, riseEnvironment, screenName) {
    var riseState = riseOwner;

        return riseState.activePopupScreenName !== "" && screenName === riseState.activePopupScreenName
    }

function applyActiveBarAnchors(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var anchors = riseState.activePopupScreenName ? riseState.barAnchorsByScreen[riseState.activePopupScreenName] : null
        if (!anchors) return

        for (var name in anchors) riseState.applyAnchor(name, anchors[name])
    }

function publishBarAnchors(riseOwner, riseEnvironment, screenName, anchors) {
    var riseState = riseOwner;

        if (!screenName || !anchors) return

        var next = {}
        for (var screen in riseState.barAnchorsByScreen) next[screen] = riseState.barAnchorsByScreen[screen]
        next[screenName] = anchors
        riseState.barAnchorsByScreen = next

        if (screenName === riseState.activePopupScreenName) riseState.applyActiveBarAnchors()
    }

function setPanelAnchor(riseOwner, riseEnvironment, name, x, screenName) {
    var riseState = riseOwner;

        var targetScreen = screenName || riseState.activePopupScreenName
        if (targetScreen) {
            var next = {}
            for (var screen in riseState.barAnchorsByScreen) next[screen] = riseState.barAnchorsByScreen[screen]

            var current = next[targetScreen] || {}
            var anchors = {}
            for (var key in current) anchors[key] = current[key]
            anchors[name] = x
            next[targetScreen] = anchors
            riseState.barAnchorsByScreen = next
        }

        if (!targetScreen || targetScreen === riseState.activePopupScreenName) riseState.applyAnchor(name, x)
    }

function showTooltip(riseOwner, riseEnvironment, text, x, topY, bottomY, owner) {
    var riseState = riseOwner;

        if (!text) return;
        riseState.tooltipText = text;
        riseState.tooltipX = x;
        riseState.tooltipTopY = topY;
        riseState.tooltipBottomY = bottomY;
        riseState.tooltipY = (topY + bottomY) / 2;
        riseState.tooltipOwner = owner !== undefined ? owner : null;
        riseState.tooltipShown = true;
    }

function hideTooltip(riseOwner, riseEnvironment, owner) {
    var riseState = riseOwner;

        if (owner === undefined || owner === null) {
            riseState.tooltipShown = false; riseState.tooltipOwner = null;
        } else if (typeof owner === "object") {
            if (riseState.tooltipOwner === owner) { riseState.tooltipShown = false; riseState.tooltipOwner = null; }
        } else if (riseState.tooltipText === owner) {
            riseState.tooltipShown = false; riseState.tooltipOwner = null;
        }
    }

function openCalendar(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        riseState.calendarMonthOffset = 0;
        riseState.calendarTick++;
        riseState.selectedDay = (new Date()).getDate();
        riseState.calendarVisible = true;
    }

function toggleDisplayManager(riseOwner, riseEnvironment, screen, anchorItem) {
    var riseState = riseOwner;

        if (!screen || !screen.name) return
        riseState.activatePopupScreen(screen)
        var point = anchorItem ? anchorItem.mapToItem(null, anchorItem.width / 2, anchorItem.height) : null
        riseState.displayManagerBarX = point ? point.x : screen.width / 2
        riseState.displayManagerBarY = point ? Math.max(0, point.y) : 35
        var next = !riseState.displayManagerVisible
        if (next) riseState.closePopups("displayManagerVisible")
        riseState.displayManagerVisible = next
    }

function verticalAnchorY(riseOwner, riseEnvironment, name) {
    var riseState = riseOwner;

        var map = riseState.verticalAnchorsByScreen[riseState.activePopupScreenName] || {}
        return map[name] !== undefined ? map[name] : (riseState.activePopupScreen ? riseState.activePopupScreen.height / 2 : 200)
    }

function publishVerticalAnchors(riseOwner, riseEnvironment, screenName, values) {
    var riseState = riseOwner;

        var next = Object.assign({}, riseState.verticalAnchorsByScreen)
        next[screenName] = values
        riseState.verticalAnchorsByScreen = next
    }
