import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
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

    visible: PopupController.isOpen("keybinds")
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
    WlrLayershell.namespace: "solitude-keybinds"

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

    function open() {
        PopupController.open("keybinds")
        loadError = ""
        copiedStatus = ""
        refresh()
        Qt.callLater(() => search.forceActiveFocus())
    }

    function close() {
        PopupController.close("keybinds")
        practiceMode = false
        practiceStatus = ""
        searchText = ""
        search.text = ""
    }

    function toggle() {
        if (visible)
            close()
        else
            open()
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
        keyboardScope.forceActiveFocus()
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

    IpcHandler {
        target: "keybinds"
        function toggle(): void { overlay.toggle() }
        function searchBindings(text: string): void {
            if (!overlay.visible)
                overlay.open()
            search.text = text
            Qt.callLater(() => search.forceActiveFocus())
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
        running: overlay.visible && !overlay.practiceMode
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

    MouseArea {
        anchors.fill: parent
        onClicked: overlay.close()
    }

    FocusScope {
        id: keyboardScope
        anchors.fill: parent
        focus: overlay.visible

        Keys.onPressed: event => {
            if (overlay.practiceMode) {
                if (event.key === Qt.Key_Escape) {
                    overlay.practiceMode = false
                    overlay.practiceStatus = ""
                } else {
                    overlay.handlePractice(event)
                }
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Escape) {
                overlay.close()
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                overlay.selectedIndex = Math.min(overlay.filteredEntries.length - 1, overlay.selectedIndex + 1)
                bindings.positionViewAtIndex(overlay.selectedIndex, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                overlay.selectedIndex = Math.max(0, overlay.selectedIndex - 1)
                bindings.positionViewAtIndex(overlay.selectedIndex, ListView.Contain)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                overlay.startPractice()
                event.accepted = true
            } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier) && overlay.selectedEntry) {
                overlay.copyText(overlay.selectedEntry.chord, "Shortcut copied")
                event.accepted = true
            }
        }

        PanelCard {
            id: card
            anchors.centerIn: parent
            width: Math.min(Theme.keybindsWidth, overlay.width - 80)
            height: Math.min(Theme.keybindsHeight, overlay.height - 100)

            MouseArea { anchors.fill: parent }

            Text {
                id: title
                anchors { top: parent.top; left: parent.left; topMargin: 22; leftMargin: 28 }
                text: "Shortcut explorer"
                color: Theme.foreground
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
            }

            Text {
                anchors { baseline: title.baseline; right: parent.right; rightMargin: 28 }
                text: `${overlay.filteredEntries.length}/${overlay.entries.length} bindings  ·  ${overlay.conflictCount} conflicts  ·  ${overlay.recentCount} recent`
                color: overlay.conflictCount > 0 ? Theme.warning : Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
            }

            Rectangle {
                id: searchBox
                anchors { top: title.bottom; left: parent.left; right: parent.right; topMargin: 14; leftMargin: 28; rightMargin: 28 }
                height: 46
                radius: Theme.radiusSmall
                color: Theme.backgroundDark
                border.color: search.activeFocus ? Theme.accent : Theme.border
                border.width: Theme.borderWidth

                TextInput {
                    id: search
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.foreground
                    selectionColor: Theme.selection
                    selectedTextColor: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontBody
                    focus: overlay.visible
                    onTextChanged: {
                        overlay.searchText = text
                        overlay.selectedIndex = 0
                    }
                }

                Text {
                    anchors { left: search.left; verticalCenter: parent.verticalCenter }
                    visible: search.text.length === 0
                    text: "Search action, category, or chord…"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontBody
                }
            }

            Rectangle {
                id: preview
                anchors { top: searchBox.bottom; right: parent.right; bottom: footer.top; topMargin: 12; rightMargin: 24; bottomMargin: 12 }
                width: 450
                radius: Theme.radiusMedium
                color: Theme.backgroundDark
                border.color: overlay.selectedEntry && overlay.selectedEntry.conflict ? Theme.warning : Theme.backgroundDarker
                border.width: Theme.borderWidth

                Column {
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                    spacing: 14

                    Text {
                        width: parent.width
                        text: overlay.practiceMode ? "PRACTICE" : overlay.selectedEntry ? overlay.selectedEntry.category.toUpperCase() : "SHORTCUT"
                        color: overlay.practiceMode ? Theme.success : Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                    }

                    Text {
                        width: parent.width
                        text: overlay.practiceMode && overlay.practiceEntry ? overlay.practiceEntry.action
                            : overlay.selectedEntry ? overlay.selectedEntry.action : "No shortcut selected"
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }

                    Flow {
                        width: parent.width
                        spacing: 7
                        Repeater {
                            model: overlay.practiceMode && overlay.practiceEntry ? overlay.practiceEntry.tokens
                                : overlay.selectedEntry ? overlay.selectedEntry.tokens : []
                            Rectangle {
                                required property var modelData
                                width: keyText.implicitWidth + 20
                                height: 36
                                radius: Theme.radiusSmall
                                color: Theme.selection
                                border.color: Theme.accent
                                border.width: Theme.borderWidth
                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    color: Theme.foreground
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontCaption + 1
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }

                    Text {
                        visible: overlay.practiceMode
                        width: parent.width
                        text: overlay.practiceStatus
                        color: overlay.practiceStatus === "Correct" ? Theme.success : Theme.warning
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontBody
                        wrapMode: Text.Wrap
                    }

                    Text {
                        visible: !overlay.practiceMode && overlay.selectedEntry && overlay.selectedEntry.conflict
                        width: parent.width
                        text: overlay.selectedEntry ? `${overlay.selectedEntry.conflictCount} actions use this chord` : ""
                        color: Theme.warning
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontBody
                    }

                    Text {
                        visible: !overlay.practiceMode && overlay.selectedEntry
                        width: parent.width
                        text: overlay.selectedEntry
                            ? `${overlay.selectedEntry.dispatcher}${overlay.selectedEntry.argument ? `  ·  ${overlay.selectedEntry.argument}` : ""}` : ""
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        visible: !overlay.practiceMode && overlay.selectedEntry && !overlay.selectedEntry.mouse
                        width: parent.width
                        height: 36
                        radius: Theme.radiusSmall
                        color: practiceHover.containsMouse ? Theme.selection : "transparent"
                        border.color: Theme.border
                        border.width: Theme.borderWidth
                        Text {
                            anchors.centerIn: parent
                            text: "Practice this chord"
                            color: Theme.foregroundSoft
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: practiceHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: overlay.startPractice()
                        }
                    }

                    Rectangle {
                        visible: !overlay.practiceMode && overlay.selectedEntry
                        width: parent.width
                        height: 36
                        radius: Theme.radiusSmall
                        color: copyHover.containsMouse ? Theme.selection : "transparent"
                        border.color: Theme.border
                        border.width: Theme.borderWidth
                        Text {
                            anchors.centerIn: parent
                            text: "Copy shortcut"
                            color: Theme.foregroundSoft
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: copyHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: overlay.copyText(overlay.selectedEntry.chord, "Shortcut copied")
                        }
                    }
                }
            }

            ListView {
                id: bindings
                anchors { top: searchBox.bottom; left: parent.left; right: preview.left; bottom: footer.top; topMargin: 12; leftMargin: 24; rightMargin: 12; bottomMargin: 12 }
                model: bindingModel
                spacing: 4
                clip: true
                currentIndex: overlay.selectedIndex

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: bindings.width
                    height: 58
                    radius: Theme.radiusSmall
                    color: index === overlay.selectedIndex ? Theme.selection : rowHover.containsMouse ? Theme.backgroundDark : "transparent"
                    border.color: modelData.conflict ? Theme.warning : index === overlay.selectedIndex ? Theme.accent : "transparent"
                    border.width: Theme.borderWidth

                    Column {
                        anchors { left: parent.left; right: chord.left; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                        spacing: 3
                        Text {
                            width: parent.width
                            text: `${row.modelData.category}${row.modelData.recent ? "  ·  NEW" : ""}`
                            color: row.modelData.recent ? Theme.accent : Theme.muted
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: row.modelData.action
                            color: Theme.foreground
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontBody
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        id: chord
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                        width: 230
                        horizontalAlignment: Text.AlignRight
                        text: row.modelData.chord
                        color: row.modelData.conflict ? Theme.warning : Theme.foregroundSoft
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                        elide: Text.ElideLeft
                    }

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: overlay.selectedIndex = row.index
                        onClicked: overlay.selectedIndex = row.index
                        onDoubleClicked: overlay.startPractice()
                    }
                }
            }

            Text {
                anchors.centerIn: bindings
                visible: overlay.loadError.length > 0 || overlay.filteredEntries.length === 0
                width: bindings.width - 30
                text: overlay.loadError.length > 0 ? overlay.loadError : "No matching shortcuts"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: overlay.loadError.length > 0 ? Theme.error : Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontBody
            }

            Item {
                id: footer
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 28; rightMargin: 28 }
                height: 46
                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.backgroundDarker }
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: overlay.copiedStatus.length > 0 ? overlay.copiedStatus : "↑↓ navigate  ·  Enter practice  ·  Ctrl+C copy"
                    color: overlay.copiedStatus.length > 0 ? Theme.success : Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: overlay.practiceMode ? "esc leave practice" : "esc or click outside to close"
                    color: Theme.muted
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                }
            }
        }
    }
}
