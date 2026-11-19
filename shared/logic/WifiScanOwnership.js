.pragma library

// Participating NetworkManagerAdapter instances share one temporary scanner
// request per exact device object. Quickshell exposes only a writable bool, so
// this is cooperative ownership among these adapters, not a token for every
// possible native or external writer.
var deviceRequests = []

function findDeviceRequest(device) {
    for (var i = 0; i < deviceRequests.length; i++) {
        if (deviceRequests[i].device === device)
            return i
    }
    return -1
}

function acquire(device, owner) {
    if (!device || !owner)
        return false

    var index = findDeviceRequest(device)
    if (index < 0) {
        deviceRequests.push({
            device: device,
            baselineEnabled: device.scannerEnabled === true,
            owners: []
        })
        index = deviceRequests.length - 1
    }

    var owners = deviceRequests[index].owners
    if (owners.indexOf(owner) < 0)
        owners.push(owner)

    if (device.scannerEnabled !== true)
        device.scannerEnabled = true
    return true
}

function release(device, owner) {
    if (!device || !owner)
        return false

    var index = findDeviceRequest(device)
    if (index < 0)
        return false

    var request = deviceRequests[index]
    var ownerIndex = request.owners.indexOf(owner)
    if (ownerIndex < 0)
        return false

    request.owners.splice(ownerIndex, 1)
    if (request.owners.length > 0)
        return true

    // Remove the shared record before restoring the initial external baseline.
    deviceRequests.splice(index, 1)
    if (device.scannerEnabled !== request.baselineEnabled)
        device.scannerEnabled = request.baselineEnabled
    return true
}
