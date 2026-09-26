import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import qs.ui

PanelWindow {
    id: root
    visible: root.displayed
    screen: PopupController.focusedScreen
    color: "transparent"
    implicitWidth: 420
    implicitHeight: 96
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    anchors {
        bottom: true
    }

    margins {
        bottom: 72
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-osd"

    readonly property var output: Pipewire.defaultAudioSink
    readonly property var microphone: Pipewire.defaultAudioSource
    readonly property var outputAudio: output !== null && output !== undefined && output.ready ? output.audio : null
    readonly property var microphoneAudio: microphone !== null && microphone !== undefined && microphone.ready ? microphone.audio : null
    readonly property real outputLevel: outputAudio !== null && outputAudio !== undefined ? outputAudio.volume : -1
    readonly property bool outputMuted: outputAudio !== null && outputAudio !== undefined ? outputAudio.muted : false
    readonly property real microphoneLevel: microphoneAudio !== null && microphoneAudio !== undefined ? microphoneAudio.volume : -1
    readonly property bool microphoneMuted: microphoneAudio !== null && microphoneAudio !== undefined ? microphoneAudio.muted : false

    property bool displayed: false
    property bool shown: false
    property bool outputObserved: false
    property bool microphoneObserved: false
    property string lastOutputState: ""
    property string lastMicrophoneState: ""
    property string badge: "OSD"
    property string icon: "circle-dot"
    property string heading: ""
    property string detail: ""
    property string valueText: ""
    property real level: 0
    property bool hasProgress: false
    property color highlight: Theme.accent

    function normalizedLevel(value: real): real {
        if (!isFinite(value))
            return 0

        return Math.max(0, Math.min(1, value))
    }

    function percentage(value: real): string {
        return `${Math.round(normalizedLevel(value) * 100)}%`
    }

    function fileName(path: string): string {
        const cleanPath = String(path || "").replace(/\/$/, "")
        const parts = cleanPath.split("/")
        return parts.length > 0 ? parts[parts.length - 1] : cleanPath
    }

    function present(nextBadge: string, nextIcon: string, nextHeading: string, nextDetail: string, nextValue: string, nextLevel: real, progress: bool, nextHighlight, holdMilliseconds: int): void {
        badge = nextBadge
        icon = nextIcon
        heading = nextHeading
        detail = nextDetail
        valueText = nextValue
        level = normalizedLevel(nextLevel)
        hasProgress = progress
        highlight = nextHighlight

        closeTimer.stop()
        hideTimer.interval = Math.max(900, Math.min(5000, holdMilliseconds))
        hideTimer.restart()

        if (!displayed) {
            shown = false
            displayed = true
            Qt.callLater(() => {
                if (displayed)
                    shown = true
            })
        } else {
            shown = true
        }
    }

    function outputVolume(value: real, muted: bool): void {
        const normalized = normalizedLevel(value)
        present(
            muted ? "MUTE" : "VOL",
            muted ? "volume-x" : "volume-2",
            "Output volume",
            muted ? "Audio output is muted" : "Default audio output",
            muted ? "MUTED" : percentage(normalized),
            normalized,
            true,
            muted ? Theme.danger : Theme.accent,
            1800
        )
    }

    function microphoneVolume(value: real, muted: bool): void {
        const normalized = normalizedLevel(value)
        present(
            muted ? "MUTE" : "MIC",
            muted ? "mic-off" : "mic",
            "Microphone",
            muted ? "Microphone is muted" : "Default audio input",
            muted ? "MUTED" : percentage(normalized),
            normalized,
            true,
            muted ? Theme.danger : Theme.accent,
            1800
        )
    }

    function microphoneMute(muted: bool): void {
        microphoneVolume(microphoneLevel >= 0 ? microphoneLevel : 0, muted)
    }

    function brightness(value: real): void {
        const normalized = normalizedLevel(value)
        present(
            "SUN",
            "sun",
            "Brightness",
            "Display backlight",
            percentage(normalized),
            normalized,
            true,
            Theme.warning,
            1800
        )
    }

    function media(title: string, artist: string, playing: bool): void {
        const cleanTitle = String(title || "").trim()
        const cleanArtist = String(artist || "").trim()
        present(
            playing ? "PLAY" : "PAUSE",
            playing ? "play" : "pause",
            cleanTitle || "Media",
            cleanArtist || (playing ? "Now playing" : "Playback paused"),
            playing ? "PLAYING" : "PAUSED",
            0,
            false,
            Theme.accent,
            2400
        )
    }

    function showPlayer(player): void {
        if (player === null || player === undefined)
            return

        const playing = player.playbackState === MprisPlaybackState.Playing
        const stopped = player.playbackState === MprisPlaybackState.Stopped
        const title = String(player.trackTitle || "").trim()
        const artist = String(player.trackArtist || "").trim()
        present(
            playing ? "PLAY" : stopped ? "STOP" : "PAUSE",
            playing ? "play" : stopped ? "square" : "pause",
            title || "Media",
            artist || (playing ? "Now playing" : stopped ? "Playback stopped" : "Playback paused"),
            playing ? "PLAYING" : stopped ? "STOPPED" : "PAUSED",
            0,
            false,
            Theme.accent,
            2400
        )
    }

    function screenshotSaved(path: string): void {
        const name = fileName(path)
        present(
            "SHOT",
            "camera",
            "Screenshot saved",
            name || "Saved to disk",
            "SAVED",
            0,
            false,
            Theme.success,
            2200
        )
    }

    function screenshotCopied(): void {
        present(
            "SHOT",
            "clipboard-check",
            "Screenshot copied",
            "Image copied to the clipboard",
            "COPIED",
            0,
            false,
            Theme.success,
            2200
        )
    }

    function recording(recordingActive: bool): void {
        present(
            recordingActive ? "REC" : "STOP",
            recordingActive ? "circle-dot" : "circle-stop",
            recordingActive ? "Recording started" : "Recording stopped",
            recordingActive ? "Screen capture is in progress" : "Screen capture finished",
            recordingActive ? "RECORDING" : "STOPPED",
            0,
            false,
            recordingActive ? Theme.danger : Theme.success,
            2500
        )
    }

    function close(): void {
        hideTimer.stop()
        beginExit()
    }

    function beginExit(): void {
        if (!displayed)
            return

        shown = false
        closeTimer.restart()
    }

    function handleOutputState(): void {
        if (outputLevel < 0 || !isFinite(outputLevel)) {
            outputObserved = false
            lastOutputState = ""
            return
        }

        const state = `${Math.round(normalizedLevel(outputLevel) * 1000)}:${outputMuted}`
        if (!outputObserved) {
            outputObserved = true
            lastOutputState = state
            return
        }

        if (state === lastOutputState)
            return

        lastOutputState = state
        outputVolume(outputLevel, outputMuted)
    }

    function handleMicrophoneState(): void {
        if (microphoneLevel < 0 || !isFinite(microphoneLevel)) {
            microphoneObserved = false
            lastMicrophoneState = ""
            return
        }

        const state = `${Math.round(normalizedLevel(microphoneLevel) * 1000)}:${microphoneMuted}`
        if (!microphoneObserved) {
            microphoneObserved = true
            lastMicrophoneState = state
            return
        }

        if (state === lastMicrophoneState)
            return

        lastMicrophoneState = state
        microphoneVolume(microphoneLevel, microphoneMuted)
    }

    onOutputLevelChanged: handleOutputState()
    onOutputMutedChanged: handleOutputState()
    onMicrophoneLevelChanged: handleMicrophoneState()
    onMicrophoneMutedChanged: handleMicrophoneState()
    Component.onCompleted: {
        handleOutputState()
        handleMicrophoneState()
    }


    PwObjectTracker {
        objects: [root.output, root.microphone]
    }

    IpcHandler {
        target: "osd"

        function outputVolume(value: real, muted: bool): void {
            root.outputVolume(value, muted)
        }

        function microphoneVolume(value: real, muted: bool): void {
            root.microphoneVolume(value, muted)
        }

        function microphoneMute(muted: bool): void {
            root.microphoneMute(muted)
        }

        function brightness(value: real): void {
            root.brightness(value)
        }

        function media(title: string, artist: string, playing: bool): void {
            root.media(title, artist, playing)
        }

        function screenshotSaved(path: string): void {
            root.screenshotSaved(path)
        }

        function screenshotCopied(): void {
            root.screenshotCopied()
        }

        function recording(active: bool): void {
            root.recording(active)
        }

        function close(): void {
            root.close()
        }
    }

    Item {
        Repeater {
            model: Mpris.players

            delegate: Item {
                id: mediaWatcher

                required property var modelData
                property string lastState: ""

                function currentState(): string {
                    if (modelData === null || modelData === undefined)
                        return ""

                    return `${String(modelData.trackTitle || "")}\n${String(modelData.trackArtist || "")}\n${modelData.playbackState}`
                }

                function publishChange(): void {
                    const state = currentState()
                    if (state === "" || state === lastState)
                        return

                    if (lastState === "") {
                        lastState = state
                        return
                    }

                    lastState = state
                    root.showPlayer(modelData)
                }

                Component.onCompleted: lastState = currentState()

                Connections {
                    target: mediaWatcher.modelData

                    function onTrackTitleChanged(): void {
                        mediaWatcher.publishChange()
                    }

                    function onTrackArtistChanged(): void {
                        mediaWatcher.publishChange()
                    }

                    function onPlaybackStateChanged(): void {
                        mediaWatcher.publishChange()
                    }
                }
            }
        }
    }

    Timer {
        id: hideTimer

        interval: 1800
        repeat: false
        onTriggered: root.beginExit()
    }

    Timer {
        id: closeTimer

        interval: 180
        repeat: false
        onTriggered: {
            if (!root.shown)
                root.displayed = false
        }
    }

    Card {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shown ? parent.height - height - Theme.space.xl : parent.height - height - Theme.space.xl + 14
        width: parent.width - Theme.space.xxl
        height: 60
        radius: Theme.radius.pill
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.98

        Behavior on y {
            NumberAnimation {
                duration: Theme.motion.base
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motion.fast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.motion.base
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: iconDisc

            anchors {
                left: parent.left
                leftMargin: Theme.space.md
                verticalCenter: parent.verticalCenter
            }
            width: 36
            height: 36
            radius: width / 2
            color: Theme.withAlpha(root.highlight, Theme.alpha.tint)

            Icon {
                anchors.centerIn: parent
                name: root.icon
                size: 17
                color: root.highlight
            }
        }

        Column {
            anchors {
                left: iconDisc.right
                right: valueLabel.left
                leftMargin: Theme.space.md
                rightMargin: Theme.space.md
                verticalCenter: parent.verticalCenter
            }
            spacing: root.hasProgress ? Theme.space.sm - 1 : 1

            Item {
                width: parent.width
                height: headingLabel.implicitHeight

                Label {
                    id: headingLabel

                    anchors.left: parent.left
                    width: root.hasProgress ? Math.min(implicitWidth, parent.width) : parent.width
                    text: root.heading
                    variant: "small"
                    font.weight: Font.Medium
                }

                // With a meter the detail shares the heading line.
                Label {
                    visible: root.hasProgress
                    anchors {
                        left: headingLabel.right
                        right: parent.right
                        leftMargin: Theme.space.sm
                        baseline: headingLabel.baseline
                    }
                    text: root.detail
                    variant: "caption"
                    tone: "faint"
                    elide: Text.ElideMiddle
                }
            }

            Label {
                visible: !root.hasProgress
                width: parent.width
                text: root.detail
                variant: "caption"
                tone: "faint"
                elide: Text.ElideMiddle
            }

            Meter {
                visible: root.hasProgress
                width: parent.width
                value: root.level
                fillColor: root.highlight
            }
        }

        Label {
            id: valueLabel

            anchors {
                right: parent.right
                rightMargin: Theme.space.xl
                verticalCenter: parent.verticalCenter
            }
            width: Math.max(44, implicitWidth)
            horizontalAlignment: Text.AlignRight
            text: root.valueText
            variant: root.hasProgress ? "numeric" : "label"
            color: root.highlight
        }
    }
}
