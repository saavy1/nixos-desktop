import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: launcher

    readonly property var modes: [
        { id: "applications", label: "Apps", shortLabel: "APP", hint: "Search applications…" },
        { id: "clipboard", label: "Clipboard", shortLabel: "CLIP", hint: "Search clipboard history…" },
        { id: "files", label: "Files", shortLabel: "FILE", hint: "Search files in your home directory…" },
        { id: "calculator", label: "Calculate", shortLabel: "CALC", hint: "Enter an arithmetic expression…" },
        { id: "commands", label: "Command", shortLabel: "CMD", hint: "Enter a command and arguments…" },
        { id: "windows", label: "Windows", shortLabel: "WIN", hint: "Search open windows…" },
        { id: "web", label: "Web", shortLabel: "WEB", hint: "Search the web…" }
    ]
    property int modeIndex: 0
    readonly property string mode: modes[modeIndex].id
    property string searchText: ""
    property var clipboardEntries: []
    property var fileEntries: []
    property string clipboardStatus: "idle"
    property string clipboardError: ""
    property string fileStatus: "idle"
    property string fileError: ""
    property string activationError: ""
    property string historyError: ""
    readonly property int sourceLimit: 2500
    readonly property var calculation: calculate(searchText.trim())
    readonly property var parsedCommand: parseCommand(searchText.trim())
    readonly property string webSearchBase: Quickshell.env("SOLITUDE_WEB_SEARCH_URL") || "https://duckduckgo.com/?q="
    readonly property string homeDirectory: Quickshell.env("HOME") || "/"

    readonly property var filteredValues: {
        const needle = normalize(searchText)
        let candidates = []

        if (mode === "applications") {
            const applications = DesktopEntries.applications.values.slice(0, sourceLimit)
            candidates = applications.map(entry => {
                const command = entry.command || []
                const stableId = entry.id || `${entry.name || "application"}|${command.join("\u001f")}`
                return {
                    kind: "application",
                    key: `application:${stableId}`,
                    label: entry.name || "Unnamed application",
                    subtitle: entry.genericName || entry.comment || "Application",
                    searchable: `${entry.name || ""} ${entry.genericName || ""} ${entry.comment || ""}`,
                    icon: entry.icon || "",
                    payload: entry
                }
            })
        } else if (mode === "clipboard") {
            candidates = clipboardEntries.slice(0, sourceLimit).map(raw => {
                const preview = raw.replace(/^\d+\s+/, "")
                return {
                    kind: "clipboard",
                    key: `clipboard:${raw}`,
                    label: preview || "Clipboard entry",
                    subtitle: "Copy from clipboard history",
                    searchable: preview,
                    icon: "",
                    payload: raw
                }
            })
        } else if (mode === "files") {
            candidates = fileEntries.slice(0, sourceLimit).map(path => {
                const slash = path.lastIndexOf("/")
                return {
                    kind: "file",
                    key: `file:${path}`,
                    label: slash >= 0 ? path.slice(slash + 1) : path,
                    subtitle: path,
                    searchable: path,
                    icon: "text-x-generic",
                    payload: path
                }
            })
        } else if (mode === "calculator") {
            if (searchText.trim().length > 0 && calculation.ok) {
                candidates = [{
                    kind: "calculator",
                    key: `calculator:${searchText.trim()}`,
                    label: calculation.text,
                    subtitle: `${searchText.trim()}  ·  Enter copies result`,
                    searchable: searchText,
                    icon: "accessories-calculator",
                    payload: calculation.text
                }]
            }
        } else if (mode === "commands") {
            if (searchText.trim().length > 0 && parsedCommand.ok) {
                candidates = [{
                    kind: "command",
                    key: `command:${searchText.trim()}`,
                    label: searchText.trim(),
                    subtitle: `Run ${parsedCommand.argv[0]} with ${Math.max(0, parsedCommand.argv.length - 1)} argument${parsedCommand.argv.length === 2 ? "" : "s"}`,
                    searchable: searchText,
                    icon: "utilities-terminal",
                    payload: parsedCommand.argv,
                    historyValue: searchText.trim()
                }]
            } else if (searchText.trim().length === 0) {
                candidates = historyCandidates("commands")
            }
        } else if (mode === "windows") {
            candidates = Hyprland.toplevels.values.slice(0, sourceLimit).filter(window => window.address.length > 0).map(window => {
                const details = window.lastIpcObject || ({})
                const appClass = details.class || details.initialClass || "Window"
                const workspaceName = window.workspace ? window.workspace.name : "unknown workspace"
                return {
                    kind: "window",
                    key: `window:${window.address}`,
                    label: window.title || appClass,
                    subtitle: `${appClass}  ·  ${workspaceName}${window.activated ? "  ·  active" : ""}`,
                    searchable: `${window.title || ""} ${appClass} ${workspaceName}`,
                    icon: "focus-windows",
                    payload: window.address
                }
            })
        } else if (mode === "web" && searchText.trim().length > 0) {
            candidates = [{
                kind: "web",
                key: `web:${searchText.trim()}`,
                label: searchText.trim(),
                subtitle: "Search with the default web browser",
                searchable: searchText,
                icon: "web-browser",
                payload: searchText.trim(),
                historyValue: searchText.trim()
            }]
        }

        return candidates
            .map(candidate => {
                const fuzzy = fuzzyScore(needle, normalize(candidate.searchable || candidate.label))
                const learned = historyScore(candidate.key)
                return { candidate, score: fuzzy + learned }
            })
            .filter(scored => scored.score > -1000000)
            .sort((left, right) => {
                if (left.score !== right.score)
                    return right.score - left.score

                const leftHistory = historyEntry(left.candidate.key)
                const rightHistory = historyEntry(right.candidate.key)
                if (leftHistory.lastUsed !== rightHistory.lastUsed)
                    return rightHistory.lastUsed - leftHistory.lastUsed

                const labelOrder = left.candidate.label.localeCompare(right.candidate.label)
                if (labelOrder !== 0)
                    return labelOrder
                return left.candidate.key.localeCompare(right.candidate.key)
            })
            .slice(0, Theme.launcherMaxResults)
            .map(scored => scored.candidate)
    }

    readonly property string emptyStateText: {
        if (activationError.length > 0)
            return activationError
        if (mode === "clipboard") {
            if (clipboardStatus === "loading")
                return "Loading clipboard history…"
            if (clipboardStatus === "error")
                return clipboardError || "Could not load clipboard history"
            return searchText.length > 0 ? "No matching clipboard entries" : "Clipboard history is empty"
        }
        if (mode === "files") {
            if (fileStatus === "loading")
                return "Indexing files…"
            if (fileStatus === "error")
                return fileError || "Could not index files"
            return searchText.length > 0 ? "No matching files" : "No files found"
        }
        if (mode === "calculator") {
            if (searchText.trim().length === 0)
                return "Type an expression, for example (12 + 8) / 4"
            return calculation.error || "Invalid expression"
        }
        if (mode === "commands") {
            if (searchText.trim().length === 0)
                return "Type a command; it runs only when you press Enter"
            return parsedCommand.error || "Invalid command"
        }
        if (mode === "windows")
            return searchText.length > 0 ? "No matching open windows" : "There are no open windows"
        if (mode === "web")
            return "Type a query; it opens only when you press Enter"
        return searchText.length > 0 ? "No matching applications" : "No applications found"
    }

    visible: PopupController.isOpen("launcher")
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
    WlrLayershell.namespace: "solitude-launcher"

    function normalize(value) {
        return String(value || "").trim().toLowerCase()
    }

    function fuzzyScore(needle, haystack) {
        if (needle.length === 0)
            return 0

        let score = 0
        let searchFrom = 0
        let previous = -2
        for (let index = 0; index < needle.length; ++index) {
            const found = haystack.indexOf(needle[index], searchFrom)
            if (found < 0)
                return -1000001

            score += 24
            if (found === 0)
                score += 32
            else if (" /._-".includes(haystack[found - 1]))
                score += 20
            if (found === previous + 1)
                score += 28
            score -= Math.min(found, 40)
            previous = found
            searchFrom = found + 1
        }

        score -= Math.min(haystack.length - needle.length, 80) * 0.25
        return score
    }

    function historyEntry(key) {
        const entries = historyAdapter.entries || ({})
        const value = entries[key]
        return value || ({ count: 0, lastUsed: 0 })
    }

    function historyScore(key) {
        const value = historyEntry(key)
        return Math.log(1 + (value.count || 0)) * 90 + (value.lastUsed || 0) / 1000000000000
    }

    function historyCandidates(historyMode) {
        const entries = historyAdapter.entries || ({})
        const values = []
        Object.keys(entries).forEach(key => {
            const entry = entries[key]
            if (entry.mode !== historyMode || !entry.value)
                return
            const parsed = parseCommand(entry.value)
            if (!parsed.ok)
                return
            values.push({
                kind: "command",
                key,
                label: entry.label || entry.value,
                subtitle: "Run from command history",
                searchable: entry.value,
                icon: "utilities-terminal",
                payload: parsed.argv,
                historyValue: entry.value
            })
        })
        return values.slice(0, 300)
    }

    function recordSuccessful(entry) {
        const oldEntries = historyAdapter.entries || ({})
        const nextEntries = ({})
        Object.keys(oldEntries).forEach(key => nextEntries[key] = oldEntries[key])
        const previous = nextEntries[entry.key] || ({ count: 0, lastUsed: 0 })
        nextEntries[entry.key] = {
            count: (previous.count || 0) + 1,
            lastUsed: Date.now(),
            mode: mode,
            label: entry.label,
            value: entry.historyValue || ""
        }

        const keys = Object.keys(nextEntries)
        if (keys.length > 300) {
            keys.sort((left, right) => (nextEntries[right].lastUsed || 0) - (nextEntries[left].lastUsed || 0))
            keys.slice(300).forEach(key => delete nextEntries[key])
        }
        historyAdapter.entries = nextEntries
    }

    function parseCommand(text) {
        if (text.length === 0)
            return { ok: false, error: "Enter a command" }

        const argv = []
        let current = ""
        let quote = ""
        let escaping = false
        let started = false
        for (let index = 0; index < text.length; ++index) {
            const character = text[index]
            if (escaping) {
                current += character
                escaping = false
                started = true
            } else if (character === "\\" && quote !== "'") {
                escaping = true
                started = true
            } else if (quote.length > 0) {
                if (character === quote)
                    quote = ""
                else
                    current += character
                started = true
            } else if (character === "'" || character === "\"") {
                quote = character
                started = true
            } else if (/\s/.test(character)) {
                if (started) {
                    argv.push(current)
                    current = ""
                    started = false
                }
            } else {
                current += character
                started = true
            }
        }

        if (escaping)
            return { ok: false, error: "A trailing backslash needs another character" }
        if (quote.length > 0)
            return { ok: false, error: "Close the quoted argument before running" }
        if (started)
            argv.push(current)
        if (argv.length === 0 || argv[0].length === 0)
            return { ok: false, error: "Enter an executable name" }
        return { ok: true, argv }
    }

    function calculate(text) {
        if (text.length === 0)
            return { ok: false, error: "" }

        const tokens = []
        let offset = 0
        while (offset < text.length) {
            if (/\s/.test(text[offset])) {
                ++offset
                continue
            }
            const number = text.slice(offset).match(/^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/)
            if (number) {
                tokens.push({ type: "number", value: Number(number[0]) })
                offset += number[0].length
                continue
            }
            const identifier = text.slice(offset).match(/^[A-Za-z]+/)
            if (identifier) {
                const name = identifier[0].toLowerCase()
                if (name === "pi")
                    tokens.push({ type: "number", value: Math.PI })
                else if (name === "e")
                    tokens.push({ type: "number", value: Math.E })
                else
                    return { ok: false, error: `Unknown value “${identifier[0]}”` }
                offset += identifier[0].length
                continue
            }
            if ("+-*/%^()".includes(text[offset])) {
                tokens.push({ type: text[offset], value: text[offset] })
                ++offset
                continue
            }
            return { ok: false, error: `Unexpected character “${text[offset]}”` }
        }

        let position = 0
        function primary() {
            const token = tokens[position]
            if (!token)
                throw new Error("Expected a number")
            if (token.type === "number") {
                ++position
                return token.value
            }
            if (token.type === "(") {
                ++position
                const value = addition()
                if (!tokens[position] || tokens[position].type !== ")")
                    throw new Error("Close the parenthesis")
                ++position
                return value
            }
            throw new Error("Expected a number or parenthesis")
        }
        function power() {
            const left = primary()
            if (tokens[position] && tokens[position].type === "^") {
                ++position
                return Math.pow(left, unary())
            }
            return left
        }
        function unary() {
            if (tokens[position] && tokens[position].type === "+") {
                ++position
                return unary()
            }
            if (tokens[position] && tokens[position].type === "-") {
                ++position
                return -unary()
            }
            return power()
        }
        function multiplication() {
            let value = unary()
            while (tokens[position] && "*/%".includes(tokens[position].type)) {
                const operator = tokens[position++].type
                const right = unary()
                if (operator === "*")
                    value *= right
                else if (operator === "/")
                    value /= right
                else
                    value %= right
            }
            return value
        }
        function addition() {
            let value = multiplication()
            while (tokens[position] && (tokens[position].type === "+" || tokens[position].type === "-")) {
                const operator = tokens[position++].type
                const right = multiplication()
                value = operator === "+" ? value + right : value - right
            }
            return value
        }

        try {
            const value = addition()
            if (position !== tokens.length)
                return { ok: false, error: "Unexpected token in expression" }
            if (!Number.isFinite(value))
                return { ok: false, error: "The result is not finite" }
            const rounded = Number(value.toPrecision(12))
            return { ok: true, value: rounded, text: String(rounded) }
        } catch (error) {
            return { ok: false, error: error.message }
        }
    }

    function resetCurrentResult() {
        Qt.callLater(() => results.currentIndex = results.count > 0 ? 0 : -1)
    }

    function setMode(nextIndex, clearQuery) {
        modeIndex = (nextIndex + modes.length) % modes.length
        activationError = ""
        resetCurrentResult()
        if (clearQuery) {
            searchText = ""
            query.text = ""
        }
        if (mode === "clipboard")
            loadClipboard()
        else if (mode === "files")
            loadFiles()
        else if (mode === "windows")
            Hyprland.refreshToplevels()
        Qt.callLater(() => query.forceActiveFocus())
    }

    function open(nextMode) {
        let nextIndex = modes.findIndex(item => item.id === (nextMode || "applications"))
        if (nextIndex < 0)
            nextIndex = 0
        PopupController.open("launcher")
        setMode(nextIndex, true)
    }

    function close() {
        PopupController.close("launcher")
        searchText = ""
        query.text = ""
        activationError = ""
    }

    function toggle() {
        if (visible)
            close()
        else
            open("applications")
    }

    function loadClipboard() {
        clipboardStatus = "loading"
        clipboardError = ""
        clipboardProc.running = false
        clipboardProc.running = true
    }

    function loadFiles() {
        if (fileStatus === "ready" || fileStatus === "loading")
            return
        fileStatus = "loading"
        fileError = ""
        fileProc.running = false
        fileProc.running = true
    }

    function activate(entry) {
        if (!entry)
            return
        activationError = ""

        if (entry.kind === "application") {
            Quickshell.execDetached({
                command: ["uwsm-app", "--"].concat(entry.payload.command),
                workingDirectory: entry.payload.workingDirectory
            })
        } else if (entry.kind === "clipboard") {
            Quickshell.execDetached(["clipboard-select", entry.payload])
        } else if (entry.kind === "file") {
            Quickshell.execDetached(["xdg-open", entry.payload])
        } else if (entry.kind === "calculator") {
            Quickshell.execDetached(["wl-copy", entry.payload])
        } else if (entry.kind === "command") {
            if (!entry.payload || entry.payload.length === 0) {
                activationError = "The command has no executable"
                return
            }
            Quickshell.execDetached(entry.payload)
        } else if (entry.kind === "window") {
            if (!/^0x[0-9a-f]+$/i.test(entry.payload)) {
                activationError = "That window is no longer available"
                return
            }
            Hyprland.dispatch(`focuswindow address:${entry.payload}`)
        } else if (entry.kind === "web") {
            Quickshell.execDetached(["xdg-open", webSearchBase + encodeURIComponent(entry.payload)])
        } else {
            activationError = "This result cannot be opened"
            return
        }

        recordSuccessful(entry)
        close()
    }

    function activateCurrent() {
        if (results.currentItem)
            activate(results.currentItem.entry)
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { launcher.toggle() }
        function clipboard(): void {
            if (launcher.visible && launcher.mode === "clipboard")
                launcher.close()
            else
                launcher.open("clipboard")
        }
        function applications(): void { launcher.open("applications") }
        function files(): void { launcher.open("files") }
        function calculator(): void { launcher.open("calculator") }
        function commands(): void { launcher.open("commands") }
        function windows(): void { launcher.open("windows") }
        function web(): void { launcher.open("web") }
        function close(): void { launcher.close() }
    }

    FileView {
        id: historyFile
        path: Quickshell.statePath("launcher-history.json")
        preload: true
        atomicWrites: true
        printErrors: false
        adapter: JsonAdapter {
            id: historyAdapter
            property var entries: ({})
        }
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                launcher.historyError = "History could not be loaded"
        }
        onSaveFailed: launcher.historyError = "History could not be saved"
    }

    Process {
        id: clipboardProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()
                launcher.clipboardEntries = output.length === 0 ? [] : output.split("\n").slice(0, launcher.sourceLimit)
                launcher.clipboardStatus = "ready"
                launcher.resetCurrentResult()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    launcher.clipboardError = text.trim().split("\n")[0]
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                launcher.clipboardStatus = "error"
                if (launcher.clipboardError.length === 0)
                    launcher.clipboardError = `Clipboard command failed (${exitCode})`
            }
        }
    }

    Process {
        id: fileProc
        command: [
            "find", launcher.homeDirectory, "-xdev", "-maxdepth", "4", "-type", "f",
            "-not", "-path", "*/.cache/*",
            "-not", "-path", "*/.local/share/Trash/*",
            "-print"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()
                launcher.fileEntries = output.length === 0 ? [] : output.split("\n").slice(0, launcher.sourceLimit)
                launcher.fileStatus = "ready"
                launcher.resetCurrentResult()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    launcher.fileError = text.trim().split("\n")[0]
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                launcher.fileStatus = "error"
                if (launcher.fileError.length === 0)
                    launcher.fileError = `File index failed (${exitCode})`
            }
        }
    }

    ScriptModel {
        id: resultModel
        values: launcher.filteredValues
    }

    MouseArea {
        anchors.fill: parent
        onClicked: launcher.close()
    }

    PanelCard {
        id: card
        anchors.centerIn: parent
        width: Math.min(Theme.launcherWidth, launcher.width - 80)
        height: Math.min(Theme.launcherHeight, launcher.height - 120)

        MouseArea { anchors.fill: parent }

        Rectangle {
            id: searchBox
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 20
            }
            height: 62
            radius: Theme.radiusMedium
            color: Theme.withAlpha(Theme.backgroundDark, 0.98)
            border.color: query.activeFocus ? Theme.accent : Theme.backgroundDarker
            border.width: Theme.borderWidth

            Text {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 18
                }
                text: launcher.modes[launcher.modeIndex].shortLabel
                color: Theme.accent
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
                font.weight: Font.DemiBold
            }

            TextInput {
                id: query
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 76
                    rightMargin: 18
                }
                color: Theme.foreground
                selectionColor: Theme.selection
                selectedTextColor: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontBody + 3
                clip: true
                focus: launcher.visible

                onTextChanged: {
                    launcher.searchText = text
                    launcher.activationError = ""
                    launcher.resetCurrentResult()
                }

                Keys.onPressed: event => {
                    if ((event.modifiers & Qt.AltModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_7) {
                        launcher.setMode(event.key - Qt.Key_1, true)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) {
                        launcher.setMode(launcher.modeIndex - 1, true)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                        launcher.setMode(launcher.modeIndex + 1, true)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        if (results.count > 0)
                            results.currentIndex = Math.min(results.count - 1, results.currentIndex + 1)
                        results.positionViewAtIndex(results.currentIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        results.currentIndex = Math.max(0, results.currentIndex - 1)
                        results.positionViewAtIndex(results.currentIndex, ListView.Contain)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        launcher.activateCurrent()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        launcher.close()
                        event.accepted = true
                    }
                }
            }

            Text {
                anchors {
                    left: query.left
                    verticalCenter: parent.verticalCenter
                }
                visible: query.text.length === 0
                text: launcher.modes[launcher.modeIndex].hint
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontBody + 3
            }
        }

        Row {
            id: modeBar
            anchors {
                top: searchBox.bottom
                left: parent.left
                right: parent.right
                topMargin: 10
                leftMargin: 20
                rightMargin: 20
            }
            spacing: 5

            Repeater {
                model: launcher.modes
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: (modeBar.width - modeBar.spacing * (launcher.modes.length - 1)) / launcher.modes.length
                    height: 28
                    radius: Theme.radiusSmall
                    color: index === launcher.modeIndex ? Theme.selection : modeHover.containsMouse ? Theme.backgroundDark : "transparent"
                    border.color: index === launcher.modeIndex ? Theme.accent : Theme.border
                    border.width: Theme.borderWidth

                    Text {
                        anchors.centerIn: parent
                        text: `${index + 1} ${parent.modelData.label}`
                        color: index === launcher.modeIndex ? Theme.foreground : Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: index === launcher.modeIndex ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: modeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: launcher.setMode(parent.index, true)
                    }
                }
            }
        }

        ListView {
            id: results
            anchors {
                top: modeBar.bottom
                left: parent.left
                right: parent.right
                bottom: footer.top
                topMargin: 9
                leftMargin: 16
                rightMargin: 16
                bottomMargin: 8
            }
            model: resultModel
            spacing: 3
            clip: true
            currentIndex: -1

            delegate: Rectangle {
                id: result
                required property var modelData
                required property int index
                property var entry: modelData
                width: results.width
                height: 58
                radius: Theme.radiusMedium
                color: ListView.isCurrentItem ? Theme.selection : resultHover.containsMouse ? Theme.backgroundDark : "transparent"

                IconImage {
                    id: resultIcon
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                    }
                    implicitWidth: 30
                    implicitHeight: 30
                    source: result.modelData.icon.length > 0 ? Quickshell.iconPath(result.modelData.icon, true) : ""
                }

                Text {
                    anchors.centerIn: resultIcon
                    visible: resultIcon.source.toString().length === 0
                    text: result.modelData.label.length > 0 ? result.modelData.label.charAt(0).toUpperCase() : "?"
                    color: Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontBody + 2
                    font.weight: Font.DemiBold
                }

                Column {
                    anchors {
                        left: parent.left
                        right: shortcut.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 56
                        rightMargin: 10
                    }
                    spacing: 2

                    Text {
                        width: parent.width
                        text: result.modelData.label
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontBody
                        font.weight: result.ListView.isCurrentItem ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: result.modelData.subtitle
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        elide: Text.ElideMiddle
                    }
                }

                Text {
                    id: shortcut
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: 12
                    }
                    text: result.index === 0 ? "↵" : String(result.index + 1)
                    color: Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontCaption + 1
                }

                MouseArea {
                    id: resultHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: results.currentIndex = result.index
                    onClicked: launcher.activate(result.modelData)
                }
            }
        }

        Text {
            anchors.centerIn: results
            width: results.width - 40
            visible: results.count === 0
            text: launcher.emptyStateText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: launcher.activationError.length > 0 || launcher.clipboardStatus === "error" || launcher.fileStatus === "error" ? Theme.error : Theme.muted
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontBody
        }

        Item {
            id: footer
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: 20
                rightMargin: 20
            }
            height: 36

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: launcher.historyError.length > 0
                    ? launcher.historyError
                    : `${results.count} ${results.count === 1 ? "result" : "results"}  ·  ${launcher.modes[launcher.modeIndex].label}`
                color: launcher.historyError.length > 0 ? Theme.warning : Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "tab mode   alt+1…7 direct   ↑↓ navigate   ↵ activate   esc close"
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
            }
        }
    }
}
