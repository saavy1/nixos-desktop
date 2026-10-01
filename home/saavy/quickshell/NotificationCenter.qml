import Quickshell
import QtQuick
import qs.ui

PopupPanel {
    id: center

    required property var notificationState
    property bool confirmClear: false

    readonly property bool dnd: notificationState ? notificationState.dnd : false
    readonly property int count: notificationState ? notificationState.count : 0

    name: "notifications"
    title: "Notifications"
    subtitle: notificationState
        ? `${count} ${count === 1 ? "notification" : "notifications"}${dnd ? " · do not disturb" : ""}`
        : "unavailable"
    cardWidth: 500

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

    onOpening: {
        confirmClear = false
        clearConfirmation.stop()
    }

    Timer {
        id: clearConfirmation

        interval: 4000
        onTriggered: center.confirmClear = false
    }

    headerTrailing: [
        Item {
            implicitWidth: dndRow.implicitWidth
            implicitHeight: 32

            Row {
                id: dndRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.sm

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: center.dnd ? "bell-off" : "bell"
                    size: 15
                    color: center.dnd ? Theme.warning : Theme.text.faint
                }

                Toggle {
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: center.notificationState !== null && center.notificationState !== undefined
                    checked: center.dnd
                    onToggled: center.notificationState.toggleDnd()
                }
            }
        },
        Button {
            enabled: center.count > 0
            variant: center.confirmClear ? "danger" : "ghost"
            icon: center.confirmClear ? "trash-2" : ""
            text: center.confirmClear ? "Confirm clear" : "Clear"
            onClicked: center.requestClear()
        }
    ]

    Column {
        width: parent.width
        spacing: Theme.space.sm

        move: Transition {
            NumberAnimation {
                properties: "y"
                duration: Theme.motion.fast
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: center.notificationState ? center.notificationState.history : null

            delegate: NotificationCard {
                width: parent ? parent.width : 0
                notificationState: center.notificationState
                compact: false
                showInlineReply: true
                // Rows inside the panel: flat, no second shadow or grain layer.
                shadow: false
                grain: false
                surfaceColor: Theme.surface.sunk
                surfaceOpacity: 0.55
            }
        }
    }

    Column {
        visible: center.count === 0
        width: parent.width
        topPadding: Theme.space.xl
        bottomPadding: Theme.space.xl
        spacing: Theme.space.sm

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: center.dnd ? "bell-off" : "inbox"
            size: 22
            color: Theme.text.disabled
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: center.dnd ? "Do not disturb is on" : "No notifications"
            tone: "soft"
        }

        Label {
            visible: center.dnd
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "New notifications will be saved here"
            variant: "small"
            tone: "faint"
        }
    }

    footer: [
        Label {
            width: parent ? parent.width : 0
            horizontalAlignment: Text.AlignHCenter
            visible: center.dnd
            text: "popups inhibited · critical alerts still shown"
            variant: "numeric"
            font.pixelSize: Theme.fontSize.caption
            font.weight: Font.Normal
            tone: center.dnd ? "warning" : "faint"
        }
    ]
}
