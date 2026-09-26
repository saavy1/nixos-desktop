import QtQuick
import qs

// Horizontal 0..1 slider. It does not own its value: bind `value` and write
// back from `moved`. `level` (0..1, optional) draws a second, brighter fill
// under the handle, e.g. a live input level.
Item {
    id: root

    property real value: 0
    property real level: -1
    property color fillColor: Theme.accent
    property real wheelStep: 0.05
    readonly property bool dragging: mouse.pressed

    signal moved(real value)

    property real shownValue: Math.max(0, Math.min(1, value))

    Behavior on shownValue {
        enabled: !mouse.pressed

        NumberAnimation {
            duration: Theme.motion.fast
            easing.type: Easing.OutCubic
        }
    }

    function setFromX(x: real): void {
        root.moved(Math.max(0, Math.min(1, (x - handle.width / 2) / (width - handle.width))));
    }

    implicitWidth: 200
    implicitHeight: 20
    opacity: enabled ? 1 : Theme.alpha.disabled

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surface.sunk
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: handle.x + handle.width / 2
        height: track.height
        radius: track.radius
        color: root.level >= 0 ? Theme.withAlpha(root.fillColor, 0.45) : root.fillColor
    }

    Rectangle {
        visible: root.level >= 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(handle.x + handle.width / 2, track.width * Math.max(0, Math.min(1, root.level)))
        height: track.height
        radius: track.radius
        color: root.fillColor
    }

    Rectangle {
        id: handle

        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - width) * root.shownValue
        width: 18
        height: 18
        radius: 9
        color: root.fillColor
        border.width: mouse.containsMouse || mouse.pressed ? 4 : 0
        border.color: Theme.withAlpha(root.fillColor, 0.22)

        Behavior on border.width {
            NumberAnimation {
                duration: Theme.motion.fast
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        onPressed: event => root.setFromX(event.x)
        onPositionChanged: event => {
            if (pressed)
                root.setFromX(event.x);
        }
        onWheel: event => {
            const step = event.angleDelta.y > 0 ? root.wheelStep : -root.wheelStep;
            root.moved(Math.max(0, Math.min(1, root.value + step)));
        }
    }
}
