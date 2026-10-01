import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.ui

PopupPanel {
    id: panel

    property var monitors: []
    property string selectedName: ""
    property string operationStatus: ""
    property bool actionRunning: false
    property string actionDescription: ""
    property string actionKind: ""
    property string pendingDisableName: ""
    property var osd: null
    property string pendingDisplayRollbackCommand: ""
    property string pendingDisplayDescription: ""

    property var backlightDevices: []
    readonly property var selectedBacklight: backlightFor(selectedOutput)
    readonly property string backlightDevice: selectedBacklight ? selectedBacklight.name : ""
    readonly property int backlightPercent: selectedBacklight ? selectedBacklight.percent : -1
    property var ddcDisplays: []
    property int ddcPercent: -1
    property int ddcMaximum: 100

    property bool nightLightAvailable: false
    property bool nightLightEnabled: false
    property int nightTemperature: 3500
    property bool capabilitiesChecked: false

    readonly property string focusedMonitorName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property int activeMonitorCount: monitors.filter(monitor => monitor.enabled).length
    readonly property var selectedOutput: monitorNamed(selectedName)
    readonly property string brightnessBackend: brightnessBackendFor(selectedOutput)
    readonly property bool brightnessAvailable: brightnessBackend.length > 0
    readonly property int brightnessPercent: brightnessBackend === "backlight" ? backlightPercent
        : brightnessBackend === "ddc" ? ddcPercent
        : -1
    readonly property bool refreshing: monitorProc.running || brightnessDetectProc.running || ddcDetectProc.running
    // Brightness shown while the slider is dragged; committed on release.
    property int brightnessPreview: -1
    readonly property bool displayChangeLocked: actionRunning || pendingDisplayRollbackCommand.length > 0

    name: "display"
    title: "Display"
    subtitle: activeMonitorCount > 0
        ? `${activeMonitorCount} active · ${focusedMonitorName || "no focused output"}`
        : refreshing ? "querying outputs…" : "no active outputs reported"
    cardWidth: 480
    ipcEnabled: false

    onOpening: {
        pendingDisableName = ""
        if (focusedMonitorName.length > 0)
            selectedName = focusedMonitorName
        operationStatus = ""
        requestRefresh(true)
    }

    onKeyPressed: event => {
        if (event.key !== Qt.Key_Escape)
            return
        if (pendingDisableName.length > 0) {
            cancelDisable()
            event.accepted = true
        } else if (pendingDisplayRollbackCommand.length > 0) {
            revertDisplayChange()
            event.accepted = true
        }
    }

    function monitorNamed(name): var {
        for (const monitor of monitors) {
            if (monitor.name === name)
                return monitor
        }
        return null
    }

    function selectMonitor(name): void {
        if (monitorNamed(name) === null)
            return
        selectedName = name
        ddcPercent = -1
        refreshBrightness()
    }

    function parseMonitors(text): void {
        let values
        try {
            values = JSON.parse(text)
        } catch (error) {
            operationStatus = "Hyprland returned invalid monitor data"
            return
        }

        if (!Array.isArray(values)) {
            operationStatus = "Hyprland monitor data is unavailable"
            return
        }

        monitors = values.map(value => {
            const width = Number(value.width) || 0
            const height = Number(value.height) || 0
            const disabled = value.disabled === true || width <= 0 || height <= 0
            return {
                id: Number(value.id),
                name: value.name || "Unknown output",
                description: value.description || [value.make, value.model].filter(part => part).join(" ") || "Unknown display",
                make: value.make || "",
                model: value.model || "",
                serial: value.serial || "",
                width: width,
                height: height,
                refreshRate: Number(value.refreshRate) || 0,
                x: Number(value.x) || 0,
                y: Number(value.y) || 0,
                scale: Number(value.scale) || 1,
                transform: Number(value.transform) || 0,
                focused: value.focused === true,
                enabled: !disabled,
                dpms: value.dpmsStatus !== false,
                vrr: Number(value.vrr) || 0,
                mirrorOf: value.mirrorOf || "none",
                availableModes: Array.isArray(value.availableModes) ? value.availableModes : [],
                currentFormat: value.currentFormat || "",
                colorManagementPreset: value.colorManagementPreset || "srgb",
                sdrBrightness: Number(value.sdrBrightness) || 1,
                sdrSaturation: Number(value.sdrSaturation) || 1,
                sdrMaxLuminance: Number(value.sdrMaxLuminance) || 80,
                internal: /^(eDP|LVDS|DSI)-/i.test(value.name || "")
            }
        }).sort((left, right) => {
            if (left.focused !== right.focused)
                return left.focused ? -1 : 1
            if (left.enabled !== right.enabled)
                return left.enabled ? -1 : 1
            return left.name.localeCompare(right.name)
        })

        if (monitorNamed(selectedName) === null) {
            const focused = monitors.find(monitor => monitor.focused)
            const firstEnabled = monitors.find(monitor => monitor.enabled)
            selectedName = focused ? focused.name : firstEnabled ? firstEnabled.name : monitors.length > 0 ? monitors[0].name : ""
        }

        Hyprland.refreshMonitors()
        Qt.callLater(() => refreshBrightness())
    }

    function requestRefresh(includeCapabilities): void {
        if (!shown)
            return
        if (!monitorProc.running)
            monitorProc.running = true

        if (includeCapabilities || !capabilitiesChecked) {
            capabilitiesChecked = true
            if (!brightnessDetectProc.running)
                brightnessDetectProc.running = true
            if (!ddcDetectProc.running)
                ddcDetectProc.running = true
            if (!nightProfileProc.running)
                nightProfileProc.running = true
        } else if (brightnessBackend === "backlight" && !brightnessDetectProc.running) {
            brightnessDetectProc.running = true
        }
    }

    function transformLabel(transform): string {
        switch (transform) {
        case 1: return "90°"
        case 2: return "180°"
        case 3: return "270°"
        case 4: return "flipped"
        case 5: return "flipped 90°"
        case 6: return "flipped 180°"
        case 7: return "flipped 270°"
        default: return "normal"
        }
    }

    function modeLabel(monitor): string {
        if (!monitor)
            return "No output selected"
        if (!monitor.enabled)
            return "Output disabled"
        const refresh = monitor.refreshRate > 0 ? ` @ ${monitor.refreshRate.toFixed(2)} Hz` : ""
        return `${monitor.width} × ${monitor.height}${refresh}`
    }

    function outputDetail(monitor): string {
        if (!monitor.enabled)
            return `${monitor.description} · disabled`
        const vrr = monitor.vrr === 0 ? "VRR off" : monitor.vrr === 2 ? "VRR fullscreen" : "VRR on"
        return `${modeLabel(monitor)} · ${monitor.scale.toFixed(2)}× · ${transformLabel(monitor.transform)} · ${vrr}`
    }

    function validScalePresets(monitor): var {
        if (!monitor || !monitor.enabled || monitor.width <= 0 || monitor.height <= 0)
            return []
        return [1, 1.25, 1.5, 1.6, 1.75, 2, 2.5, 3].filter(scale => {
            const logicalWidth = monitor.width / scale
            const logicalHeight = monitor.height / scale
            return Math.abs(logicalWidth - Math.round(logicalWidth)) < 0.001
                && Math.abs(logicalHeight - Math.round(logicalHeight)) < 0.001
        })
    }

    function bitdepthFor(monitor): int {
        if (!monitor)
            return 8
        return /2101010|16161616/i.test(monitor.currentFormat) ? 10 : 8
    }

    function colorModeFor(monitor): string {
        if (!monitor)
            return "sdr"
        const preset = String(monitor.colorManagementPreset || "srgb").toLowerCase()
        if (preset === "hdr" || preset === "hdredid")
            return "hdr"
        return preset === "srgb" ? "sdr" : "auto"
    }

    function availableRefreshPresets(monitor): var {
        if (!monitor || !monitor.enabled)
            return []
        const prefix = `${monitor.width}x${monitor.height}@`
        return [60, 120].filter(refresh => monitor.availableModes.some(mode => {
            if (!String(mode).startsWith(prefix))
                return false
            const value = Number(String(mode).slice(prefix.length).replace(/Hz$/i, ""))
            return isFinite(value) && Math.abs(value - refresh) < 0.5
        }))
    }

    function luaQuote(value): string {
        return JSON.stringify(String(value))
    }

    function monitorMode(monitor): string {
        if (!monitor || !monitor.enabled || monitor.width <= 0 || monitor.height <= 0)
            return "preferred"
        return monitor.refreshRate > 0
            ? `${monitor.width}x${monitor.height}@${monitor.refreshRate.toFixed(3)}`
            : `${monitor.width}x${monitor.height}`
    }

    function monitorExpression(monitor, overrides): string {
        const values = overrides || {}
        const mode = values.mode !== undefined ? values.mode : monitorMode(monitor)
        const position = values.position !== undefined
            ? values.position
            : monitor && monitor.enabled ? `${monitor.x}x${monitor.y}` : "auto"
        const scale = values.scale !== undefined ? values.scale : monitor ? monitor.scale : 1
        const transform = values.transform !== undefined ? values.transform : monitor ? monitor.transform : 0
        const bitdepth = values.bitdepth !== undefined ? values.bitdepth : bitdepthFor(monitor)
        const colorMode = values.cm !== undefined
            ? values.cm
            : colorModeFor(monitor) === "sdr" ? "srgb"
            : colorModeFor(monitor) === "hdr" ? "hdr"
            : "auto"
        const sdrBrightness = values.sdrbrightness !== undefined
            ? values.sdrbrightness
            : monitor ? monitor.sdrBrightness : 1
        const sdrSaturation = values.sdrsaturation !== undefined
            ? values.sdrsaturation
            : monitor ? monitor.sdrSaturation : 1
        const sdrMaxLuminance = values.sdr_max_luminance !== undefined
            ? values.sdr_max_luminance
            : monitor ? monitor.sdrMaxLuminance : 80
        const vrr = values.vrr !== undefined ? values.vrr : monitor ? monitor.vrr : 0
        const mirror = monitor && monitor.mirrorOf && monitor.mirrorOf !== "none"
            ? `, mirror = ${luaQuote(monitor.mirrorOf)}`
            : ""
        const hdrCapabilities = monitor && String(monitor.description).startsWith("LG Electronics LG TV SSCR2")
            ? ", supports_wide_color = 1, supports_hdr = 1"
            : ""
        return `hl.monitor({ output = ${luaQuote(monitor.name)}, mode = ${luaQuote(mode)}, position = ${luaQuote(position)}, scale = ${scale}, transform = ${transform}, bitdepth = ${bitdepth}, cm = ${luaQuote(colorMode)}, sdr_max_luminance = ${sdrMaxLuminance}, sdrbrightness = ${sdrBrightness}, sdrsaturation = ${sdrSaturation}, vrr = ${vrr}${mirror}${hdrCapabilities} })`
    }

    function requestDisplayChange(overrides, description): void {
        const monitor = selectedOutput
        if (!monitor || !monitor.enabled || actionRunning || pendingDisplayRollbackCommand.length > 0)
            return
        pendingDisplayRollbackCommand = monitorExpression(monitor, {})
        pendingDisplayDescription = description
        displayConfirmTimer.restart()
        runAction(["hyprctl", "eval", monitorExpression(monitor, overrides)], description, "monitor")
    }

    function confirmDisplayChange(): void {
        displayConfirmTimer.stop()
        pendingDisplayRollbackCommand = ""
        pendingDisplayDescription = ""
        operationStatus = "Display change kept for this Hyprland session"
    }

    function revertDisplayChange(): void {
        if (pendingDisplayRollbackCommand.length === 0)
            return
        const rollback = pendingDisplayRollbackCommand
        displayConfirmTimer.stop()
        pendingDisplayRollbackCommand = ""
        pendingDisplayDescription = ""
        runAction(["hyprctl", "eval", rollback], "Reverting display change", "monitor")
    }

    function setRefresh(refresh): void {
        const monitor = selectedOutput
        if (!monitor || availableRefreshPresets(monitor).indexOf(refresh) < 0)
            return
        requestDisplayChange(
            { mode: `${monitor.width}x${monitor.height}@${refresh}` },
            `Setting ${monitor.name} to ${refresh} Hz`
        )
    }

    function setBitdepth(bitdepth): void {
        if (bitdepth !== 8 && bitdepth !== 10)
            return
        const overrides = { bitdepth: bitdepth }
        if (bitdepth === 8)
            overrides.cm = "srgb"
        requestDisplayChange(overrides, `Setting ${selectedName} to ${bitdepth}-bit output`)
    }

    function setColorMode(mode): void {
        if (mode !== "sdr" && mode !== "auto" && mode !== "hdr")
            return
        requestDisplayChange({
            bitdepth: 10,
            cm: mode === "sdr" ? "srgb" : mode,
            sdrbrightness: 1.2,
            sdrsaturation: 1
        }, `Setting ${selectedName} color mode to ${mode === "sdr" ? "SDR" : mode === "auto" ? "Auto HDR" : "HDR"}`)
    }

    function runAction(argv, description, kind): void {
        if (actionProc.running)
            return
        actionDescription = description
        actionKind = kind || "display"
        operationStatus = `${description}…`
        actionProc.command = argv
        actionProc.running = true
    }

    function setScale(scale): void {
        const monitor = selectedOutput
        if (!monitor || !monitor.enabled || validScalePresets(monitor).indexOf(scale) < 0) {
            operationStatus = "That scale is not valid for the selected mode"
            return
        }
        requestDisplayChange({ scale: scale }, `Setting ${monitor.name} scale to ${scale}×`)
    }

    function toggleVrr(): void {
        const monitor = selectedOutput
        if (!monitor || !monitor.enabled) {
            operationStatus = "Enable the output before changing adaptive sync"
            return
        }
        const nextVrr = monitor.vrr === 0 ? 1 : 0
        requestDisplayChange({ vrr: nextVrr }, `${nextVrr ? "Enabling" : "Disabling"} adaptive sync on ${monitor.name}`)
    }

    function requestMonitorEnabled(name, enabled): void {
        const monitor = monitorNamed(name)
        if (!monitor || monitor.enabled === enabled)
            return
        if (enabled) {
            runAction(
                ["hyprctl", "eval", `hl.monitor({ output = ${luaQuote(monitor.name)}, mode = "preferred", position = "auto", scale = "auto" })`],
                `Enabling ${monitor.name}`,
                "monitor"
            )
            return
        }
        if (activeMonitorCount <= 1) {
            operationStatus = "The last active display cannot be disabled"
            return
        }
        pendingDisableName = monitor.name
    }

    function cancelDisable(): void {
        pendingDisableName = ""
    }

    function confirmDisable(): void {
        const monitor = monitorNamed(pendingDisableName)
        if (!monitor || !monitor.enabled) {
            pendingDisableName = ""
            return
        }
        if (activeMonitorCount <= 1) {
            pendingDisableName = ""
            operationStatus = "The last active display cannot be disabled"
            return
        }
        pendingDisableName = ""
        runAction(
            ["hyprctl", "eval", `hl.monitor({ output = ${luaQuote(monitor.name)}, disabled = true })`],
            `Disabling ${monitor.name}`,
            "monitor"
        )
    }

    function parseBacklights(text): void {
        const lines = text.split("\n").map(line => line.trim()).filter(line => line.length > 0)
        backlightDevices = lines.map(line => {
            const fields = line.split(",")
            const match = (fields[4] || "").match(/(\d+)%/)
            return {
                name: fields[0] || "",
                ddcLike: /^ddcci/i.test(fields[0] || ""),
                percent: match ? Math.max(0, Math.min(100, Number(match[1]))) : -1
            }
        }).filter(device => device.name.length > 0)
    }

    function parseDdcDisplays(text): void {
        const displays = []
        let current = null
        for (const rawLine of text.split("\n")) {
            const line = rawLine.trim()
            const displayMatch = line.match(/^Display\s+(\d+)/i)
            if (displayMatch) {
                if (current)
                    displays.push(current)
                current = { index: Number(displayMatch[1]), connector: "" }
                continue
            }
            const connectorMatch = line.match(/^DRM connector:\s*(.+)$/i)
            if (current && connectorMatch)
                current.connector = connectorMatch[1].trim().replace(/^.*\//, "").replace(/^card\d+-/i, "")
        }
        if (current)
            displays.push(current)
        ddcDisplays = displays
        Qt.callLater(() => refreshBrightness())
    }

    function ddcDisplayFor(monitor): var {
        if (!monitor)
            return null
        const exact = ddcDisplays.find(display => display.connector === monitor.name)
        if (exact)
            return exact
        const external = monitors.filter(candidate => candidate.enabled && !candidate.internal)
        return ddcDisplays.length === 1 && external.length === 1 && external[0].name === monitor.name ? ddcDisplays[0] : null
    }

    function backlightFor(monitor): var {
        if (!monitor || !monitor.enabled)
            return null
        if (monitor.internal) {
            const nativeDevices = backlightDevices.filter(device => !device.ddcLike)
            return nativeDevices.length > 0 ? nativeDevices[0] : null
        }
        const externalDisplays = monitors.filter(candidate => candidate.enabled && !candidate.internal)
        const ddcBacklights = backlightDevices.filter(device => device.ddcLike)
        return externalDisplays.length === 1 && ddcBacklights.length === 1 ? ddcBacklights[0] : null
    }

    function brightnessBackendFor(monitor): string {
        if (!monitor || !monitor.enabled)
            return ""
        if (backlightFor(monitor))
            return "backlight"
        return ddcDisplayFor(monitor) ? "ddc" : ""
    }

    function refreshBrightness(): void {
        if (!shown)
            return
        if (brightnessBackend === "backlight") {
            if (!brightnessDetectProc.running)
                brightnessDetectProc.running = true
            return
        }
        const ddc = ddcDisplayFor(selectedOutput)
        if (!ddc || ddcReadProc.running)
            return
        ddcReadProc.displayIndex = ddc.index
        ddcReadProc.command = ["ddcutil", "--display", String(ddc.index), "getvcp", "10", "--brief"]
        ddcReadProc.running = true
    }

    function setBrightness(percent): void {
        const value = Math.max(1, Math.min(100, Math.round(percent)))
        if (brightnessBackend === "backlight") {
            runAction(["brightnessctl", "--device", backlightDevice, "set", `${value}%`], `Setting ${selectedName} brightness to ${value}%`, "brightness")
            if (osd)
                osd.brightness(value / 100)
            return
        }
        const ddc = ddcDisplayFor(selectedOutput)
        if (ddc) {
            const rawValue = Math.max(1, Math.round(ddcMaximum * value / 100))
            runAction(["ddcutil", "--display", String(ddc.index), "setvcp", "10", String(rawValue)], `Setting ${selectedName} brightness to ${value}%`, "brightness")
            if (osd)
                osd.brightness(value / 100)
            return
        }
        operationStatus = "Brightness control is unavailable for this output"
    }

    function parseNightProfile(text): void {
        const identity = text.match(/identity\s*[:=]\s*(true|false|1|0)/i)
        const temperature = text.match(/temperature\s*[:=]\s*(\d+)/i)
        if (temperature) {
            nightTemperature = Math.max(1000, Math.min(20000, Number(temperature[1])))
            nightLightEnabled = !(identity && /^(true|1)$/i.test(identity[1]))
        } else if (identity) {
            nightLightEnabled = !/^(true|1)$/i.test(identity[1])
        }
    }

    function toggleNightLight(): void {
        if (!nightLightAvailable) {
            operationStatus = "hyprsunset is not running"
            return
        }
        if (nightLightEnabled)
            runAction(["hyprctl", "hyprsunset", "identity"], "Disabling night light", "night-off")
        else
            runAction(["hyprctl", "hyprsunset", "temperature", String(nightTemperature)], `Enabling ${nightTemperature} K night light`, "night-on")
    }

    function setNightTemperature(temperature): void {
        const value = Math.max(1000, Math.min(20000, Math.round(temperature)))
        nightTemperature = value
        if (!nightLightAvailable) {
            operationStatus = "hyprsunset is not running"
            return
        }
        runAction(["hyprctl", "hyprsunset", "temperature", String(value)], `Setting night light to ${value} K`, "night-temperature")
    }

    IpcHandler {
        target: "display"

        function open(): void {
            panel.open()
        }

        function close(): void {
            panel.pendingDisableName = ""
            panel.close()
        }

        function toggle(): void {
            panel.toggle()
        }

        function refreshRate(refresh: int): void {
            panel.setRefresh(refresh)
        }

        function bitdepth(depth: int): void {
            panel.setBitdepth(depth)
        }

        function colorMode(mode: string): void {
            panel.setColorMode(mode)
        }

        function keep(): void {
            panel.confirmDisplayChange()
        }

        function revert(): void {
            panel.revertDisplayChange()
        }
    }

    Timer {
        interval: 6000
        repeat: true
        running: panel.shown
        onTriggered: panel.requestRefresh(false)
    }

    Timer {
        id: settleTimer
        interval: 450
        repeat: false
        onTriggered: panel.requestRefresh(false)
    }
    Timer {
        id: displayConfirmTimer
        interval: 15000
        repeat: false
        onTriggered: panel.revertDisplayChange()
    }

    Process {
        id: monitorProc
        property string output: ""
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: monitorProc.output = text
        }
        onStarted: output = ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                panel.parseMonitors(output)
            else
                panel.operationStatus = "Unable to query Hyprland monitors"
        }
    }

    Process {
        id: brightnessDetectProc
        property string output: ""
        command: ["brightnessctl", "--list", "--class", "backlight", "--machine-readable"]
        stdout: StdioCollector {
            onStreamFinished: brightnessDetectProc.output = text
        }
        onStarted: output = ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                panel.parseBacklights(output)
            else
                panel.backlightDevices = []
        }
    }

    Process {
        id: ddcDetectProc
        property string output: ""
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: ddcDetectProc.output = text
        }
        onStarted: output = ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                panel.parseDdcDisplays(output)
            else
                panel.ddcDisplays = []
        }
    }

    Process {
        id: ddcReadProc
        property int displayIndex: -1
        property string output: ""
        stdout: StdioCollector {
            onStreamFinished: ddcReadProc.output = text
        }
        onStarted: output = ""
        onExited: (exitCode, exitStatus) => {
            const selectedDdc = panel.ddcDisplayFor(panel.selectedOutput)
            if (exitCode !== 0 || !selectedDdc || displayIndex !== selectedDdc.index)
                return
            const values = output.match(/VCP\s+10\s+(?:C\s+)?(\d+)\s+(\d+)/i)
            if (!values)
                return
            const current = Number(values[1])
            const maximum = Math.max(1, Number(values[2]))
            panel.ddcMaximum = maximum
            panel.ddcPercent = Math.max(0, Math.min(100, Math.round(current * 100 / maximum)))
        }
    }

    Process {
        id: nightProfileProc
        property string output: ""
        command: ["hyprctl", "hyprsunset", "profile"]
        stdout: StdioCollector {
            onStreamFinished: nightProfileProc.output = text
        }
        onStarted: output = ""
        onExited: (exitCode, exitStatus) => {
            panel.nightLightAvailable = exitCode === 0
            if (exitCode === 0)
                panel.parseNightProfile(output)
        }
    }

    Process {
        id: actionProc
        property string failureText: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: actionProc.failureText = text.trim()
        }
        onStarted: {
            failureText = ""
            panel.actionRunning = true
        }
        onExited: (exitCode, exitStatus) => {
            panel.actionRunning = false
            if (exitCode === 0) {
                panel.operationStatus = `${panel.actionDescription} succeeded`
                if (panel.actionKind === "night-off")
                    panel.nightLightEnabled = false
                else if (panel.actionKind === "night-on" || panel.actionKind === "night-temperature")
                    panel.nightLightEnabled = true
            } else {
                panel.operationStatus = `${panel.actionDescription} failed${failureText.length > 0 ? ` — ${failureText}` : ""}`
            }
            if (panel.shown) {
                if (panel.actionKind === "brightness")
                    Qt.callLater(() => panel.refreshBrightness())
                else if (panel.actionKind === "monitor")
                    settleTimer.restart()
            }
            panel.actionKind = ""
        }
    }

    headerTrailing: [
        Button {
            compact: true
            icon: "refresh-cw"
            text: panel.refreshing ? "Refreshing…" : "Refresh"
            enabled: !panel.refreshing
            onClicked: panel.requestRefresh(true)
        }
    ]

    footer: [
        Label {
            width: parent ? parent.width : 0
            text: panel.operationStatus.length > 0 ? panel.operationStatus : "Changes apply for this Hyprland session"
            variant: "small"
            tone: panel.operationStatus.includes("failed") || panel.operationStatus.includes("cannot")
                || panel.operationStatus.includes("unavailable") || panel.operationStatus.includes("Unable")
                ? "warning" : "faint"
        }
    ]

    // Outputs

    SectionHeader {
        width: parent.width
        text: "Outputs"
        trailing: panel.monitors.length > 0 ? String(panel.monitors.length) : ""
    }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: panel.monitors

            delegate: ListItem {
                id: outputRow

                required property var modelData

                width: parent ? parent.width : 0
                icon: !modelData.enabled ? "monitor-off" : modelData.internal ? "laptop" : "monitor"
                title: modelData.name
                subtitle: panel.outputDetail(modelData)
                trailing: modelData.focused ? "focused" : ""
                trailingTone: "success"
                selected: panel.selectedName === modelData.name
                onClicked: panel.selectMonitor(modelData.name)

                Button {
                    compact: true
                    text: outputRow.modelData.enabled ? "Disable" : "Enable"
                    enabled: !panel.actionRunning && (!outputRow.modelData.enabled || panel.activeMonitorCount > 1)
                    onClicked: panel.requestMonitorEnabled(outputRow.modelData.name, !outputRow.modelData.enabled)
                }
            }
        }

        Column {
            visible: panel.monitors.length === 0
            width: parent.width
            topPadding: Theme.space.md
            bottomPadding: Theme.space.md
            spacing: Theme.space.sm

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "monitor-off"
                size: 22
                color: Theme.text.faint
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: panel.refreshing ? "Discovering Hyprland outputs…" : "No display outputs were found"
                tone: "soft"
            }
        }
    }

    // Disable confirmation

    Rectangle {
        visible: panel.pendingDisableName.length > 0
        width: parent.width
        height: confirmColumn.implicitHeight + Theme.space.lg * 2
        radius: Theme.radius.medium
        color: Theme.dangerTint
        border.width: Theme.borderWidth
        border.color: Theme.withAlpha(Theme.danger, Theme.alpha.lineStrong)

        Column {
            id: confirmColumn

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.space.lg
            }
            spacing: Theme.space.sm

            Label {
                width: parent.width
                text: "Disable display?"
                variant: "heading"
            }

            Label {
                width: parent.width
                text: `${panel.pendingDisableName} will stop displaying immediately. Windows and workspaces may move to another active output.`
                variant: "small"
                tone: "soft"
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                text: `${panel.activeMonitorCount - 1} display${panel.activeMonitorCount - 1 === 1 ? "" : "s"} will remain active.`
                variant: "small"
                tone: "warning"
            }

            Item {
                width: parent.width
                height: confirmButtons.height + Theme.space.xs

                Row {
                    id: confirmButtons

                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: Theme.space.sm

                    Button {
                        compact: true
                        text: "Cancel"
                        onClicked: panel.cancelDisable()
                    }

                    Button {
                        compact: true
                        variant: "danger"
                        icon: "monitor-off"
                        text: "Disable output"
                        enabled: panel.activeMonitorCount > 1 && !panel.actionRunning
                        onClicked: panel.confirmDisable()
                    }
                }
            }
        }
    }

    // Selected output

    Column {
        visible: panel.selectedOutput !== null
        width: parent.width
        spacing: Theme.space.md

        SectionHeader {
            width: parent.width
            text: "Output"
            trailing: panel.selectedOutput ? panel.selectedOutput.name : ""
        }

        Column {
            width: parent.width
            spacing: Theme.space.xs

            Label {
                width: parent.width
                text: panel.selectedOutput ? panel.selectedOutput.description : ""
                font.weight: Font.Medium
            }

            Label {
                width: parent.width
                text: panel.selectedOutput && panel.selectedOutput.enabled
                    ? `position ${panel.selectedOutput.x}, ${panel.selectedOutput.y} · ${panel.transformLabel(panel.selectedOutput.transform)} · vrr ${panel.selectedOutput.vrr === 0 ? "off" : panel.selectedOutput.vrr === 2 ? "fullscreen" : "on"}`
                    : "Enable this output to adjust it"
                variant: "numeric"
                font.pixelSize: Theme.fontSize.caption
                font.weight: Font.Normal
                tone: "faint"
            }
        }

        SwitchRow {
            title: "Adaptive sync"
            detail: panel.selectedOutput && panel.selectedOutput.vrr !== 0 ? (panel.selectedOutput.vrr === 2 ? "VRR on · fullscreen only" : "VRR on") : "VRR off"
            checked: panel.selectedOutput !== null && panel.selectedOutput.vrr !== 0
            enabled: panel.selectedOutput !== null && panel.selectedOutput.enabled && !panel.actionRunning
            onToggled: panel.toggleVrr()
        }

        SectionHeader {
            width: parent.width
            text: "Signal"
            trailing: panel.selectedOutput
                ? `${panel.selectedOutput.refreshRate.toFixed(0)} hz · ${panel.bitdepthFor(panel.selectedOutput)}-bit · ${panel.selectedOutput.colorManagementPreset}${panel.selectedOutput.currentFormat ? ` · ${panel.selectedOutput.currentFormat}` : ""}`
                : ""
        }

        OptionRow {
            visible: panel.availableRefreshPresets(panel.selectedOutput).length > 0
            label: "Refresh"
            enabled: !panel.displayChangeLocked

            Repeater {
                model: panel.availableRefreshPresets(panel.selectedOutput)

                Chip {
                    required property var modelData

                    text: `${Number(modelData)} Hz`
                    selected: panel.selectedOutput !== null && Math.abs(panel.selectedOutput.refreshRate - Number(modelData)) < 0.5
                    onClicked: panel.setRefresh(Number(modelData))
                }
            }
        }

        OptionRow {
            label: "Depth"
            enabled: !panel.displayChangeLocked

            Chip {
                text: "8-bit"
                selected: panel.bitdepthFor(panel.selectedOutput) === 8
                onClicked: panel.setBitdepth(8)
            }

            Chip {
                text: "10-bit"
                selected: panel.bitdepthFor(panel.selectedOutput) === 10
                onClicked: panel.setBitdepth(10)
            }
        }

        OptionRow {
            label: "Color"
            enabled: !panel.displayChangeLocked

            Chip {
                text: "SDR"
                selected: panel.colorModeFor(panel.selectedOutput) === "sdr"
                onClicked: panel.setColorMode("sdr")
            }

            Chip {
                text: "Auto HDR"
                selected: panel.colorModeFor(panel.selectedOutput) === "auto"
                onClicked: panel.setColorMode("auto")
            }

            Chip {
                text: "HDR on"
                selected: panel.colorModeFor(panel.selectedOutput) === "hdr"
                onClicked: panel.setColorMode("hdr")
            }
        }

        OptionRow {
            label: "Scale"
            enabled: !panel.actionRunning

            Repeater {
                model: panel.validScalePresets(panel.selectedOutput)

                Chip {
                    required property var modelData

                    text: `${Number(modelData).toFixed(Number(modelData) % 1 === 0 ? 0 : 2)}×`
                    selected: panel.selectedOutput !== null && Math.abs(panel.selectedOutput.scale - Number(modelData)) < 0.01
                    onClicked: panel.setScale(Number(modelData))
                }
            }
        }

        Label {
            visible: panel.selectedOutput !== null && panel.selectedOutput.enabled && panel.validScalePresets(panel.selectedOutput).length <= 1
            width: parent.width
            leftPadding: 96
            text: "No additional preset divides the current mode into whole logical pixels"
            variant: "small"
            tone: "faint"
            wrapMode: Text.Wrap
        }

        Rectangle {
            visible: panel.pendingDisplayRollbackCommand.length > 0
            width: parent.width
            height: 44
            radius: Theme.radius.medium
            color: Theme.withAlpha(Theme.warning, Theme.alpha.tint)

            Icon {
                id: rollbackIcon

                anchors.left: parent.left
                anchors.leftMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                name: "timer"
                size: 15
                color: Theme.warning
            }

            Label {
                anchors {
                    left: rollbackIcon.right
                    right: rollbackButtons.left
                    leftMargin: Theme.space.sm
                    rightMargin: Theme.space.sm
                    verticalCenter: parent.verticalCenter
                }
                text: `${panel.pendingDisplayDescription} · reverting in 15 seconds`
                variant: "small"
                tone: "warning"
            }

            Row {
                id: rollbackButtons

                anchors.right: parent.right
                anchors.rightMargin: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.xs + 2

                Button {
                    compact: true
                    variant: "danger"
                    text: "Revert"
                    enabled: !panel.actionRunning
                    onClicked: panel.revertDisplayChange()
                }

                Button {
                    compact: true
                    variant: "primary"
                    text: "Keep"
                    enabled: !panel.actionRunning
                    onClicked: panel.confirmDisplayChange()
                }
            }
        }
    }

    // Brightness

    SectionHeader {
        width: parent.width
        text: "Brightness"
        trailing: panel.brightnessAvailable ? (panel.brightnessBackend === "ddc" ? "ddc/ci" : "backlight") : ""
    }

    Column {
        width: parent.width
        spacing: Theme.space.sm

        Item {
            width: parent.width
            height: 22

            Label {
                anchors.left: parent.left
                anchors.right: brightnessValue.left
                anchors.rightMargin: Theme.space.md
                anchors.verticalCenter: parent.verticalCenter
                text: panel.selectedOutput ? panel.selectedOutput.name : "No output"
                font.weight: Font.Medium
                tone: panel.brightnessAvailable ? "base" : "faint"
            }

            Label {
                id: brightnessValue

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: brightnessSlider.dragging ? `${panel.brightnessPreview}%`
                    : panel.brightnessPercent >= 0 ? `${panel.brightnessPercent}%`
                    : "unavailable"
                variant: panel.brightnessPercent >= 0 ? "numeric" : "label"
                tone: panel.brightnessPercent >= 0 ? "base" : "faint"
            }
        }

        Slider {
            id: brightnessSlider

            visible: panel.brightnessAvailable
            width: parent.width
            enabled: panel.brightnessAvailable && panel.brightnessPercent >= 0 && !panel.actionRunning
            value: brightnessSlider.dragging ? panel.brightnessPreview / 100 : Math.max(0, panel.brightnessPercent) / 100
            onMoved: value => {
                panel.brightnessPreview = Math.max(1, Math.min(100, Math.round(value * 100)))
                // Wheel steps commit immediately; drags commit on release.
                if (!brightnessSlider.dragging)
                    panel.setBrightness(panel.brightnessPreview)
            }
            onDraggingChanged: {
                if (!dragging && panel.brightnessPreview >= 0)
                    panel.setBrightness(panel.brightnessPreview)
            }
        }

        Label {
            width: parent.width
            text: panel.selectedOutput === null ? "Select an output"
                : panel.brightnessAvailable ? `Hardware brightness for ${panel.selectedOutput.name}`
                : panel.selectedOutput.internal ? "brightnessctl did not report a backlight device"
                : "No matching DDC/CI display was detected"
            variant: "small"
            tone: "faint"
        }
    }

    // Night light

    SectionHeader {
        width: parent.width
        text: "Night light"
        trailing: panel.nightLightAvailable ? "" : "unavailable"
    }

    Column {
        width: parent.width
        spacing: Theme.space.md

        SwitchRow {
            title: "Warm colors"
            detail: panel.nightLightAvailable
                ? panel.nightLightEnabled ? `${panel.nightTemperature} K · warmer colors active` : "Color temperature filter off"
                : "hyprsunset is not running"
            checked: panel.nightLightEnabled
            enabled: panel.nightLightAvailable && !panel.actionRunning
            onToggled: panel.toggleNightLight()
        }

        OptionRow {
            label: "Temperature"
            enabled: panel.nightLightAvailable && !panel.actionRunning

            Repeater {
                model: [2500, 3500, 4500, 5500]

                Chip {
                    required property var modelData

                    text: `${modelData} K`
                    selected: panel.nightLightEnabled && panel.nightTemperature === Number(modelData)
                    onClicked: panel.setNightTemperature(Number(modelData))
                }
            }
        }
    }
}
