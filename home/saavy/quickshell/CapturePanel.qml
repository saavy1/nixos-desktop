import Quickshell
import QtQuick
import qs.ui

PopupPanel {
    id: panel

    required property var state

    readonly property bool locked: state.recording || state.busy

    name: "capture"
    title: "Capture"
    subtitle: state.status
    cardWidth: 460

    function homePath(path): string {
        const home = state.homeDirectory
        return home.length > 1 && path.startsWith(`${home}/`) ? `~${path.slice(home.length)}` : path
    }

    headerTrailing: [
        Chip {
            visible: panel.state.recording
            interactive: false
            tone: "danger"
            icon: "circle-dot"
            text: `rec ${panel.state.formatDuration(panel.state.elapsedSeconds)}`
        }
    ]

    footer: [
        Label {
            width: parent ? parent.width : 0
            text: "Super+Shift+G capture · Super+Ctrl+R record"
            variant: "numeric"
            font.pixelSize: Theme.fontSize.caption
            font.weight: Font.Normal
            tone: "faint"
        }
    ]

    Label {
        visible: panel.state.lastError.length > 0
        width: parent.width
        text: panel.state.status
        variant: "small"
        tone: "warning"
        wrapMode: Text.Wrap
        maximumLineCount: 4
    }

    // Screenshot

    SectionHeader {
        width: parent.width
        text: "Screenshot"
        trailing: "png"
    }

    Label {
        width: parent.width
        text: "Choose what to capture and where it should go, then use the button below."
        variant: "small"
        tone: "faint"
        wrapMode: Text.Wrap
    }

    Column {
        width: parent.width
        spacing: Theme.space.md

        OptionRow {
            label: "Capture"
            enabled: !panel.state.busy

            Chip {
                icon: "monitor"
                text: "Current display"
                selected: panel.state.screenshotMode === "output"
                onClicked: panel.state.screenshotMode = "output"
            }

            Chip {
                icon: "app-window"
                text: "Window"
                selected: panel.state.screenshotMode === "window"
                onClicked: panel.state.screenshotMode = "window"
            }

            Chip {
                icon: "scan-line"
                text: "Region"
                selected: panel.state.screenshotMode === "region"
                onClicked: panel.state.screenshotMode = "region"
            }
        }

        OptionRow {
            label: "Send to"
            enabled: !panel.state.busy

            Chip {
                icon: "image"
                text: "Save to Pictures"
                selected: panel.state.screenshotDestination === "save"
                onClicked: panel.state.screenshotDestination = "save"
            }

            Chip {
                icon: "clipboard"
                text: "Copy only"
                selected: panel.state.screenshotDestination === "clipboard"
                onClicked: panel.state.screenshotDestination = "clipboard"
            }
        }
    }

    Button {
        width: parent.width
        variant: "primary"
        icon: "camera"
        text: panel.state.busy ? "Selection already in progress…" : "Capture screenshot"
        enabled: !panel.state.busy
        onClicked: {
            panel.close()
            panel.state.takeScreenshot(panel.state.screenshotMode, panel.state.screenshotDestination)
        }
    }

    // Recording

    SectionHeader {
        width: parent.width
        text: "Screen recording"
        trailing: panel.state.recording ? panel.state.formatDuration(panel.state.elapsedSeconds) : "av1 · mkv"
        trailingTone: panel.state.recording ? "danger" : "faint"
    }

    Label {
        width: parent.width
        text: panel.state.recording
            ? `${panel.state.recordingLabel} · ${panel.state.recordingFps} fps · ${panel.state.recordingAudio ? "desktop audio" : "silent"}`
            : "Choose an area and options. For a region, press Start and then drag a rectangle on screen. Recordings save to Videos."
        variant: panel.state.recording ? "numeric" : "small"
        font.pixelSize: Theme.fontSize.small
        tone: panel.state.recording ? "soft" : "faint"
        wrapMode: Text.Wrap
    }

    Column {
        width: parent.width
        spacing: Theme.space.md

        OptionRow {
            label: "Area"
            enabled: !panel.locked

            Chip {
                icon: "monitor"
                text: "Current display"
                selected: panel.state.recordingTarget === "output"
                onClicked: panel.state.recordingTarget = "output"
            }

            Chip {
                icon: "scan-line"
                text: "Select region"
                selected: panel.state.recordingTarget === "region"
                onClicked: panel.state.recordingTarget = "region"
            }
        }

        OptionRow {
            label: "Frame rate"
            enabled: !panel.locked

            Repeater {
                model: [30, 60, 120]

                Chip {
                    required property var modelData

                    text: `${Number(modelData)} fps`
                    selected: panel.state.recordingFps === Number(modelData)
                    onClicked: panel.state.recordingFps = Number(modelData)
                }
            }
        }

        OptionRow {
            label: "Options"
            enabled: !panel.locked

            Chip {
                icon: panel.state.recordingAudio ? "volume-2" : "volume-x"
                text: panel.state.recordingAudio ? "Audio on" : "Audio off"
                selected: panel.state.recordingAudio
                onClicked: panel.state.recordingAudio = !panel.state.recordingAudio
            }

            Chip {
                icon: "sun"
                text: panel.state.recordingHdr ? "HDR codec" : "10-bit SDR"
                selected: panel.state.recordingHdr
                onClicked: panel.state.recordingHdr = !panel.state.recordingHdr
            }
        }
    }

    Button {
        width: parent.width
        variant: panel.state.recording ? "danger" : "primary"
        icon: panel.state.recording ? "circle-stop" : "circle-dot"
        text: panel.state.recording ? "Stop and save recording" : panel.state.busy ? "Selecting region…" : "Start recording"
        enabled: panel.state.recording || !panel.state.busy
        onClicked: {
            if (panel.state.recording) {
                panel.state.stopRecording()
            } else {
                panel.close()
                panel.state.startRecording(panel.state.recordingTarget)
            }
        }
    }

    Label {
        visible: panel.state.recordingPath.length > 0
        width: parent.width
        text: panel.homePath(panel.state.recordingPath)
        variant: "numeric"
        font.pixelSize: Theme.fontSize.caption
        font.weight: Font.Normal
        tone: "faint"
        elide: Text.ElideMiddle
    }

    // History

    SectionHeader {
        width: parent.width
        text: "Recent captures"
        trailing: panel.state.history.count > 0 ? String(panel.state.history.count) : ""
    }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: panel.state.history

            delegate: ListItem {
                required property string kind
                required property string detail
                required property string path
                required property string duration

                width: parent ? parent.width : 0
                interactive: false
                icon: kind === "Recording" ? "video" : "camera"
                title: `${kind} · ${detail}`
                subtitle: path.length > 0 ? panel.homePath(path) : "Clipboard"
                trailing: duration
            }
        }

        Label {
            visible: panel.state.history.count === 0
            width: parent.width
            text: "No captures in this shell session"
            variant: "small"
            tone: "faint"
        }
    }
}
