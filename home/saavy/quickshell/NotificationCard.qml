import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import qs.ui

// Notification toast ("C · toast"): icon tile, mono app name + time, summary,
// body, optional image, action buttons, inline reply and a timeout line.
Card {
    id: root

    required property var notification
    required property var notificationState
    required property real receivedAt
    property bool compact: false
    property bool showInlineReply: false
    // Popup deadline (ms since epoch); 0 hides the timeout line.
    property real expiresAt: 0
    property real timeoutProgress: 0

    readonly property bool critical: notification && notification.urgency === NotificationUrgency.Critical
    readonly property string imageSource: notification && notification.image ? notification.image : ""
    readonly property string appIconSource: notification && notification.appIcon
        ? Quickshell.iconPath(notification.appIcon, true)
        : ""

    function restartTimeout(): void {
        timeoutAnimation.stop()
        const total = notificationState && notification ? notificationState.popupTimeout(notification) * 1000 : 0
        if (expiresAt <= 0 || total <= 0) {
            timeoutProgress = 0
            return
        }
        const remaining = Math.max(0, expiresAt - Date.now())
        timeoutProgress = Math.max(0, Math.min(1, remaining / total))
        timeoutAnimation.from = timeoutProgress
        timeoutAnimation.duration = remaining
        timeoutAnimation.start()
    }

    onExpiresAtChanged: restartTimeout()
    Component.onCompleted: restartTimeout()

    implicitHeight: content.implicitHeight + Theme.space.lg * 2
    surfaceOpacity: Math.min(1, Theme.panelOpacity + 0.05)

    NumberAnimation {
        id: timeoutAnimation

        target: root
        property: "timeoutProgress"
        to: 0
    }

    MouseArea {
        anchors.fill: parent
    }

    // Urgent notifications get a rust outline over the card's hairline.
    Rectangle {
        anchors.fill: parent
        visible: root.critical
        radius: root.radius
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.withAlpha(Theme.danger, 0.7)
    }

    Rectangle {
        id: iconTile

        anchors {
            left: parent.left
            top: parent.top
            margins: Theme.space.lg
        }
        width: 36
        height: 36
        radius: Theme.radius.medium
        color: appIcon.visible ? "transparent" : root.critical ? Theme.dangerTint : Theme.surface.raised

        IconImage {
            id: appIcon

            anchors.centerIn: parent
            implicitWidth: 30
            implicitHeight: 30
            source: root.appIconSource
            visible: source.toString().length > 0
        }

        Icon {
            anchors.centerIn: parent
            visible: !appIcon.visible
            name: root.critical ? "triangle-alert" : "message-square"
            size: 17
            color: root.critical ? Theme.danger : Theme.text.soft
        }
    }

    Column {
        id: content

        anchors {
            left: iconTile.right
            right: parent.right
            top: parent.top
            leftMargin: Theme.space.md
            rightMargin: Theme.space.lg
            topMargin: Theme.space.lg
        }
        spacing: Theme.space.sm

        Column {
            width: parent.width
            spacing: Theme.space.xs

            Item {
                width: parent.width
                height: 18

                Row {
                    anchors {
                        left: parent.left
                        right: closeButton.left
                        rightMargin: Theme.space.sm
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.space.sm

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - timeLabel.width - parent.spacing)
                        text: root.notification ? (root.notification.appName || "Notification") : "Notification"
                        variant: "label"
                        tone: root.critical ? "danger" : "soft"
                    }

                    Label {
                        id: timeLabel

                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatTime(new Date(root.receivedAt), "hh:mm")
                        variant: "numeric"
                        font.pixelSize: Theme.fontSize.caption
                        font.weight: Font.Normal
                        tone: "faint"
                    }
                }

                IconButton {
                    id: closeButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 24
                    implicitHeight: 22
                    iconSize: 14
                    icon: "x"
                    tone: "faint"
                    onClicked: root.notificationState.dismiss(root.notification)
                }
            }

            Label {
                width: parent.width
                text: root.notification ? (root.notification.summary || "Notification") : "Notification"
                font.weight: Font.Medium
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                visible: text.length > 0
                text: root.notification ? root.notification.body : ""
                textFormat: Text.StyledText
                variant: "small"
                tone: "soft"
                linkColor: Theme.accent
                wrapMode: Text.Wrap
                maximumLineCount: root.compact ? 2 : 12
                lineHeight: 1.15
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
        }

        Image {
            width: parent.width
            height: visible ? (root.compact ? 110 : 160) : 0
            visible: root.imageSource.length > 0
            source: root.imageSource
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            verticalAlignment: Image.AlignVCenter
        }

        Flow {
            width: parent.width
            spacing: Theme.space.sm - 2
            visible: actionRepeater.count > 0
            height: visible ? childrenRect.height : 0

            Repeater {
                id: actionRepeater

                model: root.notification ? root.notification.actions : []

                delegate: Button {
                    required property var modelData
                    required property int index

                    compact: true
                    variant: index === 0 ? "primary" : "ghost"
                    text: modelData.text || "Open"
                    width: Math.min(200, Math.max(64, implicitWidth))
                    onClicked: root.notificationState.invokeAction(root.notification, modelData)
                }
            }
        }

        Row {
            width: parent.width
            height: visible ? replyInput.implicitHeight : 0
            visible: root.showInlineReply && root.notification && root.notification.hasInlineReply
            spacing: Theme.space.sm

            function send(): void {
                if (root.notificationState.sendReply(root.notification, replyInput.text))
                    replyInput.text = ""
            }

            TextField {
                id: replyInput

                width: parent.width - sendButton.width - parent.spacing
                placeholder: root.notification && root.notification.inlineReplyPlaceholder
                    ? root.notification.inlineReplyPlaceholder
                    : "Reply…"
                onAccepted: parent.send()
            }

            Button {
                id: sendButton

                anchors.verticalCenter: parent.verticalCenter
                text: "Send"
                icon: "send"
                variant: "subtle"
                onClicked: parent.send()
            }
        }
    }

    // Popup timeout: a 2px lichen line draining along the bottom edge.
    Item {
        visible: root.expiresAt > 0 && root.timeoutProgress > 0
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: Theme.space.lg
            rightMargin: Theme.space.lg
            bottomMargin: Theme.space.sm - 2
        }
        height: 2

        Rectangle {
            anchors.fill: parent
            radius: 1
            color: Theme.line
        }

        Rectangle {
            width: parent.width * root.timeoutProgress
            height: parent.height
            radius: 1
            color: Theme.secondary
        }
    }
}
