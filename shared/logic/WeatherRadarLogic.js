// Common behavior for variant-specific presentations.
.pragma library

function tileY(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var lat = Math.max(-85, Math.min(85, riseState.latitude)) * Math.PI / 180
        return Math.floor((1 - Math.log(Math.tan(lat) + 1 / Math.cos(lat)) / Math.PI) / 2 * Math.pow(2, riseState.tileZoom))
    }

function pixelOffsetX(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var count = Math.pow(2, riseState.tileZoom)
        return ((riseState.longitude + 180) / 360 * count * 256) - riseState.tileX() * 256
    }

function pixelOffsetY(riseOwner, riseEnvironment) {
    var riseState = riseOwner;

        var lat = Math.max(-85, Math.min(85, riseState.latitude)) * Math.PI / 180
        var count = Math.pow(2, riseState.tileZoom)
        var worldY = (1 - Math.log(Math.tan(lat) + 1 / Math.cos(lat)) / Math.PI) / 2 * count * 256
        return worldY - riseState.tileY() * 256
    }

function setZoom(riseOwner, riseEnvironment, value) {
    var riseState = riseOwner;

        riseOwner.zoom = Math.max(riseOwner.minZoom, Math.min(riseOwner.maxZoom, Math.round(value * 4) / 4))
    }
