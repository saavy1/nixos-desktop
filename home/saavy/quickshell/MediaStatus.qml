import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Scope {
    id: root

    readonly property var players: Mpris.players.values || []
    property string selectedPlayerId: ""
    readonly property var activePlayer: chooseActivePlayer()
    readonly property bool hasPlayers: activePlayer !== null
    readonly property bool playing: activePlayer !== null && activePlayer.isPlaying
    readonly property string title: activePlayer ? activePlayer.trackTitle || "" : ""
    readonly property string artist: activePlayer ? activePlayer.trackArtist || "" : ""
    readonly property string album: activePlayer ? activePlayer.trackAlbum || "" : ""
    readonly property string albumArt: activePlayer ? activePlayer.trackArtUrl || "" : ""
    readonly property string playerName: activePlayer ? displayName(activePlayer) : ""
    readonly property real position: activePlayer && activePlayer.positionSupported
        ? safeNumber(activePlayer.position)
        : 0
    readonly property real length: activePlayer && activePlayer.lengthSupported
        ? safeNumber(activePlayer.length)
        : 0
    readonly property bool canPlay: activePlayer !== null && activePlayer.canPlay
    readonly property bool canPause: activePlayer !== null && activePlayer.canPause
    readonly property bool canTogglePlaying: activePlayer !== null && activePlayer.canTogglePlaying
    readonly property bool canGoNext: activePlayer !== null && activePlayer.canGoNext
    readonly property bool canGoPrevious: activePlayer !== null && activePlayer.canGoPrevious
    readonly property bool canSeek: activePlayer !== null
        && activePlayer.canSeek
        && activePlayer.positionSupported
        && activePlayer.lengthSupported
        && length > 0

    function safeNumber(value): real {
        const number = Number(value)
        return isFinite(number) && number >= 0 ? number : 0
    }

    function playerId(player): string {
        return player ? player.dbusName || "" : ""
    }

    function displayName(player): string {
        if (!player)
            return ""

        if (player.identity)
            return player.identity
        if (player.desktopEntry)
            return player.desktopEntry

        const id = playerId(player)
        const prefix = "org.mpris.MediaPlayer2."
        return id.indexOf(prefix) === 0 ? id.slice(prefix.length) : id
    }

    function chooseActivePlayer() {
        const availablePlayers = players
        if (availablePlayers.length === 0)
            return null

        if (selectedPlayerId.length > 0) {
            for (const player of availablePlayers) {
                if (player && playerId(player) === selectedPlayerId)
                    return player
            }
        }

        for (const player of availablePlayers) {
            if (player && player.isPlaying)
                return player
        }

        for (const player of availablePlayers) {
            if (player && player.playbackState === MprisPlaybackState.Paused)
                return player
        }

        for (const player of availablePlayers) {
            if (player)
                return player
        }

        return null
    }

    function selectPlayer(player): void {
        if (!player)
            return

        const id = playerId(player)
        if (id.length > 0)
            selectedPlayerId = id
    }

    function selectPlayerById(id: string): void {
        if (!id)
            return

        for (const player of players) {
            if (player && playerId(player) === id) {
                selectedPlayerId = id
                return
            }
        }
    }

    function useAutomaticSelection(): void {
        selectedPlayerId = ""
    }

    function play(): void {
        const player = activePlayer
        if (player && player.canPlay)
            player.play()
    }

    function pause(): void {
        const player = activePlayer
        if (player && player.canPause)
            player.pause()
    }

    function togglePlaying(): void {
        const player = activePlayer
        if (!player)
            return

        if (player.canTogglePlaying) {
            player.togglePlaying()
        } else if (player.isPlaying && player.canPause) {
            player.pause()
        } else if (!player.isPlaying && player.canPlay) {
            player.play()
        }
    }

    function playPause(): void {
        togglePlaying()
    }

    function next(): void {
        const player = activePlayer
        if (player && player.canGoNext)
            player.next()
    }

    function previous(): void {
        const player = activePlayer
        if (player && player.canGoPrevious)
            player.previous()
    }

    function seekTo(seconds: real): void {
        const player = activePlayer
        if (!player || !canSeek)
            return

        player.position = Math.max(0, Math.min(length, seconds))
    }

    function seekBy(seconds: real): void {
        const player = activePlayer
        if (player && player.canSeek && isFinite(seconds))
            player.seek(seconds)
    }
}
