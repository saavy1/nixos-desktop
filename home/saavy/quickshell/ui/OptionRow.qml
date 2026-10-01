import QtQuick
import qs

// Mono label column beside a wrapping row of options (usually Chips).
//   OptionRow { label: "Refresh"; Chip { text: "60 Hz" } Chip { … } }
Item {
    id: root

    property string label
    property int labelWidth: 96
    default property alias options: optionFlow.data

    width: parent ? parent.width : 0
    height: Math.max(24, optionFlow.height)
    opacity: enabled ? 1 : Theme.alpha.disabled

    Label {
        width: root.labelWidth
        height: 24
        verticalAlignment: Text.AlignVCenter
        text: root.label
        variant: "label"
        tone: "faint"
    }

    Flow {
        id: optionFlow

        x: root.labelWidth
        width: parent.width - x
        spacing: Theme.space.xs + 2
    }
}
