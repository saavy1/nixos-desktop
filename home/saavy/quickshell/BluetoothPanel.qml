import Quickshell
import Quickshell.Io
import QtQuick
import qs.ui

PopupPanel {
    id: root

    property bool hasAdapter: false
    property string adapterAddress: ""
    property string adapterName: ""
    property bool powered: false
    property bool discovering: false
    property bool pairable: false
    property var devices: []
    property string operationStatus: ""
    property bool actionRunning: false
    property string actionDescription: ""
    property string pendingRemoval: ""
    property var pendingInfo: []

    readonly property var pairedDevices: devices.filter(device => device.paired)
    readonly property var discoveredDevices: devices.filter(device => !device.paired)
    readonly property bool refreshing: adapterProc.running || deviceProc.running || infoProc.running
    readonly property bool scanning: scanProc.running || discovering
    readonly property int connectedCount: devices.filter(device => device.connected).length
    readonly property string adapterSummary: {
        if (!hasAdapter)
            return "No Bluetooth adapter"
        if (!powered)
            return `${adapterName || adapterAddress || "Bluetooth"} is powered off`
        if (scanning)
            return `Scanning · ${pairedDevices.length} paired · ${discoveredDevices.length} nearby`
        return `${pairedDevices.length} paired · ${connectedCount} connected`
    }

    name: "bluetooth"
    title: "Bluetooth"
    subtitle: adapterSummary.toLowerCase()
    cardWidth: 460

    function outputLines(text): var {
        return text.split("\n").map(line => line.trim()).filter(line => line.length > 0)
    }

    function validAddress(address): bool {
        return /^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$/.test(address)
    }

    function parseYes(value): bool {
        return value.trim().toLowerCase() === "yes"
    }

    function defaultDevice(address, name): var {
        return {
            address: address,
            name: name || address,
            alias: name || address,
            icon: "",
            paired: false,
            bonded: false,
            trusted: false,
            blocked: false,
            connected: false,
            battery: -1,
            detailsLoaded: false
        }
    }

    function parseAdapter(text): void {
        let found = false
        let address = ""
        let name = ""
        let isPowered = false
        let isDiscovering = false
        let isPairable = false

        for (const line of outputLines(text)) {
            const controller = line.match(/^Controller\s+([0-9A-Fa-f:]{17})(?:\s+(.+?))?(?:\s+\[default\])?$/)
            if (controller) {
                found = true
                address = controller[1]
                if (controller[2])
                    name = controller[2]
                continue
            }

            const separator = line.indexOf(":")
            if (separator < 0)
                continue
            const key = line.slice(0, separator).trim()
            const value = line.slice(separator + 1).trim()
            if (key === "Name")
                name = value
            else if (key === "Powered")
                isPowered = parseYes(value)
            else if (key === "Discovering")
                isDiscovering = parseYes(value)
            else if (key === "Pairable")
                isPairable = parseYes(value)
        }

        adapterProc.adapterSeen = found
        if (found) {
            hasAdapter = true
            adapterAddress = address
            adapterName = name
            powered = isPowered
            discovering = isDiscovering
            pairable = isPairable
        }
    }

    function parseDevices(text): var {
        const parsed = []
        const seen = ({})
        for (const line of outputLines(text)) {
            const match = line.match(/^Device\s+([0-9A-Fa-f:]{17})(?:\s+(.*))?$/)
            if (!match || !validAddress(match[1]))
                continue
            const address = match[1].toUpperCase()
            if (seen[address])
                continue
            seen[address] = true
            parsed.push(defaultDevice(address, match[2] || address))
        }
        return parsed
    }

    function parseBattery(value): int {
        const parenthesized = value.match(/\((\d{1,3})\)/)
        if (parenthesized)
            return Math.max(0, Math.min(100, Number(parenthesized[1])))
        const decimal = value.match(/^(\d{1,3})$/)
        if (decimal)
            return Math.max(0, Math.min(100, Number(decimal[1])))
        return -1
    }

    function applyDeviceInfo(address, text): void {
        let index = -1
        for (let deviceIndex = 0; deviceIndex < devices.length; ++deviceIndex) {
            if (devices[deviceIndex].address === address) {
                index = deviceIndex
                break
            }
        }
        if (index < 0)
            return

        const current = devices[index]
        const updated = {
            address: current.address,
            name: current.name,
            alias: current.alias,
            icon: current.icon,
            paired: current.paired,
            bonded: current.bonded,
            trusted: current.trusted,
            blocked: current.blocked,
            connected: current.connected,
            battery: current.battery,
            detailsLoaded: true
        }

        for (const line of outputLines(text)) {
            const separator = line.indexOf(":")
            if (separator < 0)
                continue
            const key = line.slice(0, separator).trim()
            const value = line.slice(separator + 1).trim()
            if (key === "Name")
                updated.name = value || updated.name
            else if (key === "Alias")
                updated.alias = value || updated.alias
            else if (key === "Icon")
                updated.icon = value
            else if (key === "Paired")
                updated.paired = parseYes(value)
            else if (key === "Bonded")
                updated.bonded = parseYes(value)
            else if (key === "Trusted")
                updated.trusted = parseYes(value)
            else if (key === "Blocked")
                updated.blocked = parseYes(value)
            else if (key === "Connected")
                updated.connected = parseYes(value)
            else if (key === "Battery Percentage")
                updated.battery = parseBattery(value)
        }

        const replacement = devices.slice()
        replacement[index] = updated
        devices = replacement
    }

    function beginDeviceInfo(parsedDevices): void {
        devices = parsedDevices
        pendingInfo = parsedDevices.map(device => device.address)
        startNextDeviceInfo()
    }

    function startNextDeviceInfo(): void {
        if (infoProc.running || pendingInfo.length === 0 || !shown)
            return
        const queue = pendingInfo.slice()
        const address = queue.shift()
        pendingInfo = queue
        if (!validAddress(address)) {
            startNextDeviceInfo()
            return
        }
        infoProc.currentAddress = address
        infoProc.command = ["bluetoothctl", "info", address]
        infoProc.running = true
    }

    function requestRefresh(): void {
        if (!shown || refreshing || actionRunning)
            return
        adapterProc.running = true
    }

    function runAction(argv, description): void {
        if (actionProc.running)
            return
        actionDescription = description
        operationStatus = `${description}…`
        actionProc.command = argv
        actionProc.running = true
    }

    function togglePower(): void {
        if (!hasAdapter) {
            operationStatus = "No Bluetooth adapter is available"
            return
        }
        if (powered && scanProc.running) {
            scanProc.stopRequested = true
            scanProc.running = false
        }
        runAction(["bluetoothctl", "power", powered ? "off" : "on"], powered ? "Turning Bluetooth off" : "Turning Bluetooth on")
    }

    function toggleScan(): void {
        if (!hasAdapter) {
            operationStatus = "No Bluetooth adapter is available"
            return
        }
        if (!powered) {
            operationStatus = "Turn Bluetooth on before scanning"
            return
        }
        if (scanning) {
            if (scanProc.running) {
                scanProc.stopRequested = true
                scanProc.running = false
            }
            runAction(["bluetoothctl", "scan", "off"], "Stopping scan")
        } else {
            operationStatus = "Scanning for nearby devices…"
            scanProc.stopRequested = false
            scanProc.running = true
        }
    }

    function connectDevice(device): void {
        if (!validAddress(device.address))
            return
        runAction(["bluetoothctl", device.connected ? "disconnect" : "connect", device.address], `${device.connected ? "Disconnecting" : "Connecting to"} ${device.alias || device.name}`)
    }

    function toggleTrust(device): void {
        if (!validAddress(device.address))
            return
        runAction(["bluetoothctl", device.trusted ? "untrust" : "trust", device.address], `${device.trusted ? "Removing trust from" : "Trusting"} ${device.alias || device.name}`)
    }

    function removeDevice(device): void {
        if (!validAddress(device.address))
            return
        if (pendingRemoval !== device.address) {
            pendingRemoval = device.address
            operationStatus = `Click Confirm remove to forget ${device.alias || device.name}`
            confirmationTimer.restart()
            return
        }
        pendingRemoval = ""
        confirmationTimer.stop()
        runAction(["bluetoothctl", "remove", device.address], `Removing ${device.alias || device.name}`)
    }

    function deviceDetails(device): string {
        const states = []
        if (!device.detailsLoaded)
            return "Checking device details…"
        states.push(device.paired ? "Paired" : "Discovered")
        if (device.connected)
            states.push("Connected")
        if (device.trusted)
            states.push("Trusted")
        if (device.blocked)
            states.push("Blocked")
        if (device.battery >= 0)
            states.push(`${device.battery}% battery`)
        return states.join(" · ")
    }

    function deviceIcon(device): string {
        const icon = device.icon || ""
        if (icon.startsWith("audio-head"))
            return "headphones"
        if (icon.startsWith("audio"))
            return "speaker"
        if (icon === "input-keyboard")
            return "keyboard"
        if (icon === "input-mouse" || icon === "input-tablet")
            return "mouse"
        if (icon === "input-gaming")
            return "gamepad-2"
        if (icon === "phone")
            return "smartphone"
        if (icon === "computer")
            return "laptop"
        if (icon.startsWith("video"))
            return "tv"
        return "bluetooth"
    }

    onOpening: {
        operationStatus = ""
        refreshTimer.start()
        requestRefresh()
    }

    onShownChanged: {
        if (shown)
            return
        refreshTimer.stop()
        pendingInfo = []
        pendingRemoval = ""
        if (scanProc.running) {
            scanProc.stopRequested = true
            scanProc.running = false
        }
    }

    // Device row: ListItem styling with a third mono line for the address and
    // connect / trust / remove actions on the right.
    component DeviceRow: ListItem {
        id: deviceRow

        required property var device
        readonly property bool confirming: root.pendingRemoval === device.address

        width: parent ? parent.width : 0
        interactive: false
        hoverHighlight: true
        selected: device.connected
        icon: root.deviceIcon(device)
        title: device.alias || device.name || device.address
        subtitle: root.deviceDetails(device)
        subtitleTone: device.connected ? "success" : "faint"
        detail: device.address

        Button {
            anchors.verticalCenter: parent.verticalCenter
            compact: true
            text: deviceRow.device.connected ? "Disconnect" : "Connect"
            icon: deviceRow.device.connected ? "unlink" : "link"
            enabled: !root.actionRunning && root.powered && !deviceRow.device.blocked
            onClicked: root.connectDevice(deviceRow.device)
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 28
            implicitHeight: 26
            iconSize: 14
            icon: deviceRow.device.trusted ? "shield-check" : "shield"
            tone: deviceRow.device.trusted ? "success" : "faint"
            enabled: !root.actionRunning && deviceRow.device.detailsLoaded
            onClicked: root.toggleTrust(deviceRow.device)
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: !deviceRow.confirming
            implicitWidth: 28
            implicitHeight: 26
            iconSize: 14
            icon: "trash-2"
            tone: "faint"
            enabled: !root.actionRunning
            onClicked: root.removeDevice(deviceRow.device)
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            visible: deviceRow.confirming
            compact: true
            variant: "danger"
            text: "Confirm remove"
            enabled: !root.actionRunning
            onClicked: root.removeDevice(deviceRow.device)
        }
    }

    Timer {
        id: refreshTimer
        interval: root.scanning ? 5000 : 15000
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: root.requestRefresh()
    }

    Timer {
        id: refreshDelay
        interval: 650
        repeat: false
        onTriggered: root.requestRefresh()
    }

    Timer {
        id: confirmationTimer
        interval: 8000
        repeat: false
        onTriggered: {
            root.pendingRemoval = ""
            if (root.operationStatus.startsWith("Click Confirm remove"))
                root.operationStatus = "Removal cancelled"
        }
    }

    Process {
        id: scanProc

        property bool stopRequested: false
        property string failureText: ""

        command: ["bluetoothctl", "--timeout", "30", "scan", "on"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (root.shown && data.startsWith("[NEW] Device") && !refreshDelay.running)
                    refreshDelay.restart()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: scanProc.failureText = text.trim()
        }
        onStarted: {
            failureText = ""
            if (root.shown)
                refreshDelay.restart()
        }
        onExited: (exitCode, exitStatus) => {
            if (root.shown && !stopRequested) {
                root.operationStatus = exitCode === 0
                    ? "Scan finished"
                    : `Scan failed${failureText.length > 0 ? ` — ${failureText.split("\n")[0]}` : ""}`
            }
            if (root.shown)
                refreshDelay.restart()
        }
    }

    Process {
        id: adapterProc

        property bool adapterSeen: false

        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.parseAdapter(text)
        }
        stderr: StdioCollector {}
        onStarted: adapterSeen = false
        onExited: (exitCode, exitStatus) => {
            root.hasAdapter = adapterSeen
            if (!adapterSeen) {
                root.adapterAddress = ""
                root.adapterName = ""
                root.powered = false
                root.discovering = false
                root.pairable = false
                root.devices = []
                root.pendingInfo = []
                if (root.shown && root.operationStatus.length === 0)
                    root.operationStatus = "No Bluetooth adapter detected"
                return
            }
            if (root.shown && !deviceProc.running)
                deviceProc.running = true
        }
    }

    Process {
        id: deviceProc

        property bool receivedOutput: false

        command: ["bluetoothctl", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                deviceProc.receivedOutput = true
                root.beginDeviceInfo(root.parseDevices(text))
            }
        }
        stderr: StdioCollector {}
        onStarted: receivedOutput = false
        onExited: (exitCode, exitStatus) => {
            if (!receivedOutput) {
                root.devices = []
                root.pendingInfo = []
            }
        }
    }

    Process {
        id: infoProc

        property string currentAddress: ""
        property string collectedOutput: ""

        stdout: StdioCollector {
            onStreamFinished: infoProc.collectedOutput = text
        }
        stderr: StdioCollector {}
        onStarted: collectedOutput = ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root.validAddress(currentAddress))
                root.applyDeviceInfo(currentAddress, collectedOutput)
            currentAddress = ""
            root.startNextDeviceInfo()
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
            root.actionRunning = true
        }
        onExited: (exitCode, exitStatus) => {
            root.actionRunning = false
            root.operationStatus = exitCode === 0
                ? `${root.actionDescription} succeeded`
                : `${root.actionDescription} failed${failureText.length > 0 ? ` — ${failureText.split("\n")[0]}` : ""}`
            if (root.shown)
                refreshDelay.restart()
        }
    }


    headerTrailing: [
        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            enabled: root.hasAdapter && !root.actionRunning
            checked: root.hasAdapter && root.powered
            onToggled: root.togglePower()
        },
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "radar"
            label: root.scanning ? "stop" : "scan"
            active: root.scanning
            enabled: root.hasAdapter && root.powered && !root.actionRunning
            onClicked: root.toggleScan()
        },
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "refresh-cw"
            label: root.refreshing ? "checking" : ""
            enabled: !root.refreshing && !root.actionRunning
            onClicked: {
                root.operationStatus = "Refreshing Bluetooth state…"
                root.requestRefresh()
            }
        }
    ]

    footer: [
        Label {
            width: parent.width - footerHint.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: root.operationStatus.length > 0 ? root.operationStatus : "Device addresses are passed directly to bluetoothctl"
            variant: "small"
            tone: root.operationStatus.includes("failed") || root.operationStatus.includes("Confirm") ? "warning" : "faint"
        },
        Label {
            id: footerHint

            anchors.verticalCenter: parent.verticalCenter
            text: "esc close"
            variant: "numeric"
            font.pixelSize: Theme.fontSize.caption
            font.weight: Font.Normal
            tone: "disabled"
        }
    ]

    ListItem {
        width: parent.width
        interactive: false
        icon: root.hasAdapter && root.powered ? "bluetooth" : "bluetooth-off"
        title: root.hasAdapter ? (root.adapterName || "Bluetooth controller") : "No adapter detected"
        subtitle: root.hasAdapter
            ? `${root.adapterAddress}${root.pairable ? " · Pairable" : ""}${root.discovering ? " · Discovering devices" : ""}`
            : "Bluetooth controls will appear when an adapter is available"
        trailing: !root.hasAdapter ? "none" : root.powered ? "on" : "off"
        trailingTone: !root.hasAdapter ? "faint" : root.powered ? "success" : "warning"

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 3.5
            color: !root.hasAdapter ? Theme.text.disabled : root.powered ? Theme.success : Theme.warning
        }
    }

    SectionHeader {
        width: parent.width
        text: "Paired devices"
        trailing: String(root.pairedDevices.length)
    }

    Column {
        width: parent.width
        spacing: 2

        Label {
            visible: root.pairedDevices.length === 0
            width: parent.width
            topPadding: Theme.space.xs
            text: root.hasAdapter && root.powered ? "No paired devices" : root.hasAdapter ? "Bluetooth is powered off" : "No Bluetooth adapter available"
            variant: "small"
            tone: "faint"
        }

        Repeater {
            model: ScriptModel {
                values: root.pairedDevices
            }

            delegate: DeviceRow {
                required property var modelData

                device: modelData
            }
        }
    }

    SectionHeader {
        width: parent.width
        text: "Discovered devices"
        trailing: String(root.discoveredDevices.length)
    }

    Column {
        width: parent.width
        spacing: 2

        Label {
            visible: root.discoveredDevices.length === 0
            width: parent.width
            topPadding: Theme.space.xs
            wrapMode: Text.WordWrap
            text: !root.hasAdapter
                ? "Attach a Bluetooth adapter to discover devices"
                : !root.powered
                    ? "Turn Bluetooth on to discover devices"
                    : root.discovering
                        ? "Scanning for nearby devices…"
                        : "No nearby devices cached · start a scan to discover"
            variant: "small"
            tone: "faint"
        }

        Repeater {
            model: ScriptModel {
                values: root.discoveredDevices
            }

            delegate: DeviceRow {
                required property var modelData

                device: modelData
            }
        }
    }
}
