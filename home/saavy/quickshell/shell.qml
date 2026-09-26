import Quickshell

ShellRoot {
    NotificationState {
        id: notificationState
    }

    MediaStatus {
        id: mediaStatus
    }

    AgentUsage {
        id: agentUsage
    }

    LabState {
        id: labState
    }

    Osd {
        id: osd
    }
    CaptureState {
        id: captureState
        osd: osd
    }

    Wallpaper {}
    NotificationPopup {
        notificationState: notificationState
    }
    Bar {
        notificationState: notificationState
        mediaStatus: mediaStatus
        captureState: captureState
        agentUsage: agentUsage
        labState: labState
    }
    Launcher {}
    Keybinds {}
    AgentsPanel {
        usage: agentUsage
    }
    AudioPanel {}
    BluetoothPanel {}
    CalendarPanel {}
    CapturePanel {
        state: captureState
    }
    LabPanel {
        lab: labState
    }
    DisplayPanel {
        osd: osd
    }
    MediaPanel {
        status: mediaStatus
    }
    NetworkPanel {}
    NotificationCenter {
        notificationState: notificationState
    }
    SystemPanel {}
    WallpaperPicker {}
    ClipboardPanel {}
}
