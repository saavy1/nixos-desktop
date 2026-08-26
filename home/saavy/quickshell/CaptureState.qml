import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQml.Models

Scope {
    id: root

    required property var osd

    property string screenshotMode: "region"
    property string screenshotDestination: "save"
    property string recordingTarget: "output"
    property int recordingFps: 60
    property bool recordingAudio: true
    property bool recordingHdr: false
    property string status: "Ready"
    property string lastError: ""
    property string pendingScreenshotPath: ""
    property string pendingScreenshotMode: ""
    property string recordingPath: ""
    property string recordingLabel: ""
    property double recordingStartedAt: 0
    property int elapsedSeconds: 0
    property bool recordingStopRequested: false

    readonly property bool recording: recordProc.running
    readonly property bool busy: screenshotProc.running || selectionProc.running
    readonly property var history: historyModel
    readonly property string homeDirectory: Quickshell.env("HOME") || "/"
    readonly property string picturesDirectory: `${homeDirectory}/Pictures`
    readonly property string videosDirectory: `${homeDirectory}/Videos`
    readonly property string focusedOutput: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    function pad(value): string {
        return String(value).padStart(2, "0")
    }

    function timestamp(): string {
        const now = new Date()
        return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}_${pad(now.getHours())}-${pad(now.getMinutes())}-${pad(now.getSeconds())}`
    }

    function formatDuration(seconds): string {
        const safe = Math.max(0, Math.floor(seconds))
        const hours = Math.floor(safe / 3600)
        const minutes = Math.floor((safe % 3600) / 60)
        const remainder = safe % 60
        return hours > 0
            ? `${pad(hours)}:${pad(minutes)}:${pad(remainder)}`
            : `${pad(minutes)}:${pad(remainder)}`
    }

    function addHistory(kind, detail, path, duration): void {
        historyModel.insert(0, {
            kind: String(kind),
            detail: String(detail),
            path: String(path || ""),
            duration: String(duration || ""),
            createdAt: Date.now()
        })
        while (historyModel.count > 12)
            historyModel.remove(historyModel.count - 1)
    }
    function completeScreenshot(): void {
        if (pendingScreenshotPath.length > 0) {
            status = `Saved ${pendingScreenshotPath.replace(/^.*\//, "")}`
            addHistory("Screenshot", pendingScreenshotMode, pendingScreenshotPath, "")
            if (osd)
                osd.screenshotSaved(pendingScreenshotPath)
        } else {
            status = "Screenshot copied to clipboard"
            addHistory("Screenshot", `${pendingScreenshotMode} · clipboard`, "", "")
            if (osd)
                osd.screenshotCopied()
        }
        pendingScreenshotPath = ""
        pendingScreenshotMode = ""
    }


    function takeScreenshot(mode, destination): void {
        const captureMode = ["output", "window", "region"].indexOf(mode) >= 0 ? mode : screenshotMode
        const captureDestination = destination === "clipboard" ? "clipboard" : "save"
        if (busy) {
            status = "Another capture selection is already active"
            return
        }

        screenshotMode = captureMode
        screenshotDestination = captureDestination
        lastError = ""
        pendingScreenshotMode = captureMode
        const argv = ["hyprshot", "-m", captureMode]
        if (captureMode === "output" && focusedOutput.length > 0)
            argv.push("-m", focusedOutput)
        if (captureMode === "region")
            argv.push("--freeze")
        argv.push("--silent")

        if (captureDestination === "clipboard") {
            pendingScreenshotPath = ""
            argv.push("--clipboard-only")
            status = `Selecting ${captureMode} for clipboard…`
        } else {
            const filename = `Screenshot-${timestamp()}.png`
            pendingScreenshotPath = `${picturesDirectory}/${filename}`
            argv.push("--output-folder", picturesDirectory, "--filename", filename)
            status = captureMode === "output" ? "Capturing display…" : `Selecting ${captureMode} to save…`
        }

        screenshotProc.command = argv
        screenshotProc.running = true
    }

    function startRecording(target): void {
        if (recording || selectionProc.running) {
            status = recording ? "Recording is already active" : "Region selection is already active"
            return
        }

        recordingTarget = target === "region" ? "region" : "output"
        lastError = ""
        if (recordingTarget === "region") {
            status = "Select a recording region…"
            selectionProc.command = ["slurp", "-f", "%wx%h+%x+%y"]
            selectionProc.running = true
        } else {
            beginRecording("")
        }
    }

    function beginRecording(region): void {
        const output = focusedOutput
        if (recordingTarget === "output" && output.length === 0) {
            status = "No focused display is available"
            return
        }

        const filename = `Recording-${timestamp()}.mkv`
        recordingPath = `${videosDirectory}/${filename}`
        recordingLabel = recordingTarget === "region" ? "Region" : output
        recordingStartedAt = Date.now()
        elapsedSeconds = 0
        recordingStopRequested = false

        const argv = [
            "gpu-screen-recorder",
            "-w", recordingTarget === "region" ? "region" : output
        ]
        if (recordingTarget === "region")
            argv.push("-region", region)
        argv.push(
            "-f", String(recordingFps),
            "-k", recordingHdr ? "av1_hdr" : "av1_10bit",
            "-q", "very_high",
            "-fm", "vfr",
            "-cursor", "yes"
        )
        if (recordingAudio)
            argv.push("-a", "default_output")
        argv.push("-o", recordingPath)

        recordProc.command = argv
        status = `Starting ${recordingLabel} recording…`
        recordProc.running = true
    }

    function stopRecording(): void {
        if (!recording)
            return
        recordingStopRequested = true
        status = "Finalizing recording…"
        recordProc.running = false
    }

    function toggleRecording(): void {
        if (recording)
            stopRecording()
        else
            startRecording(recordingTarget)
    }

    ListModel {
        id: historyModel
    }

    Timer {
        interval: 250
        repeat: true
        running: root.recording
        onTriggered: root.elapsedSeconds = Math.floor((Date.now() - root.recordingStartedAt) / 1000)
    }

    IpcHandler {
        target: "capture-state"

        function screenshot(mode: string, destination: string): void {
            root.takeScreenshot(mode, destination)
        }

        function startRecording(target: string): void {
            root.startRecording(target)
        }

        function stopRecording(): void {
            root.stopRecording()
        }

        function toggleRecording(): void {
            root.toggleRecording()
        }
    }

    Process {
        id: screenshotProc

        property string failureText: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: screenshotProc.failureText = text.trim()
        }
        onStarted: failureText = ""
        onExited: (exitCode, exitStatus) => {
            if (root.pendingScreenshotPath.length > 0) {
                screenshotVerifyProc.command = ["test", "-s", root.pendingScreenshotPath]
                screenshotVerifyProc.running = true
            } else if (exitCode === 0 || exitCode === 1) {
                root.completeScreenshot()
            } else {
                root.lastError = failureText.length > 0 ? failureText : `hyprshot exited with code ${exitCode}`
                root.status = `Screenshot failed · ${root.lastError}`
                root.pendingScreenshotMode = ""
            }
        }
    }

    Process {
        id: screenshotVerifyProc

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.completeScreenshot()
            } else {
                root.status = "Screenshot selection cancelled"
                root.pendingScreenshotPath = ""
                root.pendingScreenshotMode = ""
            }
        }
    }

    Process {
        id: selectionProc

        property string output: ""
        property string failureText: ""
        stdout: StdioCollector {
            onStreamFinished: selectionProc.output = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: selectionProc.failureText = text.trim()
        }
        onStarted: {
            output = ""
            failureText = ""
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && output.length > 0) {
                root.beginRecording(output)
            } else if (exitCode === 1) {
                root.status = "Recording selection cancelled"
            } else {
                root.lastError = failureText.length > 0 ? failureText : "Unable to select a recording region"
                root.status = `Recording selection failed · ${root.lastError}`
            }
        }
    }

    Process {
        id: recordProc

        property string failureText: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: recordProc.failureText = text.trim()
        }
        onStarted: {
            failureText = ""
            root.status = `Recording ${root.recordingLabel} · ${root.recordingFps} FPS`
            if (root.osd)
                root.osd.recording(true)
        }
        onExited: (exitCode, exitStatus) => {
            const duration = root.formatDuration(root.elapsedSeconds)
            if (root.recordingStopRequested || exitCode === 0) {
                root.status = `Saved ${root.recordingPath.replace(/^.*\//, "")} · ${duration}`
                root.addHistory("Recording", `${root.recordingLabel} · ${root.recordingFps} FPS`, root.recordingPath, duration)
            } else {
                root.lastError = failureText.length > 0 ? failureText : `gpu-screen-recorder exited with code ${exitCode}`
                root.status = `Recording failed · ${root.lastError}`
            }
            if (root.osd)
                root.osd.recording(false)
            root.recordingStartedAt = 0
            root.recordingStopRequested = false
        }
    }
}
