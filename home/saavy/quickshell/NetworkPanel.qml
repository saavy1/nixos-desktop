import Quickshell
import Quickshell.Io
import QtQuick
import qs.ui

PopupPanel {
    id: root

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
    readonly property string headerSummary: {
        if (activeConnections.length === 0)
            return "no active connections"
        const primary = activeConnections[0]
        const extra = activeConnections.length > 1 ? ` · +${activeConnections.length - 1}` : ""
        return `${primary.device} · ${primary.name}${extra}`.toLowerCase()
    }
    readonly property string connectivityTone: connectivity === "full" ? "success" : connectivity === "none" ? "danger" : "warning"

    name: "network"
    title: "Network"
    subtitle: headerSummary
    cardWidth: 460

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
        return Theme.text.disabled
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

    function deviceIcon(type): string {
        switch (type) {
        case "wifi": return "wifi"
        case "ethernet": return "ethernet-port"
        case "loopback": return "circle-dot"
        default: return "network"
        }
    }

    function signalBars(signal): int {
        if (signal >= 75)
            return 4
        if (signal >= 50)
            return 3
        if (signal >= 25)
            return 2
        return signal > 0 ? 1 : 0
    }

    function requestRefresh(forceScan): void {
        if (!shown)
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

    // Tailscale: parsed from `tailscale status --json` (read-only).
    property string tailscaleState: ""
    property var tailscaleSelf: null
    property var tailscalePeers: []
    property string tailscaleSuffix: ""
    property bool showOfflinePeers: false
    readonly property var onlinePeers: tailscalePeers.filter(peer => peer.online)
    readonly property var offlinePeers: tailscalePeers.filter(peer => !peer.online)

    function peerIcon(peer): string {
        const tags = peer.tags.join(" ")
        if (/k8s/.test(tags))
            return "box"
        if (peer.os === "android" || peer.os === "iOS")
            return "smartphone"
        if (peer.os === "macOS")
            return "laptop"
        if (peer.os === "windows")
            return "monitor"
        return "server"
    }

    function sinceLabel(stamp): string {
        const seen = Date.parse(stamp)
        if (!isFinite(seen) || seen <= 0)
            return "never seen"
        const hours = Math.round((Date.now() - seen) / 3600000)
        if (hours < 1)
            return "seen just now"
        if (hours < 48)
            return `seen ${hours}h ago`
        return `seen ${Math.round(hours / 24)}d ago`
    }

    function parseTailscale(text): void {
        let data
        try {
            data = JSON.parse(text)
        } catch (error) {
            tailscaleState = "Unavailable"
            return
        }

        const toPeer = node => ({
            name: (node.DNSName || "").split(".")[0] || node.HostName,
            host: node.HostName,
            dns: (node.DNSName || "").replace(/\.$/, ""),
            ip: (node.TailscaleIPs || [])[0] || "",
            os: node.OS || "",
            tags: (node.Tags || []).map(tag => tag.replace(/^tag:/, "")),
            online: !!node.Online,
            direct: !!node.CurAddr,
            relay: node.Relay || "",
            lastSeen: node.LastSeen || ""
        })
        tailscaleState = data.BackendState || ""
        tailscaleSelf = data.Self ? toPeer(data.Self) : null
        tailscaleSuffix = data.MagicDNSSuffix || ""
        tailscalePeers = Object.values(data.Peer || {}).map(toPeer)
            .sort((left, right) => (right.online - left.online) || left.name.localeCompare(right.name))
    }

    onOpening: {
        operationStatus = ""
        requestRefresh(true)
        tailscaleProc.running = true
    }

    Process {
        id: tailscaleProc

        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.parseTailscale(text)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.tailscaleState = "Unavailable"
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.shown
        onTriggered: {
            if (!tailscaleProc.running)
                tailscaleProc.running = true
        }
    }

    component PeerRow: ListItem {
        id: peerRow

        required property var modelData

        width: parent ? parent.width : 0
        interactive: false
        hoverHighlight: true
        opacity: modelData.online ? 1 : 0.6
        icon: root.peerIcon(modelData)
        title: modelData.name
        subtitle: [modelData.tags.join(", ") || modelData.os,
            modelData.online ? (modelData.direct ? "direct" : `relay ${modelData.relay}`) : root.sinceLabel(modelData.lastSeen)]
            .filter(part => part).join(" · ")
        trailing: modelData.ip

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 26
            implicitHeight: 24
            iconSize: 13
            icon: "copy"
            tone: "faint"
            onClicked: Quickshell.execDetached(["wl-copy", peerRow.modelData.dns])
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            // Phones and k8s service proxies don't run an SSH server.
            visible: peerRow.modelData.online && root.peerIcon(peerRow.modelData) !== "smartphone"
                && root.peerIcon(peerRow.modelData) !== "box"
            implicitWidth: 26
            implicitHeight: 24
            iconSize: 13
            icon: "terminal"
            tone: "faint"
            onClicked: {
                Quickshell.execDetached(["ghostty", "-e", "tailscale", "ssh", peerRow.modelData.dns])
                root.close()
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 15000
        repeat: true
        running: root.shown
        triggeredOnStart: false
        onTriggered: root.requestRefresh(false)
    }

    Process {
        id: connectivityProc
        command: ["nmcli", "-t", "-f", "CONNECTIVITY", "general"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim().toLowerCase()
                root.connectivity = value.length > 0 ? value : "unknown"
            }
        }
    }

    Process {
        id: activeProc
        command: ["nmcli", "-t", "--escape", "yes", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.activeConnections = root.outputLines(text).map(line => {
                    const fields = root.splitTerse(line)
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
                root.devices = root.outputLines(text).map(line => {
                    const fields = root.splitTerse(line)
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
                root.wifiProfiles = root.outputLines(text).map(line => {
                    const fields = root.splitTerse(line)
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
            onStreamFinished: root.wifiEnabled = text.trim().toLowerCase() === "enabled"
        }
    }

    Process {
        id: wifiProc
        command: ["nmcli", "-t", "--escape", "yes", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const strongest = ({})
                for (const line of root.outputLines(text)) {
                    const fields = root.splitTerse(line)
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
                root.networks = Object.keys(strongest).map(key => strongest[key]).sort((left, right) => {
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
            root.actionRunning = true
        }
        onExited: (exitCode, exitStatus) => {
            root.actionRunning = false
            root.operationStatus = exitCode === 0
                ? `${root.actionDescription} succeeded`
                : `${root.actionDescription} failed${actionProc.failureText.length > 0 ? " — check the saved NetworkManager profile" : ""}`
            if (root.shown)
                root.requestRefresh(false)
        }
    }


    // Four ascending bars for a 0–100 signal value.
    component SignalBars: Row {
        id: bars

        property int signal: 0
        property color fillColor: Theme.text.soft
        readonly property int level: root.signalBars(signal)

        spacing: 2

        Repeater {
            model: 4

            delegate: Rectangle {
                required property int index

                anchors.bottom: parent.bottom
                width: 3
                height: 4 + index * 3
                radius: 1
                color: index < bars.level ? bars.fillColor : Theme.lineStrong
            }
        }
    }

    headerTrailing: [
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasWifiDevice ? "Wi-Fi" : "No Wi-Fi"
            variant: "label"
            tone: root.hasWifiDevice && root.wifiEnabled ? "soft" : "faint"
        },
        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            enabled: !root.actionRunning
            opacity: root.hasWifiDevice && enabled ? 1 : Theme.alpha.disabled
            checked: root.hasWifiDevice && root.wifiEnabled
            onToggled: root.toggleWifi()
        },
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "refresh-cw"
            label: root.refreshing ? "checking" : ""
            enabled: !root.refreshing
            onClicked: {
                root.operationStatus = "Refreshing network state…"
                root.requestRefresh(true)
            }
        }
    ]

    footer: [
        Label {
            width: parent.width - footerHint.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: root.operationStatus.length > 0 ? root.operationStatus : "Saved Wi-Fi profiles connect without exposing credentials"
            variant: "small"
            tone: root.operationStatus.includes("failed") || root.operationStatus.includes("required") ? "warning" : "faint"
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
        icon: root.connectivity === "none" ? "wifi-off" : "globe"
        title: root.connectivityLabel()
        subtitle: root.activeSummary
        trailing: root.connectivity
        trailingTone: root.connectivityTone

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 7
            height: 7
            radius: 3.5
            color: Theme.tone(root.connectivityTone)
        }
    }

    SectionHeader {
        width: parent.width
        text: "Devices"
        trailing: root.devices.length > 0 ? String(root.devices.length) : ""
    }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: ScriptModel {
                values: root.devices
            }

            delegate: ListItem {
                id: deviceRow

                required property var modelData
                readonly property bool linked: root.isConnectedState(modelData.state)

                width: parent.width
                interactive: false
                selected: modelData.state === "connected"
                icon: root.deviceIcon(modelData.type)
                title: modelData.device
                subtitle: modelData.connection && modelData.connection !== "--"
                    ? `${modelData.state} — ${modelData.connection}`
                    : modelData.state
                trailing: modelData.type

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    color: root.connectionColor(deviceRow.modelData.state)
                }

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: deviceRow.linked
                    compact: true
                    text: "Disconnect"
                    icon: "unlink"
                    enabled: !root.actionRunning
                    onClicked: root.disconnectDevice(deviceRow.modelData.device)
                }
            }
        }

        Label {
            visible: root.devices.length === 0
            width: parent.width
            topPadding: Theme.space.sm
            text: root.refreshing ? "Reading devices…" : "No network devices reported"
            variant: "small"
            tone: "faint"
        }
    }

    SectionHeader {
        width: parent.width
        text: "Tailscale"
        trailing: root.tailscaleState === "Running"
            ? `${root.onlinePeers.length}/${root.tailscalePeers.length} online`
            : root.tailscaleState.toLowerCase()
        trailingTone: root.tailscaleState === "Running" || root.tailscaleState === "" ? "faint" : "warning"
    }

    Column {
        width: parent.width
        spacing: 2

        ListItem {
            visible: root.tailscaleSelf !== null
            width: parent.width
            interactive: false
            icon: "network"
            title: root.tailscaleSelf ? `${root.tailscaleSelf.name} (this device)` : ""
            subtitle: root.tailscaleSuffix
            trailing: root.tailscaleSelf ? root.tailscaleSelf.ip : ""
            selected: true

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 26
                implicitHeight: 24
                iconSize: 13
                icon: "copy"
                tone: "faint"
                onClicked: Quickshell.execDetached(["wl-copy", root.tailscaleSelf.ip])
            }
        }

        Repeater {
            model: root.onlinePeers

            delegate: PeerRow {}
        }

        Button {
            visible: root.offlinePeers.length > 0
            compact: true
            variant: "subtle"
            icon: root.showOfflinePeers ? "chevron-up" : "chevron-down"
            text: root.showOfflinePeers ? "Hide offline" : `${root.offlinePeers.length} offline`
            onClicked: root.showOfflinePeers = !root.showOfflinePeers
        }

        Repeater {
            model: root.showOfflinePeers ? root.offlinePeers : []

            delegate: PeerRow {}
        }

        Label {
            visible: root.tailscaleState !== "" && root.tailscaleState !== "Running"
            width: parent.width
            text: root.tailscaleState === "Unavailable"
                ? "tailscale status is unavailable"
                : `Tailscale is ${root.tailscaleState.toLowerCase()}`
            variant: "small"
            tone: "warning"
        }
    }

    SectionHeader {
        width: parent.width
        text: "Wi-Fi networks"
        trailing: String(root.networks.length)
    }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: ScriptModel {
                values: root.networks
            }

            delegate: ListItem {
                id: networkRow

                required property var modelData
                readonly property var profile: root.wifiProfile(modelData.ssid)

                width: parent.width
                interactive: !root.actionRunning
                selected: modelData.active
                indicator: true
                icon: modelData.secured ? "lock" : "lock-open"
                title: modelData.hidden ? "Hidden network" : modelData.ssid
                subtitle: modelData.active
                    ? "Connected"
                    : profile !== null
                        ? "Saved — click to connect"
                        : modelData.secured
                            ? "Password required — configure first"
                            : "Not saved — configure first"
                trailing: modelData.secured ? modelData.security : "Open"
                onClicked: root.activateNetwork(modelData)

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    horizontalAlignment: Text.AlignRight
                    text: `${networkRow.modelData.signal}%`
                    variant: "numeric"
                    font.pixelSize: Theme.fontSize.small
                    tone: networkRow.modelData.signal >= 65 ? "soft" : networkRow.modelData.signal >= 35 ? "faint" : "warning"
                }

                SignalBars {
                    anchors.verticalCenter: parent.verticalCenter
                    signal: networkRow.modelData.signal
                    fillColor: networkRow.modelData.active ? Theme.accent
                        : networkRow.modelData.signal >= 35 ? Theme.text.soft
                        : Theme.warning
                }
            }
        }

        Label {
            visible: root.networks.length === 0
            width: parent.width
            topPadding: Theme.space.sm
            wrapMode: Text.WordWrap
            text: !root.hasWifiDevice
                ? "No Wi-Fi adapter detected. Ethernet devices and connections remain available above."
                : root.wifiEnabled
                    ? "No Wi-Fi networks discovered"
                    : "Wi-Fi is turned off"
            variant: "small"
            tone: "faint"
        }
    }
}
