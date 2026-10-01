import QtQuick
import QtQuick.Effects
import qs

// Image cropped to a rounded rectangle, on a sunk placeholder that shows
// `placeholderIcon` until the image is ready.
Item {
    id: root

    property alias source: image.source
    property alias sourceSize: image.sourceSize
    property alias status: image.status
    property int radius: Theme.radius.medium
    property string placeholderIcon
    property bool bordered: false

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.surface.sunk

        Icon {
            anchors.centerIn: parent
            visible: root.placeholderIcon !== "" && image.status !== Image.Ready
            name: root.placeholderIcon
            size: Math.max(16, Math.round(Math.min(root.width, root.height) / 4))
            color: Theme.text.disabled
        }
    }

    Image {
        id: image

        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false
        layer.enabled: true
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        visible: image.status === Image.Ready
        source: image
        maskEnabled: true
        maskSource: mask
    }

    Rectangle {
        visible: root.bordered
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.line
    }
}
