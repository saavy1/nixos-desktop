import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: audioPanel

    readonly property var output: Pipewire.defaultAudioSink
    readonly property var microphone: Pipewire.defaultAudioSource
    readonly property var outputDevices: Pipewire.nodes.values
        .filter(node => node.audio !== null && node.isSink && !node.isStream)
        .sort((left, right) => audioPanel.nodeName(left).localeCompare(audioPanel.nodeName(right)))
    readonly property var playbackStreams: Pipewire.nodes.values
        .filter(node => node.audio !== null && node.isStream && !node.isSink)
        .sort((left, right) => audioPanel.streamName(left).localeCompare(audioPanel.streamName(right)))
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
    readonly property color macStatusTone: macStatus === "AVAILABLE"
        ? Theme.success
        : macStatus === "UNAVAILABLE" ? Theme.error : Theme.warning

    visible: PopupController.isOpen("audio")
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
    WlrLayershell.namespace: "solitude-audio"

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

    function open(): void {
        PopupController.open("audio")
        Qt.callLater(() => keyScope.forceActiveFocus())
    }

    function close(): void {
        PopupController.close("audio")
    }

    function toggle(): void {
        if (visible)
            close()
        else
            open()
    }

    IpcHandler {
        target: "audio"

        function toggle(): void {
            audioPanel.toggle()
        }

        function close(): void {
            audioPanel.close()
        }
    }

    PwObjectTracker {
        objects: [audioPanel.output, audioPanel.microphone]
    }

    PwObjectTracker {
        objects: audioPanel.outputDevices
    }

    PwObjectTracker {
        objects: audioPanel.playbackStreams
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: audioPanel.macClockTick = Date.now()
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

        command: ["/home/saavy/.local/bin/audioctl", "watch", "--json", "--interval-ms", "5000"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => audioPanel.acceptAudioEnvelope(data)
        }
        onExited: (exitCode, exitStatus) => {
            audioPanel.macWatchError = audioPanel.macHasEnvelope
                ? "Mac audio watcher stopped; showing the last known snapshot."
                : "Mac audio watcher is unavailable; retrying in 5 seconds."
            audioWatchRestartTimer.restart()
        }
    }

    Component.onCompleted: audioWatchProcess.running = true

    component VolumeSlider: Item {
        id: slider

        required property var node
        readonly property bool available: audioPanel.nodeAvailable(node)
        readonly property real level: available ? Math.max(0, Math.min(1, node.audio.volume)) : 0

        implicitHeight: 24
        opacity: available ? 1 : 0.45

        function setFromPosition(position: real): void {
            if (!available)
                return

            const nextVolume = Math.max(0, Math.min(1, position / width))
            node.audio.volume = nextVolume
            if (nextVolume > 0 && node.audio.muted)
                node.audio.muted = false
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            height: 6
            radius: 3
            color: Theme.backgroundDarker

            Rectangle {
                width: parent.width * slider.level
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
        }

        Rectangle {
            x: Math.max(0, Math.min(parent.width - width, parent.width * slider.level - width / 2))
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
            onPressed: mouse => slider.setFromPosition(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    slider.setFromPosition(mouse.x)
            }
        }
    }

    component VolumeRow: Rectangle {
        id: volumeRow

        required property var node
        required property string title
        property string subtitle: ""
        property string badge: ""
        readonly property bool available: audioPanel.nodeAvailable(node)

        width: parent ? parent.width : 0
        height: 92
        radius: Theme.radiusMedium
        color: Theme.backgroundDark
        border.color: Theme.backgroundDarker
        border.width: Theme.borderWidth

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: 14
                topMargin: 14
            }
            width: 36
            height: 24
            radius: Theme.radiusSmall
            color: Theme.selection

            Text {
                anchors.centerIn: parent
                text: volumeRow.badge
                color: Theme.accent
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
                font.weight: Font.DemiBold
            }
        }

        Column {
            anchors {
                left: parent.left
                right: muteButton.left
                top: parent.top
                leftMargin: 60
                rightMargin: 12
                topMargin: 10
            }
            spacing: 1

            Text {
                width: parent.width
                text: volumeRow.title
                color: volumeRow.available ? Theme.foreground : Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: volumeRow.subtitle
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: muteButton

            anchors {
                right: parent.right
                top: parent.top
                rightMargin: 12
                topMargin: 11
            }
            width: 62
            height: 30
            radius: Theme.radiusSmall
            color: !volumeRow.available
                ? Theme.backgroundDarker
                : volumeRow.node.audio.muted ? Theme.error : muteHover.containsMouse ? Theme.selection : Theme.backgroundDarker

            Text {
                anchors.centerIn: parent
                text: volumeRow.available && volumeRow.node.audio.muted ? "MUTED" : "MUTE"
                color: volumeRow.available && volumeRow.node.audio.muted ? Theme.background : Theme.foregroundSoft
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: muteHover

                anchors.fill: parent
                enabled: volumeRow.available
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: volumeRow.node.audio.muted = !volumeRow.node.audio.muted
            }
        }

        VolumeSlider {
            anchors {
                left: parent.left
                right: percentage.left
                bottom: parent.bottom
                leftMargin: 14
                rightMargin: 12
                bottomMargin: 10
            }
            node: volumeRow.node
        }

        Text {
            id: percentage

            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: 14
                bottomMargin: 14
            }
            width: 44
            horizontalAlignment: Text.AlignRight
            text: volumeRow.available ? `${Math.round(volumeRow.node.audio.volume * 100)}%` : "—"
            color: volumeRow.available ? Theme.foregroundSoft : Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontCaption
        }
    }

    Item {
        id: keyScope

        anchors.fill: parent
        focus: audioPanel.visible
        Keys.onEscapePressed: audioPanel.close()

        MouseArea {
            anchors.fill: parent
            onClicked: audioPanel.close()
        }

        PanelCard {
            id: card

            anchors {
                top: parent.top
                right: parent.right
                topMargin: Theme.outerMargin + Theme.barHeight + Theme.shellGap
                rightMargin: Theme.outerMargin
            }
            width: Math.max(320, Math.min(600, audioPanel.width - 48))
            height: Math.min(720, Math.max(320, audioPanel.height - 64))

            MouseArea {
                anchors.fill: parent
            }

            Text {
                anchors {
                    left: parent.left
                    top: parent.top
                    leftMargin: 22
                    topMargin: 18
                }
                text: "Audio"
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
            }

            Text {
                anchors {
                    right: parent.right
                    top: parent.top
                    rightMargin: 22
                    topMargin: 23
                }
                text: Pipewire.ready ? "PIPEWIRE  LIVE" : "CONNECTING"
                color: Pipewire.ready ? Theme.accent : Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontCaption
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: 62
                }
                height: 1
                color: Theme.backgroundDarker
            }

            Flickable {
                id: mixerView

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: footerDivider.top
                    leftMargin: 20
                    rightMargin: 20
                    topMargin: 76
                    bottomMargin: 12
                }
                contentWidth: width
                contentHeight: mixerContent.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: mixerContent

                    width: mixerView.width
                    spacing: 12

                    Text {
                        text: "OUTPUT"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    VolumeRow {
                        node: audioPanel.output
                        title: audioPanel.output ? "System output" : "No output available"
                        subtitle: audioPanel.output ? audioPanel.nodeName(audioPanel.output) : "Waiting for a default PipeWire sink"
                        badge: "OUT"
                    }

                    Text {
                        topPadding: 5
                        text: "OUTPUT DEVICE"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    Column {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: audioPanel.outputDevices

                            delegate: Rectangle {
                                id: deviceRow

                                required property var modelData
                                readonly property bool selected: audioPanel.output !== null && modelData === audioPanel.output

                                width: parent.width
                                height: 48
                                radius: Theme.radiusSmall
                                color: selected ? Theme.selection : deviceHover.containsMouse ? Theme.backgroundDark : "transparent"
                                border.color: selected ? Theme.accent : Theme.backgroundDarker
                                border.width: Theme.borderWidth

                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 12
                                    }
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: deviceRow.selected ? Theme.accent : Theme.muted
                                }

                                Text {
                                    anchors {
                                        left: parent.left
                                        right: statusText.left
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 34
                                        rightMargin: 10
                                    }
                                    text: audioPanel.nodeName(deviceRow.modelData)
                                    color: deviceRow.selected ? Theme.foreground : Theme.foregroundSoft
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontBody
                                    font.weight: deviceRow.selected ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: statusText

                                    anchors {
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        rightMargin: 12
                                    }
                                    text: deviceRow.selected ? "ACTIVE" : "SELECT"
                                    color: deviceRow.selected ? Theme.accent : Theme.muted
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontCaption
                                }

                                MouseArea {
                                    id: deviceHover

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Pipewire.preferredDefaultAudioSink = deviceRow.modelData
                                }
                            }
                        }

                        Text {
                            visible: audioPanel.outputDevices.length === 0
                            width: parent.width
                            height: 40
                            verticalAlignment: Text.AlignVCenter
                            text: Pipewire.ready ? "No output devices found" : "Discovering output devices…"
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontBody
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.backgroundDarker
                    }

                    Text {
                        topPadding: 5
                        text: "MICROPHONE"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    VolumeRow {
                        node: audioPanel.microphone
                        title: audioPanel.microphone ? "Microphone" : "No microphone available"
                        subtitle: audioPanel.microphone ? audioPanel.nodeName(audioPanel.microphone) : "Waiting for a default PipeWire source"
                        badge: "MIC"
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.backgroundDarker
                    }
                    Text {
                        topPadding: 5
                        text: "DANTE / MAC"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        width: parent.width
                        height: danteContent.implicitHeight + 24
                        radius: Theme.radiusMedium
                        color: Theme.backgroundDark
                        border.color: audioPanel.macStatusTone
                        border.width: Theme.borderWidth

                        Column {
                            id: danteContent

                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 12
                            }
                            spacing: 8

                            Item {
                                width: parent.width
                                height: 20

                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: audioPanel.macStatusTone
                                }

                                Text {
                                    anchors {
                                        left: parent.left
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: 20
                                    }
                                    text: audioPanel.macStatus
                                    color: audioPanel.macStatusTone
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontCaption
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    anchors {
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: `MAC / VIA · ${audioPanel.macRoutes.length} ${audioPanel.macRoutes.length === 1 ? "ROUTE" : "ROUTES"}`
                                    color: Theme.foregroundSoft
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontCaption
                                    font.weight: Font.DemiBold
                                }
                            }

                            Text {
                                width: parent.width
                                text: audioPanel.coreAudioDeviceSummary()
                                color: audioPanel.macDevices.length > 0 ? Theme.foregroundSoft : Theme.muted
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                                wrapMode: Text.Wrap
                            }

                            Column {
                                width: parent.width
                                spacing: 0

                                Repeater {
                                    model: audioPanel.macNonLocalRoutes

                                    delegate: Item {
                                        required property var modelData

                                        width: parent.width
                                        height: routeText.implicitHeight + 12

                                        Rectangle {
                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                top: parent.top
                                            }
                                            height: 1
                                            color: Theme.backgroundDarker
                                        }

                                        Text {
                                            id: routeText

                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                verticalCenter: parent.verticalCenter
                                                leftMargin: 8
                                                rightMargin: 8
                                            }
                                            text: `${audioPanel.routeSourceLabel(parent.modelData)} → ${audioPanel.routeSinkLabel(parent.modelData)}`
                                            color: Theme.foreground
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontCaption
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }

                                Text {
                                    visible: audioPanel.macNonLocalRoutes.length === 0
                                    width: parent.width
                                    topPadding: 4
                                    bottomPadding: 4
                                    text: "No non-local Via routes reported"
                                    color: Theme.muted
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontCaption
                                }
                            }

                            Text {
                                width: parent.width
                                text: "INTERNAL MODEL · semantics unknown"
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontCaption
                            }

                            Text {
                                visible: audioPanel.macStatusMessage().length > 0
                                width: parent.width
                                text: audioPanel.macStatusMessage()
                                color: audioPanel.macStatus === "UNAVAILABLE" ? Theme.error : Theme.warning
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.backgroundDarker
                    }

                    Text {
                        topPadding: 5
                        text: "APPLICATIONS"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    Column {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: audioPanel.playbackStreams

                            delegate: VolumeRow {
                                required property var modelData

                                node: modelData
                                title: audioPanel.streamName(modelData)
                                subtitle: audioPanel.streamDetail(modelData)
                                badge: "APP"
                            }
                        }

                        Text {
                            visible: audioPanel.playbackStreams.length === 0
                            width: parent.width
                            height: 48
                            verticalAlignment: Text.AlignVCenter
                            text: Pipewire.ready ? "No applications are playing audio" : "Discovering playback streams…"
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontBody
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
                    bottom: parent.bottom
                    leftMargin: 22
                    bottomMargin: 13
                }
                text: `${audioPanel.playbackStreams.length} playback ${audioPanel.playbackStreams.length === 1 ? "stream" : "streams"}`
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
            }

            Text {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: 22
                    bottomMargin: 13
                }
                text: "esc or click outside to close"
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
            }
        }
    }
}
