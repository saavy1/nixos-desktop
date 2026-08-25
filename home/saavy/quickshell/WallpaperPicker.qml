import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: picker

    property string currentSource: Theme.wallpaperSource.toString()
    readonly property var sources: Theme.wallpaperSources

    visible: PopupController.isOpen("wallpaper")
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: visible
    screen: PopupController.focusedScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "solitude-wallpaper-picker"

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

    function open(): void {
        syncSelection()
        thumbnailGrid.currentIndex = Math.max(0, sourceIndex(currentSource))
        PopupController.open("wallpaper")
        Qt.callLater(() => keyboardScope.forceActiveFocus())
    }

    function close(): void {
        PopupController.close("wallpaper")
    }

    function toggle(): void {
        if (visible)
            close()
        else
            open()
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            picker.toggle()
        }

        function close(): void {
            picker.close()
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

    MouseArea {
        anchors.fill: parent
        onClicked: picker.close()
    }

    Item {
        id: keyboardScope

        anchors.fill: parent
        focus: picker.visible
        Keys.onEscapePressed: picker.close()
        Keys.onPressed: event => {
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

        PanelCard {
            id: card

            anchors.centerIn: parent
            width: Math.min(1080, picker.width - 80)
            height: Math.min(760, picker.height - 120)

            MouseArea {
                anchors.fill: parent
            }

            Text {
                id: title

                anchors {
                    top: parent.top
                    left: parent.left
                    topMargin: 24
                    leftMargin: 28
                }
                text: "Wallpaper"
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
            }

            Text {
                anchors {
                    baseline: title.baseline
                    left: title.right
                    leftMargin: 14
                }
                text: `${picker.sources.length} choices`
                color: Theme.foregroundSoft
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
            }

            Rectangle {
                anchors {
                    right: parent.right
                    verticalCenter: title.verticalCenter
                    rightMargin: 28
                }
                width: closeLabel.implicitWidth + 24
                height: 34
                radius: Theme.radiusSmall
                color: closeMouse.containsMouse ? Theme.selection : Theme.backgroundDark
                border.color: Theme.border
                border.width: Theme.borderWidth

                Text {
                    id: closeLabel

                    anchors.centerIn: parent
                    text: "Close"
                    color: Theme.foregroundSoft
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                }

                MouseArea {
                    id: closeMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.close()
                }
            }

            GridView {
                id: thumbnailGrid

                anchors {
                    top: title.bottom
                    bottom: footer.top
                    left: parent.left
                    right: parent.right
                    topMargin: 28
                    bottomMargin: 20
                    leftMargin: 24
                    rightMargin: 24
                }
                readonly property int columns: Math.max(1, Math.floor(width / 292))
                cellWidth: width / columns
                cellHeight: 220
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: picker.sources

                delegate: Rectangle {
                    id: thumbnail

                    required property var modelData
                    required property int index
                    readonly property string sourceUrl: picker.sourceString(modelData)
                    readonly property bool selected: sourceUrl === picker.currentSource

                    width: GridView.view.cellWidth - Theme.shellGap
                    height: GridView.view.cellHeight - Theme.shellGap
                    radius: Theme.radiusMedium
                    color: mouse.containsMouse ? Theme.selection : Theme.backgroundDark
                    border.color: selected ? Theme.accent : Theme.backgroundDarker
                    border.width: selected ? Math.max(2, Theme.borderWidth) : Theme.borderWidth

                    Rectangle {
                        id: preview

                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 8
                        }
                        height: parent.height - nameLabel.height - 30
                        radius: Theme.radiusSmall
                        color: Theme.backgroundDarker
                        clip: true

                        Image {
                            id: image

                            anchors.fill: parent
                            source: thumbnail.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: image.status === Image.Error
                            text: "Preview unavailable"
                            color: Theme.foregroundSoft
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontCaption
                        }

                        Rectangle {
                            anchors {
                                top: parent.top
                                right: parent.right
                                margins: 10
                            }
                            visible: thumbnail.selected
                            width: 58
                            height: 26
                            radius: Theme.radiusSmall
                            color: Theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: "Active"
                                color: Theme.backgroundDarker
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Text {
                        id: nameLabel

                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: 12
                            rightMargin: 12
                            bottomMargin: 10
                        }
                        text: picker.displayName(thumbnail.modelData)
                        color: thumbnail.selected ? Theme.foreground : Theme.foregroundSoft
                        elide: Text.ElideRight
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontBody
                        font.weight: thumbnail.selected ? Font.DemiBold : Font.Normal
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

                highlight: Rectangle {
                    radius: Theme.radiusMedium
                    color: "transparent"
                    border.color: Theme.foregroundSoft
                    border.width: Theme.borderWidth
                }
                highlightMoveDuration: 120
            }

            Text {
                id: footer

                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 18
                }
                text: "Select a preview to apply it on every display"
                color: Theme.foregroundSoft
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
            }
        }
    }

    Component.onCompleted: syncSelection()
}
