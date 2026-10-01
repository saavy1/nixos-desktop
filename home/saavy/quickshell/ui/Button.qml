import QtQuick
import qs

// Text button with an optional leading icon.
//   variant: primary | ghost | subtle | danger
// `selected` renders any variant in the primary (filled) style.
Item {
    id: root

    property string text
    property string icon
    property string variant: "ghost"
    property bool selected: false
    property bool compact: false
    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.pressed
    property alias acceptedButtons: mouse.acceptedButtons

    readonly property bool filled: selected || variant === "primary"
    readonly property color foreground: filled ? Theme.accentText
        : variant === "danger" ? Theme.danger
        : variant === "subtle" || mouse.containsMouse ? Theme.text.base
        : Theme.text.soft

    signal clicked(var mouse)

    implicitHeight: compact ? 26 : 32
    implicitWidth: content.implicitWidth + (compact ? 20 : 28)
    opacity: enabled ? 1 : Theme.alpha.disabled
    scale: mouse.pressed ? 0.97 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.motion.fast
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.small
        color: {
            if (root.filled)
                return mouse.containsMouse ? Qt.lighter(Theme.accent, 1.07) : Theme.accent;
            if (root.variant === "danger")
                return mouse.containsMouse ? Theme.withAlpha(Theme.danger, 0.24) : Theme.dangerTint;
            if (root.variant === "subtle")
                return mouse.containsMouse ? Theme.surface.hover : Theme.surface.raised;
            return mouse.containsMouse ? Theme.hover : "transparent";
        }
        border.width: root.variant === "ghost" && !root.filled ? Theme.borderWidth : 0
        border.color: Theme.lineStrong

        Behavior on color {
            ColorAnimation {
                duration: Theme.motion.fast
            }
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.space.xs + 2

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: root.compact ? 13 : 15
            color: root.foreground
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            variant: root.compact ? "small" : "body"
            font.pixelSize: root.compact ? Theme.fontSize.small : Theme.fontSize.bar
            font.weight: root.filled || root.variant === "danger" ? Font.Medium : Font.Normal
            color: root.foreground
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => root.clicked(event)
    }
}
