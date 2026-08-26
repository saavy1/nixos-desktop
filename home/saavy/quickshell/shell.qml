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
    }
    Launcher {}
    Keybinds {}
    AudioPanel {}
    BluetoothPanel {}
    CalendarPanel {}
    CapturePanel {
        state: captureState
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
}
