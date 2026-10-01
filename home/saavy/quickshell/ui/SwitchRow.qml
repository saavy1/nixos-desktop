import QtQuick
import qs

// Title and optional detail on the left, a Toggle on the right.
Item {
    id: root

    property string title
    property string detail
    property bool checked: false

    signal toggled

    width: parent ? parent.width : 0
    height: Math.max(copy.implicitHeight, 24)

    Column {
        id: copy

        anchors {
            left: parent.left
            right: toggle.left
            rightMargin: Theme.space.md
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Label {
            width: parent.width
            text: root.title
            font.weight: Font.Medium
            tone: root.enabled ? "base" : "faint"
        }

        Label {
            width: parent.width
            visible: root.detail !== ""
            text: root.detail
            variant: "small"
            tone: "faint"
        }
    }

    Toggle {
        id: toggle

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: root.checked
        onToggled: root.toggled()
    }
}
