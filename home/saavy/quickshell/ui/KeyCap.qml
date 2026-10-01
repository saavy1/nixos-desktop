import QtQuick
import qs

// One key of a shortcut, drawn as a small raised cap.
Rectangle {
    id: root

    property string text
    property bool large: false
    property string tone: "base"

    implicitHeight: large ? 34 : 22
    implicitWidth: Math.max(implicitHeight, capLabel.implicitWidth + (large ? Theme.space.lg : Theme.space.sm + 2))
    radius: Theme.radius.small
    color: Theme.surface.raised
    border.width: Theme.borderWidth
    border.color: tone === "warning" ? Theme.withAlpha(Theme.warning, Theme.alpha.lineStrong * 2) : Theme.line

    Label {
        id: capLabel

        anchors.centerIn: parent
        text: root.text
        variant: "numeric"
        font.pixelSize: root.large ? Theme.fontSize.body : Theme.fontSize.caption
        tone: root.tone
    }
}
