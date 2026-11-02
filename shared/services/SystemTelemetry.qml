import QtQuick
import Quickshell.Io

Item {
    id: telemetry
    required property var owner
    property bool cpuDetailsInBar: false
    // ── Central system telemetry ──
    // One ShellRoot-level sampler feeds all monitor BarSlots. This replaces
    // per-widget bash/awk polling for CPU and memory, so adding monitors does not
    // multiply these status process chains.
    property var systemCpuHistory: []
    readonly property int systemCpuMaxSamples: 30
    property var gpuHistory: []
    property int systemCpuPercent: 0
    property int systemCpuUserPercent: 0
    property int systemCpuSystemPercent: 0
    property int systemCpuIoWaitPercent: 0
    property real _systemCpuPrevIdle: -1
    property real _systemCpuPrevTotal: -1
    property real _systemCpuPrevUser: -1
    property real _systemCpuPrevSystem: -1
    property real _systemCpuPrevIoWait: -1
    property string cpuModelName: ""
    property int cpuCoreCount: 0
    property int cpuThreadCount: 0
    property int cpuClockMHz: 0
    property int cpuMaxClockMHz: 0
    property string cpuEnergyPreference: ""
    property string cpuScalingGovernor: ""
    property int cpuThrottleCount: 0
    property real systemLoad1: 0
    property real systemLoad5: 0
    property real systemLoad15: 0
    property string kernelRelease: ""
    property var cpuTopProcesses: []

    property int systemMemTotalMiB: 0
    property int systemMemAvailMiB: 0
    property int systemMemFreeMiB: 0
    property int systemMemBuffersMiB: 0
    property int systemMemCachedMiB: 0
    property string memoryType: ""
    property int memorySpeedMTs: 0
    readonly property int systemMemUsedMiB: Math.max(0, systemMemTotalMiB - systemMemAvailMiB)
    readonly property int systemMemPercent: systemMemTotalMiB > 0
        ? Math.max(0, Math.min(100, Math.round(systemMemUsedMiB / systemMemTotalMiB * 100)))
        : 0
    readonly property real systemMemUsedGiB: systemMemUsedMiB / 1024
    readonly property real systemMemTotalGiB: systemMemTotalMiB / 1024

    // Compact V2 telemetry. These samplers live on the singleton Theme so a
    // second monitor adds another view, not another nvidia-smi/df/hwmon poller.
    property string gpuBackend: ""
    property string gpuName: ""
    property string gpuDriverVersion: ""
    property int gpuPercent: 0
    property int gpuTemperatureC: 0
    property int gpuMemoryUsedMiB: 0
    property int gpuMemoryTotalMiB: 0
    property int gpuClockMHz: 0
    property real gpuPowerW: 0
    property real gpuPowerLimitW: 0
    property string gpuPerformanceState: ""
    property int gpuFanPercent: 0
    property int gpuFanRpm: -1
    readonly property bool gpuAvailable: gpuBackend !== ""

    property int cpuTemperatureC: 0
    property int cpuCoreMaxTemperatureC: 0
    property int cpuTemperatureMaxC: 0
    property int cpuTemperatureCriticalC: 0
    property int nvmeTemperatureC: 0
    property int nvmeTemperatureMaxC: 0
    property int nvmeTemperatureCriticalC: 0
    property int memoryTemperatureC: 0
    readonly property bool cpuTemperatureAvailable: cpuTemperatureC > 0

    property string barTemperatureSource: "cpu"
    readonly property int barTemperatureC: barTemperatureSource === "core" ? cpuCoreMaxTemperatureC
        : barTemperatureSource === "gpu" ? gpuTemperatureC
        : barTemperatureSource === "nvme" ? nvmeTemperatureC
        : barTemperatureSource === "memory" ? memoryTemperatureC
        : cpuTemperatureC
    readonly property bool barTemperatureAvailable: barTemperatureC > 0

    function barTemperatureSourceValid(source) {
        return source === "cpu" || source === "core" || source === "gpu"
            || source === "nvme" || source === "memory"
    }
    function barTemperatureSourceLabel(source) {
        if (source === "core") return "Hottest CPU core"
        if (source === "gpu") return "GPU"
        if (source === "nvme") return "NVMe"
        if (source === "memory") return "Memory"
        return "CPU package"
    }
    function barTemperatureSourceAvailable(source) {
        if (source === "core") return cpuCoreMaxTemperatureC > 0
        if (source === "gpu") return gpuTemperatureC > 0
        if (source === "nvme") return nvmeTemperatureC > 0
        if (source === "memory") return memoryTemperatureC > 0
        return cpuTemperatureC > 0
    }

    property int storagePercent: 0
    property real storageUsedBytes: 0
    property real storageTotalBytes: 0
    property bool storageAvailable: false
    readonly property real storageUsedGiB: storageUsedBytes / 1073741824
    readonly property real storageTotalGiB: storageTotalBytes / 1073741824
    property var storageDrives: []
    property bool storageInventoryAvailable: false

    function parseSystemCpu(text) {
        var lines = String(text || "").split("\n")
        if (lines.length === 0 || lines[0].indexOf("cpu ") !== 0) return
        var parts = lines[0].trim().split(/\s+/)
        if (parts.length < 8) return

        function field(index) {
            var value = parseFloat(parts[index])
            return isNaN(value) ? 0 : value
        }
        var user = field(1) + field(2)
        var system = field(3) + field(6) + field(7) + field(8)
        var ioWait = field(5)
        var idle = field(4) + ioWait
        var total = 0
        for (var i = 1; i < parts.length; i++) {
            var v = parseFloat(parts[i])
            if (!isNaN(v)) total += v
        }
        if (isNaN(idle) || isNaN(total) || total <= 0) return

        if (_systemCpuPrevTotal >= 0 && total > _systemCpuPrevTotal) {
            var totalDelta = total - _systemCpuPrevTotal
            var idleDelta = idle - _systemCpuPrevIdle
            var busy = totalDelta > 0 ? Math.round((totalDelta - idleDelta) / totalDelta * 100) : 0
            systemCpuPercent = Math.max(0, Math.min(100, busy))
            var h = systemCpuHistory.slice(-(systemCpuMaxSamples - 1))
            h.push(systemCpuPercent / 100)
            systemCpuHistory = h
            systemCpuUserPercent = Math.max(0, Math.min(100,
                Math.round((user - _systemCpuPrevUser) / totalDelta * 100)))
            systemCpuSystemPercent = Math.max(0, Math.min(100,
                Math.round((system - _systemCpuPrevSystem) / totalDelta * 100)))
            systemCpuIoWaitPercent = Math.max(0, Math.min(100,
                Math.round((ioWait - _systemCpuPrevIoWait) / totalDelta * 100)))
        }

        _systemCpuPrevIdle = idle
        _systemCpuPrevTotal = total
        _systemCpuPrevUser = user
        _systemCpuPrevSystem = system
        _systemCpuPrevIoWait = ioWait
    }

    function parseCpuInfo(text) {
        var blocks = String(text || "").trim().split(/\n\s*\n/)
        var model = ""
        var threads = 0
        var cores = {}
        var fallbackCores = 0

        for (var i = 0; i < blocks.length; i++) {
            var lines = blocks[i].split("\n")
            var physical = "0"
            var core = ""
            var processorFound = false
            for (var j = 0; j < lines.length; j++) {
                var splitAt = lines[j].indexOf(":")
                if (splitAt < 0) continue
                var key = lines[j].slice(0, splitAt).trim()
                var value = lines[j].slice(splitAt + 1).trim()
                if (key === "processor") processorFound = true
                else if ((key === "model name" || key === "Hardware") && model === "") model = value
                else if (key === "physical id") physical = value
                else if (key === "core id") core = value
                else if (key === "cpu cores" && fallbackCores === 0) fallbackCores = parseInt(value) || 0
            }
            if (processorFound) threads++
            if (core !== "") cores[physical + ":" + core] = true
        }

        cpuModelName = model.replace(/\(R\)|\(TM\)/g, "")
            .replace(/\s+CPU\s+@\s+.*$/, "").replace(/\s+/g, " ").trim()
        cpuThreadCount = threads
        var coreKeys = Object.keys(cores)
        cpuCoreCount = coreKeys.length > 0 ? coreKeys.length : fallbackCores
    }

    function parseSystemLoad(text) {
        var fields = String(text || "").trim().split(/\s+/)
        if (fields.length < 3) return
        systemLoad1 = parseFloat(fields[0]) || 0
        systemLoad5 = parseFloat(fields[1]) || 0
        systemLoad15 = parseFloat(fields[2]) || 0
    }

    function parseCpuDetail(text) {
        var fields = String(text || "").trim().split("|")
        if (fields.length > 5) cpuTemperatureC = Math.max(0, parseInt(fields[5]) || 0)
        if (fields.length < 5) return
        cpuClockMHz = Math.max(0, parseInt(fields[0]) || 0)
        cpuMaxClockMHz = Math.max(0, parseInt(fields[1]) || 0)
        cpuEnergyPreference = String(fields[2] || "").trim()
        cpuScalingGovernor = String(fields[3] || "").trim()
        cpuThrottleCount = Math.max(0, parseInt(fields[4]) || 0)
    }

    function parseCpuTopProcesses(text) {
        var lines = String(text || "").split("\n")
        var processes = []
        for (var i = 0; i < lines.length && processes.length < 3; i++) {
            var match = lines[i].trim().match(/^(.*\S)\s+([0-9]+(?:[.,][0-9]+)?)$/)
            if (!match || match[1] === "ps") continue
            var percent = parseFloat(match[2].replace(",", "."))
            if (isNaN(percent)) continue
            processes.push({ name: match[1], percent: percent })
        }
        cpuTopProcesses = processes
    }

    function parseSystemMem(text) {
        var total = 0, avail = 0, free = 0, buffers = 0, cached = 0
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].trim().split(/\s+/)
            if (parts.length < 2) continue
            var value = parseInt(parts[1])
            if (isNaN(value)) continue
            if (parts[0] === "MemTotal:") total = value
            else if (parts[0] === "MemAvailable:") avail = value
            else if (parts[0] === "MemFree:") free = value
            else if (parts[0] === "Buffers:") buffers = value
            else if (parts[0] === "Cached:") cached = value
        }
        if (total <= 0) return
        systemMemTotalMiB = Math.round(total / 1024)
        systemMemAvailMiB = Math.round(avail / 1024)
        systemMemFreeMiB = Math.round(free / 1024)
        systemMemBuffersMiB = Math.round(buffers / 1024)
        systemMemCachedMiB = Math.round(cached / 1024)
    }

    function parseMemoryHardware(text) {
        var raw = String(text || "")
        var matcher = /type:\s*(DDR[0-9]+)\b[^\n]*\bspeed:\s*([0-9]+)\s*MT\/s/gi
        var match
        var type = ""
        var speed = 0
        while ((match = matcher.exec(raw)) !== null) {
            var candidate = parseInt(match[2]) || 0
            if (type === "") type = match[1].toUpperCase()
            if (candidate > 0 && (speed === 0 || candidate < speed)) speed = candidate
        }
        memoryType = type
        memorySpeedMTs = speed
    }

    function parseGpuTelemetry(text) {
        var fields = String(text || "").trim().split("|")
        if (fields.length < 12 || fields[0] === "none") {
            gpuBackend = ""
            gpuName = ""
            gpuDriverVersion = ""
            gpuPercent = 0
            gpuHistory = []
            gpuTemperatureC = 0
            gpuMemoryUsedMiB = 0
            gpuMemoryTotalMiB = 0
            gpuClockMHz = 0
            gpuPowerW = 0
            gpuPowerLimitW = 0
            gpuPerformanceState = ""
            gpuFanPercent = 0
            gpuFanRpm = -1
            return
        }

        function clean(value) { return String(value || "").trim() }
        function number(value) {
            var parsed = parseFloat(clean(value))
            return isNaN(parsed) ? 0 : parsed
        }

        var rpm = clean(fields[12])
        gpuFanRpm = /^\d+$/.test(rpm) ? Number(rpm) : -1
        gpuBackend = clean(fields[0])
        gpuName = clean(fields[1])
        gpuDriverVersion = clean(fields[2])
        gpuPercent = Math.max(0, Math.min(100, Math.round(number(fields[3]))))
        var history = gpuHistory.slice(-29)
        history.push(gpuPercent / 100)
        gpuHistory = history
        gpuTemperatureC = Math.max(0, Math.round(number(fields[4])))
        gpuMemoryUsedMiB = Math.max(0, Math.round(number(fields[5])))
        gpuMemoryTotalMiB = Math.max(0, Math.round(number(fields[6])))
        gpuClockMHz = Math.max(0, Math.round(number(fields[7])))
        gpuPowerW = Math.max(0, number(fields[8]))
        gpuPowerLimitW = Math.max(0, number(fields[9]))
        gpuPerformanceState = clean(fields[10])
        gpuFanPercent = Math.max(0, Math.min(100, Math.round(number(fields[11]))))
    }

    function parseThermalTelemetry(text) {
        var fields = String(text || "").trim().split("|")
        function thermal(index) {
            var value = parseInt(fields[index])
            return isNaN(value) ? 0 : Math.max(0, Math.min(150, value))
        }
        cpuTemperatureC = thermal(0)
        cpuCoreMaxTemperatureC = thermal(1)
        cpuTemperatureMaxC = thermal(2)
        cpuTemperatureCriticalC = thermal(3)
        nvmeTemperatureC = thermal(4)
        nvmeTemperatureMaxC = thermal(5)
        nvmeTemperatureCriticalC = thermal(6)
        memoryTemperatureC = thermal(7)
    }

    function parseStorageInventory(text) {
        var parsed
        try {
            parsed = JSON.parse(String(text || ""))
        } catch (error) {
            storageInventoryAvailable = false
            storageDrives = []
            return
        }

        var devices = parsed && parsed.blockdevices ? parsed.blockdevices : []
        var drives = []

        function textValue(value) {
            return value === null || value === undefined ? "" : String(value).trim()
        }
        function collectVolumes(node, target) {
            var fs = textValue(node.fstype)
            var mounts = node.mountpoints || []
            var mountedAt = ""
            for (var m = 0; m < mounts.length; m++) {
                var candidate = textValue(mounts[m])
                if (candidate !== "" && candidate !== "[SWAP]") {
                    mountedAt = candidate
                    break
                }
            }
            if (fs !== "") {
                var pct = parseInt(textValue(node["fsuse%"]).replace("%", ""))
                var freeText = textValue(node.fsavail)
                var freeBytes = freeText === "" ? -1 : Number(freeText)
                var usedText = textValue(node.fsused)
                var usedBytes = usedText === "" ? -1 : Number(usedText)
                target.push({
                    fs: fs,
                    mount: mountedAt,
                    percent: isNaN(pct) ? -1 : Math.max(0, Math.min(100, pct)),
                    freeBytes: isNaN(freeBytes) ? -1 : Math.max(0, freeBytes),
                    usedBytes: isNaN(usedBytes) ? -1 : Math.max(0, usedBytes)
                })
            }
            var children = node.children || []
            for (var c = 0; c < children.length; c++) collectVolumes(children[c], target)
        }

        for (var i = 0; i < devices.length; i++) {
            var device = devices[i]
            var name = textValue(device.name)
            if (device.type !== "disk" || name.indexOf("loop") === 0
                    || name.indexOf("ram") === 0 || name.indexOf("zram") === 0)
                continue

            var volumes = []
            collectVolumes(device, volumes)
            var fileSystems = []
            var mountedAt = ""
            var usage = -1
            var freeBytes = -1
            var usedBytes = -1
            for (var v = 0; v < volumes.length; v++) {
                if (fileSystems.indexOf(volumes[v].fs) < 0) fileSystems.push(volumes[v].fs)
                if (mountedAt === "" && volumes[v].mount !== "") {
                    mountedAt = volumes[v].mount
                    usage = volumes[v].percent
                    freeBytes = volumes[v].freeBytes
                    usedBytes = volumes[v].usedBytes
                }
            }

            var transport = textValue(device.tran).toUpperCase()
            var removable = device.rm === true || device.hotplug === true || transport === "USB"
            var driveType = transport === "NVME" ? "nvme"
                : device.rota === true ? "hdd"
                : "ssd"
            var media = removable ? "USB DRIVE"
                : transport === "NVME" ? "NVME SSD"
                : device.rota === true ? (transport !== "" ? transport + " HDD" : "HDD")
                : (transport !== "" ? transport + " SSD" : "SSD")
            var state = mountedAt !== "" ? mountedAt
                : (fileSystems.length > 0 ? "Not mounted" : "No filesystem")

            drives.push({
                name: name,
                model: textValue(device.model) || name,
                size: Number(device.size) || 0,
                driveType: driveType,
                media: media,
                fileSystems: fileSystems.join(" + ").toUpperCase(),
                state: state,
                percent: usage,
                freeBytes: freeBytes,
                usedBytes: usedBytes,
                totalBytes: usedBytes >= 0 && freeBytes >= 0 ? usedBytes + freeBytes : -1
            })
        }

        storageDrives = drives
        storageInventoryAvailable = true
    }

    function parseStorageTelemetry(text) {
        var fields = String(text || "").trim().split("|")
        if (fields.length < 3) {
            storageAvailable = false
            storagePercent = 0
            storageUsedBytes = 0
            storageTotalBytes = 0
            return
        }

        var percent = parseInt(fields[0])
        var used = parseFloat(fields[1])
        var total = parseFloat(fields[2])
        if (isNaN(percent) || isNaN(used) || isNaN(total) || total <= 0) {
            storageAvailable = false
            return
        }

        storageAvailable = true
        storagePercent = Math.max(0, Math.min(100, percent))
        storageUsedBytes = Math.max(0, used)
        storageTotalBytes = Math.max(0, total)
    }

    FileView {
        id: systemCpuFile
        path: "/proc/stat"
        onLoaded: telemetry.parseSystemCpu(systemCpuFile.text())
    }

    FileView {
        id: systemCpuInfoFile
        path: "/proc/cpuinfo"
        onLoaded: telemetry.parseCpuInfo(systemCpuInfoFile.text())
    }

    FileView {
        id: systemLoadFile
        path: "/proc/loadavg"
        onLoaded: telemetry.parseSystemLoad(systemLoadFile.text())
    }

    FileView {
        id: kernelReleaseFile
        path: "/proc/sys/kernel/osrelease"
        onLoaded: telemetry.kernelRelease = String(kernelReleaseFile.text() || "").trim()
    }

    FileView {
        id: systemMemFile
        path: "/proc/meminfo"
        onLoaded: telemetry.parseSystemMem(systemMemFile.text())
    }

    Process {
        id: cpuDetailProc
        command: ["bash", "-c",
            "sum=0; count=0; max=0; epp=''; governor=''; throttle=0; "
            + "for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do [[ -r $f ]] || continue; IFS= read -r v < \"$f\"; "
            + "[[ $v =~ ^[0-9]+$ ]] || continue; sum=$((sum + v)); count=$((count + 1)); done; "
            + "(( count > 0 )) && avg=$((sum / count / 1000)) || avg=0; "
            + "f=/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq; [[ -r $f ]] && { IFS= read -r v < \"$f\"; [[ $v =~ ^[0-9]+$ ]] && max=$((v / 1000)); }; "
            + "f=/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference; [[ -r $f ]] && IFS= read -r epp < \"$f\"; "
            + "f=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor; [[ -r $f ]] && IFS= read -r governor < \"$f\"; "
            + "f=/sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count; [[ -r $f ]] && { IFS= read -r v < \"$f\"; [[ $v =~ ^[0-9]+$ ]] && throttle=$v; }; "
            + "printf '%s|%s|%s|%s|%s\\n' \"$avg\" \"$max\" \"$epp\" \"$governor\" \"$throttle\""]
        stdout: StdioCollector { onStreamFinished: telemetry.parseCpuDetail(this.text) }
    }

    Process {
        id: memoryHardwareProc
        command: ["bash", "-c",
            "if command -v inxi >/dev/null 2>&1; then LC_ALL=C inxi -m -c 0 --no-host 2>/dev/null; fi"]
        running: true
        stdout: StdioCollector { onStreamFinished: telemetry.parseMemoryHardware(this.text) }
    }

    Process {
        id: cpuTopProcessesProc
        command: ["ps", "-eo", "comm=,%cpu=", "--sort=-%cpu"]
        stdout: StdioCollector { onStreamFinished: telemetry.parseCpuTopProcesses(this.text) }
    }

    Process {
        id: gpuTelemetryProc
        command: ["bash", "-c",
            "if command -v nvidia-smi >/dev/null 2>&1; then "
            + "IFS=, read -r name driver util temp used total clock power limit pstate fan < <(nvidia-smi --query-gpu=name,driver_version,utilization.gpu,temperature.gpu,memory.used,memory.total,clocks.current.graphics,power.draw,power.limit,pstate,fan.speed --format=csv,noheader,nounits 2>/dev/null | head -n1); "
            + "if [[ $util =~ ^[[:space:]]*[0-9]+[[:space:]]*$ && $temp =~ ^[[:space:]]*[0-9]+[[:space:]]*$ && $used =~ ^[[:space:]]*[0-9]+[[:space:]]*$ && $total =~ ^[[:space:]]*[0-9]+[[:space:]]*$ ]]; then "
            + "printf 'nvidia|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$name\" \"$driver\" \"$util\" \"$temp\" \"$used\" \"$total\" \"$clock\" \"$power\" \"$limit\" \"$pstate\" \"$fan\"; exit 0; fi; "
            + "fi; "
            + "for busy in /sys/class/drm/card*/device/gpu_busy_percent; do "
            + "[[ -r $busy ]] || continue; read -r util < \"$busy\"; temp=0; "
            + "for sensor in \"${busy%/gpu_busy_percent}\"/hwmon/hwmon*/temp1_input; do "
            + "[[ -r $sensor ]] || continue; read -r raw < \"$sensor\"; temp=$((raw / 1000)); break; done; "
            + "rpm=''; for sensor in \"${busy%/gpu_busy_percent}\"/hwmon/hwmon*/fan1_input; do "
            + "[[ -r $sensor ]] || continue; read -r raw < \"$sensor\"; [[ $raw =~ ^[0-9]+$ ]] && rpm=$raw; break; done; "
            + "printf 'sysfs|GPU||%s|%s|0|0|0|0|0||0|%s\\n' \"$util\" \"$temp\" \"$rpm\"; exit 0; done; "
            + "printf 'none|||||||||||\\n'"]
        stdout: StdioCollector { onStreamFinished: telemetry.parseGpuTelemetry(this.text) }
    }

    Process {
        id: cpuTemperatureProc
        command: ["bash", "-c",
            "cpu=0; core=0; cpu_max=0; cpu_crit=0; nvme=0; nvme_max=0; nvme_crit=0; dimm=0; "
            + "for d in /sys/class/hwmon/hwmon*; do [[ -r $d/name ]] || continue; IFS= read -r name < \"$d/name\"; "
            + "case $name in coretemp|k10temp|zenpower|cpu_thermal) "
            + "for input in \"$d\"/temp*_input; do [[ -r $input ]] || continue; raw=0; IFS= read -r raw < \"$input\"; [[ $raw =~ ^[0-9]+$ ]] || continue; "
            + "label_file=${input%_input}_label; label=''; [[ -r $label_file ]] && IFS= read -r label < \"$label_file\"; value=$((raw / 1000)); "
            + "case $label in 'Package id 0'|Tctl|Tdie|'CPU Package'|CPU) cpu=$value; max_file=${input%_input}_max; crit_file=${input%_input}_crit; "
            + "[[ -r $max_file ]] && { IFS= read -r v < \"$max_file\"; [[ $v =~ ^[0-9]+$ ]] && cpu_max=$((v / 1000)); }; "
            + "[[ -r $crit_file ]] && { IFS= read -r v < \"$crit_file\"; [[ $v =~ ^[0-9]+$ ]] && cpu_crit=$((v / 1000)); };; "
            + "Core*) (( value > core )) && core=$value;; esac; (( cpu == 0 )) && cpu=$value; done;; "
            + "nvme) for label_file in \"$d\"/temp*_label; do [[ -r $label_file ]] || continue; IFS= read -r label < \"$label_file\"; [[ $label == Composite ]] || continue; "
            + "input=${label_file%_label}_input; [[ -r $input ]] || continue; IFS= read -r raw < \"$input\"; [[ $raw =~ ^[0-9]+$ ]] || continue; nvme=$((raw / 1000)); "
            + "max_file=${input%_input}_max; crit_file=${input%_input}_crit; [[ -r $max_file ]] && { IFS= read -r v < \"$max_file\"; [[ $v =~ ^[0-9]+$ ]] && nvme_max=$((v / 1000)); }; "
            + "[[ -r $crit_file ]] && { IFS= read -r v < \"$crit_file\"; [[ $v =~ ^[0-9]+$ ]] && nvme_crit=$((v / 1000)); }; break; done;; "
            + "jc42) for input in \"$d\"/temp*_input; do [[ -r $input ]] || continue; IFS= read -r raw < \"$input\"; [[ $raw =~ ^[0-9]+$ ]] || continue; "
            + "value=$((raw / 1000)); (( value > dimm )) && dimm=$value; done;; esac; done; "
            + "if (( cpu == 0 )); then for zone in /sys/class/thermal/thermal_zone*; do [[ -r $zone/type && -r $zone/temp ]] || continue; "
            + "IFS= read -r type < \"$zone/type\"; case $type in x86_pkg_temp|cpu-thermal|cpu_thermal) IFS= read -r raw < \"$zone/temp\"; "
            + "[[ $raw =~ ^[0-9]+$ ]] && { cpu=$((raw / 1000)); break; };; esac; done; fi; "
            + "printf '%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$cpu\" \"$core\" \"$cpu_max\" \"$cpu_crit\" \"$nvme\" \"$nvme_max\" \"$nvme_crit\" \"$dimm\""]
        stdout: StdioCollector { onStreamFinished: telemetry.parseThermalTelemetry(this.text) }
    }

    Process {
        id: storageTelemetryProc
        command: ["bash", "-c",
            "LC_ALL=C df -P -B1 / 2>/dev/null | awk 'NR == 2 { gsub(/%/, \"\", $5); printf \"%s|%s|%s\\n\", $5, $3, $2 }'"]
        stdout: StdioCollector { onStreamFinished: telemetry.parseStorageTelemetry(this.text) }
    }

    Process {
        id: storageInventoryProc
        command: ["lsblk", "-J", "-b", "-o",
            "NAME,PATH,TYPE,SIZE,FSTYPE,FSUSED,FSAVAIL,FSUSE%,MOUNTPOINTS,MODEL,TRAN,ROTA,RM,HOTPLUG"]
        stdout: StdioCollector { onStreamFinished: telemetry.parseStorageInventory(this.text) }
    }

    Timer {
        interval: (telemetry.owner.modCpu || telemetry.owner.cpuVisible || telemetry.owner.modMemory || telemetry.owner.memVisible) ? 2000 : 10000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            systemCpuFile.reload()
            systemLoadFile.reload()
            systemMemFile.reload()
        }
    }

    Timer {
        interval: 2500
        running: telemetry.owner.cpuVisible || (telemetry.cpuDetailsInBar && telemetry.owner.modCpu)
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cpuDetailProc.running) cpuDetailProc.running = true
    }

    Timer {
        interval: 3000
        running: telemetry.owner.cpuVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cpuTopProcessesProc.running) cpuTopProcessesProc.running = true
    }

    Timer {
        interval: telemetry.owner.gpuVisible ? 500 : 1000
        running: telemetry.owner.modGpu || telemetry.owner.gpuVisible || telemetry.owner.thermalVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!gpuTelemetryProc.running) gpuTelemetryProc.running = true
    }

    Timer {
        interval: telemetry.cpuDetailsInBar ? 2500 : 5000
        running: telemetry.owner.modCpuTemperature || telemetry.owner.cpuVisible || telemetry.owner.thermalVisible || (telemetry.cpuDetailsInBar && telemetry.owner.modCpu)
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cpuTemperatureProc.running) cpuTemperatureProc.running = true
    }

    Timer {
        interval: 30000
        running: telemetry.owner.modStorage || telemetry.owner.storageVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!storageTelemetryProc.running) storageTelemetryProc.running = true
    }

    Timer {
        interval: telemetry.owner.storageVisible ? 5000 : 60000
        running: telemetry.owner.modStorage || telemetry.owner.storageVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!storageInventoryProc.running) storageInventoryProc.running = true
    }

}
