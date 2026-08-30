import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import QtQuick

Variants {
    id: root

    required property var notificationState
    required property var mediaStatus
    required property var captureState
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: bar

            required property var modelData
            property bool trayExpanded: false
            property string networkState: "unknown"
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property var hyprMonitor: Hyprland.monitorFor(screen)
            readonly property var notifications: root.notificationState
            readonly property var media: root.mediaStatus
            readonly property var capture: root.captureState

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
            WlrLayershell.namespace: "solitude-bar"

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


            Rectangle {
                id: leftPill

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: leftContent.implicitWidth + 16
                height: parent.height
                radius: Theme.radiusMedium
                color: Theme.withAlpha(Theme.background, Theme.panelOpacity)
                border.color: Theme.backgroundDarker
                border.width: Theme.borderWidth

                Row {
                    id: leftContent

                    anchors.centerIn: parent
                    spacing: 4

                    Rectangle {
                        width: 30
                        height: 30
                        color: PopupController.isOpen("system") || menuHover.containsMouse ? Theme.selection : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "S"
                            color: Theme.accent
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontBar
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: menuHover

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: bar.togglePanel("system")
                        }
                    }

                    PanelDivider {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Repeater {
                        model: Hyprland.workspaces

                        delegate: Rectangle {
                            id: workspace

                            required property var modelData
                            readonly property bool belongsToScreen: !modelData.monitor || modelData.monitor === bar.hyprMonitor

                            visible: modelData.id > 0 && belongsToScreen
                            width: 32
                            height: 30
                            radius: Theme.radiusSmall
                            color: modelData.urgent ? Theme.error : modelData.focused ? Theme.selection : workspaceHover.containsMouse ? Theme.backgroundDark : "transparent"

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: workspace.modelData.focused
                                width: 16
                                height: 2
                                radius: 1
                                color: Theme.accent
                            }

                            Text {
                                anchors.centerIn: parent
                                text: workspace.modelData.id
                                color: workspace.modelData.urgent ? Theme.background : workspace.modelData.focused ? Theme.foreground : Theme.foregroundSoft
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontBody
                                font.weight: workspace.modelData.focused ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: workspaceHover

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: workspace.modelData.activate()
                            }
                        }
                    }

                    PanelDivider {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Hyprland.activeToplevel !== null
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Hyprland.activeToplevel !== null
                        width: Theme.barTitleWidth
                        text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                id: clockPill

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: clockText.implicitWidth + 28
                height: parent.height
                radius: Theme.radiusMedium
                color: Theme.withAlpha(Theme.background, Theme.panelOpacity)
                border.color: PopupController.isOpen("calendar") ? Theme.accent : Theme.backgroundDarker
                border.width: Theme.borderWidth

                Text {
                    id: clockText

                    anchors.centerIn: parent
                    text: Qt.formatDateTime(systemClock.date, "ddd MMM d   HH:mm")
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontBar
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.togglePanel("calendar")
                }
            }

            Rectangle {
                id: rightPill

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: rightContent.implicitWidth + 18
                height: parent.height
                radius: Theme.radiusMedium
                color: Theme.withAlpha(Theme.background, Theme.panelOpacity)
                border.color: PopupController.isOpen("audio") || PopupController.isOpen("bluetooth") || PopupController.isOpen("capture") || PopupController.isOpen("display") || PopupController.isOpen("media") || PopupController.isOpen("network") || PopupController.isOpen("notifications") ? Theme.accent : Theme.backgroundDarker
                border.width: Theme.borderWidth

                Row {
                    id: rightContent

                    anchors.centerIn: parent
                    spacing: Theme.shellGap

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: bar.media && bar.media.hasPlayers
                        width: visible ? Math.min(220, implicitWidth) : 0
                        text: bar.media ? bar.media.title || bar.media.playerName : ""
                        color: PopupController.isOpen("media") || bar.media && bar.media.playing ? Theme.accent : Theme.foregroundSoft
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
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

                    PanelDivider {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: bar.media && bar.media.hasPlayers
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: bar.networkState === "full" ? "NET" : bar.networkState.toUpperCase()
                        color: PopupController.isOpen("network") ? Theme.accent : bar.networkState === "full" ? Theme.foregroundSoft : bar.networkState === "none" ? Theme.error : Theme.warning
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.togglePanel("network")
                        }
                    }

                    PanelDivider {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "BT"
                        color: PopupController.isOpen("bluetooth") ? Theme.accent : Theme.foregroundSoft
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.togglePanel("bluetooth")
                        }
                    }

                    PanelDivider {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DSP"
                        color: PopupController.isOpen("display") ? Theme.accent : Theme.foregroundSoft
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.togglePanel("display")
                        }
                    }

                    PanelDivider {
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: bar.capture && bar.capture.recording
                            ? `REC ${bar.capture.formatDuration(bar.capture.elapsedSeconds)}`
                            : "CAP"
                        color: bar.capture && bar.capture.recording
                            ? Theme.error
                            : PopupController.isOpen("capture") ? Theme.accent : Theme.foregroundSoft
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton && bar.capture && bar.capture.recording)
                                    bar.capture.stopRecording()
                                else
                                    bar.togglePanel("capture")
                            }
                        }
                    }

                    PanelDivider {
                        anchors.verticalCenter: parent.verticalCenter
                    }



                    Text {
                        id: volume

                        anchors.verticalCenter: parent.verticalCenter
                        text: bar.sink && bar.sink.audio
                            ? bar.sink.audio.muted
                                ? "MUTED"
                                : `VOL ${Math.round(bar.sink.audio.volume * 100)}%`
                            : "VOL --"
                        color: PopupController.isOpen("audio") ? Theme.accent : bar.sink && bar.sink.audio && bar.sink.audio.muted ? Theme.muted : Theme.foregroundSoft
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    if (bar.sink && bar.sink.audio)
                                        bar.sink.audio.muted = !bar.sink.audio.muted
                                } else {
                                    bar.togglePanel("audio")
                                }
                            }
                            onWheel: wheel => {
                                if (!bar.sink || !bar.sink.audio)
                                    return

                                const change = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                bar.sink.audio.volume = Math.max(0, Math.min(1.5, bar.sink.audio.volume + change))
                            }
                        }
                    }

                    PanelDivider {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: notifications && notifications.dnd ? "DND" : notifications && notifications.count > 0 ? `N ${notifications.count}` : "N"
                        color: PopupController.isOpen("notifications") ? Theme.accent : notifications && notifications.dnd ? Theme.warning : notifications && notifications.count > 0 ? Theme.accent : Theme.foregroundSoft
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    notifications.toggleDnd()
                                else
                                    notifications.toggleCenter()
                            }
                        }
                    }

                    PanelDivider {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: SystemTray.items.values.length > 0
                    }

                    Repeater {
                        model: SystemTray.items

                        delegate: Item {
                            id: trayItem

                            required property var modelData
                            visible: bar.trayExpanded
                            width: visible ? 22 : 0
                            height: 30

                            Image {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                source: trayItem.modelData.icon
                                sourceSize.width: 18
                                sourceSize.height: 18
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton)
                                        trayItem.modelData.secondaryActivate()
                                    else
                                        trayItem.modelData.activate()
                                }
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: SystemTray.items.values.length > 0
                        text: bar.trayExpanded ? "›" : `TRAY ${SystemTray.items.values.length}`
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.trayExpanded = !bar.trayExpanded
                        }
                    }
                }
            }
        }
    }
}
