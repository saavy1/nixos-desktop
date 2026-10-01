import Quickshell
import Quickshell.Io
import QtQuick
import qs.ui

PopupPanel {
    id: root

    required property var status
    readonly property bool hasPlayers: status !== null && status !== undefined && status.hasPlayers
    readonly property var activePlayer: hasPlayers ? status.activePlayer : null
    readonly property bool canSeek: activePlayer !== null && status.canSeek
    readonly property real duration: activePlayer !== null ? status.length : 0
    readonly property real currentPosition: activePlayer !== null ? status.position : 0
    readonly property bool playing: status !== null && status !== undefined && status.playing
    readonly property int playerCount: hasPlayers ? status.players.length : 0

    name: "media"
    title: "Now playing"
    subtitle: activePlayer ? `${status.playerName.toLowerCase()} · mpris` : "no player"
    cardWidth: 460
    ipcEnabled: false

    function formatTime(seconds: real): string {
        const safeSeconds = isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0
        const minutes = Math.floor(safeSeconds / 60)
        const remainder = safeSeconds % 60
        return `${minutes}:${remainder < 10 ? "0" : ""}${remainder}`
    }

    // The panel only opens while there is a player to control.
    function openIfPlayers(): void {
        if (!hasPlayers) {
            close()
            return
        }

        open()
    }

    onOpening: {
        if (!hasPlayers)
            Qt.callLater(() => root.close())
    }

    Connections {
        target: root.status

        function onHasPlayersChanged(): void {
            if (!root.hasPlayers && root.shown)
                root.close()
        }
    }

    IpcHandler {
        target: "media"

        function open(): void {
            root.openIfPlayers()
        }

        function toggle(): void {
            if (root.shown)
                root.close()
            else
                root.openIfPlayers()
        }

        function playPause(): void {
            if (root.status)
                root.status.playPause()
        }

        function next(): void {
            if (root.status)
                root.status.next()
        }

        function previous(): void {
            if (root.status)
                root.status.previous()
        }

        function close(): void {
            root.close()
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.shown
            && root.activePlayer !== null
            && root.status.playing
            && root.activePlayer.positionSupported
        onTriggered: {
            const player = root.activePlayer
            if (player)
                player.positionChanged()
        }
    }

    headerTrailing: [
        Chip {
            visible: root.activePlayer !== null
            interactive: false
            text: root.playing ? "Playing" : "Paused"
            icon: root.playing ? "audio-lines" : "pause"
            tone: root.playing ? "success" : "neutral"
        }
    ]

    Row {
        width: parent.width
        spacing: Theme.space.lg

        RoundedImage {
            id: artwork

            width: 116
            height: 116
            source: root.activePlayer ? root.status.albumArt : ""
            sourceSize: Qt.size(360, 360)
            placeholderIcon: "music"
            bordered: true
        }

        Column {
            width: parent.width - parent.spacing - artwork.width
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.xs

            Label {
                width: parent.width
                text: root.activePlayer ? root.status.title || "Unknown title" : "Nothing playing"
                variant: "heading"
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }

            Label {
                width: parent.width
                visible: text.length > 0
                text: root.activePlayer ? root.status.artist || "Unknown artist" : ""
                tone: "soft"
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            Label {
                width: parent.width
                visible: text.length > 0
                text: root.activePlayer ? root.status.album : ""
                variant: "small"
                tone: "faint"
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.space.xs

        Item {
            id: progress

            property real dragRatio: 0
            readonly property real positionRatio: root.duration > 0
                ? Math.max(0, Math.min(1, root.currentPosition / root.duration))
                : 0

            width: parent.width
            height: 20

            // Seeks on release, like the old panel; the wheel seeks immediately.
            Slider {
                id: seekSlider

                anchors.fill: parent
                visible: root.canSeek
                value: dragging ? progress.dragRatio : progress.positionRatio
                onMoved: value => {
                    progress.dragRatio = value
                    if (!dragging)
                        root.status.seekTo(value * root.duration)
                }
                onDraggingChanged: {
                    if (!dragging && root.canSeek)
                        root.status.seekTo(progress.dragRatio * root.duration)
                }
            }

            Meter {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                visible: !root.canSeek
                value: progress.positionRatio
                fillColor: Theme.accent
            }
        }

        Item {
            width: parent.width
            height: elapsed.implicitHeight

            Label {
                id: elapsed

                anchors.left: parent.left
                text: root.formatTime(seekSlider.dragging ? progress.dragRatio * root.duration : root.currentPosition)
                variant: "numeric"
                font.pixelSize: Theme.fontSize.caption
                font.weight: Font.Normal
                tone: "faint"
            }

            Label {
                anchors.right: parent.right
                text: root.duration > 0 ? root.formatTime(root.duration) : "--:--"
                variant: "numeric"
                font.pixelSize: Theme.fontSize.caption
                font.weight: Font.Normal
                tone: "faint"
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.space.md

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 44
            implicitHeight: 40
            iconSize: 18
            icon: "skip-back"
            enabled: root.activePlayer !== null && root.status.canGoPrevious
            onClicked: root.status.previous()
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 56
            implicitHeight: 44
            iconSize: 20
            active: true
            icon: root.playing ? "pause" : "play"
            enabled: root.activePlayer !== null
                && (root.status.canTogglePlaying
                    || root.status.playing && root.status.canPause
                    || !root.status.playing && root.status.canPlay)
            onClicked: root.status.togglePlaying()
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 44
            implicitHeight: 40
            iconSize: 18
            icon: "skip-forward"
            enabled: root.activePlayer !== null && root.status.canGoNext
            onClicked: root.status.next()
        }
    }

    SectionHeader {
        width: parent.width
        text: "Players"
        trailing: root.hasPlayers
            ? `${root.playerCount} ${root.playerCount === 1 ? "player" : "players"}`
            : "No media players"
    }

    Column {
        width: parent.width
        spacing: 2

        Repeater {
            model: root.hasPlayers ? root.status.players : []

            delegate: ListItem {
                id: playerItem

                required property var modelData
                readonly property bool playerPlaying: modelData !== null && modelData !== undefined && modelData.isPlaying

                width: parent.width
                icon: playerPlaying ? "audio-lines" : "music"
                title: root.status.displayName(modelData) || "Unknown player"
                subtitle: modelData && modelData.trackTitle
                    ? modelData.trackTitle
                    : playerPlaying ? "Playing" : "No track metadata"
                trailing: playerPlaying ? "playing" : ""
                trailingTone: "success"
                indicator: true
                selected: root.activePlayer !== null && modelData === root.activePlayer
                onClicked: root.status.selectPlayer(modelData)
            }
        }

        ListItem {
            visible: root.status && root.status.selectedPlayerId.length > 0
            width: parent.width
            icon: "refresh-cw"
            title: "Follow whichever player is playing"
            trailing: "auto"
            trailingTone: "accent"
            onClicked: root.status.useAutomaticSelection()
        }
    }

}
