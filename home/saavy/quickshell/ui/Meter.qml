import QtQuick
import qs

// Thin read-only level bar.
Item {
    id: root

    property real value: 0
    property color fillColor: Theme.secondary

    implicitWidth: 120
    implicitHeight: 4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surface.sunk
    }

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.value))
        height: parent.height
        radius: height / 2
        color: root.fillColor

        Behavior on width {
            NumberAnimation {
                duration: Theme.motion.base
                easing.type: Easing.OutCubic
            }
        }
    }
}
