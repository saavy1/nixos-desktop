import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: overlay

    property var entries: []
    property string loadError: ""
    readonly property int midpoint: Math.ceil(entries.length / 2)
    readonly property var leftEntries: entries.slice(0, midpoint)
    readonly property var rightEntries: entries.slice(midpoint)

    visible: PopupController.isOpen("keybinds")
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
    WlrLayershell.namespace: "solitude-keybinds"

    function formatKey(bind) {
        const modifiers = []
        const mask = bind.modmask || 0

        if (mask & 64)
            modifiers.push("Super")
        if (mask & 4)
            modifiers.push("Ctrl")
        if (mask & 8)
            modifiers.push("Alt")
        if (mask & 1)
            modifiers.push("Shift")

        const names = {
            "SPACE": "Space",
            "PRINT": "Print",
            "LEFT": "←",
            "RIGHT": "→",
            "UP": "↑",
            "DOWN": "↓",
            "mouse:272": "Mouse 1",
            "mouse:273": "Mouse 2"
        }
        const key = names[bind.key] || bind.key
        modifiers.push(key)
        return modifiers.join(" + ")
    }

    function open() {
        PopupController.open("keybinds")
        loadError = ""
        bindsProc.running = false
        bindsProc.running = true
        Qt.callLater(() => keyboardScope.forceActiveFocus())
    }

    function close() {
        PopupController.close("keybinds")
    }

    function toggle() {
        if (visible)
            close()
        else
            open()
    }

    IpcHandler {
        target: "keybinds"

        function toggle(): void {
            overlay.toggle()
        }

        function close(): void {
            overlay.close()
        }
    }

    Process {
        id: bindsProc

        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    overlay.entries = parsed
                        .filter(bind => bind.has_description && bind.description.length > 0)
                        .map(bind => {
                            const separator = bind.description.indexOf(" · ")
                            return {
                                category: separator === -1 ? "Other" : bind.description.slice(0, separator),
                                action: separator === -1 ? bind.description : bind.description.slice(separator + 3),
                                key: overlay.formatKey(bind)
                            }
                        })
                        .sort((left, right) => {
                            const categoryOrder = left.category.localeCompare(right.category)
                            return categoryOrder === 0 ? left.action.localeCompare(right.action) : categoryOrder
                        })
                } catch (error) {
                    overlay.entries = []
                    overlay.loadError = `Could not read Hyprland keybinds: ${error}`
                }
            }
        }
    }

    ScriptModel {
        id: leftModel
        values: overlay.leftEntries
    }

    ScriptModel {
        id: rightModel
        values: overlay.rightEntries
    }

    MouseArea {
        anchors.fill: parent
        onClicked: overlay.close()
    }

    Item {
        id: keyboardScope

        anchors.fill: parent
        focus: overlay.visible
        Keys.onEscapePressed: overlay.close()

        PanelCard {
            id: card

            anchors.centerIn: parent
            width: Math.min(Theme.keybindsWidth, overlay.width - 80)
            height: Math.min(Theme.keybindsHeight, overlay.height - 100)

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
                text: "Keybindings"
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
            }

            Text {
                anchors {
                    baseline: title.baseline
                    right: parent.right
                    rightMargin: 28
                }
                text: `${overlay.entries.length} bindings`
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption + 1
            }

            Rectangle {
                anchors {
                    top: title.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 18
                    leftMargin: 28
                    rightMargin: 28
                }
                height: 1
                color: Theme.backgroundDarker
            }

            ListView {
                id: leftList

                anchors {
                    top: title.bottom
                    bottom: footer.top
                    left: parent.left
                    right: divider.left
                    topMargin: 34
                    bottomMargin: 12
                    leftMargin: 24
                    rightMargin: 18
                }
                model: leftModel
                spacing: 3
                clip: true
                interactive: contentHeight > height
                delegate: BindingRow {
                    required property var modelData
                    width: leftList.width
                    category: modelData.category
                    shortcut: modelData.key
                    action: modelData.action
                }
            }

            Rectangle {
                id: divider

                anchors {
                    top: title.bottom
                    bottom: footer.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 34
                    bottomMargin: 12
                }
                width: 1
                color: Theme.backgroundDarker
            }

            ListView {
                id: rightList

                anchors {
                    top: title.bottom
                    bottom: footer.top
                    left: divider.right
                    right: parent.right
                    topMargin: 34
                    bottomMargin: 12
                    leftMargin: 18
                    rightMargin: 24
                }
                model: rightModel
                spacing: 3
                clip: true
                interactive: contentHeight > height
                delegate: BindingRow {
                    required property var modelData
                    width: rightList.width
                    category: modelData.category
                    shortcut: modelData.key
                    action: modelData.action
                }
            }

            Text {
                anchors.centerIn: parent
                visible: overlay.loadError.length > 0 || overlay.entries.length === 0
                text: overlay.loadError.length > 0 ? overlay.loadError : "No described keybindings found"
                color: overlay.loadError.length > 0 ? Theme.error : Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontBody
            }

            Item {
                id: footer

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: 28
                    rightMargin: 28
                }
                height: 46

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Theme.backgroundDarker
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "esc or click outside to close"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                }
            }
        }
    }
}
