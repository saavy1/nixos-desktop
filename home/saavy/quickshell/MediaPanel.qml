import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: mediaPanel

    required property var status
    readonly property bool hasPlayers: status !== null && status !== undefined && status.hasPlayers
    readonly property var activePlayer: hasPlayers ? status.activePlayer : null
    readonly property bool canSeek: activePlayer !== null && status.canSeek
    readonly property real duration: activePlayer !== null ? status.length : 0
    readonly property real currentPosition: activePlayer !== null ? status.position : 0

    visible: PopupController.isOpen("media")
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
    WlrLayershell.namespace: "solitude-media"

    function formatTime(seconds: real): string {
        const safeSeconds = isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0
        const minutes = Math.floor(safeSeconds / 60)
        const remainder = safeSeconds % 60
        return `${minutes}:${remainder < 10 ? "0" : ""}${remainder}`
    }

    function open(): void {
        if (!hasPlayers) {
            close()
            return
        }

        PopupController.open("media")
        Qt.callLater(() => keyScope.forceActiveFocus())
    }

    function close(): void {
        PopupController.close("media")
    }

    function toggle(): void {
        if (visible)
            close()
        else
            open()
    }

    onVisibleChanged: {
        if (!visible)
            return

        if (!hasPlayers)
            close()
        else
            Qt.callLater(() => keyScope.forceActiveFocus())
    }

    Connections {
        target: mediaPanel.status

        function onHasPlayersChanged(): void {
            if (!mediaPanel.hasPlayers && mediaPanel.visible)
                mediaPanel.close()
        }
    }

    IpcHandler {
        target: "media"

        function toggle(): void {
            mediaPanel.toggle()
        }

        function playPause(): void {
            if (mediaPanel.status)
                mediaPanel.status.playPause()
        }

        function next(): void {
            if (mediaPanel.status)
                mediaPanel.status.next()
        }

        function previous(): void {
            if (mediaPanel.status)
                mediaPanel.status.previous()
        }

        function close(): void {
            mediaPanel.close()
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: mediaPanel.visible
            && mediaPanel.activePlayer !== null
            && mediaPanel.status.playing
            && mediaPanel.activePlayer.positionSupported
        onTriggered: {
            const player = mediaPanel.activePlayer
            if (player)
                player.positionChanged()
        }
    }

    component ControlButton: Rectangle {
        id: control

        required property string label
        property bool controlEnabled: true
        property bool prominent: false
        signal invoked

        width: prominent ? 104 : 82
        height: 42
        radius: Theme.radiusMedium
        opacity: controlEnabled ? 1 : 0.4
        color: prominent
            ? controlHover.containsMouse ? Theme.foreground : Theme.accent
            : controlHover.containsMouse ? Theme.selection : Theme.backgroundDark
        border.color: prominent ? Theme.accent : Theme.backgroundDarker
        border.width: Theme.borderWidth

        Text {
            anchors.centerIn: parent
            text: control.label
            color: control.prominent ? Theme.background : Theme.foregroundSoft
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontCaption
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: controlHover

            anchors.fill: parent
            enabled: control.controlEnabled
            hoverEnabled: true
            cursorShape: control.controlEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: control.invoked()
        }
    }

    component PlayerRow: Rectangle {
        id: playerRow

        required property var player
        readonly property bool selected: mediaPanel.activePlayer !== null && player === mediaPanel.activePlayer
        readonly property bool playerPlaying: player !== null && player !== undefined && player.isPlaying

        width: parent ? parent.width : 0
        height: 48
        radius: Theme.radiusSmall
        color: selected ? Theme.selection : playerHover.containsMouse ? Theme.backgroundDark : "transparent"
        border.color: selected ? Theme.accent : Theme.backgroundDarker
        border.width: Theme.borderWidth

        Rectangle {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 12
            }
            width: 9
            height: 9
            radius: 5
            color: playerRow.playerPlaying ? Theme.success : playerRow.selected ? Theme.accent : Theme.muted
        }

        Column {
            anchors {
                left: parent.left
                right: playerState.left
                verticalCenter: parent.verticalCenter
                leftMargin: 32
                rightMargin: 10
            }
            spacing: 1

            Text {
                width: parent.width
                text: mediaPanel.status.displayName(playerRow.player) || "Unknown player"
                color: playerRow.selected ? Theme.foreground : Theme.foregroundSoft
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontBody
                font.weight: playerRow.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: playerRow.player && playerRow.player.trackTitle
                    ? playerRow.player.trackTitle
                    : playerRow.playerPlaying ? "Playing" : "No track metadata"
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
                elide: Text.ElideRight
            }
        }

        Text {
            id: playerState

            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 12
            }
            text: playerRow.playerPlaying ? "PLAYING" : playerRow.selected ? "ACTIVE" : "SELECT"
            color: playerRow.playerPlaying || playerRow.selected ? Theme.accent : Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontCaption
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: playerHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaPanel.status.selectPlayer(playerRow.player)
        }
    }

    Item {
        id: keyScope

        anchors.fill: parent
        focus: mediaPanel.visible
        Keys.onEscapePressed: mediaPanel.close()

        MouseArea {
            anchors.fill: parent
            onClicked: mediaPanel.close()
        }

        PanelCard {
            id: card

            anchors {
                top: parent.top
                right: parent.right
                topMargin: Theme.outerMargin + Theme.barHeight + Theme.shellGap
                rightMargin: Theme.outerMargin
            }
            width: Math.max(340, Math.min(520, mediaPanel.width - 48))
            height: Math.min(720, Math.max(440, mediaPanel.height - 64))

            MouseArea {
                anchors.fill: parent
            }

            Text {
                anchors {
                    left: parent.left
                    top: parent.top
                    leftMargin: 22
                    topMargin: 18
                }
                text: "Media"
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
            }

            Text {
                anchors {
                    right: parent.right
                    top: parent.top
                    rightMargin: 22
                    topMargin: 23
                }
                text: mediaPanel.activePlayer ? mediaPanel.status.playerName.toUpperCase() : "NO PLAYER"
                color: mediaPanel.activePlayer ? Theme.accent : Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontCaption
                font.weight: Font.DemiBold
                elide: Text.ElideLeft
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: 62
                }
                height: 1
                color: Theme.backgroundDarker
            }

            Flickable {
                id: contentView

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: footerDivider.top
                    leftMargin: 20
                    rightMargin: 20
                    topMargin: 76
                    bottomMargin: 12
                }
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: contentColumn

                    width: contentView.width
                    spacing: 14

                    Row {
                        width: parent.width
                        spacing: 18

                        Rectangle {
                            width: Math.min(168, Math.max(112, contentColumn.width * 0.36))
                            height: width
                            radius: Theme.radiusMedium
                            color: Theme.backgroundDark
                            border.color: Theme.backgroundDarker
                            border.width: Theme.borderWidth
                            clip: true

                            Image {
                                id: artwork

                                anchors.fill: parent
                                source: mediaPanel.activePlayer ? mediaPanel.status.albumArt : ""
                                sourceSize: Qt.size(360, 360)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: artwork.status !== Image.Ready
                                color: Theme.backgroundDark

                                Text {
                                    anchors.centerIn: parent
                                    text: "MEDIA"
                                    color: Theme.muted
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontCaption
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Column {
                            width: parent.width - parent.spacing - parent.children[0].width
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7

                            Text {
                                width: parent.width
                                text: mediaPanel.activePlayer
                                    ? mediaPanel.status.title || "Unknown title"
                                    : "Nothing playing"
                                color: Theme.foreground
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontTitle
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: mediaPanel.activePlayer
                                    ? mediaPanel.status.artist || "Unknown artist"
                                    : ""
                                color: Theme.foregroundSoft
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontBody
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: mediaPanel.activePlayer ? mediaPanel.status.album : ""
                                visible: text.length > 0
                                color: Theme.muted
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                width: stateText.implicitWidth + 16
                                height: 24
                                radius: Theme.radiusSmall
                                color: Theme.selection

                                Text {
                                    id: stateText

                                    anchors.centerIn: parent
                                    text: mediaPanel.status && mediaPanel.status.playing ? "PLAYING" : "PAUSED"
                                    color: mediaPanel.status && mediaPanel.status.playing ? Theme.success : Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontCaption
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 7

                        Item {
                            id: progressSlider

                            width: parent.width
                            height: 24
                            opacity: mediaPanel.canSeek ? 1 : 0.55
                            property bool dragging: false
                            property real dragRatio: 0
                            readonly property real positionRatio: dragging
                                ? dragRatio
                                : mediaPanel.duration > 0
                                    ? Math.max(0, Math.min(1, mediaPanel.currentPosition / mediaPanel.duration))
                                    : 0

                            function updateDrag(position: real): void {
                                dragRatio = width > 0 ? Math.max(0, Math.min(1, position / width)) : 0
                            }

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                height: 6
                                radius: 3
                                color: Theme.backgroundDarker

                                Rectangle {
                                    width: parent.width * progressSlider.positionRatio
                                    height: parent.height
                                    radius: parent.radius
                                    color: Theme.accent
                                }
                            }

                            Rectangle {
                                x: Math.max(0, Math.min(parent.width - width, parent.width * progressSlider.positionRatio - width / 2))
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                radius: 8
                                color: mediaPanel.canSeek ? Theme.foreground : Theme.muted
                                border.color: Theme.backgroundDarker
                                border.width: Theme.borderWidth
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: mediaPanel.canSeek
                                cursorShape: mediaPanel.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onPressed: mouse => {
                                    progressSlider.dragging = true
                                    progressSlider.updateDrag(mouse.x)
                                }
                                onPositionChanged: mouse => {
                                    if (pressed)
                                        progressSlider.updateDrag(mouse.x)
                                }
                                onReleased: mouse => {
                                    progressSlider.updateDrag(mouse.x)
                                    mediaPanel.status.seekTo(progressSlider.dragRatio * mediaPanel.duration)
                                    progressSlider.dragging = false
                                }
                                onCanceled: progressSlider.dragging = false
                            }
                        }

                        Row {
                            width: parent.width

                            Text {
                                text: mediaPanel.formatTime(mediaPanel.currentPosition)
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontCaption
                            }

                            Item {
                                width: parent.width - parent.children[0].width - parent.children[2].width
                                height: 1
                            }

                            Text {
                                text: mediaPanel.duration > 0 ? mediaPanel.formatTime(mediaPanel.duration) : "--:--"
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontCaption
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        ControlButton {
                            label: "PREVIOUS"
                            controlEnabled: mediaPanel.activePlayer !== null && mediaPanel.status.canGoPrevious
                            onInvoked: mediaPanel.status.previous()
                        }

                        ControlButton {
                            label: mediaPanel.status && mediaPanel.status.playing ? "PAUSE" : "PLAY"
                            prominent: true
                            controlEnabled: mediaPanel.activePlayer !== null
                                && (mediaPanel.status.canTogglePlaying
                                    || mediaPanel.status.playing && mediaPanel.status.canPause
                                    || !mediaPanel.status.playing && mediaPanel.status.canPlay)
                            onInvoked: mediaPanel.status.togglePlaying()
                        }

                        ControlButton {
                            label: "NEXT"
                            controlEnabled: mediaPanel.activePlayer !== null && mediaPanel.status.canGoNext
                            onInvoked: mediaPanel.status.next()
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.backgroundDarker
                    }

                    Text {
                        text: "PLAYERS"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    Column {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: mediaPanel.hasPlayers ? mediaPanel.status.players : []

                            delegate: PlayerRow {
                                required property var modelData

                                player: modelData
                            }
                        }

                        Rectangle {
                            id: automaticRow

                            visible: mediaPanel.status && mediaPanel.status.selectedPlayerId.length > 0
                            width: parent.width
                            height: visible ? 40 : 0
                            radius: Theme.radiusSmall
                            color: automaticHover.containsMouse ? Theme.backgroundDark : "transparent"
                            border.color: Theme.backgroundDarker
                            border.width: Theme.borderWidth

                            Text {
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 12
                                }
                                text: "Follow whichever player is playing"
                                color: Theme.foregroundSoft
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                            }

                            Text {
                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    rightMargin: 12
                                }
                                text: "AUTO"
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: automaticHover

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mediaPanel.status.useAutomaticSelection()
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: footerDivider

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: 42
                }
                height: 1
                color: Theme.backgroundDarker
            }

            Text {
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    leftMargin: 22
                    bottomMargin: 13
                }
                text: mediaPanel.hasPlayers
                    ? `${mediaPanel.status.players.length} ${mediaPanel.status.players.length === 1 ? "player" : "players"}`
                    : "No media players"
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
            }

            Text {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: 22
                    bottomMargin: 13
                }
                text: "esc or click outside to close"
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
            }
        }
    }
}
