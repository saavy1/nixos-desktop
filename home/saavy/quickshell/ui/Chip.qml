import QtQuick
import qs

// Small mono pill for modes, filters and statuses. Clickable when `interactive`.
//   tone: neutral | accent | success | warning | danger
Item {
    id: root

    property string text
    property string icon
    property bool selected: false
    property bool interactive: true
    property string tone: "neutral"

    readonly property color toneColor: tone === "neutral" ? Theme.text.soft : Theme.tone(tone)

    signal clicked(var mouse)

    implicitHeight: 24
    implicitWidth: row.implicitWidth + 18
    opacity: enabled ? 1 : Theme.alpha.disabled

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.small
        color: root.selected ? Theme.accent
            : root.tone !== "neutral" ? Theme.withAlpha(root.toneColor, Theme.alpha.tint)
            : mouse.containsMouse && root.interactive ? Theme.hover
            : "transparent"
        border.width: root.selected || root.tone !== "neutral" ? 0 : Theme.borderWidth
        border.color: Theme.line

        Behavior on color {
            ColorAnimation {
                duration: Theme.motion.fast
            }
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 5

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            size: 12
            color: root.selected ? Theme.accentText : root.toneColor
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            variant: "label"
            color: root.selected ? Theme.accentText : root.toneColor
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: event => root.clicked(event)
    }
}
