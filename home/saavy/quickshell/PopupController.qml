pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: controller

    property string activePopup: ""
    readonly property var focusedScreen: {
        const monitor = Hyprland.focusedMonitor
        if (monitor) {
            for (const screen of Quickshell.screens) {
                if (Hyprland.monitorFor(screen) === monitor)
                    return screen
            }
        }

        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    function isOpen(name): bool {
        return activePopup === name
    }

    function open(name): void {
        closeNotificationCenter()
        activePopup = name
    }

    function close(name): void {
        if (activePopup === name)
            activePopup = ""
    }

    function closeAll(): void {
        activePopup = ""
    }

    function toggle(name): void {
        if (activePopup === name) {
            activePopup = ""
        } else {
            closeNotificationCenter()
            activePopup = name
        }
    }

    function closeNotificationCenter(): void {
        if (!notificationClose.running)
            notificationClose.running = true
    }

    Process {
        id: notificationClose

        command: ["swaync-client", "--close-panel", "--skip-wait"]
    }
}
