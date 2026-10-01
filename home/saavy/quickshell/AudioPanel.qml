import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import qs.ui

PopupPanel {
    id: root

    readonly property var output: Pipewire.defaultAudioSink
    readonly property var microphone: Pipewire.defaultAudioSource
    readonly property var outputDevices: Pipewire.nodes.values
        .filter(node => node.audio !== null && node.isSink && !node.isStream)
        .sort((left, right) => root.nodeName(left).localeCompare(root.nodeName(right)))
    readonly property var playbackStreams: Pipewire.nodes.values
        .filter(node => node.audio !== null && node.isStream && !node.isSink)
        .sort((left, right) => root.streamName(left).localeCompare(root.streamName(right)))
    property string macAvailability: "UNAVAILABLE"
    property int macRevision: 0
    property string macReceivedAt: ""
    property int macStaleAfterMs: 15000
    property string macError: ""
    property var macRoutes: []
    property var macDevices: []
    property bool macHasEnvelope: false
    property double macLastLineAtMs: 0
    property double macClockTick: Date.now()
    property string macWatchError: ""
    readonly property var macNonLocalRoutes: macRoutes
        .filter(route => route && route.is_local === false)
        .slice(0, 4)
    readonly property string macStatus: effectiveMacAvailability()

    name: "audio"
    title: "Sound"
    subtitle: nodeAvailable(output) ? `${nodeName(output).toLowerCase()} · pipewire` : (Pipewire.ready ? "no output" : "connecting…")
    cardWidth: 440

    function nodeAvailable(node): bool {
        return node !== null && node !== undefined && node.ready && node.audio !== null
    }

    function nodeName(node): string {
        if (node === null || node === undefined)
            return "Unknown device"

        return node.description || node.nickname || node.name || "Unknown device"
    }

    function streamName(node): string {
        if (node === null || node === undefined)
            return "Unknown application"

        if (node.ready && node.properties) {
            return node.properties["application.name"]
                || node.properties["media.name"]
                || node.description
                || node.name
                || "Unknown application"
        }

        return node.description || node.name || "Unknown application"
    }

    function streamDetail(node): string {
        if (node === null || node === undefined || !node.ready || !node.properties)
            return "Playback stream"

        const title = node.properties["media.title"] || node.properties["media.name"] || ""
        const artist = node.properties["media.artist"] || ""

        if (artist.length > 0 && title.length > 0)
            return `${artist} — ${title}`

        return title || "Playback stream"
    }

    function validAudioEnvelope(envelope): bool {
        if (!envelope || typeof envelope !== "object"
                || envelope.schema_version !== 1
                || typeof envelope.revision !== "number"
                || !isFinite(envelope.revision)
                || Math.floor(envelope.revision) !== envelope.revision
                || typeof envelope.received_at !== "string"
                || typeof envelope.stale_after_ms !== "number"
                || !isFinite(envelope.stale_after_ms)
                || envelope.stale_after_ms <= 0
                || typeof envelope.availability !== "string"
                || (envelope.error !== null && typeof envelope.error !== "string")) {
            return false
        }

        const supportedAvailability = [
            "AVAILABLE",
            "DEGRADED",
            "STALE",
            "UNAVAILABLE",
            "UNSUPPORTED",
            "UNKNOWN"
        ]
        if (supportedAvailability.indexOf(envelope.availability) < 0)
            return false

        if (envelope.state === null)
            return envelope.availability === "UNAVAILABLE"

        if (typeof envelope.state !== "object"
                || envelope.state.schema_version !== 1
                || !envelope.state.via
                || typeof envelope.state.via !== "object"
                || envelope.state.via.support !== "PRIVATE_UNKNOWN"
                || !Array.isArray(envelope.state.via.routes)
                || !envelope.state.focusrite
                || typeof envelope.state.focusrite !== "object"
                || !envelope.state.coreaudio
                || typeof envelope.state.coreaudio !== "object"
                || !Array.isArray(envelope.state.coreaudio.devices)) {
            return false
        }

        const routesValid = envelope.state.via.routes.every(route =>
            route
                && typeof route === "object"
                && (route.source_device === null || typeof route.source_device === "string")
                && (route.source_channel === null || typeof route.source_channel === "string")
                && typeof route.sink_id === "string"
                && typeof route.sink_index === "number"
                && isFinite(route.sink_index)
                && typeof route.sink_type === "string"
                && typeof route.is_local === "boolean")
        const devicesValid = envelope.state.coreaudio.devices.every(device =>
            device
                && typeof device === "object"
                && typeof device.name === "string")

        return routesValid && devicesValid
    }

    function acceptAudioEnvelope(line): void {
        const text = line.trim()
        if (text.length === 0)
            return

        let envelope
        try {
            envelope = JSON.parse(text)
        } catch (error) {
            return
        }

        if (!validAudioEnvelope(envelope))
            return

        macAvailability = envelope.availability
        macRevision = envelope.revision
        macReceivedAt = envelope.received_at
        macStaleAfterMs = Math.max(1000, envelope.stale_after_ms)
        macError = envelope.error || ""
        if (envelope.state !== null) {
            macRoutes = envelope.state.via.routes.slice()
            macDevices = envelope.state.coreaudio.devices.slice()
        }
        macHasEnvelope = true
        macLastLineAtMs = Date.now()
        macClockTick = macLastLineAtMs
        macWatchError = ""
    }

    function effectiveMacAvailability(): string {
        const now = macClockTick
        if (!macHasEnvelope)
            return "UNAVAILABLE"

        if (macLastLineAtMs > 0 && now - macLastLineAtMs > macStaleAfterMs)
            return "STALE"

        if (macAvailability === "UNAVAILABLE"
                || macAvailability === "UNSUPPORTED"
                || macAvailability === "UNKNOWN") {
            return "UNAVAILABLE"
        }

        if (macWatchError.length > 0)
            return "DEGRADED"

        return macAvailability === "AVAILABLE" ? "AVAILABLE"
            : macAvailability === "STALE" ? "STALE"
            : "DEGRADED"
    }

    function macStatusMessage(): string {
        if (macError.length > 0)
            return macError

        if (macStatus === "STALE")
            return "Snapshot is stale; showing the last known Mac routes."

        if (macStatus === "UNAVAILABLE")
            return macWatchError.length > 0 ? macWatchError : "Mac audio snapshot is unavailable."

        if (macStatus === "DEGRADED")
            return macWatchError.length > 0
                ? macWatchError
                : "Mac snapshot is partial; route details may be incomplete."

        return ""
    }

    function coreAudioDeviceSummary(): string {
        if (macDevices.length === 0)
            return "COREAUDIO · no devices reported"

        return `COREAUDIO · ${macDevices.map(device => device.name).join(" · ")}`
    }

    function routeSourceLabel(route): string {
        const device = route.source_device && route.source_device.length > 0
            ? route.source_device
            : "Unknown source"
        const channel = route.source_channel && route.source_channel.length > 0
            ? ` / ${route.source_channel}`
            : ""
        return `${device}${channel}`
    }

    function routeSinkLabel(route): string {
        const type = route.sink_type.toLowerCase()
        const label = type === "soundcard"
            ? "MAC AUDIO"
            : type === "application" ? "MAC APPLICATION" : "MAC SINK"
        return `${label} / ${route.sink_index}`
    }

    function deviceKind(node): string {
        const name = node && node.name ? node.name : ""
        if (name.startsWith("bluez"))
            return "BT"
        if (name.indexOf("hdmi") >= 0 || name.indexOf("HDMI") >= 0)
            return "HDMI"
        if (name.indexOf("usb") >= 0)
            return "USB"
        return ""
    }

    function deviceIcon(node): string {
        switch (deviceKind(node)) {
        case "BT":
            return "headphones"
        case "HDMI":
            return "monitor"
        default:
            return "speaker"
        }
    }

    function setVolume(node, value: real): void {
        if (!nodeAvailable(node))
            return

        node.audio.volume = value
        if (value > 0 && node.audio.muted)
            node.audio.muted = false
    }

    function toggleMute(node): void {
        if (nodeAvailable(node))
            node.audio.muted = !node.audio.muted
    }

    function percent(node): string {
        return nodeAvailable(node) ? `${Math.round(node.audio.volume * 100)}%` : "—"
    }

    PwObjectTracker {
        objects: [root.output, root.microphone]
    }

    PwObjectTracker {
        objects: root.outputDevices
    }

    PwObjectTracker {
        objects: root.playbackStreams
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.macClockTick = Date.now()
    }

    Timer {
        id: audioWatchRestartTimer

        interval: 5000
        repeat: false
        onTriggered: {
            if (!audioWatchProcess.running)
                audioWatchProcess.running = true
        }
    }

    Process {
        id: audioWatchProcess

        command: [Quickshell.env("HOME") + "/.local/bin/audioctl", "watch", "--json", "--interval-ms", "5000"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.acceptAudioEnvelope(data)
        }
        onExited: (exitCode, exitStatus) => {
            root.macWatchError = root.macHasEnvelope
                ? "Mac audio watcher stopped; showing the last known snapshot."
                : "Mac audio watcher is unavailable; retrying in 5 seconds."
            audioWatchRestartTimer.restart()
        }
    }

    Component.onCompleted: audioWatchProcess.running = true


    component LevelControl: Column {
        id: control

        required property var node
        required property string label
        property color fillColor: Theme.accent
        readonly property bool available: root.nodeAvailable(node)
        readonly property bool muted: available && node.audio.muted

        width: parent ? parent.width : 0
        spacing: Theme.space.sm

        Item {
            width: parent.width
            height: 22

            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: control.label
                font.weight: Font.Medium
                tone: control.available ? "base" : "faint"
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.xs

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: control.muted ? "MUTED" : root.percent(control.node)
                    variant: "numeric"
                    tone: control.muted ? "danger" : "base"
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 24
                    implicitHeight: 22
                    iconSize: 14
                    enabled: control.available
                    icon: control.muted ? (control.label === "Microphone" ? "mic-off" : "volume-x") : (control.label === "Microphone" ? "mic" : "volume-2")
                    tone: control.muted ? "danger" : "faint"
                    onClicked: root.toggleMute(control.node)
                }
            }
        }

        Slider {
            width: parent.width
            enabled: control.available
            value: control.available ? control.node.audio.volume : 0
            fillColor: control.muted ? Theme.text.disabled : control.fillColor
            onMoved: value => root.setVolume(control.node, value)
        }
    }

    component StreamRow: Item {
        id: stream

        required property var modelData
        readonly property bool available: root.nodeAvailable(modelData)
        readonly property bool muted: available && modelData.audio.muted

        width: parent ? parent.width : 0
        height: 40

        Column {
            id: streamText

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 118
            spacing: 1

            Label {
                width: parent.width
                text: root.streamName(stream.modelData)
                variant: "small"
                font.pixelSize: Theme.fontSize.bar
                tone: stream.muted ? "faint" : "base"
            }

            Label {
                width: parent.width
                text: root.streamDetail(stream.modelData)
                variant: "caption"
                tone: "faint"
            }
        }

        Slider {
            anchors {
                left: streamText.right
                right: streamValue.left
                leftMargin: Theme.space.md
                rightMargin: Theme.space.sm
                verticalCenter: parent.verticalCenter
            }
            enabled: stream.available
            value: stream.available ? stream.modelData.audio.volume : 0
            fillColor: stream.muted ? Theme.text.disabled : Theme.secondary
            onMoved: value => root.setVolume(stream.modelData, value)
        }

        Label {
            id: streamValue

            anchors.right: streamMute.left
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            horizontalAlignment: Text.AlignRight
            text: stream.muted ? "MUTE" : root.percent(stream.modelData)
            variant: "numeric"
            font.pixelSize: Theme.fontSize.small
            tone: stream.muted ? "danger" : "faint"
        }

        IconButton {
            id: streamMute

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 26
            implicitHeight: 24
            iconSize: 14
            enabled: stream.available
            icon: stream.muted ? "volume-x" : "volume-1"
            tone: stream.muted ? "danger" : "faint"
            onClicked: root.toggleMute(stream.modelData)
        }
    }

    headerTrailing: [
        Button {
            compact: true
            enabled: root.nodeAvailable(root.output)
            text: root.nodeAvailable(root.output) && root.output.audio.muted ? "Unmute" : "Mute"
            icon: root.nodeAvailable(root.output) && root.output.audio.muted ? "volume-2" : "volume-x"
            onClicked: root.toggleMute(root.output)
        }
    ]

    LevelControl {
        node: root.output
        label: "Output"
    }

    LevelControl {
        node: root.microphone
        label: "Microphone"
        fillColor: Theme.secondary
    }

    SectionHeader {
        width: parent.width
        text: "Devices"
        trailing: root.outputDevices.length > 0 ? String(root.outputDevices.length) : ""
    }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: root.outputDevices

            delegate: ListItem {
                required property var modelData

                width: parent.width
                icon: root.deviceIcon(modelData)
                title: root.nodeName(modelData)
                trailing: root.deviceKind(modelData)
                indicator: true
                selected: root.output !== null && modelData === root.output
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }

        Label {
            visible: root.outputDevices.length === 0
            width: parent.width
            topPadding: Theme.space.sm
            text: Pipewire.ready ? "No output devices found" : "Discovering output devices…"
            variant: "small"
            tone: "faint"
        }
    }

    SectionHeader {
        width: parent.width
        text: "Playing"
        trailing: root.playbackStreams.length > 0 ? String(root.playbackStreams.length) : ""
    }

    Column {
        width: parent.width
        spacing: Theme.space.xs

        Repeater {
            model: root.playbackStreams

            delegate: StreamRow {}
        }

        Label {
            visible: root.playbackStreams.length === 0
            width: parent.width
            text: Pipewire.ready ? "Nothing is playing" : "Discovering playback streams…"
            variant: "small"
            tone: "faint"
        }
    }

    SectionHeader {
        width: parent.width
        text: "Dante / Mac"
        trailing: root.macStatus
        trailingTone: root.macStatus === "AVAILABLE" ? "success" : root.macStatus === "UNAVAILABLE" ? "danger" : "warning"
    }

    Column {
        width: parent.width
        spacing: Theme.space.sm

        Label {
            width: parent.width
            text: root.coreAudioDeviceSummary()
            variant: "numeric"
            font.pixelSize: Theme.fontSize.caption
            font.weight: Font.Normal
            tone: root.macDevices.length > 0 ? "soft" : "faint"
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.macNonLocalRoutes

            delegate: Row {
                required property var modelData

                width: parent.width
                spacing: Theme.space.sm

                Icon {
                    name: "arrow-right"
                    size: 13
                    color: Theme.text.faint
                }

                Label {
                    width: parent.width - 21
                    text: `${root.routeSourceLabel(modelData)} → ${root.routeSinkLabel(modelData)}`
                    variant: "small"
                    tone: "soft"
                    wrapMode: Text.Wrap
                }
            }
        }

        Label {
            visible: root.macNonLocalRoutes.length === 0
            width: parent.width
            text: "No non-local Via routes reported"
            variant: "small"
            tone: "faint"
        }

        Label {
            visible: root.macStatusMessage().length > 0
            width: parent.width
            text: root.macStatusMessage()
            variant: "small"
            tone: root.macStatus === "UNAVAILABLE" ? "danger" : "warning"
            wrapMode: Text.Wrap
        }
    }
}
