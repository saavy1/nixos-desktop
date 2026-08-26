import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: panel

    required property var state

    visible: PopupController.isOpen("capture")
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
    WlrLayershell.namespace: "solitude-capture"

    function open(): void {
        PopupController.open("capture")
        Qt.callLater(() => keyboardScope.forceActiveFocus())
    }

    function close(): void {
        PopupController.close("capture")
    }

    function toggle(): void {
        if (visible)
            close()
        else
            open()
    }

    IpcHandler {
        target: "capture"

        function toggle(): void {
            panel.toggle()
        }

        function close(): void {
            panel.close()
        }
    }

    component ActionButton: Rectangle {
        id: button

        required property string label
        property bool selected: false
        property bool destructive: false
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

    FocusScope {
        id: keyboardScope
        anchors.fill: parent
        focus: panel.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
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
                bottom: parent.bottom
                topMargin: Theme.outerMargin + Theme.barHeight + Theme.shellGap
                rightMargin: Theme.outerMargin
                bottomMargin: Theme.outerMargin
            }
            width: Math.min(640, panel.width - Theme.outerMargin * 2)

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
                        right: recordingBadge.left
                        verticalCenter: parent.verticalCenter
                        rightMargin: 14
                    }
                    spacing: 2

                    Text {
                        text: "Capture"
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        text: panel.state.status
                        color: panel.state.lastError.length > 0 ? Theme.warning : Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: recordingBadge
                    visible: panel.state.recording
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: recordingText.implicitWidth + 24
                    height: 34
                    radius: Theme.radiusSmall
                    color: Theme.withAlpha(Theme.error, 0.18)
                    border.color: Theme.error
                    border.width: Theme.borderWidth

                    Text {
                        id: recordingText
                        anchors.centerIn: parent
                        text: `REC ${panel.state.formatDuration(panel.state.elapsedSeconds)}`
                        color: Theme.error
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                    }
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

                    Rectangle {
                        width: parent.width
                        height: screenshotContent.implicitHeight + 28
                        radius: Theme.radiusMedium
                        color: Theme.backgroundDark
                        border.color: Theme.backgroundDarker
                        border.width: Theme.borderWidth

                        Column {
                            id: screenshotContent
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 14
                            }
                            spacing: 10

                            Text {
                                text: "SCREENSHOT"
                                color: Theme.accent
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.DemiBold
                            }

                            Text {
                                width: parent.width
                                text: "Choose a display, window, or region. Saved captures also copy to the clipboard."
                                color: Theme.muted
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                                wrapMode: Text.Wrap
                            }

                            Flow {
                                width: parent.width
                                spacing: 8

                                ActionButton {
                                    label: "Display"
                                    selected: panel.state.screenshotMode === "output"
                                    enabled: !panel.state.busy
                                    onActivated: panel.state.screenshotMode = "output"
                                }
                                ActionButton {
                                    label: "Window"
                                    selected: panel.state.screenshotMode === "window"
                                    enabled: !panel.state.busy
                                    onActivated: panel.state.screenshotMode = "window"
                                }
                                ActionButton {
                                    label: "Region"
                                    selected: panel.state.screenshotMode === "region"
                                    enabled: !panel.state.busy
                                    onActivated: panel.state.screenshotMode = "region"
                                }
                                ActionButton {
                                    label: "Save"
                                    selected: panel.state.screenshotDestination === "save"
                                    enabled: !panel.state.busy
                                    onActivated: panel.state.screenshotDestination = "save"
                                }
                                ActionButton {
                                    label: "Clipboard"
                                    selected: panel.state.screenshotDestination === "clipboard"
                                    enabled: !panel.state.busy
                                    onActivated: panel.state.screenshotDestination = "clipboard"
                                }
                                ActionButton {
                                    label: panel.state.busy ? "Selecting…" : "Capture"
                                    selected: true
                                    enabled: !panel.state.busy
                                    onActivated: {
                                        panel.close()
                                        panel.state.takeScreenshot(panel.state.screenshotMode, panel.state.screenshotDestination)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: recordingContent.implicitHeight + 28
                        radius: Theme.radiusMedium
                        color: Theme.backgroundDark
                        border.color: panel.state.recording ? Theme.error : Theme.backgroundDarker
                        border.width: Theme.borderWidth

                        Column {
                            id: recordingContent
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 14
                            }
                            spacing: 10

                            Row {
                                width: parent.width

                                Text {
                                    width: parent.width - recordStatus.width
                                    text: "SCREEN RECORDING"
                                    color: panel.state.recording ? Theme.error : Theme.accent
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontCaption
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    id: recordStatus
                                    text: panel.state.recording ? panel.state.formatDuration(panel.state.elapsedSeconds) : "AV1 · MKV"
                                    color: panel.state.recording ? Theme.error : Theme.muted
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontCaption
                                }
                            }

                            Text {
                                width: parent.width
                                text: panel.state.recording
                                    ? `${panel.state.recordingLabel}  ·  ${panel.state.recordingFps} FPS  ·  ${panel.state.recordingAudio ? "desktop audio" : "silent"}`
                                    : "GPU-accelerated AV1 recording to Videos. Region capture opens an interactive selector."
                                color: Theme.muted
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                                wrapMode: Text.Wrap
                            }

                            Flow {
                                width: parent.width
                                spacing: 8

                                ActionButton {
                                    label: "Display"
                                    selected: panel.state.recordingTarget === "output"
                                    enabled: !panel.state.recording && !panel.state.busy
                                    onActivated: panel.state.recordingTarget = "output"
                                }
                                ActionButton {
                                    label: "Region"
                                    selected: panel.state.recordingTarget === "region"
                                    enabled: !panel.state.recording && !panel.state.busy
                                    onActivated: panel.state.recordingTarget = "region"
                                }
                                Repeater {
                                    model: [30, 60, 120]

                                    ActionButton {
                                        required property var modelData
                                        label: `${Number(modelData)} FPS`
                                        selected: panel.state.recordingFps === Number(modelData)
                                        enabled: !panel.state.recording && !panel.state.busy
                                        onActivated: panel.state.recordingFps = Number(modelData)
                                    }
                                }
                                ActionButton {
                                    label: panel.state.recordingAudio ? "Audio on" : "Audio off"
                                    selected: panel.state.recordingAudio
                                    enabled: !panel.state.recording && !panel.state.busy
                                    onActivated: panel.state.recordingAudio = !panel.state.recordingAudio
                                }
                                ActionButton {
                                    label: panel.state.recordingHdr ? "HDR codec" : "10-bit SDR"
                                    selected: panel.state.recordingHdr
                                    enabled: !panel.state.recording && !panel.state.busy
                                    onActivated: panel.state.recordingHdr = !panel.state.recordingHdr
                                }
                            }

                            ActionButton {
                                label: panel.state.recording ? "Stop and save recording" : panel.state.busy ? "Selecting region…" : "Start recording"
                                destructive: panel.state.recording
                                selected: !panel.state.recording
                                enabled: panel.state.recording || !panel.state.busy
                                onActivated: {
                                    if (panel.state.recording)
                                        panel.state.stopRecording()
                                    else {
                                        panel.close()
                                        panel.state.startRecording(panel.state.recordingTarget)
                                    }
                                }
                            }

                            Text {
                                visible: panel.state.recordingPath.length > 0
                                width: parent.width
                                text: panel.state.recordingPath
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontCaption
                                elide: Text.ElideMiddle
                            }
                        }
                    }

                    Text {
                        text: "RECENT CAPTURES"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    Column {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: panel.state.history

                            delegate: Rectangle {
                                required property string kind
                                required property string detail
                                required property string path
                                required property string duration

                                width: parent ? parent.width : 0
                                height: 54
                                radius: Theme.radiusSmall
                                color: Theme.backgroundDark
                                border.color: Theme.backgroundDarker
                                border.width: Theme.borderWidth

                                Column {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        margins: 12
                                    }
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: `${kind.toUpperCase()}  ·  ${detail}${duration.length > 0 ? `  ·  ${duration}` : ""}`
                                        color: Theme.foreground
                                        font.family: Theme.fontSans
                                        font.pixelSize: Theme.fontCaption
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: path.length > 0 ? path : "Clipboard"
                                        color: Theme.muted
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontCaption
                                        elide: Text.ElideMiddle
                                    }
                                }
                            }
                        }

                        Text {
                            visible: panel.state.history.count === 0
                            width: parent.width
                            height: 48
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: "No captures in this shell session"
                            color: Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontCaption
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
                    leftMargin: 20
                    bottomMargin: 13
                }
                text: "Super+Shift+G capture  ·  Super+Ctrl+R record"
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
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
        }
    }
}
