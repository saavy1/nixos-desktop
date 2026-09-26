import Quickshell
import Quickshell.Io
import QtQuick
import qs.ui

PopupPanel {
    id: picker

    property string currentSource: Theme.wallpaperSource.toString()
    readonly property var sources: Theme.wallpaperSources

    name: "wallpaper"
    title: "Wallpaper"
    subtitle: `${sources.length} choices · every display`
    placement: "center"
    cardWidth: 1080
    maxCardHeight: Math.min(760, (screen ? screen.height : 900) - topOffset - Theme.outerMargin)
    scrollable: false

    function sourceString(source): string {
        return source ? source.toString() : ""
    }

    function sourceIndex(source): int {
        const value = sourceString(source)

        for (let index = 0; index < sources.length; ++index) {
            if (sourceString(sources[index]) === value)
                return index
        }

        return -1
    }

    function displayName(source): string {
        const value = sourceString(source)
        const encodedName = value.slice(value.lastIndexOf("/") + 1)
        let name = decodeURIComponent(encodedName).replace(/\.[^.]+$/, "")
        name = name.replace(/^[a-z0-9]{32}-/, "")
        name = name.replace(/[-_]+/g, " ")
        return name.replace(/\b\w/g, letter => letter.toUpperCase())
    }

    function syncSelection(): void {
        const saved = selectionFile.text().trim()
        currentSource = sourceIndex(saved) === -1 ? sourceString(Theme.wallpaperSource) : saved
    }

    function select(source): void {
        const value = sourceString(source)

        if (sourceIndex(value) === -1)
            return

        currentSource = value
        selectionFile.setText(value)
    }

    onOpening: {
        syncSelection()
        thumbnailGrid.currentIndex = Math.max(0, sourceIndex(currentSource))
    }

    onKeyPressed: event => {
        if (event.key === Qt.Key_Left) {
            thumbnailGrid.moveCurrentIndexLeft()
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            thumbnailGrid.moveCurrentIndexRight()
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            thumbnailGrid.moveCurrentIndexUp()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            thumbnailGrid.moveCurrentIndexDown()
            event.accepted = true
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && thumbnailGrid.currentIndex >= 0) {
            picker.select(picker.sources[thumbnailGrid.currentIndex])
            event.accepted = true
        }
    }

    FileView {
        id: selectionFile

        path: Quickshell.statePath("wallpaper")
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: picker.syncSelection()
    }

    Component.onCompleted: syncSelection()

    headerTrailing: [
        Button {
            compact: true
            icon: "x"
            text: "Close"
            onClicked: picker.close()
        }
    ]

    GridView {
        id: thumbnailGrid

        readonly property int columns: Math.max(1, Math.floor(width / 292))
        readonly property int rows: Math.ceil(count / columns)

        width: parent.width
        height: Math.max(cellHeight, Math.min(rows * cellHeight,
            picker.maxCardHeight - picker.padding * 2 - picker.card.headerHeight - picker.card.footerHeight - picker.spacing))
        cellWidth: width / columns
        cellHeight: 220
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: picker.sources
        highlightMoveDuration: Theme.motion.fast

        // Keyboard cursor.
        highlight: Rectangle {
            radius: Theme.radius.medium + 4
            color: Theme.hover
            border.color: Theme.lineStrong
            border.width: Theme.borderWidth
        }

        delegate: Item {
            id: thumbnail

            required property var modelData
            required property int index
            readonly property string sourceUrl: picker.sourceString(modelData)
            readonly property bool selected: sourceUrl === picker.currentSource

            width: GridView.view.cellWidth
            height: GridView.view.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: Theme.space.xs
                radius: Theme.radius.medium + 4
                color: mouse.containsMouse ? Theme.hover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.motion.fast
                    }
                }
            }

            RoundedImage {
                id: preview

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: Theme.space.md
                }
                height: parent.height - nameLabel.height - Theme.space.md * 2 - Theme.space.sm
                source: thumbnail.modelData

                Label {
                    anchors.centerIn: parent
                    visible: preview.status === Image.Error
                    text: "Preview unavailable"
                    variant: "small"
                    tone: "faint"
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: preview.radius + 3
                    color: "transparent"
                    border.width: thumbnail.selected ? 2 : Theme.borderWidth
                    border.color: thumbnail.selected ? Theme.accent : Theme.line
                }

                Rectangle {
                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: Theme.space.sm
                    }
                    visible: thumbnail.selected
                    width: 24
                    height: 24
                    radius: Theme.radius.large
                    color: Theme.accent

                    Icon {
                        anchors.centerIn: parent
                        name: "check"
                        size: 14
                        color: Theme.accentText
                    }
                }
            }

            Label {
                id: nameLabel

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: Theme.space.md
                    rightMargin: Theme.space.md
                    bottomMargin: Theme.space.md
                }
                text: picker.displayName(thumbnail.modelData)
                tone: thumbnail.selected ? "base" : "soft"
                font.weight: thumbnail.selected ? Font.Medium : Font.Normal
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    thumbnailGrid.currentIndex = thumbnail.index
                    picker.select(thumbnail.modelData)
                }
            }
        }
    }

    footer: [
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Select a preview to apply it on every display"
            variant: "small"
            tone: "faint"
        }
    ]
}
