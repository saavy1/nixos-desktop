import Quickshell
import Quickshell.Io
import QtQuick
import qs.ui

PopupPanel {
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

    name: "system"
    title: "System"
    subtitle: hostName === "Loading…"
        ? "session and power"
        : `${hostName} · ${uptime === "Loading…" || uptime === "Unavailable" ? "uptime unavailable" : "up " + uptime}`.toLowerCase()
    cardWidth: 440

    function startIfIdle(process): void {
        if (!process.running)
            process.running = true
    }

    // Same shape as `uptime -p` ("2 days, 3 hours, 14 minutes").
    function formatUptime(seconds: real): string {
        const units = [["day", 86400], ["hour", 3600], ["minute", 60]]
        const parts = []
        let rest = Math.floor(seconds)
        for (const [name, size] of units) {
            const count = Math.floor(rest / size)
            rest -= count * size
            if (count > 0)
                parts.push(`${count} ${name}${count === 1 ? "" : "s"}`)
        }
        return parts.length > 0 ? parts.join(", ") : "less than a minute"
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

    function infoTone(value): string {
        return value === "Unavailable" || value === "Loading…" ? "faint" : "base"
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

    function actionIcon(action): string {
        switch (action) {
        case "logout": return "log-out"
        case "reboot": return "rotate-ccw"
        case "hibernate": return "hard-drive-download"
        default: return "power"
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

    onOpening: {
        pendingAction = ""
        refreshSystemInfo()
    }

    onKeyPressed: event => {
        if (event.key === Qt.Key_Escape && pendingAction.length > 0) {
            cancelConfirmation()
            event.accepted = true
        }
    }

    Timer {
        id: uptimeTimer
        interval: 60000
        repeat: true
        running: systemPanel.shown
        triggeredOnStart: false
        onTriggered: systemPanel.refreshUptime()
    }

    Process {
        id: uptimeProc
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seconds = parseFloat(text)
                systemPanel.uptime = isFinite(seconds) ? systemPanel.formatUptime(seconds) : "Unavailable"
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

    // Large power tile: icon over a label and a one-line hint. Destructive
    // tiles turn rust on hover.
    component PowerTile: Rectangle {
        id: tile

        required property string title
        required property string detail
        required property string action
        required property string icon
        property bool destructive: false
        readonly property bool hot: tileMouse.containsMouse && tileMouse.enabled

        width: (actionGrid.width - actionGrid.columnSpacing * (actionGrid.columns - 1)) / actionGrid.columns
        height: 96
        radius: Theme.radius.medium
        color: !hot ? Theme.withAlpha(Theme.surface.raised, 0.55)
            : destructive ? Theme.dangerTint
            : Theme.surface.hover
        border.width: Theme.borderWidth
        border.color: hot && destructive ? Theme.withAlpha(Theme.danger, 0.55) : hot ? Theme.lineStrong : Theme.line
        opacity: enabled && !systemPanel.actionRunning ? 1 : Theme.alpha.disabled
        scale: tileMouse.pressed ? 0.97 : 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.motion.fast
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.motion.fast
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Theme.space.sm
                rightMargin: Theme.space.sm
            }
            spacing: Theme.space.xs

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: tile.icon
                size: 22
                color: tile.hot ? (tile.destructive ? Theme.danger : Theme.text.base) : Theme.text.soft
            }

            Item {
                width: 1
                height: Theme.space.xs
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.title
                variant: "small"
                font.pixelSize: Theme.fontSize.bar
                font.weight: Font.Medium
                color: tile.hot && tile.destructive ? Theme.danger : Theme.text.base
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.detail
                variant: "caption"
                tone: "faint"
            }
        }

        MouseArea {
            id: tileMouse

            anchors.fill: parent
            enabled: tile.enabled && !systemPanel.actionRunning
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: systemPanel.requestAction(tile.action)
        }
    }

    SectionHeader {
        width: parent.width
        text: systemPanel.pendingAction.length > 0 ? "Confirm action" : "Session and power"
        trailing: systemPanel.actionRunning ? "working" : ""
    }

    Rectangle {
        visible: systemPanel.pendingAction.length > 0
        width: parent.width
        height: confirmColumn.implicitHeight + Theme.space.lg * 2
        radius: Theme.radius.medium
        color: Theme.withAlpha(Theme.danger, 0.08)
        border.width: Theme.borderWidth
        border.color: Theme.withAlpha(Theme.danger, 0.45)

        Column {
            id: confirmColumn

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.space.lg
            }
            spacing: Theme.space.sm

            Row {
                width: parent.width
                spacing: Theme.space.sm + 2

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: systemPanel.actionIcon(systemPanel.pendingAction)
                    size: 18
                    color: Theme.danger
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 28
                    text: systemPanel.confirmationTitle(systemPanel.pendingAction)
                    variant: "heading"
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                }
            }

            Label {
                width: parent.width
                text: systemPanel.confirmationDetail(systemPanel.pendingAction)
                variant: "small"
                tone: "soft"
                wrapMode: Text.Wrap
            }

            Item {
                width: 1
                height: Theme.space.xs
            }

            Row {
                width: parent.width
                spacing: Theme.space.sm

                Button {
                    width: (parent.width - parent.spacing) / 2
                    enabled: !systemPanel.actionRunning
                    text: "Cancel"
                    onClicked: systemPanel.cancelConfirmation()
                }

                Button {
                    width: (parent.width - parent.spacing) / 2
                    enabled: !systemPanel.actionRunning
                    variant: "danger"
                    icon: systemPanel.actionIcon(systemPanel.pendingAction)
                    text: systemPanel.confirmationButton(systemPanel.pendingAction)
                    onClicked: systemPanel.confirmAction()
                }
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "esc to cancel"
                variant: "numeric"
                font.pixelSize: Theme.fontSize.caption
                font.weight: Font.Normal
                tone: "faint"
            }
        }
    }

    Grid {
        id: actionGrid

        visible: systemPanel.pendingAction.length === 0
        width: parent.width
        columns: 3
        columnSpacing: Theme.space.sm
        rowSpacing: Theme.space.sm

        PowerTile {
            title: "Lock"
            detail: "Secure this session"
            action: "lock"
            icon: "lock"
        }
        PowerTile {
            title: "Suspend"
            detail: "Sleep in memory"
            action: "suspend"
            icon: "moon"
        }
        PowerTile {
            visible: systemPanel.hibernateSupported
            title: "Hibernate"
            detail: "Save session to disk"
            action: "hibernate"
            icon: "hard-drive-download"
            destructive: true
        }
        PowerTile {
            title: "Log out"
            detail: "End this session"
            action: "logout"
            icon: "log-out"
            destructive: true
        }
        PowerTile {
            title: "Restart"
            detail: "Reboot the system"
            action: "reboot"
            icon: "rotate-ccw"
            destructive: true
        }
        PowerTile {
            title: "Power off"
            detail: "Shut down the system"
            action: "poweroff"
            icon: "power"
            destructive: true
        }
    }

    Label {
        visible: systemPanel.pendingAction.length === 0 && !systemPanel.hibernateSupported
        width: parent.width
        text: systemPanel.hibernateState === "checking"
            ? "Checking whether hibernation is supported…"
            : "Hibernate unavailable — this system does not report hibernation support."
        variant: "small"
        tone: systemPanel.hibernateState === "checking" ? "faint" : "warning"
        wrapMode: Text.Wrap
    }

    Label {
        visible: systemPanel.pendingAction.length === 0 && systemPanel.operationStatus.length > 0
        width: parent.width
        text: systemPanel.operationStatus
        variant: "small"
        tone: systemPanel.operationStatus.indexOf("failed") >= 0 ? "danger" : "soft"
        wrapMode: Text.Wrap
    }

    SectionHeader {
        width: parent.width
        text: "System information"
    }

    Column {
        width: parent.width

        InfoRow {
            label: "Uptime"
            valueTone: systemPanel.infoTone(value)
            value: systemPanel.uptime
        }
        InfoRow {
            label: "Hostname"
            valueTone: systemPanel.infoTone(value)
            value: systemPanel.hostName
        }
        InfoRow {
            label: "Kernel"
            valueTone: systemPanel.infoTone(value)
            value: systemPanel.kernelVersion
        }
        InfoRow {
            label: "NixOS generation"
            valueTone: systemPanel.infoTone(value)
            value: systemPanel.nixosGeneration
        }
        InfoRow {
            label: "Power profile"
            valueTone: systemPanel.infoTone(value)
            value: systemPanel.powerProfileAvailable
                ? systemPanel.titleCaseProfile(systemPanel.powerProfile)
                : "Unavailable"
            last: true
        }
    }
}
