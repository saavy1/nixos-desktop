import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: panel

    property string connectivity: "unknown"
    property bool wifiEnabled: false
    property var activeConnections: []
    property var devices: []
    property var wifiProfiles: []
    property var networks: []
    property string operationStatus: ""
    property bool actionRunning: false
    property string actionDescription: ""

    readonly property bool hasWifiDevice: devices.some(device => device.type === "wifi")
    readonly property bool refreshing: connectivityProc.running
        || activeProc.running
        || deviceProc.running
        || profileProc.running
        || radioProc.running
        || wifiProc.running
    readonly property string activeSummary: {
        if (activeConnections.length === 0)
            return "No active connections"
        return activeConnections.map(connection => `${connection.name} on ${connection.device}`).join("  ·  ")
    }

    visible: PopupController.isOpen("network")
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
    WlrLayershell.namespace: "solitude-network"

    function splitTerse(line): var {
        const fields = []
        let field = ""
        let escaped = false

        for (let index = 0; index < line.length; ++index) {
            const character = line[index]
            if (escaped) {
                field += character
                escaped = false
            } else if (character === "\\") {
                escaped = true
            } else if (character === ":") {
                fields.push(field)
                field = ""
            } else {
                field += character
            }
        }

        if (escaped)
            field += "\\"
        fields.push(field)
        return fields
    }

    function outputLines(text): var {
        return text.split("\n").map(line => line.replace(/\s+$/, "")).filter(line => line.length > 0)
    }

    function isConnectedState(state): bool {
        return state === "connected" || state === "connecting"
    }

    function connectionColor(state): color {
        if (state === "connected")
            return Theme.success
        if (state === "connecting" || state === "disconnected")
            return Theme.warning
        return Theme.muted
    }

    function connectivityLabel(): string {
        switch (connectivity) {
        case "full": return "Online"
        case "limited": return "Limited connectivity"
        case "portal": return "Sign-in required"
        case "none": return "Offline"
        default: return "Checking connectivity"
        }
    }

    function wifiProfile(ssid): var {
        for (const profile of wifiProfiles) {
            if (profile.name === ssid)
                return profile
        }
        return null
    }

    function requestRefresh(forceScan): void {
        if (!visible)
            return

        if (!connectivityProc.running)
            connectivityProc.running = true
        if (!activeProc.running)
            activeProc.running = true
        if (!deviceProc.running)
            deviceProc.running = true
        if (!profileProc.running)
            profileProc.running = true
        if (!radioProc.running)
            radioProc.running = true
        if (!wifiProc.running) {
            wifiProc.command = ["nmcli", "-t", "--escape", "yes", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", forceScan ? "yes" : "no"]
            wifiProc.running = true
        }
    }

    function open(): void {
        PopupController.open("network")
        operationStatus = ""
        requestRefresh(true)
    }

    function close(): void {
        PopupController.close("network")
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

    function toggleWifi(): void {
        if (!hasWifiDevice) {
            operationStatus = "No Wi-Fi adapter is available"
            return
        }
        runAction(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"], wifiEnabled ? "Turning Wi-Fi off" : "Turning Wi-Fi on")
    }

    function disconnectDevice(device): void {
        runAction(["nmcli", "device", "disconnect", device], `Disconnecting ${device}`)
    }

    function activateNetwork(network): void {
        if (network.active) {
            operationStatus = `${network.ssid || "Hidden network"} is already active`
            return
        }
        if (network.hidden) {
            operationStatus = "Hidden networks must be configured in NetworkManager first"
            return
        }

        const profile = wifiProfile(network.ssid)
        if (!profile) {
            operationStatus = network.secured
                ? "Password required — save credentials in NetworkManager before connecting"
                : "No saved connection — create a NetworkManager profile before connecting"
            return
        }

        runAction(["nmcli", "connection", "up", "uuid", profile.uuid], `Connecting to ${network.ssid}`)
    }

    onVisibleChanged: {
        if (!visible) {
            refreshTimer.stop()
            return
        }
        refreshTimer.start()
    }

    IpcHandler {
        target: "network"

        function toggle(): void {
            panel.toggle()
        }

        function close(): void {
            panel.close()
        }
    }

    Timer {
        id: refreshTimer
        interval: 15000
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: panel.requestRefresh(false)
    }

    Process {
        id: connectivityProc
        command: ["nmcli", "-t", "-f", "CONNECTIVITY", "general"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim().toLowerCase()
                panel.connectivity = value.length > 0 ? value : "unknown"
            }
        }
    }

    Process {
        id: activeProc
        command: ["nmcli", "-t", "--escape", "yes", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                panel.activeConnections = panel.outputLines(text).map(line => {
                    const fields = panel.splitTerse(line)
                    return {
                        name: fields[0] || "Unnamed connection",
                        type: fields[1] || "unknown",
                        device: fields[2] || "unknown device"
                    }
                })
            }
        }
    }

    Process {
        id: deviceProc
        command: ["nmcli", "-t", "--escape", "yes", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                panel.devices = panel.outputLines(text).map(line => {
                    const fields = panel.splitTerse(line)
                    return {
                        device: fields[0] || "unknown",
                        type: fields[1] || "unknown",
                        state: fields[2] || "unknown",
                        connection: fields[3] || ""
                    }
                })
            }
        }
    }

    Process {
        id: profileProc
        command: ["nmcli", "-t", "--escape", "yes", "-f", "NAME,UUID,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                panel.wifiProfiles = panel.outputLines(text).map(line => {
                    const fields = panel.splitTerse(line)
                    return {
                        name: fields[0] || "",
                        uuid: fields[1] || "",
                        type: fields[2] || ""
                    }
                }).filter(profile => profile.type === "802-11-wireless" || profile.type === "wifi")
            }
        }
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: panel.wifiEnabled = text.trim().toLowerCase() === "enabled"
        }
    }

    Process {
        id: wifiProc
        command: ["nmcli", "-t", "--escape", "yes", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const strongest = ({})
                for (const line of panel.outputLines(text)) {
                    const fields = panel.splitTerse(line)
                    const ssid = fields[1] || ""
                    const hidden = ssid.length === 0
                    const key = hidden ? `hidden-${fields[2] || "0"}-${fields[3] || ""}` : ssid
                    const signal = Math.max(0, Math.min(100, Number(fields[2]) || 0))
                    const security = fields[3] || ""
                    const candidate = {
                        active: fields[0] === "*" || fields[0] === "yes",
                        ssid: ssid,
                        hidden: hidden,
                        signal: signal,
                        security: security,
                        secured: security.length > 0 && security !== "--"
                    }
                    if (!strongest[key] || candidate.active || signal > strongest[key].signal)
                        strongest[key] = candidate
                }
                panel.networks = Object.keys(strongest).map(key => strongest[key]).sort((left, right) => {
                    if (left.active !== right.active)
                        return left.active ? -1 : 1
                    return right.signal - left.signal
                })
            }
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
                : `${panel.actionDescription} failed${actionProc.failureText.length > 0 ? " — check the saved NetworkManager profile" : ""}`
            if (panel.visible)
                panel.requestRefresh(false)
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
        width: Math.min(760, panel.width - 80)
        height: Math.min(760, panel.height - 100)

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
                    right: controls.left
                    verticalCenter: parent.verticalCenter
                    rightMargin: 18
                }
                spacing: 3

                Text {
                    width: parent.width
                    text: "Network"
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: panel.activeSummary
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                    elide: Text.ElideRight
                }
            }

            Row {
                id: controls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: wifiToggleLabel.implicitWidth + 24
                    height: 34
                    radius: Theme.radiusMedium
                    color: wifiToggleArea.containsMouse ? Theme.selection : Theme.backgroundDark
                    opacity: panel.hasWifiDevice ? 1 : 0.55

                    Text {
                        id: wifiToggleLabel
                        anchors.centerIn: parent
                        text: panel.hasWifiDevice ? (panel.wifiEnabled ? "Wi-Fi on" : "Wi-Fi off") : "No Wi-Fi"
                        color: panel.wifiEnabled && panel.hasWifiDevice ? Theme.success : Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: wifiToggleArea
                        anchors.fill: parent
                        enabled: !panel.actionRunning
                        hoverEnabled: true
                        cursorShape: panel.hasWifiDevice ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: panel.toggleWifi()
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
                        enabled: !panel.refreshing
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            panel.operationStatus = "Refreshing network state…"
                            panel.requestRefresh(true)
                        }
                    }
                }
            }
        }

        Rectangle {
            id: connectivityCard
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                topMargin: 8
                leftMargin: 20
                rightMargin: 20
            }
            height: 56
            radius: Theme.radiusMedium
            color: Theme.backgroundDark
            border.color: panel.connectivity === "full" ? Theme.success : panel.connectivity === "none" ? Theme.error : Theme.border
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
                color: panel.connectivity === "full" ? Theme.success : panel.connectivity === "none" ? Theme.error : Theme.warning
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
                    text: panel.connectivityLabel()
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: panel.activeSummary
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            id: devicesHeading
            anchors {
                top: connectivityCard.bottom
                left: parent.left
                topMargin: 16
                leftMargin: 22
            }
            text: "DEVICES"
            color: Theme.accent
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontCaption
            font.weight: Font.DemiBold
        }

        ListView {
            id: deviceList
            anchors {
                top: devicesHeading.bottom
                left: parent.left
                right: parent.right
                topMargin: 7
                leftMargin: 20
                rightMargin: 20
            }
            height: Math.min(contentHeight, 152)
            model: ScriptModel { values: panel.devices }
            spacing: 4
            clip: true

            delegate: Rectangle {
                id: deviceRow
                required property var modelData
                width: deviceList.width
                height: 48
                radius: Theme.radiusSmall
                color: deviceHover.containsMouse ? Theme.backgroundDark : "transparent"

                Rectangle {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                    }
                    width: 8
                    height: 8
                    radius: 4
                    color: panel.connectionColor(deviceRow.modelData.state)
                }

                Column {
                    anchors {
                        left: parent.left
                        right: disconnectButton.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 30
                        rightMargin: 10
                    }
                    spacing: 1

                    Text {
                        width: parent.width
                        text: `${deviceRow.modelData.device}  ·  ${deviceRow.modelData.type}`
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontBody
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: deviceRow.modelData.connection && deviceRow.modelData.connection !== "--"
                            ? `${deviceRow.modelData.state} — ${deviceRow.modelData.connection}`
                            : deviceRow.modelData.state
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: disconnectButton
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 8
                    }
                    visible: panel.isConnectedState(deviceRow.modelData.state)
                    width: 82
                    height: 30
                    radius: Theme.radiusSmall
                    color: disconnectArea.containsMouse ? Theme.selection : Theme.backgroundDarker

                    Text {
                        anchors.centerIn: parent
                        text: "Disconnect"
                        color: Theme.warning
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                    }

                    MouseArea {
                        id: disconnectArea
                        anchors.fill: parent
                        enabled: !panel.actionRunning
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.disconnectDevice(deviceRow.modelData.device)
                    }
                }

                MouseArea {
                    id: deviceHover
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                }
            }
        }

        Text {
            id: networksHeading
            anchors {
                top: deviceList.bottom
                left: parent.left
                topMargin: 16
                leftMargin: 22
            }
            text: `WI-FI NETWORKS  ${panel.networks.length}`
            color: Theme.accent
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontCaption
            font.weight: Font.DemiBold
        }

        ListView {
            id: networkList
            anchors {
                top: networksHeading.bottom
                left: parent.left
                right: parent.right
                bottom: footer.top
                topMargin: 7
                leftMargin: 20
                rightMargin: 20
                bottomMargin: 8
            }
            model: ScriptModel { values: panel.networks }
            spacing: 4
            clip: true

            delegate: Rectangle {
                id: networkRow
                required property var modelData
                readonly property var profile: panel.wifiProfile(modelData.ssid)
                readonly property bool actionable: modelData.active || profile !== null

                width: networkList.width
                height: 54
                radius: Theme.radiusMedium
                color: modelData.active ? Theme.selection : networkArea.containsMouse ? Theme.backgroundDark : "transparent"
                border.color: modelData.active ? Theme.accent : "transparent"
                border.width: Theme.borderWidth

                Column {
                    anchors {
                        left: parent.left
                        right: networkMeta.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 14
                        rightMargin: 12
                    }
                    spacing: 2

                    Text {
                        width: parent.width
                        text: networkRow.modelData.hidden ? "Hidden network" : networkRow.modelData.ssid
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontBody
                        font.weight: networkRow.modelData.active ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: networkRow.modelData.active
                            ? "Connected"
                            : networkRow.profile !== null
                                ? "Saved — click to connect"
                                : networkRow.modelData.secured
                                    ? "Password required — configure first"
                                    : "Not saved — configure first"
                        color: networkRow.modelData.active ? Theme.success : Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        elide: Text.ElideRight
                    }
                }

                Column {
                    id: networkMeta
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 14
                    }
                    spacing: 2

                    Text {
                        anchors.right: parent.right
                        text: `${networkRow.modelData.signal}%`
                        color: networkRow.modelData.signal >= 65 ? Theme.success : networkRow.modelData.signal >= 35 ? Theme.warning : Theme.error
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontBody
                    }

                    Text {
                        anchors.right: parent.right
                        text: networkRow.modelData.secured ? networkRow.modelData.security : "Open"
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                    }
                }

                MouseArea {
                    id: networkArea
                    anchors.fill: parent
                    enabled: !panel.actionRunning
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.activateNetwork(networkRow.modelData)
                }
            }
        }

        Text {
            anchors.centerIn: networkList
            visible: networkList.count === 0
            width: networkList.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: !panel.hasWifiDevice
                ? "No Wi-Fi adapter detected. Ethernet devices and connections remain available above."
                : panel.wifiEnabled
                    ? "No Wi-Fi networks discovered"
                    : "Wi-Fi is turned off"
            color: Theme.muted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontBody
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
                text: panel.operationStatus.length > 0 ? panel.operationStatus : "Saved Wi-Fi profiles connect without exposing credentials"
                color: panel.operationStatus.includes("failed") || panel.operationStatus.includes("required") ? Theme.warning : Theme.muted
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
