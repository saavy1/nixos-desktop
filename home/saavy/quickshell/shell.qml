import Quickshell

ShellRoot {
    NotificationState {
        id: notificationState
    }

    MediaStatus {
        id: mediaStatus
    }

    Osd {
        id: osd
    }

    Wallpaper {}
    NotificationPopup {
        notificationState: notificationState
    }
    Bar {
        notificationState: notificationState
        mediaStatus: mediaStatus
    }
    Launcher {}
    Keybinds {}
    AudioPanel {}
    BluetoothPanel {}
    CalendarPanel {}
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
}
