import QtQuick
import qs

// Single-line input with optional leading icon and placeholder.
// Forwards the common TextInput API through aliases.
Item {
    id: root

    property string icon
    property string placeholder
    property bool large: false
    property alias text: input.text
    property alias input: input
    property alias echoMode: input.echoMode
    property alias readOnly: input.readOnly
    readonly property bool activeFocusInput: input.activeFocus

    signal accepted
    signal textEdited
    // Fires before the input handles a key; accept the event to consume it
    // (e.g. arrows or Ctrl+C driving a result list instead of the cursor).
    signal keyPressed(var event)

    function forceInputFocus(): void {
        input.forceActiveFocus();
    }

    implicitWidth: 280
    implicitHeight: large ? 44 : 34

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.small
        color: Theme.surface.sunk
        border.width: Theme.borderWidth
        border.color: input.activeFocus ? Theme.lineStrong : Theme.line

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.motion.fast
            }
        }
    }

    Icon {
        id: leadingIcon

        anchors.left: parent.left
        anchors.leftMargin: Theme.space.md
        anchors.verticalCenter: parent.verticalCenter
        visible: root.icon !== ""
        name: root.icon
        size: root.large ? 18 : 15
        color: Theme.text.faint
    }

    TextInput {
        id: input

        anchors {
            left: leadingIcon.visible ? leadingIcon.right : parent.left
            right: parent.right
            leftMargin: leadingIcon.visible ? Theme.space.sm + 2 : Theme.space.md
            rightMargin: Theme.space.md
            verticalCenter: parent.verticalCenter
        }
        clip: true
        color: Theme.text.base
        selectionColor: Theme.withAlpha(Theme.accent, 0.35)
        selectedTextColor: Theme.text.base
        font.family: root.large ? Theme.fontDisplay : Theme.fontSans
        font.pixelSize: root.large ? Theme.fontSize.title - 2 : Theme.fontSize.bar
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => root.keyPressed(event)
        onAccepted: root.accepted()
        onTextEdited: root.textEdited()

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            text: root.placeholder
            font: input.font
            color: Theme.text.disabled
        }
    }
}
