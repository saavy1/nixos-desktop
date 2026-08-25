import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: center

    required property var notificationState
    property bool confirmClear: false

    visible: PopupController.isOpen("notifications")
    screen: PopupController.focusedScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: visible

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "solitude-notifications"

    function open(): void {
        PopupController.open("notifications")
        Qt.callLater(() => keyboardScope.forceActiveFocus())
    }

    function toggle(): void {
        if (visible)
            close()
        else
            open()
    }

    function close(): void {
        confirmClear = false
        PopupController.close("notifications")
    }

    function requestClear(): void {
        if (!notificationState || notificationState.count === 0)
            return
        if (confirmClear) {
            notificationState.clear()
            confirmClear = false
            clearConfirmation.stop()
        } else {
            confirmClear = true
            clearConfirmation.restart()
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void { center.toggle() }
        function close(): void { center.close() }
    }

    Timer {
        id: clearConfirmation

        interval: 4000
        onTriggered: center.confirmClear = false
    }

    FocusScope {
        id: keyboardScope

        anchors.fill: parent
        focus: center.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                center.close()
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: center.close()
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
            width: Math.min(520, center.width - Theme.outerMargin * 2)

            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: header

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 18
                }
                height: 54

                Column {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Text {
                        text: "Notifications"
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: center.notificationState
                            ? `${center.notificationState.count} ${center.notificationState.count === 1 ? "notification" : "notifications"}`
                            : "Unavailable"
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                    }
                }

                Row {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 8

                    Rectangle {
                        width: dndLabel.implicitWidth + 26
                        height: 36
                        radius: Theme.radiusSmall
                        color: center.notificationState && center.notificationState.dnd ? Theme.selection : Theme.backgroundDark
                        border.color: center.notificationState && center.notificationState.dnd ? Theme.warning : Theme.border
                        border.width: Theme.borderWidth

                        Text {
                            id: dndLabel

                            anchors.centerIn: parent
                            text: center.notificationState && center.notificationState.dnd ? "DND on" : "DND off"
                            color: center.notificationState && center.notificationState.dnd ? Theme.warning : Theme.foregroundSoft
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: center.notificationState.toggleDnd()
                        }
                    }

                    Rectangle {
                        width: clearLabel.implicitWidth + 26
                        height: 36
                        radius: Theme.radiusSmall
                        color: center.confirmClear ? Theme.withAlpha(Theme.error, 0.18) : Theme.backgroundDark
                        border.color: center.confirmClear ? Theme.error : Theme.border
                        border.width: Theme.borderWidth
                        opacity: center.notificationState && center.notificationState.count > 0 ? 1 : 0.45

                        Text {
                            id: clearLabel

                            anchors.centerIn: parent
                            text: center.confirmClear ? "Confirm clear" : "Clear"
                            color: center.confirmClear ? Theme.error : Theme.foregroundSoft
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: center.notificationState && center.notificationState.count > 0
                            hoverEnabled: true
                            onClicked: center.requestClear()
                        }
                    }
                }
            }

            PanelDivider {
                vertical: false
                anchors {
                    top: header.bottom
                    left: parent.left
                    right: parent.right
                    leftMargin: 18
                    rightMargin: 18
                    topMargin: 8
                }
            }

            ListView {
                id: historyList

                anchors {
                    top: header.bottom
                    bottom: footer.top
                    left: parent.left
                    right: parent.right
                    topMargin: 22
                    bottomMargin: 10
                    leftMargin: 14
                    rightMargin: 14
                }
                model: center.notificationState ? center.notificationState.history : null
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: NotificationCard {

                    width: historyList.width
                    notificationState: center.notificationState
                    compact: false
                    showInlineReply: true
                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: historyList.count === 0
                    text: center.notificationState && center.notificationState.dnd
                        ? "Do not disturb is on\nNew notifications will be saved here"
                        : "No notifications"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontBody
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.4
                }
            }

            Item {
                id: footer

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 42

                Text {
                    anchors.centerIn: parent
                    text: center.notificationState && center.notificationState.dnd
                        ? "Popups inhibited · critical alerts still shown"
                        : "esc or click outside to close"
                    color: center.notificationState && center.notificationState.dnd ? Theme.warning : Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                }
            }
        }
    }
}
