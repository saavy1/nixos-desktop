import QtQuick
import qs

// Square icon button, or an icon + mono label chip when `label` is set.
// `active` fills it with the accent (e.g. while its popup is open).
Item {
    id: root

    property string icon
    property string label
    property string tone: "soft"
    property bool active: false
    property bool badge: false
    property int iconSize: 16
    // Set when `scrolled` is handled; otherwise wheel events pass through.
    property bool wheelEnabled: false
    property alias hovered: mouse.containsMouse
    property alias acceptedButtons: mouse.acceptedButtons

    readonly property color foreground: active ? Theme.accentText
        : mouse.containsMouse && tone === "soft" ? Theme.text.base
        : Theme.tone(tone)

    signal clicked(var mouse)
    signal scrolled(var wheel)

    implicitHeight: 30
    implicitWidth: label === "" ? 32 : content.implicitWidth + 20
    opacity: enabled ? 1 : Theme.alpha.disabled

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.small
        color: root.active ? (mouse.containsMouse ? Qt.lighter(Theme.accent, 1.07) : Theme.accent)
            : mouse.pressed ? Theme.selected
            : mouse.containsMouse ? Theme.hover
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
        spacing: 7

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: root.iconSize
            color: root.foreground
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            variant: "numeric"
            font.pixelSize: Theme.fontSize.small
            color: root.foreground
        }
    }

    Rectangle {
        visible: root.badge
        x: root.label === "" ? parent.width - 11 : parent.width - 8
        y: 5
        width: 6
        height: 6
        radius: 3
        color: Theme.danger
        border.width: 1
        border.color: Theme.surface.base
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => root.clicked(event)
        onWheel: event => {
            if (root.wheelEnabled)
                root.scrolled(event);
            else
                event.accepted = false;
        }
    }
}
