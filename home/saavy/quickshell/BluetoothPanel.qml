import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: panel

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

    visible: PopupController.isOpen("bluetooth")
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
    WlrLayershell.namespace: "solitude-bluetooth"

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
        if (infoProc.running || pendingInfo.length === 0 || !visible)
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
        if (!visible || refreshing || actionRunning)
            return
        adapterProc.running = true
    }

    function open(): void {
        PopupController.open("bluetooth")
        operationStatus = ""
        requestRefresh()
    }

    function close(): void {
        pendingRemoval = ""
        PopupController.close("bluetooth")
    }

    function toggle(): void {
        if (visible)
            close()
        else
            open()
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

    onVisibleChanged: {
        if (visible) {
            refreshTimer.start()
            requestRefresh()
        } else {
            refreshTimer.stop()
            pendingInfo = []
            pendingRemoval = ""
            if (scanProc.running) {
                scanProc.stopRequested = true
                scanProc.running = false
            }
        }
    }

    component BluetoothDeviceRow: Rectangle {
        id: deviceRow

        required property var device

        height: 66
        radius: Theme.radiusMedium
        color: device.connected ? Theme.selection : rowHover.containsMouse ? Theme.backgroundDark : "transparent"
        border.color: device.connected ? Theme.accent : "transparent"
        border.width: Theme.borderWidth

        Rectangle {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 12
            }
            width: 9
            height: 9
            radius: 5
            color: deviceRow.device.connected ? Theme.success : deviceRow.device.paired ? Theme.warning : Theme.muted
        }

        Column {
            anchors {
                left: parent.left
                right: actions.left
                verticalCenter: parent.verticalCenter
                leftMargin: 32
                rightMargin: 12
            }
            spacing: 3

            Text {
                width: parent.width
                text: deviceRow.device.alias || deviceRow.device.name || deviceRow.device.address
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontBody
                font.weight: deviceRow.device.connected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: panel.deviceDetails(deviceRow.device)
                color: deviceRow.device.connected ? Theme.success : Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: deviceRow.device.address
                color: Theme.muted
                opacity: 0.7
                font.family: Theme.fontMono
                font.pixelSize: Math.max(9, Theme.fontCaption - 1)
                elide: Text.ElideRight
            }
        }

        Row {
            id: actions
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 8
            }
            spacing: 6

            Rectangle {
                width: connectLabel.implicitWidth + 20
                height: 30
                radius: Theme.radiusSmall
                color: connectArea.containsMouse ? Theme.selection : Theme.backgroundDarker

                Text {
                    id: connectLabel
                    anchors.centerIn: parent
                    text: deviceRow.device.connected ? "Disconnect" : "Connect"
                    color: deviceRow.device.connected ? Theme.warning : Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                }

                MouseArea {
                    id: connectArea
                    anchors.fill: parent
                    enabled: !panel.actionRunning && panel.powered && !deviceRow.device.blocked
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: panel.connectDevice(deviceRow.device)
                }
            }

            Rectangle {
                width: trustLabel.implicitWidth + 20
                height: 30
                radius: Theme.radiusSmall
                color: trustArea.containsMouse ? Theme.selection : Theme.backgroundDarker

                Text {
                    id: trustLabel
                    anchors.centerIn: parent
                    text: deviceRow.device.trusted ? "Untrust" : "Trust"
                    color: deviceRow.device.trusted ? Theme.warning : Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                }

                MouseArea {
                    id: trustArea
                    anchors.fill: parent
                    enabled: !panel.actionRunning && deviceRow.device.detailsLoaded
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: panel.toggleTrust(deviceRow.device)
                }
            }

            Rectangle {
                width: removeLabel.implicitWidth + 20
                height: 30
                radius: Theme.radiusSmall
                color: removeArea.containsMouse ? Theme.selection : Theme.backgroundDarker

                Text {
                    id: removeLabel
                    anchors.centerIn: parent
                    text: panel.pendingRemoval === deviceRow.device.address ? "Confirm remove" : "Remove"
                    color: panel.pendingRemoval === deviceRow.device.address ? Theme.error : Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                }

                MouseArea {
                    id: removeArea
                    anchors.fill: parent
                    enabled: !panel.actionRunning
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.removeDevice(deviceRow.device)
                }
            }
        }

        MouseArea {
            id: rowHover
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
        }
    }

    IpcHandler {
        target: "bluetooth"

        function toggle(): void {
            panel.toggle()
        }

        function close(): void {
            panel.close()
        }
    }

    Timer {
        id: refreshTimer
        interval: panel.scanning ? 5000 : 15000
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: panel.requestRefresh()
    }

    Timer {
        id: refreshDelay
        interval: 650
        repeat: false
        onTriggered: panel.requestRefresh()
    }

    Timer {
        id: confirmationTimer
        interval: 8000
        repeat: false
        onTriggered: {
            panel.pendingRemoval = ""
            if (panel.operationStatus.startsWith("Click Confirm remove"))
                panel.operationStatus = "Removal cancelled"
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
                if (panel.visible && data.startsWith("[NEW] Device") && !refreshDelay.running)
                    refreshDelay.restart()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: scanProc.failureText = text.trim()
        }
        onStarted: {
            failureText = ""
            if (panel.visible)
                refreshDelay.restart()
        }
        onExited: (exitCode, exitStatus) => {
            if (panel.visible && !stopRequested) {
                panel.operationStatus = exitCode === 0
                    ? "Scan finished"
                    : `Scan failed${failureText.length > 0 ? ` — ${failureText.split("\n")[0]}` : ""}`
            }
            if (panel.visible)
                refreshDelay.restart()
        }
    }

    Process {
        id: adapterProc

        property bool adapterSeen: false

        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: panel.parseAdapter(text)
        }
        stderr: StdioCollector {}
        onStarted: adapterSeen = false
        onExited: (exitCode, exitStatus) => {
            panel.hasAdapter = adapterSeen
            if (!adapterSeen) {
                panel.adapterAddress = ""
                panel.adapterName = ""
                panel.powered = false
                panel.discovering = false
                panel.pairable = false
                panel.devices = []
                panel.pendingInfo = []
                if (panel.visible && panel.operationStatus.length === 0)
                    panel.operationStatus = "No Bluetooth adapter detected"
                return
            }
            if (panel.visible && !deviceProc.running)
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
                panel.beginDeviceInfo(panel.parseDevices(text))
            }
        }
        stderr: StdioCollector {}
        onStarted: receivedOutput = false
        onExited: (exitCode, exitStatus) => {
            if (!receivedOutput) {
                panel.devices = []
                panel.pendingInfo = []
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
            if (exitCode === 0 && panel.validAddress(currentAddress))
                panel.applyDeviceInfo(currentAddress, collectedOutput)
            currentAddress = ""
            panel.startNextDeviceInfo()
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
            panel.operationStatus = exitCode === 0
                ? `${panel.actionDescription} succeeded`
                : `${panel.actionDescription} failed${failureText.length > 0 ? ` — ${failureText.split("\n")[0]}` : ""}`
            if (panel.visible)
                refreshDelay.restart()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: panel.visible
        onActivated: panel.close()
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
        width: Math.min(780, panel.width - 80)
        height: Math.min(780, panel.height - 100)

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
            height: 58

            Column {
                anchors {
                    left: parent.left
                    right: headerControls.left
                    verticalCenter: parent.verticalCenter
                    rightMargin: 18
                }
                spacing: 3

                Text {
                    width: parent.width
                    text: "Bluetooth"
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: panel.adapterSummary
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                    elide: Text.ElideRight
                }
            }

            Row {
                id: headerControls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: powerLabel.implicitWidth + 24
                    height: 34
                    radius: Theme.radiusMedium
                    color: powerArea.containsMouse ? Theme.selection : Theme.backgroundDark
                    opacity: panel.hasAdapter ? 1 : 0.55

                    Text {
                        id: powerLabel
                        anchors.centerIn: parent
                        text: panel.hasAdapter ? (panel.powered ? "Bluetooth on" : "Bluetooth off") : "No adapter"
                        color: panel.powered && panel.hasAdapter ? Theme.success : Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: powerArea
                        anchors.fill: parent
                        enabled: panel.hasAdapter && !panel.actionRunning
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: panel.togglePower()
                    }
                }

                Rectangle {
                    width: scanLabel.implicitWidth + 24
                    height: 34
                    radius: Theme.radiusMedium
                    color: scanArea.containsMouse ? Theme.selection : Theme.backgroundDark
                    opacity: panel.hasAdapter && panel.powered ? 1 : 0.55

                    Text {
                        id: scanLabel
                        anchors.centerIn: parent
                        text: panel.scanning ? "Stop scan" : "Start scan"
                        color: panel.scanning ? Theme.warning : Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: scanArea
                        anchors.fill: parent
                        enabled: panel.hasAdapter && panel.powered && !panel.actionRunning
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: panel.toggleScan()
                    }
                }

                Rectangle {
                    width: 76
                    height: 34
                    radius: Theme.radiusMedium
                    color: refreshArea.containsMouse ? Theme.selection : Theme.backgroundDark

                    Text {
                        anchors.centerIn: parent
                        text: panel.refreshing ? "Checking" : "Refresh"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        enabled: !panel.refreshing && !panel.actionRunning
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            panel.operationStatus = "Refreshing Bluetooth state…"
                            panel.requestRefresh()
                        }
                    }
                }
            }
        }

        Rectangle {
            id: adapterCard
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                topMargin: 8
                leftMargin: 20
                rightMargin: 20
            }
            height: 58
            radius: Theme.radiusMedium
            color: Theme.backgroundDark
            border.color: !panel.hasAdapter ? Theme.border : panel.powered ? Theme.success : Theme.warning
            border.width: Theme.borderWidth

            Rectangle {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 14
                }
                width: 10
                height: 10
                radius: 5
                color: !panel.hasAdapter ? Theme.muted : panel.powered ? Theme.success : Theme.warning
            }

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 36
                    rightMargin: 14
                }
                spacing: 2

                Text {
                    width: parent.width
                    text: panel.hasAdapter ? (panel.adapterName || "Bluetooth controller") : "No adapter detected"
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: panel.hasAdapter
                        ? `${panel.adapterAddress}${panel.pairable ? " · Pairable" : ""}${panel.discovering ? " · Discovering devices" : ""}`
                        : "Bluetooth controls will appear when an adapter is available"
                    color: Theme.muted
                    font.family: panel.hasAdapter ? Theme.fontMono : Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                    elide: Text.ElideRight
                }
            }
        }

        Flickable {
            id: deviceFlick
            anchors {
                top: adapterCard.bottom
                left: parent.left
                right: parent.right
                bottom: footer.top
                topMargin: 14
                leftMargin: 20
                rightMargin: 20
                bottomMargin: 8
            }
            contentWidth: width
            contentHeight: deviceColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: deviceColumn
                width: deviceFlick.width
                spacing: 5

                Text {
                    width: parent.width
                    leftPadding: 2
                    text: `PAIRED DEVICES  ${panel.pairedDevices.length}`
                    color: Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.DemiBold
                }

                Text {
                    visible: panel.pairedDevices.length === 0
                    width: parent.width
                    height: visible ? 50 : 0
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: panel.hasAdapter && panel.powered ? "No paired devices" : panel.hasAdapter ? "Bluetooth is powered off" : "No Bluetooth adapter available"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontBody
                }

                Repeater {
                    model: ScriptModel { values: panel.pairedDevices }
                    delegate: BluetoothDeviceRow {
                        required property var modelData
                        width: deviceColumn.width
                        device: modelData
                    }
                }

                Item { width: 1; height: 8 }

                Text {
                    width: parent.width
                    leftPadding: 2
                    text: `DISCOVERED DEVICES  ${panel.discoveredDevices.length}`
                    color: Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.DemiBold
                }

                Text {
                    visible: panel.discoveredDevices.length === 0
                    width: parent.width
                    height: visible ? 56 : 0
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: !panel.hasAdapter
                        ? "Attach a Bluetooth adapter to discover devices"
                        : !panel.powered
                            ? "Turn Bluetooth on to discover devices"
                            : panel.discovering
                                ? "Scanning for nearby devices…"
                                : "No nearby devices cached · start a scan to discover"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontBody
                }

                Repeater {
                    model: ScriptModel { values: panel.discoveredDevices }
                    delegate: BluetoothDeviceRow {
                        required property var modelData
                        width: deviceColumn.width
                        device: modelData
                    }
                }
            }
        }

        Item {
            id: footer
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 20
                rightMargin: 20
            }
            height: 42

            Text {
                anchors {
                    left: parent.left
                    right: footerHint.left
                    verticalCenter: parent.verticalCenter
                    rightMargin: 16
                }
                text: panel.operationStatus.length > 0 ? panel.operationStatus : "Device addresses are passed directly to bluetoothctl"
                color: panel.operationStatus.includes("failed") || panel.operationStatus.includes("Confirm") ? Theme.warning : Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
                elide: Text.ElideRight
            }

            Text {
                id: footerHint
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "esc close"
                color: Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontCaption
            }
        }
    }
}
