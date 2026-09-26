import QtQuick
import qs

// Text with a typographic role and a color tone from the theme.
//   variant: display | title | heading | body | small | caption | label | numeric
//   tone:    base | soft | faint | disabled | accent | accentText | danger | warning | success
Text {
    property string variant: "body"
    property string tone: "base"

    readonly property bool isMono: variant === "label" || variant === "numeric"

    color: Theme.tone(tone)
    elide: Text.ElideRight
    textFormat: Text.PlainText
    font.family: variant === "display" ? Theme.fontDisplay : isMono ? Theme.fontMono : Theme.fontSans
    font.pixelSize: {
        switch (variant) {
        case "display":
            return Theme.fontSize.display;
        case "title":
            return Theme.fontSize.title;
        case "heading":
            return Theme.fontSize.heading;
        case "small":
            return Theme.fontSize.small;
        case "caption":
            return Theme.fontSize.caption;
        case "label":
            return Theme.fontSize.label;
        case "numeric":
            return Theme.fontSize.bar;
        default:
            return Theme.fontSize.body;
        }
    }
    font.weight: {
        switch (variant) {
        case "display":
        case "label":
        case "numeric":
            return Font.Medium;
        case "title":
        case "heading":
            return Font.DemiBold;
        default:
            return Font.Normal;
        }
    }
    font.letterSpacing: variant === "label" ? 1.4 : 0
    font.capitalization: variant === "label" ? Font.AllUppercase : Font.MixedCase

    Behavior on color {
        ColorAnimation {
            duration: Theme.motion.fast
        }
    }
}
