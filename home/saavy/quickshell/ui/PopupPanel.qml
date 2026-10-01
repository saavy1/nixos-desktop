import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs

// Base for every popup: a fullscreen overlay that closes on outside click or
// Escape, a Card anchored under the bar with an open/close animation, an IPC
// handler named after the panel, and an optional title header, scrolling body
// and footer.
//
//   PopupPanel {
//       name: "audio"
//       title: "Sound"
//       headerTrailing: [ Button { text: "Mute all" } ]
//       Slider { ... }            // body content, stacked in a Column
//   }
PanelWindow {
    id: panel

    required property string name
    property string title
    property string subtitle
    // "right" | "left" | "center"
    property string placement: "right"
    property int cardWidth: 420
    property int topOffset: Theme.outerMargin + Theme.barHeight + Theme.shellGap
    property int maxCardHeight: (screen ? screen.height : 900) - topOffset - Theme.outerMargin
    property int padding: Theme.space.xl
    property int spacing: Theme.space.lg
    property bool scrollable: true
    // Disable to declare your own IpcHandler (target: name) with extra functions.
    property bool ipcEnabled: true

    readonly property bool shown: PopupController.isOpen(name)
    property real reveal: shown ? 1 : 0

    default property alias content: body.data
    property alias headerTrailing: headerTrailingRow.data
    property alias footer: footerRow.data
    property alias card: card
    property alias keyScope: keyScope
    property alias flickable: flick

    // Runs whenever the panel opens, however it was opened.
    signal opening
    // Keys not accepted here fall through to Escape-to-close.
    signal keyPressed(var event)

    function open(): void {
        PopupController.open(name);
    }

    function close(): void {
        PopupController.close(name);
    }

    function toggle(): void {
        PopupController.toggle(name);
    }

    onShownChanged: {
        if (shown) {
            opening();
            Qt.callLater(() => keyScope.forceActiveFocus());
        }
    }

    Behavior on reveal {
        NumberAnimation {
            duration: panel.shown ? Theme.motion.base : Theme.motion.fast
            easing.type: panel.shown ? Easing.OutCubic : Easing.InCubic
        }
    }

    // True from the moment it opens, so `opening` handlers can rely on it.
    visible: shown || reveal > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: shown
    screen: PopupController.focusedScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-" + name

    IpcHandler {
        target: panel.name
        enabled: panel.ipcEnabled

        function open(): void {
            panel.open();
        }

        function close(): void {
            panel.close();
        }

        function toggle(): void {
            panel.toggle();
        }
    }

    FocusScope {
        id: keyScope

        anchors.fill: parent
        focus: panel.shown

        Keys.onPressed: event => {
            panel.keyPressed(event);
            if (!event.accepted && event.key === Qt.Key_Escape) {
                panel.close();
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.close()
        }

        Card {
            id: card

            readonly property int headerHeight: header.visible ? header.height + panel.spacing : 0
            readonly property int footerHeight: footerRow.visibleChildren.length > 0 ? footerRow.height + panel.spacing : 0

            x: panel.placement === "left" ? Theme.outerMargin
                : panel.placement === "center" ? (parent.width - width) / 2
                : parent.width - width - Theme.outerMargin
            y: panel.topOffset - (1 - panel.reveal) * 8
            width: Math.min(panel.cardWidth, parent.width - Theme.outerMargin * 2)
            height: Math.min(panel.maxCardHeight, panel.padding * 2 + headerHeight + body.implicitHeight + footerHeight)
            opacity: panel.reveal

            // Swallow clicks so they don't reach the close-on-outside area.
            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: header

                visible: panel.title !== ""
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: panel.padding
                }
                height: Math.max(titleColumn.implicitHeight, headerTrailingRow.implicitHeight)

                Column {
                    id: titleColumn

                    anchors {
                        left: parent.left
                        right: headerTrailingRow.left
                        rightMargin: Theme.space.md
                        bottom: parent.bottom
                    }
                    spacing: Theme.space.xs + 2

                    Label {
                        width: parent.width
                        text: panel.title
                        variant: "display"
                    }

                    Label {
                        width: parent.width
                        visible: panel.subtitle !== ""
                        text: panel.subtitle
                        variant: "numeric"
                        font.pixelSize: Theme.fontSize.caption
                        font.weight: Font.Normal
                        tone: "faint"
                    }
                }

                Row {
                    id: headerTrailingRow

                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: Theme.space.sm
                }
            }

            Flickable {
                id: flick

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                    leftMargin: panel.padding
                    rightMargin: panel.padding
                    topMargin: panel.padding + card.headerHeight
                    bottomMargin: panel.padding + card.footerHeight
                }
                contentWidth: width
                contentHeight: body.implicitHeight
                interactive: panel.scrollable && contentHeight > height
                clip: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: body

                    width: flick.width
                    spacing: panel.spacing
                }
            }

            Rectangle {
                visible: flick.contentHeight > flick.height
                anchors.right: parent.right
                anchors.rightMargin: 5
                y: flick.y + flick.visibleArea.yPosition * flick.height
                width: 3
                height: Math.max(24, flick.visibleArea.heightRatio * flick.height)
                radius: 1.5
                color: Theme.lineStrong
            }

            Row {
                id: footerRow

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: panel.padding
                }
                spacing: Theme.space.sm
            }
        }
    }
}
