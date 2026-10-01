import QtQuick
import qs

// A Lucide glyph by name (see the generated Icons.qml for the full set).
Text {
    property string name
    property int size: 16

    text: Icons.glyphs[name] || ""
    color: Theme.text.soft
    font.family: Theme.fontIcons
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        ColorAnimation {
            duration: Theme.motion.fast
        }
    }
}
