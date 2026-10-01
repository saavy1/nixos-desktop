import QtQuick
import QtQuick.Effects
import qs

// Glass panel surface: translucent ink, hairline border, theme shadow and
// optional grain. Children are laid out on top.
Item {
    id: root

    property real surfaceOpacity: Theme.panelOpacity
    property color surfaceColor: Theme.surface.base
    property int radius: Theme.radius.large
    property bool grain: Theme.grainEnabled
    property bool shadow: Theme.shadowStyle !== "none"

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: root.radius
        color: Theme.withAlpha(root.surfaceColor, root.surfaceOpacity)
        border.width: Theme.borderWidth
        border.color: Theme.line
        layer.enabled: root.shadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.surface.deep
            shadowOpacity: Theme.shadowStyle === "offset" ? 0.7 : 0.55
            shadowBlur: Theme.shadowStyle === "offset" ? 0 : 1
            shadowHorizontalOffset: Theme.shadowStyle === "offset" ? 6 : 0
            shadowVerticalOffset: Theme.shadowStyle === "offset" ? 6 : 12
            blurMax: 48
        }
    }

    Loader {
        anchors.fill: parent
        active: root.grain
        sourceComponent: Item {
            Image {
                id: noise

                anchors.fill: parent
                source: Theme.grainSource
                fillMode: Image.Tile
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
                source: noise
                maskEnabled: true
                maskSource: mask
                opacity: Theme.grainOpacity
            }
        }
    }
}
