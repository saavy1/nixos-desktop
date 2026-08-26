import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
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

    visible: PopupController.isOpen("display")
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: visible
    screen: PopupController.focusedScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "solitude-display"

    function open(): void {
        PopupController.open("display")
        if (focusedMonitorName.length > 0)
            selectedName = focusedMonitorName
        operationStatus = ""
        requestRefresh(true)
        Qt.callLater(() => keyboardScope.forceActiveFocus())
    }

    function close(): void {
        pendingDisableName = ""
        PopupController.close("display")
    }

    function toggle(): void {
        if (visible)
            close()
        else
            open()
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
        if (!visible)
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
            return `${monitor.description}  ·  disabled`
        const vrr = monitor.vrr === 0 ? "VRR off" : monitor.vrr === 2 ? "VRR fullscreen" : "VRR on"
        return `${modeLabel(monitor)}  ·  ${monitor.scale.toFixed(2)}×  ·  ${transformLabel(monitor.transform)}  ·  ${vrr}`
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
        const vrr = values.vrr !== undefined ? values.vrr : monitor ? monitor.vrr : 0
        const mirror = monitor && monitor.mirrorOf && monitor.mirrorOf !== "none"
            ? `, mirror = ${luaQuote(monitor.mirrorOf)}`
            : ""
        const hdrCapabilities = monitor && String(monitor.description).startsWith("LG Electronics LG TV SSCR2")
            ? ", supports_wide_color = 1, supports_hdr = 1"
            : ""
        return `hl.monitor({ output = ${luaQuote(monitor.name)}, mode = ${luaQuote(mode)}, position = ${luaQuote(position)}, scale = ${scale}, transform = ${transform}, bitdepth = ${bitdepth}, cm = ${luaQuote(colorMode)}, sdrbrightness = ${sdrBrightness}, sdrsaturation = ${sdrSaturation}, vrr = ${vrr}${mirror}${hdrCapabilities} })`
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
        if (!visible)
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


        function close(): void {
            panel.close()
        }
    }

    Timer {
        interval: 6000
        repeat: true
        running: panel.visible
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
            if (panel.visible) {
                if (panel.actionKind === "brightness")
                    Qt.callLater(() => panel.refreshBrightness())
                else if (panel.actionKind === "monitor")
                    settleTimer.restart()
            }
            panel.actionKind = ""
        }
    }

    component ActionButton: Rectangle {
        id: button
        required property string label
        property bool destructive: false
        property bool selected: false
        signal activated()

        implicitWidth: labelText.implicitWidth + 24
        implicitHeight: 34
        radius: Theme.radiusSmall
        color: !enabled ? Theme.backgroundDarker
            : selected ? Theme.selection
            : hover.containsMouse ? Theme.selection
            : Theme.backgroundDark
        border.color: destructive ? Theme.error : selected ? Theme.accent : Theme.border
        border.width: Theme.borderWidth
        opacity: enabled ? 1 : 0.45

        Text {
            id: labelText
            anchors.centerIn: parent
            text: button.label
            color: button.destructive ? Theme.error : button.selected ? Theme.accent : Theme.foreground
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontCaption
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.activated()
        }
    }

    component PercentSlider: Item {
        id: slider
        required property int value
        property bool available: true
        property int preview: value >= 0 ? value : 0
        readonly property int shownValue: dragArea.pressed ? preview : Math.max(0, value)
        signal requested(int value)

        implicitHeight: 28
        opacity: available ? 1 : 0.4
        onValueChanged: {
            if (!dragArea.pressed)
                preview = Math.max(0, value)
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            height: 7
            radius: 4
            color: Theme.backgroundDarker

            Rectangle {
                width: parent.width * slider.shownValue / 100
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
        }

        Rectangle {
            x: Math.max(0, Math.min(parent.width - width, parent.width * slider.shownValue / 100 - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: slider.available ? Theme.foreground : Theme.muted
            border.color: Theme.backgroundDarker
            border.width: Theme.borderWidth
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            enabled: slider.available
            cursorShape: Qt.PointingHandCursor
            function updateValue(xPosition): void {
                slider.preview = Math.max(1, Math.min(100, Math.round(xPosition * 100 / width)))
            }
            onPressed: mouse => updateValue(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    updateValue(mouse.x)
            }
            onReleased: slider.requested(slider.preview)
        }
    }

    FocusScope {
        id: keyboardScope
        anchors.fill: parent
        focus: panel.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (panel.pendingDisableName.length > 0)
                    panel.cancelDisable()
                else if (panel.pendingDisplayRollbackCommand.length > 0)
                    panel.revertDisplayChange()
                else
                    panel.close()
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.close()
        }

        PanelCard {
            id: card
            anchors {
                top: parent.top
                right: parent.right
                topMargin: Theme.outerMargin + Theme.barHeight + Theme.shellGap
                rightMargin: Theme.outerMargin
            }
            width: Math.min(760, panel.width - Theme.outerMargin * 2)
            height: Math.min(800, panel.height - Theme.outerMargin * 2 - Theme.barHeight)

            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: header
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 20
                }
                height: 54

                Column {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: "Displays"
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: panel.activeMonitorCount > 0
                            ? `${panel.activeMonitorCount} active  ·  ${panel.focusedMonitorName || "no focused output"}`
                            : "No active outputs reported"
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                    }
                }

                ActionButton {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    label: panel.refreshing ? "Refreshing…" : "Refresh"
                    enabled: !panel.refreshing
                    onActivated: panel.requestRefresh(true)
                }
            }

            Rectangle {
                id: headerDivider
                anchors {
                    top: header.bottom
                    left: parent.left
                    right: parent.right
                    leftMargin: 20
                    rightMargin: 20
                }
                height: 1
                color: Theme.backgroundDarker
            }

            Flickable {
                id: scroller
                anchors {
                    top: headerDivider.bottom
                    bottom: footerDivider.top
                    left: parent.left
                    right: parent.right
                    margins: 20
                    topMargin: 14
                    bottomMargin: 12
                }
                contentWidth: width
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: content
                    width: scroller.width
                    spacing: 14

                    Text {
                        text: "OUTPUTS"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    Column {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: panel.monitors

                            delegate: Rectangle {
                                id: outputRow
                                required property var modelData

                                width: parent ? parent.width : 0
                                height: 76
                                radius: Theme.radiusMedium
                                color: panel.selectedName === modelData.name ? Theme.selection : Theme.backgroundDark
                                border.color: modelData.focused ? Theme.accent : panel.selectedName === modelData.name ? Theme.border : Theme.backgroundDarker
                                border.width: Theme.borderWidth
                                opacity: modelData.enabled ? 1 : 0.65

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: panel.selectMonitor(outputRow.modelData.name)
                                }

                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 14
                                    }
                                    width: 42
                                    height: 28
                                    radius: Theme.radiusSmall
                                    color: outputRow.modelData.enabled ? Theme.backgroundDarker : "transparent"
                                    border.color: outputRow.modelData.enabled ? Theme.accent : Theme.muted
                                    border.width: Theme.borderWidth

                                    Rectangle {
                                        visible: outputRow.modelData.enabled
                                        anchors {
                                            horizontalCenter: parent.horizontalCenter
                                            top: parent.bottom
                                        }
                                        width: 14
                                        height: 3
                                        color: Theme.accent
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: outputRow.modelData.internal ? "LAP" : "EXT"
                                        color: outputRow.modelData.enabled ? Theme.accent : Theme.muted
                                        font.family: Theme.fontSans
                                        font.pixelSize: Theme.fontCaption - 1
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Column {
                                    anchors {
                                        left: parent.left
                                        right: outputToggle.left
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 68
                                        rightMargin: 14
                                    }
                                    spacing: 3

                                    Row {
                                        spacing: 8
                                        Text {
                                            text: outputRow.modelData.name
                                            color: Theme.foreground
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontBody
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            visible: outputRow.modelData.focused
                                            text: "FOCUSED"
                                            color: Theme.success
                                            font.family: Theme.fontSans
                                            font.pixelSize: Theme.fontCaption - 1
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: panel.outputDetail(outputRow.modelData)
                                        color: Theme.muted
                                        font.family: Theme.fontSans
                                        font.pixelSize: Theme.fontCaption
                                        elide: Text.ElideRight
                                    }
                                }

                                ActionButton {
                                    id: outputToggle
                                    anchors {
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        rightMargin: 12
                                    }
                                    label: outputRow.modelData.enabled ? "Disable" : "Enable"
                                    destructive: outputRow.modelData.enabled
                                    enabled: !panel.actionRunning && (!outputRow.modelData.enabled || panel.activeMonitorCount > 1)
                                    onActivated: panel.requestMonitorEnabled(outputRow.modelData.name, !outputRow.modelData.enabled)
                                }
                            }
                        }

                        Text {
                            visible: panel.monitors.length === 0
                            width: parent.width
                            height: 56
                            verticalAlignment: Text.AlignVCenter
                            text: panel.refreshing ? "Discovering Hyprland outputs…" : "No display outputs were found"
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontBody
                        }
                    }

                    Rectangle {
                        visible: panel.selectedOutput !== null
                        width: parent.width
                        height: selectedControls.implicitHeight + 28
                        radius: Theme.radiusMedium
                        color: Theme.backgroundDark
                        border.color: Theme.backgroundDarker
                        border.width: Theme.borderWidth

                        Column {
                            id: selectedControls
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 14
                            }
                            spacing: 12

                            Row {
                                width: parent.width
                                spacing: 10

                                Column {
                                    width: parent.width - vrrButton.width - 10
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: panel.selectedOutput ? panel.selectedOutput.description : ""
                                        color: Theme.foreground
                                        font.family: Theme.fontSans
                                        font.pixelSize: Theme.fontBody
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: panel.selectedOutput && panel.selectedOutput.enabled
                                            ? `Position ${panel.selectedOutput.x}, ${panel.selectedOutput.y}  ·  ${panel.transformLabel(panel.selectedOutput.transform)}  ·  VRR ${panel.selectedOutput.vrr === 0 ? "off" : panel.selectedOutput.vrr === 2 ? "fullscreen" : "on"}`
                                            : "Enable this output to adjust it"
                                        color: Theme.muted
                                        font.family: Theme.fontSans
                                        font.pixelSize: Theme.fontCaption
                                        elide: Text.ElideRight
                                    }
                                }

                                ActionButton {
                                    id: vrrButton
                                    label: panel.selectedOutput && panel.selectedOutput.vrr !== 0 ? "VRR on" : "VRR off"
                                    selected: panel.selectedOutput !== null && panel.selectedOutput.vrr !== 0
                                    enabled: panel.selectedOutput !== null && panel.selectedOutput.enabled && !panel.actionRunning
                                    onActivated: panel.toggleVrr()
                                }
                            }

                            PanelDivider {
                                vertical: false
                                width: parent.width
                            }
                            Text {
                                text: panel.selectedOutput
                                    ? `SIGNAL  ·  ${panel.selectedOutput.refreshRate.toFixed(0)} HZ  ·  ${panel.bitdepthFor(panel.selectedOutput)}-BIT  ·  ${String(panel.selectedOutput.colorManagementPreset).toUpperCase()}  ·  ${panel.selectedOutput.currentFormat}`
                                    : "SIGNAL"
                                color: Theme.accent
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.DemiBold
                            }

                            Flow {
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: panel.availableRefreshPresets(panel.selectedOutput)

                                    ActionButton {
                                        required property var modelData
                                        label: `${Number(modelData)} Hz`
                                        selected: panel.selectedOutput !== null && Math.abs(panel.selectedOutput.refreshRate - Number(modelData)) < 0.5
                                        enabled: !panel.actionRunning && panel.pendingDisplayRollbackCommand.length === 0
                                        onActivated: panel.setRefresh(Number(modelData))
                                    }
                                }

                                ActionButton {
                                    label: "8-bit"
                                    selected: panel.bitdepthFor(panel.selectedOutput) === 8
                                    enabled: !panel.actionRunning && panel.pendingDisplayRollbackCommand.length === 0
                                    onActivated: panel.setBitdepth(8)
                                }

                                ActionButton {
                                    label: "10-bit"
                                    selected: panel.bitdepthFor(panel.selectedOutput) === 10
                                    enabled: !panel.actionRunning && panel.pendingDisplayRollbackCommand.length === 0
                                    onActivated: panel.setBitdepth(10)
                                }

                                ActionButton {
                                    label: "SDR"
                                    selected: panel.colorModeFor(panel.selectedOutput) === "sdr"
                                    enabled: !panel.actionRunning && panel.pendingDisplayRollbackCommand.length === 0
                                    onActivated: panel.setColorMode("sdr")
                                }

                                ActionButton {
                                    label: "Auto HDR"
                                    selected: panel.colorModeFor(panel.selectedOutput) === "auto"
                                    enabled: !panel.actionRunning && panel.pendingDisplayRollbackCommand.length === 0
                                    onActivated: panel.setColorMode("auto")
                                }

                                ActionButton {
                                    label: "HDR on"
                                    selected: panel.colorModeFor(panel.selectedOutput) === "hdr"
                                    enabled: !panel.actionRunning && panel.pendingDisplayRollbackCommand.length === 0
                                    onActivated: panel.setColorMode("hdr")
                                }
                            }

                            Row {
                                visible: panel.pendingDisplayRollbackCommand.length > 0
                                width: parent.width
                                spacing: 8

                                Text {
                                    width: parent.width - keepDisplayButton.width - revertDisplayButton.width - 16
                                    height: keepDisplayButton.height
                                    verticalAlignment: Text.AlignVCenter
                                    text: `${panel.pendingDisplayDescription}  ·  reverting in 15 seconds`
                                    color: Theme.warning
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontCaption
                                    elide: Text.ElideRight
                                }

                                ActionButton {
                                    id: revertDisplayButton
                                    label: "Revert"
                                    destructive: true
                                    enabled: !panel.actionRunning
                                    onActivated: panel.revertDisplayChange()
                                }

                                ActionButton {
                                    id: keepDisplayButton
                                    label: "Keep"
                                    enabled: !panel.actionRunning
                                    onActivated: panel.confirmDisplayChange()
                                }
                            }

                            PanelDivider {
                                vertical: false
                                width: parent.width
                            }


                            Text {
                                text: "SAFE SCALE"
                                color: Theme.accent
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.DemiBold
                            }

                            Flow {
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: panel.validScalePresets(panel.selectedOutput)

                                    ActionButton {
                                        required property var modelData
                                        label: `${Number(modelData).toFixed(Number(modelData) % 1 === 0 ? 0 : 2)}×`
                                        selected: panel.selectedOutput !== null && Math.abs(panel.selectedOutput.scale - Number(modelData)) < 0.01
                                        enabled: !panel.actionRunning
                                        onActivated: panel.setScale(Number(modelData))
                                    }
                                }
                            }

                            Text {
                                visible: panel.selectedOutput !== null && panel.selectedOutput.enabled && panel.validScalePresets(panel.selectedOutput).length <= 1
                                text: "No additional preset divides the current mode into whole logical pixels"
                                color: Theme.muted
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 112
                        radius: Theme.radiusMedium
                        color: Theme.backgroundDark
                        border.color: Theme.backgroundDarker
                        border.width: Theme.borderWidth

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 14
                            }
                            spacing: 9

                            Row {
                                width: parent.width

                                Text {
                                    width: parent.width - brightnessValue.width
                                    text: panel.brightnessAvailable ? `BRIGHTNESS  ·  ${panel.brightnessBackend === "ddc" ? "DDC" : "BACKLIGHT"}` : "BRIGHTNESS"
                                    color: panel.brightnessAvailable ? Theme.accent : Theme.muted
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontCaption
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    id: brightnessValue
                                    text: panel.brightnessPercent >= 0 ? `${panel.brightnessPercent}%` : "UNAVAILABLE"
                                    color: panel.brightnessAvailable ? Theme.foreground : Theme.muted
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontCaption
                                }
                            }

                            PercentSlider {
                                width: parent.width
                                value: panel.brightnessPercent
                                available: panel.brightnessAvailable && panel.brightnessPercent >= 0 && !panel.actionRunning
                                onRequested: value => panel.setBrightness(value)
                            }

                            Text {
                                width: parent.width
                                text: panel.selectedOutput === null ? "Select an output"
                                    : panel.brightnessAvailable ? `Hardware brightness for ${panel.selectedOutput.name}`
                                    : panel.selectedOutput.internal ? "brightnessctl did not report a backlight device"
                                    : "No matching DDC/CI display was detected"
                                color: Theme.muted
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 126
                        radius: Theme.radiusMedium
                        color: Theme.backgroundDark
                        border.color: Theme.backgroundDarker
                        border.width: Theme.borderWidth
                        opacity: panel.nightLightAvailable ? 1 : 0.55

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 14
                            }
                            spacing: 10

                            Row {
                                width: parent.width

                                Column {
                                    width: parent.width - nightToggle.width
                                    spacing: 2
                                    Text {
                                        text: "NIGHT LIGHT"
                                        color: panel.nightLightAvailable ? Theme.accent : Theme.muted
                                        font.family: Theme.fontSans
                                        font.pixelSize: Theme.fontCaption
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        text: panel.nightLightAvailable
                                            ? panel.nightLightEnabled ? `${panel.nightTemperature} K  ·  warmer colors active` : "Color temperature filter off"
                                            : "hyprsunset is not running"
                                        color: Theme.muted
                                        font.family: Theme.fontSans
                                        font.pixelSize: Theme.fontCaption
                                    }
                                }

                                ActionButton {
                                    id: nightToggle
                                    label: panel.nightLightEnabled ? "On" : "Off"
                                    selected: panel.nightLightEnabled
                                    enabled: panel.nightLightAvailable && !panel.actionRunning
                                    onActivated: panel.toggleNightLight()
                                }
                            }

                            Flow {
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    model: [2500, 3500, 4500, 5500]

                                    ActionButton {
                                        required property var modelData
                                        label: `${modelData} K`
                                        selected: panel.nightLightEnabled && panel.nightTemperature === Number(modelData)
                                        enabled: panel.nightLightAvailable && !panel.actionRunning
                                        onActivated: panel.setNightTemperature(Number(modelData))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: footerDivider
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: 42
                }
                height: 1
                color: Theme.backgroundDarker
            }

            Text {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: 20
                    rightMargin: 210
                    bottomMargin: 13
                }
                text: panel.operationStatus.length > 0 ? panel.operationStatus : "Changes apply for this Hyprland session"
                color: panel.operationStatus.includes("failed") || panel.operationStatus.includes("cannot") || panel.operationStatus.includes("unavailable") ? Theme.warning : Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
                elide: Text.ElideRight
            }

            Text {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: 20
                    bottomMargin: 13
                }
                text: "esc or click outside to close"
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
            }

            Rectangle {
                visible: panel.pendingDisableName.length > 0
                anchors.fill: parent
                radius: parent.radius
                color: Theme.withAlpha(Theme.background, 0.92)
                z: 20

                MouseArea {
                    anchors.fill: parent
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(430, parent.width - 48)
                    height: 220
                    radius: Theme.radiusLarge
                    color: Theme.backgroundDark
                    border.color: Theme.error
                    border.width: Theme.borderWidth

                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 24
                        }
                        spacing: 10

                        Text {
                            text: "Disable display?"
                            color: Theme.foreground
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontTitle
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width
                            text: `${panel.pendingDisableName} will stop displaying immediately. Windows and workspaces may move to another active output.`
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontBody
                            wrapMode: Text.Wrap
                        }

                        Text {
                            width: parent.width
                            text: `${panel.activeMonitorCount - 1} display${panel.activeMonitorCount - 1 === 1 ? "" : "s"} will remain active.`
                            color: Theme.warning
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontCaption
                        }
                    }

                    Row {
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                            margins: 20
                        }
                        spacing: 10

                        ActionButton {
                            label: "Cancel"
                            onActivated: panel.cancelDisable()
                        }

                        ActionButton {
                            label: "Disable output"
                            destructive: true
                            enabled: panel.activeMonitorCount > 1 && !panel.actionRunning
                            onActivated: panel.confirmDisable()
                        }
                    }
                }
            }
        }
    }
}
