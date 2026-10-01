import QtQuick
import qs

// Selectable row: icon, title/subtitle/detail, mono trailing tag, optional
// radio indicator and extra trailing content (default property, e.g. buttons).
// Non-interactive rows can still highlight on hover via `hoverHighlight`.
Item {
    id: root

    property string icon
    property string title
    property string subtitle
    property string subtitleTone: "faint"
    // Third line in small mono, e.g. an address.
    property string detail
    property string trailing
    property string trailingTone: "faint"
    property bool selected: false
    property bool indicator: false
    property bool interactive: true
    property bool hoverHighlight: interactive
    property alias hovered: mouse.containsMouse
    property alias acceptedButtons: mouse.acceptedButtons
    default property alias trailingContent: trailingSlot.data

    signal clicked(var mouse)

    implicitWidth: 320
    implicitHeight: detail !== "" ? 64 : subtitle !== "" ? 52 : 42
    opacity: enabled ? 1 : Theme.alpha.disabled

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.small
        color: root.selected ? Theme.selected : mouse.containsMouse && root.hoverHighlight ? Theme.hover : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.motion.fast
            }
        }
    }

    Row {
        id: leading

        anchors {
            left: parent.left
            leftMargin: Theme.space.md
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.space.md

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            color: root.selected ? Theme.text.base : Theme.text.soft
        }
    }

    Column {
        anchors {
            left: leading.right
            leftMargin: leading.visibleChildren.length > 0 ? Theme.space.md : 0
            right: trailingRow.left
            rightMargin: Theme.space.md
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Label {
            width: parent.width
            text: root.title
            tone: root.selected ? "base" : "soft"
            font.weight: root.selected ? Font.Medium : Font.Normal
        }

        Label {
            width: parent.width
            visible: root.subtitle !== ""
            text: root.subtitle
            variant: "small"
            tone: root.subtitleTone
        }

        Label {
            width: parent.width
            visible: root.detail !== ""
            text: root.detail
            variant: "numeric"
            font.pixelSize: Theme.fontSize.caption
            font.weight: Font.Normal
            tone: "faint"
        }
    }

    Row {
        id: trailingRow

        anchors {
            right: parent.right
            rightMargin: Theme.space.md
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.space.md

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.trailing !== ""
            text: root.trailing
            variant: "label"
            tone: root.trailingTone
        }

        Row {
            id: trailingSlot

            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.sm
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.indicator
            width: 16
            height: 16
            radius: 8
            color: "transparent"
            border.width: root.selected ? 5 : 1.5
            border.color: root.selected ? Theme.accent : Theme.text.disabled

            Behavior on border.width {
                NumberAnimation {
                    duration: Theme.motion.fast
                }
            }
        }
    }

    MouseArea {
        id: mouse

        z: -1
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: root.interactive ? Qt.LeftButton : Qt.NoButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => root.clicked(event)
    }
}
