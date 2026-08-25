import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    readonly property int count: state.count
    readonly property bool dnd: state.dnd

    function refresh(): void {
        if (!countProcess.running)
            countProcess.running = true
        if (!dndProcess.running)
            dndProcess.running = true
    }

    function toggleCenter(): void {
        PopupController.closeAll()
        if (!centerToggleProcess.running)
            centerToggleProcess.running = true
    }

    function closeCenter(): void {
        if (!centerCloseProcess.running)
            centerCloseProcess.running = true
    }

    function toggleDnd(): void {
        if (!dndToggleProcess.running)
            dndToggleProcess.running = true
    }

    Component.onCompleted: refresh()

    QtObject {
        id: state

        property int count: 0
        property bool dnd: false

        function updateCount(output: string): void {
            const valueText = output.trim()
            const value = Number(valueText)
            if (valueText !== "" && isFinite(value) && Math.floor(value) === value && value >= 0 && value <= 2147483647)
                count = value
        }

        function updateDnd(output: string): void {
            const value = output.trim().toLowerCase()
            if (value === "true")
                dnd = true
            else if (value === "false")
                dnd = false
        }

        function updateSubscription(line: string): void {
            try {
                const event = JSON.parse(line)
                updateCount(String(event.count))
                if (typeof event.dnd === "boolean")
                    dnd = event.dnd
            } catch (error) {
                // Ignore malformed or partial event records and keep the last valid state.
            }
        }
    }

    Process {
        id: subscriptionProcess

        command: ["swaync-client", "--subscribe", "--skip-wait"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => state.updateSubscription(data)
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            if (!subscriptionProcess.running) {
                subscriptionProcess.running = true
                root.refresh()
            }
        }
    }

    Process {
        id: countProcess

        command: ["swaync-client", "--count", "--skip-wait"]
        stdout: StdioCollector {
            onStreamFinished: state.updateCount(text)
        }
    }

    Process {
        id: dndProcess

        command: ["swaync-client", "--get-dnd", "--skip-wait"]
        stdout: StdioCollector {
            onStreamFinished: state.updateDnd(text)
        }
    }

    Process {
        id: centerToggleProcess

        command: ["swaync-client", "--toggle-panel", "--skip-wait"]
    }

    Process {
        id: centerCloseProcess

        command: ["swaync-client", "--close-panel", "--skip-wait"]
    }

    Process {
        id: dndToggleProcess

        command: ["swaync-client", "--toggle-dnd", "--skip-wait"]
        stdout: StdioCollector {
            onStreamFinished: state.updateDnd(text)
        }
    }
}
