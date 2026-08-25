import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: systemPanel

    property string uptime: "Loading…"
    property string hostName: "Loading…"
    property string kernelVersion: "Loading…"
    property string nixosGeneration: "Loading…"
    property string powerProfile: ""
    property bool powerProfileAvailable: false
    property string hibernateState: "checking"
    property string pendingAction: ""
    property string operationStatus: ""
    property string actionDescription: ""

    readonly property bool hibernateSupported: hibernateState === "supported"
    readonly property bool actionRunning: actionProc.running

    visible: PopupController.isOpen("system")
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
    WlrLayershell.namespace: "solitude-system"

    function startIfIdle(process): void {
        if (!process.running)
            process.running = true
    }

    function refreshUptime(): void {
        startIfIdle(uptimeProc)
    }

    function refreshSystemInfo(): void {
        startIfIdle(hostnameProc)
        startIfIdle(kernelProc)
        startIfIdle(generationProc)
        startIfIdle(powerProfileProc)
        startIfIdle(hibernateProc)
        refreshUptime()
    }

    function open(): void {
        PopupController.open("system")
    }

    function close(): void {
        pendingAction = ""
        PopupController.close("system")
    }

    function toggle(): void {
        if (visible)
            close()
        else
            open()
    }

    function titleCaseProfile(profile): string {
        if (!profile)
            return "Unavailable"
        return profile.split("-").map(word => word.length > 0
            ? word.charAt(0).toUpperCase() + word.slice(1)
            : word).join(" ")
    }

    function confirmationTitle(action): string {
        switch (action) {
        case "logout": return "Log out of this session?"
        case "reboot": return "Restart this computer?"
        case "poweroff": return "Power off this computer?"
        case "hibernate": return "Hibernate this computer?"
        default: return "Confirm action"
        }
    }

    function confirmationDetail(action): string {
        switch (action) {
        case "logout": return "Open applications will be closed and unsaved work may be lost."
        case "reboot": return "The system will close the session and restart immediately."
        case "poweroff": return "The system will close the session and shut down immediately."
        case "hibernate": return "The session will be written to disk before the system powers down."
        default: return "This action cannot be undone."
        }
    }

    function confirmationButton(action): string {
        switch (action) {
        case "logout": return "Log out"
        case "reboot": return "Restart"
        case "poweroff": return "Power off"
        case "hibernate": return "Hibernate"
        default: return "Confirm"
        }
    }

    function requestAction(action): void {
        if (actionRunning)
            return

        if (action === "hibernate" && !hibernateSupported) {
            operationStatus = "Hibernate is not supported on this system"
            return
        }

        if (action === "logout" || action === "reboot" || action === "poweroff" || action === "hibernate") {
            operationStatus = ""
            pendingAction = action
            return
        }

        runAction(action)
    }

    function cancelConfirmation(): void {
        pendingAction = ""
    }

    function confirmAction(): void {
        const action = pendingAction
        pendingAction = ""
        if (action.length > 0)
            runAction(action)
    }

    function runAction(action): void {
        if (actionProc.running)
            return

        switch (action) {
        case "lock":
            actionDescription = "Locking session"
            actionProc.command = ["hyprlock"]
            break
        case "suspend":
            actionDescription = "Suspending system"
            actionProc.command = ["systemctl", "suspend"]
            break
        case "hibernate":
            if (!hibernateSupported) {
                operationStatus = "Hibernate is not supported on this system"
                return
            }
            actionDescription = "Hibernating system"
            actionProc.command = ["systemctl", "hibernate"]
            break
        case "logout":
            actionDescription = "Logging out"
            actionProc.command = ["uwsm", "stop"]
            break
        case "reboot":
            actionDescription = "Restarting system"
            actionProc.command = ["systemctl", "reboot"]
            break
        case "poweroff":
            actionDescription = "Powering off system"
            actionProc.command = ["systemctl", "poweroff"]
            break
        default:
            operationStatus = "Unknown system action"
            return
        }

        operationStatus = `${actionDescription}…`
        actionProc.running = true
    }

    onVisibleChanged: {
        if (visible) {
            pendingAction = ""
            refreshSystemInfo()
            uptimeTimer.start()
            Qt.callLater(() => keyScope.forceActiveFocus())
        } else {
            pendingAction = ""
            uptimeTimer.stop()
        }
    }

    IpcHandler {
        target: "system"

        function toggle(): void {
            systemPanel.toggle()
        }

        function close(): void {
            systemPanel.close()
        }
    }

    Timer {
        id: uptimeTimer
        interval: 60000
        repeat: true
        running: false
        triggeredOnStart: false
        onTriggered: systemPanel.refreshUptime()
    }

    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim().replace(/^up\s+/, "")
                systemPanel.uptime = value.length > 0 ? value : "Unavailable"
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                systemPanel.uptime = "Unavailable"
        }
    }

    Process {
        id: hostnameProc
        command: ["hostname"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                systemPanel.hostName = value.length > 0 ? value : "Unknown host"
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                systemPanel.hostName = "Unknown host"
        }
    }

    Process {
        id: kernelProc
        command: ["uname", "-r"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                systemPanel.kernelVersion = value.length > 0 ? value : "Unavailable"
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                systemPanel.kernelVersion = "Unavailable"
        }
    }

    Process {
        id: generationProc
        command: ["readlink", "/nix/var/nix/profiles/system"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                const match = value.match(/system-(\d+)-link/)
                systemPanel.nixosGeneration = match ? match[1] : "Unavailable"
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                systemPanel.nixosGeneration = "Unavailable"
        }
    }

    Process {
        id: powerProfileProc
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                systemPanel.powerProfile = value
                systemPanel.powerProfileAvailable = value.length > 0
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                systemPanel.powerProfile = ""
                systemPanel.powerProfileAvailable = false
            }
        }
    }

    Process {
        id: hibernateProc
        command: ["busctl", "get-property", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanHibernate"]
        stdout: StdioCollector {
            onStreamFinished: {
                const quoted = text.match(/"([^"]+)"/)
                const value = (quoted ? quoted[1] : text.trim().split(/\s+/).pop()).toLowerCase()
                systemPanel.hibernateState = value === "yes" || value === "challenge"
                    ? "supported"
                    : "unsupported"
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                systemPanel.hibernateState = "unsupported"
        }
    }

    Process {
        id: actionProc
        property string failureText: ""

        stderr: StdioCollector {
            onStreamFinished: actionProc.failureText = text.trim()
        }
        onStarted: systemPanel.close()
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                systemPanel.operationStatus = `${systemPanel.actionDescription} requested`
            } else {
                const detail = actionProc.failureText.length > 0 ? `: ${actionProc.failureText}` : ""
                systemPanel.operationStatus = `${systemPanel.actionDescription} failed${detail}`
            }
            actionProc.failureText = ""
        }
    }

    component InfoRow: Item {
        required property string label
        required property string value
        property bool last: false

        width: parent ? parent.width : 0
        height: 46

        Text {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            text: parent.label
            color: Theme.muted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontCaption
        }

        Text {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 154
            }
            horizontalAlignment: Text.AlignRight
            text: parent.value
            color: Theme.foreground
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontBody
            elide: Text.ElideMiddle
        }

        Rectangle {
            visible: !parent.last
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 1
            color: Theme.backgroundDarker
        }
    }

    component ActionButton: Rectangle {
        id: actionButton

        required property string title
        required property string detail
        required property string action
        property bool destructive: false

        width: (actionFlow.width - actionFlow.spacing) / 2
        height: 62
        radius: Theme.radiusMedium
        color: !enabled
            ? Theme.backgroundDarker
            : actionMouse.containsMouse ? Theme.selection : Theme.backgroundDark
        border.color: destructive ? Theme.withAlpha(Theme.error, 0.75) : Theme.backgroundDarker
        border.width: Theme.borderWidth
        opacity: enabled ? 1 : 0.5

        Column {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 14
                rightMargin: 14
            }
            spacing: 2

            Text {
                width: parent.width
                text: actionButton.title
                color: actionButton.destructive ? Theme.error : Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontBody
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: actionButton.detail
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            enabled: actionButton.enabled && !systemPanel.actionRunning
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: systemPanel.requestAction(actionButton.action)
        }
    }

    Item {
        id: keyScope
        anchors.fill: parent
        focus: systemPanel.visible

        Keys.onEscapePressed: {
            if (systemPanel.pendingAction.length > 0)
                systemPanel.cancelConfirmation()
            else
                systemPanel.close()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: systemPanel.close()
        }

        PanelCard {
            id: card
            anchors {
                top: parent.top
                right: parent.right
                topMargin: Theme.outerMargin + Theme.barHeight + Theme.shellGap
                rightMargin: Theme.outerMargin
            }
            width: Math.min(500, systemPanel.width - 80)
            height: Math.min(650, systemPanel.height - 100)

            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: header
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 20
                }
                height: 54

                Column {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 3

                    Text {
                        width: parent.width
                        text: "System"
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: systemPanel.hostName === "Loading…" ? "Session and power controls" : systemPanel.hostName
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        elide: Text.ElideRight
                    }
                }
            }

            PanelDivider {
                id: headerDivider
                anchors {
                    top: header.bottom
                    left: parent.left
                    right: parent.right
                    leftMargin: 20
                    rightMargin: 20
                }
            }

            Flickable {
                id: contentViewport
                anchors {
                    top: headerDivider.bottom
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 12
                    bottomMargin: 20
                    leftMargin: 20
                    rightMargin: 20
                }
                contentWidth: width
                contentHeight: panelContent.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: panelContent
                    width: contentViewport.width
                    spacing: 12

                    Text {
                        width: parent.width
                        text: "SYSTEM INFORMATION"
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        width: parent.width
                        height: informationRows.implicitHeight + 16
                        radius: Theme.radiusMedium
                        color: Theme.backgroundDark
                        border.color: Theme.backgroundDarker
                        border.width: Theme.borderWidth

                        Column {
                            id: informationRows
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 8
                            }

                            InfoRow {
                                label: "UPTIME"
                                value: systemPanel.uptime
                            }
                            InfoRow {
                                label: "HOSTNAME"
                                value: systemPanel.hostName
                            }
                            InfoRow {
                                label: "KERNEL"
                                value: systemPanel.kernelVersion
                            }
                            InfoRow {
                                label: "NIXOS GENERATION"
                                value: systemPanel.nixosGeneration
                            }
                            InfoRow {
                                label: "POWER PROFILE"
                                value: systemPanel.powerProfileAvailable
                                    ? systemPanel.titleCaseProfile(systemPanel.powerProfile)
                                    : "Unavailable"
                                last: true
                            }
                        }
                    }

                    PanelDivider {
                        width: parent.width
                    }

                    Text {
                        width: parent.width
                        text: systemPanel.pendingAction.length > 0 ? "CONFIRM ACTION" : "SESSION AND POWER"
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        visible: systemPanel.pendingAction.length > 0
                        width: parent.width
                        height: 190
                        radius: Theme.radiusMedium
                        color: Theme.backgroundDark
                        border.color: Theme.error
                        border.width: Theme.borderWidth

                        Column {
                            anchors {
                                fill: parent
                                margins: 16
                            }
                            spacing: 10

                            Text {
                                width: parent.width
                                text: systemPanel.confirmationTitle(systemPanel.pendingAction)
                                color: Theme.foreground
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontBody
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                            }

                            Text {
                                width: parent.width
                                height: 52
                                text: systemPanel.confirmationDetail(systemPanel.pendingAction)
                                color: Theme.muted
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                                wrapMode: Text.Wrap
                            }

                            Row {
                                width: parent.width
                                spacing: 10

                                Rectangle {
                                    width: (parent.width - parent.spacing) / 2
                                    height: 42
                                    radius: Theme.radiusMedium
                                    color: cancelMouse.containsMouse ? Theme.selection : Theme.backgroundDarker

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Cancel"
                                        color: Theme.foreground
                                        font.family: Theme.fontSans
                                        font.pixelSize: Theme.fontBody
                                        font.weight: Font.DemiBold
                                    }

                                    MouseArea {
                                        id: cancelMouse
                                        anchors.fill: parent
                                        enabled: !systemPanel.actionRunning
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: systemPanel.cancelConfirmation()
                                    }
                                }

                                Rectangle {
                                    width: (parent.width - parent.spacing) / 2
                                    height: 42
                                    radius: Theme.radiusMedium
                                    color: confirmMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.8) : Theme.error

                                    Text {
                                        anchors.centerIn: parent
                                        text: systemPanel.confirmationButton(systemPanel.pendingAction)
                                        color: Theme.backgroundDarker
                                        font.family: Theme.fontSans
                                        font.pixelSize: Theme.fontBody
                                        font.weight: Font.DemiBold
                                    }

                                    MouseArea {
                                        id: confirmMouse
                                        anchors.fill: parent
                                        enabled: !systemPanel.actionRunning
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: systemPanel.confirmAction()
                                    }
                                }
                            }
                        }
                    }

                    Flow {
                        id: actionFlow
                        visible: systemPanel.pendingAction.length === 0
                        width: parent.width
                        height: childrenRect.height
                        spacing: 10

                        ActionButton {
                            title: "Lock"
                            detail: "Secure this session"
                            action: "lock"
                        }
                        ActionButton {
                            title: "Suspend"
                            detail: "Sleep in memory"
                            action: "suspend"
                        }
                        ActionButton {
                            visible: systemPanel.hibernateSupported
                            title: "Hibernate"
                            detail: "Save session to disk"
                            action: "hibernate"
                            destructive: true
                        }
                        ActionButton {
                            title: "Log out"
                            detail: "End this session"
                            action: "logout"
                            destructive: true
                        }
                        ActionButton {
                            title: "Restart"
                            detail: "Reboot the system"
                            action: "reboot"
                            destructive: true
                        }
                        ActionButton {
                            title: "Power off"
                            detail: "Shut down the system"
                            action: "poweroff"
                            destructive: true
                        }
                    }

                    Text {
                        visible: systemPanel.pendingAction.length === 0 && !systemPanel.hibernateSupported
                        width: parent.width
                        text: systemPanel.hibernateState === "checking"
                            ? "Checking whether hibernation is supported…"
                            : "Hibernate unavailable — this system does not report hibernation support."
                        color: systemPanel.hibernateState === "checking" ? Theme.muted : Theme.warning
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        wrapMode: Text.Wrap
                    }

                    Text {
                        visible: systemPanel.pendingAction.length === 0 && systemPanel.operationStatus.length > 0
                        width: parent.width
                        text: systemPanel.operationStatus
                        color: systemPanel.operationStatus.indexOf("failed") >= 0 ? Theme.error : Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
