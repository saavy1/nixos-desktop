import QtQuick
import qs

// A chord as a row of KeyCaps, e.g. tokens: ["Super", "Shift", "G"].
Row {
    id: root

    property var tokens: []
    property bool large: false
    property string tone: "base"

    spacing: large ? Theme.space.xs + 2 : Theme.space.xs

    Repeater {
        model: root.tokens

        delegate: KeyCap {
            required property var modelData

            text: modelData
            large: root.large
            tone: root.tone
        }
    }
}
