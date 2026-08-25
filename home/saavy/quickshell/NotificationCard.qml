import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick

PanelCard {
    id: root

    required property var notification
    required property var notificationState
    required property real receivedAt
    property bool compact: false
    property bool showInlineReply: false

    readonly property bool critical: notification && notification.urgency === NotificationUrgency.Critical
    readonly property string imageSource: notification && notification.image ? notification.image : ""
    readonly property string appIconSource: notification && notification.appIcon
        ? Quickshell.iconPath(notification.appIcon, true)
        : ""

    implicitHeight: content.implicitHeight + 24
    color: Theme.withAlpha(Theme.background, Math.min(1, Theme.panelOpacity + 0.05))
    border.color: critical ? Theme.error : Theme.backgroundDarker

    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: content

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 10

        Item {
            width: parent.width
            height: Math.max(44, titleBlock.implicitHeight)

            Rectangle {
                id: iconBackground

                anchors {
                    left: parent.left
                    top: parent.top
                }
                width: 44
                height: 44
                radius: Theme.radiusMedium
                color: Theme.backgroundDark
                border.color: critical ? Theme.error : Theme.border
                border.width: Theme.borderWidth

                IconImage {
                    id: appIcon
                    anchors.centerIn: parent
                    implicitWidth: 30
                    implicitHeight: 30
                    source: root.appIconSource
                    visible: source.toString().length > 0
                }

                Text {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    text: root.critical ? "!" : "●"
                    color: root.critical ? Theme.error : Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.Bold
                }
            }

            Column {
                id: titleBlock

                anchors {
                    left: iconBackground.right
                    right: closeButton.left
                    top: parent.top
                    leftMargin: 10
                    rightMargin: 8
                }
                spacing: 3

                Row {
                    spacing: 8

                    Text {
                        text: root.notification ? (root.notification.appName || "Notification") : "Notification"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, titleBlock.width - timeLabel.width - 8)
                    }

                    Text {
                        id: timeLabel

                        text: Qt.formatTime(new Date(root.receivedAt), "hh:mm")
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                    }
                }

                Text {
                    width: parent.width
                    text: root.notification ? (root.notification.summary || "Notification") : "Notification"
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
            }

            Rectangle {
                id: closeButton

                anchors {
                    right: parent.right
                    top: parent.top
                }
                width: 30
                height: 30
                radius: Theme.radiusSmall
                color: closeHover.containsMouse ? Theme.selection : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: Theme.error
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontTitle
                }

                MouseArea {
                    id: closeHover

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.notificationState.dismiss(root.notification)
                }
            }
        }

        Text {
            width: parent.width
            visible: text.length > 0
            text: root.notification ? root.notification.body : ""
            textFormat: Text.StyledText
            color: Theme.foregroundSoft
            linkColor: Theme.accent
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontBody
            wrapMode: Text.Wrap
            maximumLineCount: root.compact ? 4 : 12
            elide: Text.ElideRight
            onLinkActivated: link => Qt.openUrlExternally(link)
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
            spacing: 6
            visible: actionRepeater.count > 0
            height: visible ? childrenRect.height : 0

            Repeater {
                id: actionRepeater

                model: root.notification ? root.notification.actions : []

                delegate: Rectangle {
                    required property var modelData

                    width: Math.max(72, actionText.implicitWidth + 24)
                    height: 34
                    radius: Theme.radiusSmall
                    color: actionHover.containsMouse ? Theme.selection : Theme.backgroundDark
                    border.color: actionHover.containsMouse ? Theme.accent : Theme.border
                    border.width: Theme.borderWidth

                    Text {
                        id: actionText

                        anchors.centerIn: parent
                        text: modelData.text || "Open"
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 180)
                    }

                    MouseArea {
                        id: actionHover

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.notificationState.invokeAction(root.notification, modelData)
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: visible ? 38 : 0
            visible: root.showInlineReply && root.notification && root.notification.hasInlineReply

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: Theme.backgroundDark
                border.color: replyInput.activeFocus ? Theme.accent : Theme.border
                border.width: Theme.borderWidth
            }

            TextInput {
                id: replyInput

                anchors {
                    left: parent.left
                    right: sendButton.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 10
                    rightMargin: 8
                }
                clip: true
                color: Theme.foreground
                selectionColor: Theme.selection
                selectedTextColor: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontBody
                onAccepted: sendButton.send()

                Text {
                    anchors.fill: parent
                    visible: replyInput.text.length === 0 && !replyInput.activeFocus
                    text: root.notification && root.notification.inlineReplyPlaceholder
                        ? root.notification.inlineReplyPlaceholder
                        : "Reply…"
                    color: Theme.muted
                    font: replyInput.font
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                id: sendButton

                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                width: 58
                radius: Theme.radiusSmall
                color: sendHover.containsMouse ? Theme.selection : "transparent"

                function send(): void {
                    if (root.notificationState.sendReply(root.notification, replyInput.text))
                        replyInput.text = ""
                }

                Text {
                    anchors.centerIn: parent
                    text: "Send"
                    color: Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: sendHover

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: sendButton.send()
                }
            }
        }
    }
}
