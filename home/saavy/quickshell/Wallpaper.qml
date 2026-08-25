import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: wallpaper

    function sourceString(source): string {
        return source ? source.toString() : ""
    }

    readonly property string storedSource: selectionFile.text().trim()
    readonly property url selectedSource: {
        for (let index = 0; index < Theme.wallpaperSources.length; ++index) {
            const candidate = Theme.wallpaperSources[index]

            if (sourceString(candidate) === storedSource)
                return candidate
        }

        return Theme.wallpaperSource
    }

    FileView {
        id: selectionFile

        path: Quickshell.statePath("wallpaper")
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: window

                required property var modelData
                property int activeLayer: 0
                property int pendingLayer: -1
                property url shownSource: Theme.wallpaperSource
                property url pendingSource: ""
                readonly property url requestedSource: wallpaper.selectedSource

                screen: modelData
                color: Theme.background
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: -1

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                WlrLayershell.namespace: "solitude-wallpaper"

                function requestSource(source): void {
                    const nextSource = wallpaper.sourceString(source)

                    if (nextSource.length === 0)
                        return

                    if (nextSource === wallpaper.sourceString(shownSource)) {
                        if (pendingLayer !== -1) {
                            const pending = pendingLayer === 0 ? layerA : layerB
                            pendingLayer = -1
                            pendingSource = ""
                            pending.opacity = 0
                            pending.source = ""
                        }

                        return
                    }

                    pendingSource = source
                    pendingLayer = activeLayer === 0 ? 1 : 0

                    const target = pendingLayer === 0 ? layerA : layerB
                    target.opacity = 0
                    target.source = source

                    if (target.status === Image.Ready)
                        completeLoad(pendingLayer)
                }

                function completeLoad(layerIndex): void {
                    if (pendingLayer !== layerIndex)
                        return

                    const target = layerIndex === 0 ? layerA : layerB

                    if (target.status !== Image.Ready
                            || wallpaper.sourceString(target.source) !== wallpaper.sourceString(pendingSource))
                        return

                    const previous = activeLayer === 0 ? layerA : layerB
                    target.opacity = 1
                    previous.opacity = 0
                    activeLayer = layerIndex
                    shownSource = pendingSource
                    pendingLayer = -1
                }

                function rejectLoad(layerIndex): void {
                    if (pendingLayer !== layerIndex)
                        return

                    const target = layerIndex === 0 ? layerA : layerB
                    pendingLayer = -1
                    pendingSource = ""
                    target.opacity = 0
                    target.source = ""
                }

                onRequestedSourceChanged: requestSource(requestedSource)
                Component.onCompleted: Qt.callLater(() => requestSource(requestedSource))

                Image {
                    id: layerA

                    anchors.fill: parent
                    source: Theme.wallpaperSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    opacity: 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 600
                            easing.type: Easing.InOutCubic
                        }
                    }

                    onStatusChanged: {
                        if (status === Image.Ready)
                            window.completeLoad(0)
                        else if (status === Image.Error)
                            window.rejectLoad(0)
                    }
                }

                Image {
                    id: layerB

                    anchors.fill: parent
                    source: ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    opacity: 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 600
                            easing.type: Easing.InOutCubic
                        }
                    }

                    onStatusChanged: {
                        if (status === Image.Ready)
                            window.completeLoad(1)
                        else if (status === Image.Error)
                            window.rejectLoad(1)
                    }
                }
            }
        }
    }
}
