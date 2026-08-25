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
