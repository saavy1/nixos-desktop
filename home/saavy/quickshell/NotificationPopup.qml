import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: popup

    required property var notificationState

    visible: notificationState && notificationState.popupCount > 0
    screen: PopupController.focusedScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false
    implicitWidth: 430
    implicitHeight: Math.min(notificationList.contentHeight, screen ? Math.max(120, screen.height - Theme.barHeight - Theme.outerMargin * 3) : 700)

    anchors {
        top: true
        right: true
    }

    margins {
        top: Theme.outerMargin + Theme.barHeight + Theme.shellGap
        right: Theme.outerMargin
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "solitude-notification-popup"

    ListView {
        id: notificationList

        anchors.fill: parent
        model: popup.notificationState ? popup.notificationState.popups : null
        spacing: 8
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        delegate: NotificationCard {

            width: notificationList.width
            notificationState: popup.notificationState
            compact: true
            showInlineReply: false
        }

        add: Transition {
            NumberAnimation {
                properties: "opacity,x"
                from: 0
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: 140
                easing.type: Easing.OutCubic
            }
        }
    }
}
