import Quickshell
import Quickshell.Io
import QtQuick
import qs.ui

// Shortcut explorer: searchable Hyprland binds grouped by category, a detail
// pane with key caps, and a practice mode that checks the pressed chord.
PopupPanel {
    id: overlay

    property var entries: []
    property string searchText: ""
    property string loadError: ""
    property int selectedIndex: 0
    property bool practiceMode: false
    property string practiceStatus: ""
    property int practiceIndex: -1
    property string copiedStatus: ""

    readonly property var filteredEntries: {
        const needle = normalize(searchText)
        return entries
            .map(entry => ({ entry, score: fuzzyScore(needle, normalize(`${entry.category} ${entry.action} ${entry.chord}`)) }))
            .filter(value => value.score > -1000000)
            .sort((left, right) => {
                if (needle.length > 0 && left.score !== right.score)
                    return right.score - left.score
                const categoryOrder = left.entry.category.localeCompare(right.entry.category)
                return categoryOrder === 0 ? left.entry.action.localeCompare(right.entry.action) : categoryOrder
            })
            .map(value => value.entry)
    }
    readonly property var selectedEntry: filteredEntries.length > 0
        ? filteredEntries[Math.max(0, Math.min(filteredEntries.length - 1, selectedIndex))]
        : null
    readonly property var practiceEntry: practiceIndex >= 0 && practiceIndex < filteredEntries.length
        ? filteredEntries[practiceIndex]
        : null
    readonly property int conflictCount: entries.filter(entry => entry.conflict).length
    readonly property int recentCount: entries.filter(entry => entry.recent).length

    readonly property bool grouped: normalize(searchText).length === 0
    readonly property var categoryCounts: {
        const counts = ({})
        filteredEntries.forEach(entry => counts[entry.category] = (counts[entry.category] || 0) + 1)
        return counts
    }
    readonly property var shownEntry: practiceMode && practiceEntry ? practiceEntry : selectedEntry
    readonly property int screenHeight: screen ? screen.height : 900
    readonly property int sheetHeight: Math.min(Theme.keybindsHeight, screenHeight - 100)

    name: "keybinds"
    ipcEnabled: false
    placement: "center"
    cardWidth: Theme.keybindsWidth
    topOffset: Math.max(Theme.outerMargin + Theme.barHeight + Theme.shellGap,
        Math.round((screenHeight - sheetHeight) / 2))
    scrollable: false
    title: "Shortcuts"
    subtitle: `${filteredEntries.length}/${entries.length} bindings · ${conflictCount} conflicts · ${recentCount} recent`

    onOpening: {
        practiceMode = false
        practiceStatus = ""
        searchText = ""
        search.text = ""
        loadError = ""
        copiedStatus = ""
        refresh()
        Qt.callLater(() => search.forceInputFocus())
    }

    onKeyPressed: event => overlay.handleKey(event)

    function normalize(value) {
        return String(value || "").trim().toLowerCase()
    }

    function fuzzyScore(needle, haystack) {
        if (needle.length === 0)
            return 0
        let score = 0
        let cursor = 0
        let previous = -2
        for (let index = 0; index < needle.length; ++index) {
            const found = haystack.indexOf(needle[index], cursor)
            if (found < 0)
                return -1000001
            score += 20
            if (found === 0 || " +/._-".includes(haystack[found - 1]))
                score += 24
            if (found === previous + 1)
                score += 28
            score -= Math.min(found, 40)
            previous = found
            cursor = found + 1
        }
        return score - Math.min(haystack.length - needle.length, 80) * 0.2
    }

    function formatKey(bind) {
        const modifiers = []
        const mask = bind.modmask || 0
        if (mask & 64) modifiers.push("Super")
        if (mask & 4) modifiers.push("Ctrl")
        if (mask & 8) modifiers.push("Alt")
        if (mask & 1) modifiers.push("Shift")
        const names = {
            SPACE: "Space", PRINT: "Print", ESCAPE: "Escape", RETURN: "Enter",
            LEFT: "←", RIGHT: "→", UP: "↑", DOWN: "↓",
            "mouse:272": "Mouse 1", "mouse:273": "Mouse 2"
        }
        modifiers.push(names[bind.key] || bind.key)
        return modifiers.join(" + ")
    }

    function parseBindings(text) {
        try {
            const parsed = JSON.parse(text)
            const described = parsed.filter(bind => bind.has_description && bind.description.length > 0)
            const chordCounts = ({})
            described.forEach(bind => {
                const chord = formatKey(bind)
                chordCounts[chord] = (chordCounts[chord] || 0) + 1
            })

            const known = knownAdapter.firstSeen || ({})
            const nextKnown = ({})
            Object.keys(known).forEach(key => nextKnown[key] = known[key])
            const bootstrap = Object.keys(known).length === 0
            const now = Date.now()
            const mapped = described.map(bind => {
                const separator = bind.description.indexOf(" · ")
                const category = separator === -1 ? "Other" : bind.description.slice(0, separator)
                const action = separator === -1 ? bind.description : bind.description.slice(separator + 3)
                const chord = formatKey(bind)
                const id = `${bind.modmask || 0}:${bind.key}:${bind.description}`
                if (!nextKnown[id])
                    nextKnown[id] = bootstrap ? 1 : now
                const firstSeen = nextKnown[id]
                return {
                    id,
                    category,
                    action,
                    chord,
                    tokens: chord.split(" + "),
                    modmask: bind.modmask || 0,
                    rawKey: bind.key || "",
                    dispatcher: bind.dispatcher || "",
                    argument: bind.arg || "",
                    conflict: chordCounts[chord] > 1,
                    conflictCount: chordCounts[chord] || 1,
                    recent: firstSeen > 1 && now - firstSeen < 7 * 24 * 60 * 60 * 1000,
                    mouse: String(bind.key || "").startsWith("mouse:")
                }
            })
            knownAdapter.firstSeen = nextKnown
            entries = mapped
            selectedIndex = 0
            practiceIndex = -1
            practiceMode = false
            practiceStatus = ""
        } catch (error) {
            entries = []
            loadError = `Could not read Hyprland keybinds: ${error}`
        }
    }

    function refresh() {
        if (!bindsProc.running)
            bindsProc.running = true
    }

    function copyText(value, message) {
        Quickshell.execDetached(["wl-copy", String(value)])
        copiedStatus = message
        copyStatusTimer.restart()
    }

    function startPractice() {
        if (!selectedEntry || selectedEntry.mouse)
            return
        practiceMode = true
        practiceIndex = Math.max(0, selectedIndex)
        practiceStatus = "Press the displayed chord"
        // Take focus off the search field so every key reaches the checker.
        search.input.focus = false
        keyScope.forceActiveFocus()
    }

    function nextPractice() {
        const candidates = filteredEntries
        if (candidates.length === 0)
            return
        let next = practiceIndex
        for (let offset = 1; offset <= candidates.length; ++offset) {
            const candidate = (practiceIndex + offset) % candidates.length
            if (!candidates[candidate].mouse) {
                next = candidate
                break
            }
        }
        practiceIndex = next
        selectedIndex = next
        practiceStatus = "Press the displayed chord"
    }

    function eventMask(event) {
        let mask = 0
        if (event.modifiers & Qt.MetaModifier) mask |= 64
        if (event.modifiers & Qt.ControlModifier) mask |= 4
        if (event.modifiers & Qt.AltModifier) mask |= 8
        if (event.modifiers & Qt.ShiftModifier) mask |= 1
        return mask
    }

    function eventKey(event) {
        const names = ({
            [Qt.Key_Space]: "SPACE", [Qt.Key_Print]: "PRINT", [Qt.Key_Escape]: "ESCAPE",
            [Qt.Key_Return]: "RETURN", [Qt.Key_Enter]: "RETURN",
            [Qt.Key_Left]: "LEFT", [Qt.Key_Right]: "RIGHT", [Qt.Key_Up]: "UP", [Qt.Key_Down]: "DOWN"
        })
        if (names[event.key])
            return names[event.key]
        return String(event.text || "").toUpperCase()
    }

    function handlePractice(event) {
        if (!practiceEntry)
            return
        if (eventKey(event) === practiceEntry.rawKey.toUpperCase() && eventMask(event) === practiceEntry.modmask) {
            practiceStatus = "Correct"
            practiceAdvanceTimer.restart()
        } else if (![Qt.Key_Meta, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Shift].includes(event.key)) {
            practiceStatus = "Not quite — try the displayed chord"
        }
    }

    function leavePractice() {
        practiceMode = false
        practiceStatus = ""
        Qt.callLater(() => search.forceInputFocus())
    }

    function handleKey(event) {
        if (practiceMode) {
            if (event.key === Qt.Key_Escape)
                leavePractice()
            else
                handlePractice(event)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Escape) {
            close()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            selectedIndex = Math.min(filteredEntries.length - 1, selectedIndex + 1)
            bindings.positionViewAtIndex(selectedIndex, ListView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            selectedIndex = Math.max(0, selectedIndex - 1)
            bindings.positionViewAtIndex(selectedIndex, ListView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            startPractice()
            event.accepted = true
        } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier) && selectedEntry) {
            copyText(selectedEntry.chord, "Shortcut copied")
            event.accepted = true
        }
    }

    IpcHandler {
        target: "keybinds"

        function open(): void { overlay.open() }
        function toggle(): void { overlay.toggle() }
        function searchBindings(text: string): void {
            if (!overlay.shown)
                overlay.open()
            search.text = text
            Qt.callLater(() => search.forceInputFocus())
        }
        function state(): string {
            return JSON.stringify({
                total: overlay.entries.length,
                filtered: overlay.filteredEntries.length,
                conflicts: overlay.conflictCount,
                recent: overlay.recentCount,
                selected: overlay.selectedEntry ? overlay.selectedEntry.action : "",
                chord: overlay.selectedEntry ? overlay.selectedEntry.chord : "",
                practice: overlay.practiceMode
            })
        }
        function practice(): void { overlay.startPractice() }
        function copySelected(): void {
            if (overlay.selectedEntry)
                overlay.copyText(overlay.selectedEntry.chord, "Shortcut copied")
        }
        function close(): void { overlay.close() }
    }

    FileView {
        path: Quickshell.statePath("keybind-first-seen.json")
        preload: true
        atomicWrites: true
        printErrors: false
        adapter: JsonAdapter {
            id: knownAdapter
            property var firstSeen: ({})
        }
        onAdapterUpdated: writeAdapter()
    }

    Process {
        id: bindsProc
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: overlay.parseBindings(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    overlay.loadError = text.trim().split("\n")[0]
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && overlay.loadError.length === 0)
                overlay.loadError = `hyprctl binds failed (${exitCode})`
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: overlay.shown && !overlay.practiceMode
        onTriggered: overlay.refresh()
    }

    Timer {
        id: copyStatusTimer
        interval: 1600
        onTriggered: overlay.copiedStatus = ""
    }

    Timer {
        id: practiceAdvanceTimer
        interval: 650
        onTriggered: overlay.nextPractice()
    }

    ScriptModel {
        id: bindingModel
        values: overlay.filteredEntries
    }

    headerTrailing: [
        Chip {
            visible: overlay.conflictCount > 0
            interactive: false
            icon: "triangle-alert"
            tone: "warning"
            text: `${overlay.conflictCount} ${overlay.conflictCount === 1 ? "conflict" : "conflicts"}`
        }
    ]

    footer: [
        Item {
            width: parent.width
            height: 16

            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: overlay.copiedStatus.length > 0 ? overlay.copiedStatus.toLowerCase() : "↑↓ navigate · enter practice · ctrl+c copy"
                variant: "numeric"
                font.pixelSize: Theme.fontSize.caption
                font.weight: Font.Normal
                tone: overlay.copiedStatus.length > 0 ? "success" : "faint"
            }

            Label {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: overlay.practiceMode ? "esc leave practice" : "esc or click outside to close"
                variant: "numeric"
                font.pixelSize: Theme.fontSize.caption
                font.weight: Font.Normal
                tone: "faint"
            }
        }
    ]

    Item {
        id: stage

        width: parent.width
        height: overlay.sheetHeight - overlay.padding * 2 - overlay.card.headerHeight - overlay.card.footerHeight

        TextField {
            id: search

            // Runs before the input, so arrows, Delete and Ctrl+C drive the list.
            onKeyPressed: event => overlay.handleKey(event)

            anchors {
                top: parent.top
                left: parent.left
                right: previewDivider.left
                rightMargin: Theme.space.xl
            }
            icon: "search"
            placeholder: "Search action, category, or chord…"
            onTextChanged: {
                overlay.searchText = text
                overlay.selectedIndex = 0
            }
        }

        ListView {
            id: bindings

            anchors {
                top: search.bottom
                left: parent.left
                right: previewDivider.left
                bottom: parent.bottom
                topMargin: Theme.space.md
                rightMargin: Theme.space.lg
            }
            model: bindingModel
            spacing: 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: overlay.selectedIndex

            delegate: Item {
                id: binding

                required property var modelData
                required property int index
                readonly property bool current: index === overlay.selectedIndex
                readonly property bool hasHeader: overlay.grouped
                    && (index === 0 || overlay.filteredEntries[index - 1].category !== modelData.category)

                width: bindings.width
                height: row.height + (hasHeader ? header.height + header.anchors.topMargin + Theme.space.xs : 0)

                SectionHeader {
                    id: header

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: binding.index === 0 ? Theme.space.xs : Theme.space.lg
                        leftMargin: Theme.space.sm
                    }
                    visible: binding.hasHeader
                    text: binding.modelData.category
                    trailing: String(overlay.categoryCounts[binding.modelData.category] || "")
                }

                Item {
                    id: row

                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: 40

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.medium
                        color: binding.current ? Theme.selected : rowMouse.containsMouse ? Theme.hover : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.motion.fast
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: binding.current
                        width: 2
                        height: parent.height - Theme.space.lg
                        radius: 1
                        color: Theme.accent
                    }

                    Row {
                        anchors {
                            left: parent.left
                            leftMargin: Theme.space.md
                            verticalCenter: parent.verticalCenter
                        }
                        width: Math.max(0, combo.x - Theme.space.md * 2)
                        spacing: Theme.space.sm

                        Label {
                            id: actionLabel

                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width - (categoryTag.visible ? categoryTag.implicitWidth + parent.spacing : 0)
                                - (newChip.visible ? newChip.implicitWidth + parent.spacing : 0)
                                - (conflictIcon.visible ? conflictIcon.implicitWidth + parent.spacing : 0))
                            text: binding.modelData.action
                            tone: binding.current ? "base" : "soft"
                            font.weight: binding.current ? Font.Medium : Font.Normal
                        }

                        Label {
                            id: categoryTag

                            anchors.verticalCenter: parent.verticalCenter
                            visible: !overlay.grouped
                            text: binding.modelData.category
                            variant: "label"
                            tone: "faint"
                        }

                        Chip {
                            id: newChip

                            anchors.verticalCenter: parent.verticalCenter
                            visible: binding.modelData.recent
                            implicitHeight: 18
                            interactive: false
                            tone: "accent"
                            text: "new"
                        }

                        Icon {
                            id: conflictIcon

                            anchors.verticalCenter: parent.verticalCenter
                            visible: binding.modelData.conflict
                            name: "triangle-alert"
                            size: 13
                            color: Theme.warning
                        }
                    }

                    KeyCombo {
                        id: combo

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space.md
                        anchors.verticalCenter: parent.verticalCenter
                        tokens: binding.modelData.tokens
                        tone: binding.modelData.conflict ? "warning" : binding.current ? "base" : "soft"
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: overlay.selectedIndex = binding.index
                        onClicked: overlay.selectedIndex = binding.index
                        onDoubleClicked: overlay.startPractice()
                    }
                }
            }
        }

        Label {
            anchors.centerIn: bindings
            visible: overlay.loadError.length > 0 || overlay.filteredEntries.length === 0
            width: bindings.width - Theme.space.xxl * 2
            text: overlay.loadError.length > 0 ? overlay.loadError : "No matching shortcuts"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            tone: overlay.loadError.length > 0 ? "danger" : "faint"
        }

        Hairline {
            id: previewDivider

            anchors {
                top: parent.top
                bottom: parent.bottom
                right: preview.left
                rightMargin: Theme.space.xl
            }
            vertical: true
        }

        Column {
            id: preview

            anchors {
                top: parent.top
                right: parent.right
                topMargin: Theme.space.xs
            }
            width: 420
            spacing: Theme.space.lg

            Label {
                width: parent.width
                text: overlay.practiceMode ? "Practice" : overlay.selectedEntry ? overlay.selectedEntry.category : "Shortcut"
                variant: "label"
                tone: overlay.practiceMode ? "success" : "accent"
            }

            Label {
                width: parent.width
                text: overlay.shownEntry ? overlay.shownEntry.action : "No shortcut selected"
                variant: "title"
                font.family: Theme.fontDisplay
                font.weight: Font.Medium
                wrapMode: Text.Wrap
            }

            KeyCombo {
                width: parent.width
                large: true
                tokens: overlay.shownEntry ? overlay.shownEntry.tokens : []
                tone: !overlay.practiceMode && overlay.shownEntry && overlay.shownEntry.conflict ? "warning" : "base"
            }

            Label {
                visible: overlay.practiceMode
                width: parent.width
                text: overlay.practiceStatus
                tone: overlay.practiceStatus === "Correct" ? "success" : "warning"
                wrapMode: Text.Wrap
            }

            Row {
                visible: !overlay.practiceMode && overlay.selectedEntry !== null && overlay.selectedEntry.conflict
                width: parent.width
                spacing: Theme.space.sm

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "triangle-alert"
                    size: 14
                    color: Theme.warning
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: overlay.selectedEntry ? `${overlay.selectedEntry.conflictCount} actions use this chord` : ""
                    tone: "warning"
                }
            }

            Column {
                visible: !overlay.practiceMode && overlay.selectedEntry !== null
                width: parent.width
                spacing: Theme.space.sm

                SectionHeader {
                    width: parent.width
                    text: "Dispatcher"
                }

                Label {
                    width: parent.width
                    text: overlay.selectedEntry
                        ? `${overlay.selectedEntry.dispatcher}${overlay.selectedEntry.argument ? ` · ${overlay.selectedEntry.argument}` : ""}` : ""
                    variant: "numeric"
                    font.pixelSize: Theme.fontSize.caption
                    font.weight: Font.Normal
                    tone: "faint"
                    wrapMode: Text.WrapAnywhere
                }
            }

            Row {
                visible: !overlay.practiceMode && overlay.selectedEntry !== null
                spacing: Theme.space.sm

                Button {
                    visible: overlay.selectedEntry !== null && !overlay.selectedEntry.mouse
                    variant: "primary"
                    icon: "keyboard"
                    text: "Practice this chord"
                    onClicked: overlay.startPractice()
                }

                Button {
                    icon: "copy"
                    text: "Copy shortcut"
                    onClicked: overlay.copyText(overlay.selectedEntry.chord, "Shortcut copied")
                }
            }

            Button {
                visible: overlay.practiceMode
                icon: "x"
                text: "Leave practice"
                onClicked: overlay.leavePractice()
            }
        }
    }
}
