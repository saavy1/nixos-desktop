import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick
import qs.ui

Variants {
    id: root

    required property var notificationState
    required property var mediaStatus
    required property var captureState
    required property var agentUsage
    required property var labState
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: bar

            required property var modelData
            property bool trayExpanded: false
            // workspace id -> name, from the workspace-namer service.
            property var workspaceNames: ({})
            property string networkState: "unknown"
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property var sinkAudio: sink && sink.audio ? sink.audio : null
            readonly property var hyprMonitor: Hyprland.monitorFor(screen)
            readonly property var notifications: root.notificationState
            readonly property var media: root.mediaStatus
            readonly property var capture: root.captureState
            readonly property bool recording: capture && capture.recording

            function togglePanel(target) {
                PopupController.toggle(target)
            }

            screen: modelData
            color: "transparent"
            implicitHeight: Theme.barHeight

            anchors {
                top: true
                left: true
                right: true
            }

            margins {
                top: Theme.outerMargin
                left: Theme.outerMargin
                right: Theme.outerMargin
            }

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-bar"

            SystemClock {
                id: systemClock
                precision: SystemClock.Minutes
            }

            PwObjectTracker {
                objects: [bar.sink]
            }

            Process {
                id: networkProc

                command: ["nmcli", "-t", "-f", "CONNECTIVITY", "general", "status"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: bar.networkState = text.trim().toLowerCase()
                }
            }

            Timer {
                interval: 15000
                running: true
                repeat: true
                onTriggered: networkProc.running = true
            }

            FileView {
                path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/workspace-names.json`
                preload: true
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        bar.workspaceNames = JSON.parse(text()).workspaces || ({})
                    } catch (error) {}
                }
            }

            TrayMenu {
                id: trayMenu

                screen: bar.screen
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius.medium
                color: Theme.withAlpha(Theme.surface.base, Theme.barOpacity)
                border.width: Theme.borderWidth
                border.color: Theme.line
            }

            // Left: system menu and workspaces.
            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.sm

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "snowflake"
                    tone: "base"
                    active: PopupController.isOpen("system")
                    onClicked: bar.togglePanel("system")
                }

                Hairline {
                    anchors.verticalCenter: parent.verticalCenter
                    vertical: true
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Repeater {
                        model: Hyprland.workspaces

                        delegate: Item {
                            id: workspace

                            required property var modelData
                            readonly property bool belongsToScreen: !modelData.monitor || modelData.monitor === bar.hyprMonitor
                            readonly property bool focused: modelData.focused
                            readonly property bool urgent: modelData.urgent
                            readonly property bool occupied: modelData.toplevels ? modelData.toplevels.values.length > 0 : true
                            readonly property string label: occupied ? bar.workspaceNames[String(modelData.id)] || "" : ""

                            visible: modelData.id > 0 && belongsToScreen
                            width: visible ? Math.max(30, content.implicitWidth + 20) : 0
                            height: 28

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radius.small
                                color: workspace.focused ? Theme.accent
                                    : workspace.urgent ? Theme.dangerTint
                                    : workspaceMouse.containsMouse ? Theme.hover
                                    : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.motion.fast
                                    }
                                }
                            }

                            Row {
                                id: content

                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: workspace.occupied && !workspace.focused && workspace.label === "" ? -2 : 0
                                spacing: 7

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: workspace.modelData.name || workspace.modelData.id
                                    variant: "numeric"
                                    tone: workspace.focused ? "accentText" : workspace.urgent ? "danger" : workspace.occupied ? "soft" : "disabled"
                                }

                                Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: workspace.label !== ""
                                    text: workspace.label
                                    variant: "small"
                                    tone: workspace.focused ? "accentText" : workspace.urgent ? "danger" : "faint"
                                }
                            }

                            Rectangle {
                                visible: workspace.occupied && !workspace.focused && workspace.label === ""
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                                width: 3
                                height: 3
                                radius: 1.5
                                color: workspace.urgent ? Theme.danger : Theme.text.faint
                            }

                            MouseArea {
                                id: workspaceMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: workspace.modelData.activate()
                            }
                        }
                    }
                }
            }

            // Center: date and time, opens the calendar.
            Item {
                anchors.centerIn: parent
                width: clock.implicitWidth + 28
                height: 30

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius.small
                    color: PopupController.isOpen("calendar") ? Theme.selected : clockMouse.containsMouse ? Theme.hover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.motion.fast
                        }
                    }
                }

                Row {
                    id: clock

                    anchors.centerIn: parent
                    spacing: Theme.space.md

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(systemClock.date, "dddd, MMM d")
                        variant: "display"
                        font.pixelSize: Theme.fontSize.bar + 2
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 3
                        radius: 1.5
                        color: Theme.text.faint
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(systemClock.date, "HH:mm")
                        variant: "numeric"
                        font.pixelSize: Theme.fontSize.bar + 1
                    }
                }

                MouseArea {
                    id: clockMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.togglePanel("calendar")
                }
            }

            // Right: media, status and quick-panel buttons.
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.space.sm
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Item {
                    id: mediaChip

                    anchors.verticalCenter: parent.verticalCenter
                    visible: bar.media && bar.media.hasPlayers
                    width: visible ? mediaRow.implicitWidth + 20 : 0
                    height: 30

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.small
                        color: PopupController.isOpen("media") ? Theme.selected : mediaMouse.containsMouse ? Theme.hover : "transparent"
                    }

                    Row {
                        id: mediaRow

                        anchors.centerIn: parent
                        spacing: Theme.space.sm

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: bar.media && bar.media.playing ? "music" : "pause"
                            color: bar.media && bar.media.playing ? Theme.text.base : Theme.text.faint
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(200, implicitWidth)
                            text: bar.media ? bar.media.title || bar.media.playerName : ""
                            variant: "small"
                            tone: bar.media && bar.media.playing ? "soft" : "faint"
                        }
                    }

                    MouseArea {
                        id: mediaMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                bar.media.playPause()
                            else if (mouse.button === Qt.MiddleButton)
                                bar.media.next()
                            else
                                bar.togglePanel("media")
                        }
                        onWheel: wheel => {
                            if (wheel.angleDelta.y > 0)
                                bar.media.previous()
                            else
                                bar.media.next()
                        }
                    }
                }

                Hairline {
                    anchors.verticalCenter: parent.verticalCenter
                    vertical: true
                    visible: mediaChip.visible
                }

                Item {
                    width: mediaChip.visible ? 6 : 0
                    height: 1
                }

                IconButton {
                    readonly property var limit: root.agentUsage.tightest

                    anchors.verticalCenter: parent.verticalCenter
                    visible: limit !== null
                    icon: "gauge"
                    label: limit ? `${Math.round(limit.usedFraction * 100)}%` : ""
                    tone: !limit || limit.usedFraction < 0.7 ? "soft" : limit.usedFraction < 0.9 ? "warning" : "danger"
                    active: PopupController.isOpen("agents")
                    onClicked: bar.togglePanel("agents")
                }

                IconButton {
                    readonly property string status: root.labState.status

                    anchors.verticalCenter: parent.verticalCenter
                    icon: "server"
                    tone: status === "danger" ? "danger" : status === "warning" ? "warning" : "soft"
                    badge: status === "danger"
                    active: PopupController.isOpen("lab")
                    onClicked: bar.togglePanel("lab")
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: bar.networkState === "none" ? "wifi-off" : "wifi"
                    tone: bar.networkState === "full" || bar.networkState === "unknown" ? "soft" : bar.networkState === "none" ? "danger" : "warning"
                    active: PopupController.isOpen("network")
                    onClicked: bar.togglePanel("network")
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "bluetooth"
                    active: PopupController.isOpen("bluetooth")
                    onClicked: bar.togglePanel("bluetooth")
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "monitor"
                    active: PopupController.isOpen("display")
                    onClicked: bar.togglePanel("display")
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: bar.recording ? "circle-stop" : "circle-dot"
                    label: bar.recording ? bar.capture.formatDuration(bar.capture.elapsedSeconds) : ""
                    tone: bar.recording ? "danger" : "soft"
                    active: PopupController.isOpen("capture")
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton && bar.recording)
                            bar.capture.stopRecording()
                        else
                            bar.togglePanel("capture")
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool muted: bar.sinkAudio && bar.sinkAudio.muted

                    icon: !bar.sinkAudio || muted ? "volume-x" : bar.sinkAudio.volume < 0.4 ? "volume-1" : "volume-2"
                    label: bar.sinkAudio ? (muted ? "mute" : String(Math.round(bar.sinkAudio.volume * 100))) : "--"
                    tone: muted ? "danger" : "soft"
                    active: PopupController.isOpen("audio")
                    wheelEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            if (bar.sinkAudio)
                                bar.sinkAudio.muted = !bar.sinkAudio.muted
                        } else {
                            bar.togglePanel("audio")
                        }
                    }
                    onScrolled: wheel => {
                        if (!bar.sinkAudio)
                            return

                        const change = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                        bar.sinkAudio.volume = Math.max(0, Math.min(1.5, bar.sinkAudio.volume + change))
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool dnd: bar.notifications && bar.notifications.dnd

                    icon: dnd ? "bell-off" : "bell"
                    tone: dnd ? "warning" : "soft"
                    badge: !dnd && bar.notifications && bar.notifications.count > 0
                    active: PopupController.isOpen("notifications")
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            bar.notifications.toggleDnd()
                        else
                            bar.notifications.toggleCenter()
                    }
                }

                Hairline {
                    anchors.verticalCenter: parent.verticalCenter
                    vertical: true
                    visible: SystemTray.items.values.length > 0
                }

                Repeater {
                    model: SystemTray.items

                    delegate: Item {
                        id: trayItem

                        required property var modelData

                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                        visible: bar.trayExpanded
                        width: visible ? 28 : 0
                        height: 30

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius.small
                            color: trayMenu.visible && trayMenu.trayItem === trayItem.modelData ? Theme.selected
                                : trayMouse.containsMouse ? Theme.hover : "transparent"
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: trayItem.modelData.icon
                            sourceSize.width: 16
                            sourceSize.height: 16
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            id: trayMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                const item = trayItem.modelData
                                if (mouse.button === Qt.MiddleButton)
                                    item.secondaryActivate()
                                else if (item.hasMenu && (mouse.button === Qt.RightButton || item.onlyMenu))
                                    trayMenu.openFor(item, trayItem)
                                else
                                    item.activate()
                            }
                            onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y / 120, false)
                        }
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: SystemTray.items.values.length > 0
                    icon: bar.trayExpanded ? "chevron-right" : "chevron-left"
                    label: bar.trayExpanded ? "" : String(SystemTray.items.values.length)
                    tone: "faint"
                    iconSize: 14
                    onClicked: bar.trayExpanded = !bar.trayExpanded
                }
            }
        }
    }
}
