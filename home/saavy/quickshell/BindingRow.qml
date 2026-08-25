import QtQuick

Item {
    id: row

    required property string category
    required property string shortcut
    required property string action

    height: 34

    Text {
        id: categoryText

        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        width: 96
        text: row.category.toUpperCase()
        color: Theme.accent
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontCaption
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Rectangle {
        id: keyPill

        anchors {
            left: categoryText.right
            verticalCenter: parent.verticalCenter
        }
        width: 178
        height: 26
        radius: 6
        color: Theme.backgroundDark
        border.color: Theme.backgroundDarker
        border.width: Theme.borderWidth

        Text {
            anchors.centerIn: parent
            text: row.shortcut
            color: Theme.foreground
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontCaption
            font.weight: Font.DemiBold
        }
    }

    Text {
        anchors {
            left: keyPill.right
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 12
        }
        text: row.action
        color: Theme.foregroundSoft
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontBody - 1
        elide: Text.ElideRight
    }
}
