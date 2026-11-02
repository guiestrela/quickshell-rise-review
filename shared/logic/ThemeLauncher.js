// Shared behavior; owner is the active variant, environment supplies QML services.
.pragma library

function launcherLogoTextIndex(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        for (var i = 0; i < riseState.launcherLogoTextOptions.length; i++)
            if (riseState.launcherLogoTextOptions[i] === id) return i
        return 0
    }

function launcherLogoIconIndex(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        for (var i = 0; i < riseState.launcherLogoIconOptions.length; i++)
            if (riseState.launcherLogoIconOptions[i] === id) return i
        return 0
    }

function launcherLogoTextValid(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        return riseState.launcherLogoTextIndex(id) >= 0 && riseState.launcherLogoTextOptions[riseState.launcherLogoTextIndex(id)] === id
    }

function launcherLogoIconValid(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        return riseState.launcherLogoIconIndex(id) >= 0 && riseState.launcherLogoIconOptions[riseState.launcherLogoIconIndex(id)] === id
    }

function nextLauncherLogoText(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        riseState.launcherLogoText = riseState.launcherLogoTextOptions[(riseState.launcherLogoTextIndex(riseState.launcherLogoText) + 1) % riseState.launcherLogoTextOptions.length]
    }

function nextLauncherLogoIcon(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        riseState.launcherLogoIcon = riseState.launcherLogoIconOptions[(riseState.launcherLogoIconIndex(riseState.launcherLogoIcon) + 1) % riseState.launcherLogoIconOptions.length]
    }

function launcherConfigValue(riseOwner, riseEnvironment, config, a, b, c) {
    var riseState = riseOwner;

        if (!config) return undefined
        if (config[a] !== undefined) return config[a]
        if (b && config[b] !== undefined) return config[b]
        if (c && config[c] !== undefined) return config[c]
        return undefined
    }

function applyLauncherConfig(riseOwner, riseEnvironment, config) {
    var riseState = riseOwner;

        if (!config) return

        var launcher = config.launcher || config.logo || config
        var mode = riseState.launcherConfigValue(launcher, "launcherLogoMode", "logoMode", "mode")
        var text = riseState.launcherConfigValue(launcher, "launcherLogoText", "textLogo", "text")
        var icon = riseState.launcherConfigValue(launcher, "launcherLogoIcon", "iconLogo", "icon")

        if (mode === "text" || mode === "icon") riseState.launcherLogoMode = mode
        if (text !== undefined && riseState.launcherLogoTextValid(text)) riseState.launcherLogoText = text
        if (icon !== undefined && riseState.launcherLogoIconValid(icon)) riseState.launcherLogoIcon = icon
    }

function launcherLogoLabel(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        if (id === "omarchy") return "Omarchy"
        if (id === "hyprland") return "Hyprland"
        if (id === "arch") return "Arch"
        if (id === "omacom") return "Omacom"
        if (id === "grid") return "Grid"
        if (id === "spark") return "Spark"
        if (id === "power") return "Power"
        if (id === "dragon") return "Dragon"
        if (id === "mark") return "Mark"
        if (id === "nix") return "Nix"
        if (id === "branch") return "Branch"
        if (id === "rebel") return "Rebel"
        return "Omarchy"
    }

function launcherLogoIconGlyph(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        if (id === "omarchy") return String.fromCodePoint(0xE900)
        if (id === "hyprland") return ""
        if (id === "arch") return ""
        if (id === "grid") return ""
        if (id === "spark") return ""
        if (id === "power") return ""
        if (id === "dragon") return "⻯"
        if (id === "mark") return ""
        if (id === "nix") return ""
        if (id === "branch") return ""
        if (id === "rebel") return ""
        return String.fromCodePoint(0xE900)
    }

function launcherLogoIconSize(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        if (id === "omarchy") return 15
        if (id === "arch") return 17
        if (id === "dragon") return 16
        return 16
    }

function launcherLogoIconXOffset(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        if (id === "omarchy") return 0.5
        if (id === "hyprland") return 0
        if (id === "arch") return 1
        if (id === "grid") return -1
        if (id === "spark") return 0
        if (id === "power") return 0
        if (id === "dragon") return 0
        if (id === "mark") return 0.5
        if (id === "nix") return 0
        if (id === "branch") return 0
        return 0
    }

function launcherLogoIconYOffset(riseOwner, riseEnvironment, id) {
    var riseState = riseOwner;

        if (id === "omarchy") return 0
        if (id === "hyprland") return 0
        if (id === "arch") return 0
        if (id === "mark") return 0.5
        if (id === "branch") return 0
        if (id === "dragon") return 0
        return 0
    }

function ipcApplyLauncher(riseOwner, riseEnvironment, payload) {
    var riseState = riseOwner;

        let p;
        try { p = JSON.parse(payload); }
        catch (e) { console.warn("theme.applyLauncher: bad payload —", e); return; }
        riseOwner.applyLauncherConfig(p);
    }
