import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import qs.ui

// Centered application launcher. With an empty query it shows Frequent apps
// and top-level categories you can drill into; typing searches every app
// (fuzzy, ranked by launch history). A preview pane lists the selected app's
// actions (open, desktop actions, copy, forget). Categories come from the
// app-categorize service's cache (see quickshell.nix), with keyword
// heuristics for apps it hasn't sorted yet.
PopupPanel {
    id: launcher

    property string searchText: ""
    property string activationError: ""
    property string historyError: ""
    property int actionIndex: 0
    // Category being browsed; empty at the top level.
    property string openCategory: ""
    // desktop id -> { category, fingerprint }, from app-categorize.
    property var categoryCache: ({})
    property double lastCategorizeRequest: 0
    readonly property int sourceLimit: 2500
    readonly property var selectedEntry: results.currentItem ? results.currentItem.entry : null
    readonly property var selectedActions: actionsFor(selectedEntry)
    readonly property var currentAction: selectedActions.length > 0
        ? selectedActions[Math.max(0, Math.min(selectedActions.length - 1, actionIndex))]
        : null

    readonly property var categories: AppCategories.list.concat([
        { name: "Other", icon: "shapes", description: "everything else" }
    ])

    readonly property var filteredValues: {
        const needle = normalize(searchText)
        const apps = DesktopEntries.applications.values.slice(0, sourceLimit).map(entry => {
            const command = entry.command || []
            const stableId = entry.id || `${entry.name || "application"}|${command.join("\u001f")}`
            const keywords = Array.isArray(entry.keywords) ? entry.keywords.join(" ") : String(entry.keywords || "")
            const categories = Array.isArray(entry.categories) ? entry.categories.join(" ") : String(entry.categories || "")
            const key = `application:${stableId}`
            const usage = historyEntry(key)
            return {
                kind: "app",
                category: applicationCategory(entry),
                key,
                label: entry.name || "Unnamed application",
                subtitle: entry.genericName || entry.comment || "Application",
                searchable: `${entry.name || ""} ${entry.genericName || ""} ${entry.comment || ""} ${keywords} ${categories} ${applicationAliases(entry)} ${command.join(" ")}`,
                icon: entry.icon || "",
                payload: entry,
                preview: entry.comment || entry.genericName || "Launch application",
                meta: command.join(" "),
                usageCount: usage.count || 0,
                lastUsed: usage.lastUsed || 0,
                recent: (usage.lastUsed || 0) > Date.now() - 7 * 24 * 60 * 60 * 1000
            }
        })
        const byHistory = (left, right) => historyScore(right.key) - historyScore(left.key)
            || left.label.localeCompare(right.label)

        // Typing searches everything, flat.
        if (needle.length > 0) {
            return apps
                .map(candidate => ({ candidate, score: fuzzyScore(needle, normalize(candidate.searchable)) + historyScore(candidate.key) }))
                .filter(scored => scored.score > -1000000)
                .sort((left, right) => right.score - left.score
                    || right.candidate.lastUsed - left.candidate.lastUsed
                    || left.candidate.label.localeCompare(right.candidate.label))
                .slice(0, 30)
                .map(scored => scored.candidate)
        }

        // Inside a category: a back row, then its apps.
        if (openCategory.length > 0) {
            const members = apps.filter(candidate => candidate.category === openCategory).sort(byHistory)
            members.forEach((candidate, index) => {
                candidate.group = openCategory
                candidate.showGroupHeader = index === 0
            })
            return [{
                kind: "back",
                key: "back",
                label: "All categories",
                subtitle: "Backspace or ← to go back",
                glyph: "chevron-left"
            }].concat(members)
        }

        // Top level: frequent apps, then categories with their app counts.
        const frequent = apps.filter(candidate => candidate.usageCount > 0).sort(byHistory).slice(0, 5)
        frequent.forEach((candidate, index) => {
            candidate.group = "Frequent"
            candidate.showGroupHeader = index === 0
        })
        const categoryRows = categories
            .map(category => {
                const members = apps.filter(candidate => candidate.category === category.name).sort(byHistory)
                return {
                    kind: "category",
                    key: `category:${category.name}`,
                    category: category.name,
                    label: category.name,
                    subtitle: category.description,
                    glyph: category.icon,
                    count: members.length,
                    members: members.slice(0, 8).map(member => member.label),
                    group: "Categories"
                }
            })
            .filter(row => row.count > 0)
        categoryRows.forEach((row, index) => row.showGroupHeader = index === 0)
        return frequent.concat(categoryRows)
    }

    readonly property int screenHeight: screen ? screen.height : 900
    readonly property int launcherCardHeight: Math.min(Theme.launcherHeight, screenHeight - 120)
    readonly property int previewWidth: 296

    name: "launcher"
    ipcEnabled: false
    placement: "center"
    cardWidth: Theme.launcherWidth
    topOffset: Math.max(Theme.outerMargin + Theme.barHeight + Theme.shellGap,
        Math.round((screenHeight - launcherCardHeight) * 0.42))
    scrollable: false

    Connections {
        target: DesktopEntries.applications

        function onValuesChanged() {
            launcher.requestCategorize()
        }
    }

    onOpening: {
        openCategory = ""
        requestCategorize()
        searchText = ""
        query.text = ""
        activationError = ""
        actionIndex = 0
        resetCurrentResult()
        Qt.callLater(() => query.forceInputFocus())
    }

    onKeyPressed: event => launcher.handleKey(event)

    function normalize(value) {
        return String(value || "").trim().toLowerCase()
    }

    function applicationAliases(entry) {
        const combined = normalize(`${entry.name || ""} ${(entry.command || []).join(" ")}`)
        const aliases = []
        if (/ghostty|terminal|kitty|alacritty|wezterm/.test(combined))
            aliases.push("terminal", "shell", "console")
        if (/helium|firefox|chrom|browser/.test(combined))
            aliases.push("browser", "web", "internet")
        if (/zed|code|editor|vim/.test(combined))
            aliases.push("editor", "code", "development")
        if (/yazi|nautilus|dolphin|files/.test(combined))
            aliases.push("files", "folders", "file manager")
        if (/spotify|music/.test(combined))
            aliases.push("music", "audio")
        return aliases.join(" ")
    }
    // Ask the app-categorize service to sort apps missing from its cache.
    // It runs in the background; the cache file is watched, so results show
    // up on their own. Rate-limited so a flurry of changes asks once.
    function requestCategorize() {
        if (Date.now() - lastCategorizeRequest < 10 * 60 * 1000)
            return
        const missing = DesktopEntries.applications.values.some(entry => !categoryCache[entry.id])
        if (!missing)
            return
        lastCategorizeRequest = Date.now()
        Quickshell.execDetached(["systemctl", "--user", "start", "--no-block", "app-categorize.service"])
    }

    function applicationCategory(entry) {
        const cached = categoryCache[entry.id]
        if (cached && categories.some(category => category.name === cached.category))
            return cached.category
        return heuristicCategory(entry)
    }

    // Fallback for apps the service hasn't sorted yet.
    function heuristicCategory(entry) {
        const categories = normalize(Array.isArray(entry.categories) ? entry.categories.join(" ") : entry.categories)
        const combined = `${categories} ${normalize(entry.name)} ${applicationAliases(entry)}`
        if (/\bgame\b/.test(combined))
            return "Games"
        if (/audiovideo|\baudio\b|\bvideo\b|\bmusic\b|\bplayer\b/.test(combined))
            return "Media"
        if (/\bdevelopment\b|\bide\b|\beditor\b|\bcode\b/.test(combined))
            return "Development"
        if (/network|webbrowser|\bbrowser\b|\binternet\b|\bemail\b/.test(combined))
            return "Internet & chat"
        if (/graphics|photography|2dgraphics|3dgraphics/.test(combined))
            return "Creative"
        if (/\boffice\b|wordprocessor|spreadsheet|presentation/.test(combined))
            return "Office"
        if (/\bsystem\b|\bsettings\b|\bsecurity\b|package manager/.test(combined))
            return "System"
        return "Other"
    }

    // Open, then the entry's own desktop actions (New Window, …), then utilities.
    function actionsFor(entry) {
        if (!entry || entry.kind !== "app")
            return []
        const actions = [{ id: "primary", label: "Open", icon: "corner-down-left" }]
        const desktopActions = entry.payload.actions || []
        for (let index = 0; index < desktopActions.length; ++index) {
            const action = desktopActions[index]
            if (action && action.command && action.command.length > 0)
                actions.push({ id: `desktop:${index}`, label: action.name || "Action", icon: "chevron-right", desktopAction: action })
        }
        actions.push({ id: "copy", label: "Copy command", icon: "copy" })
        if (entry.usageCount > 0)
            actions.push({ id: "forget", label: "Forget ranking", icon: "rotate-ccw" })
        return actions
    }

    function fuzzyScore(needle, haystack) {
        if (needle.length === 0)
            return 0

        const exact = haystack.indexOf(needle)
        let score = exact >= 0 ? 600 - Math.min(exact, 100) : 0
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
        return entries[key] || ({ count: 0, lastUsed: 0 })
    }

    function historyScore(key) {
        const value = historyEntry(key)
        const count = value.count || 0
        if (count <= 0)
            return 0
        const age = Math.max(0, Date.now() - (value.lastUsed || 0))
        const hour = 60 * 60 * 1000
        const day = 24 * hour
        const week = 7 * day
        const factor = age < hour ? 4 : age < day ? 2 : age < week ? 0.5 : 0.25
        return Math.log2(1 + count * factor) * 90
    }

    function recordSuccessful(entry) {
        const oldEntries = historyAdapter.entries || ({})
        const nextEntries = ({})
        Object.keys(oldEntries).forEach(key => nextEntries[key] = oldEntries[key])
        const previous = nextEntries[entry.key] || ({ count: 0, lastUsed: 0 })
        nextEntries[entry.key] = {
            count: (previous.count || 0) + 1,
            lastUsed: Date.now(),
            label: entry.label
        }

        const keys = Object.keys(nextEntries)
        if (keys.length > 300) {
            keys.sort((left, right) => (nextEntries[right].lastUsed || 0) - (nextEntries[left].lastUsed || 0))
            keys.slice(300).forEach(key => delete nextEntries[key])
        }
        historyAdapter.entries = nextEntries
    }

    function forgetHistory(key) {
        const entries = historyAdapter.entries || ({})
        const nextEntries = ({})
        Object.keys(entries).forEach(existing => {
            if (existing !== key)
                nextEntries[existing] = entries[existing]
        })
        historyAdapter.entries = nextEntries
    }

    function resetCurrentResult() {
        results.currentIndex = -1
        Qt.callLater(() => {
            results.currentIndex = results.count > 0 ? 0 : -1
            results.positionViewAtBeginning()
        })
    }

    function moveSelection(delta) {
        if (results.count === 0)
            return
        results.currentIndex = Math.max(0, Math.min(results.count - 1, results.currentIndex + delta))
        results.positionViewAtIndex(results.currentIndex, ListView.Contain)
    }

    function enterCategory(name) {
        openCategory = name
        actionIndex = 0
        // Land on the first app, not the back row.
        Qt.callLater(() => {
            results.currentIndex = results.count > 1 ? 1 : 0
            results.positionViewAtBeginning()
        })
    }

    function leaveCategory() {
        const previous = openCategory
        openCategory = ""
        actionIndex = 0
        // Land back on the category we came from.
        Qt.callLater(() => {
            const index = filteredValues.findIndex(row => row.kind === "category" && row.category === previous)
            results.currentIndex = index >= 0 ? index : 0
            results.positionViewAtIndex(results.currentIndex, ListView.Contain)
        })
    }

    function handleKey(event) {
        const browsing = searchText.length === 0 && openCategory.length > 0
        if (browsing && (event.key === Qt.Key_Backspace
                || (event.key === Qt.Key_Left && actionIndex === 0)
                || event.key === Qt.Key_Escape)) {
            leaveCategory()
        } else if (event.key === Qt.Key_Right && selectedEntry && selectedEntry.kind === "category") {
            enterCategory(selectedEntry.category)
        } else if (event.key === Qt.Key_Down) {
            moveSelection(1)
        } else if (event.key === Qt.Key_Up) {
            moveSelection(-1)
        } else if (event.key === Qt.Key_PageDown) {
            moveSelection(6)
        } else if (event.key === Qt.Key_PageUp) {
            moveSelection(-6)
        } else if (event.key === Qt.Key_Left) {
            actionIndex = Math.max(0, actionIndex - 1)
        } else if (event.key === Qt.Key_Right) {
            actionIndex = Math.max(0, Math.min(selectedActions.length - 1, actionIndex + 1))
        } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier) && !query.input.selectedText) {
            executeAction(selectedEntry, { id: "copy" })
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activateCurrent()
        } else if (event.key === Qt.Key_Escape) {
            close()
        } else {
            return
        }
        event.accepted = true
    }

    function launch(entry, command) {
        if (!command || command.length === 0) {
            activationError = `${entry.label} has no command to run`
            return
        }
        Quickshell.execDetached({
            command: ["uwsm-app", "--"].concat(command),
            workingDirectory: entry.payload.workingDirectory
        })
        recordSuccessful(entry)
        close()
    }

    function executeAction(entry, action) {
        if (!entry || !action)
            return
        activationError = ""
        if (entry.kind === "category") {
            enterCategory(entry.category)
            return
        }
        if (entry.kind === "back") {
            leaveCategory()
            return
        }
        if (action.id === "primary")
            launch(entry, entry.payload.command)
        else if (action.desktopAction)
            launch(entry, action.desktopAction.command)
        else if (action.id === "copy")
            Quickshell.execDetached(["wl-copy", (entry.payload.command || []).join(" ")])
        else if (action.id === "forget")
            forgetHistory(entry.key)
    }

    function activateCurrent() {
        executeAction(selectedEntry, currentAction || { id: "primary" })
    }

    IpcHandler {
        target: "launcher"

        function open(): void { launcher.open() }
        function close(): void { launcher.close() }
        function toggle(): void { launcher.toggle() }
        function search(text: string): void {
            if (!launcher.shown)
                launcher.open()
            query.text = text
            Qt.callLater(() => query.forceInputFocus())
        }
        function state(): string {
            return JSON.stringify({
                query: launcher.searchText,
                results: results.count,
                selected: launcher.selectedEntry ? launcher.selectedEntry.label : "",
                actions: launcher.selectedActions.map(action => action.label),
                action: launcher.currentAction ? launcher.currentAction.label : ""
            })
        }
        function activateSelected(): void { launcher.activateCurrent() }
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

    FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/app-categories.json`
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                launcher.categoryCache = JSON.parse(text()).apps || ({})
            } catch (error) {
                launcher.categoryCache = ({})
            }
            launcher.requestCategorize()
        }
        onLoadFailed: error => launcher.requestCategorize()
    }

    ScriptModel {
        id: resultModel
        values: launcher.filteredValues
    }

    // Rounded tile: the app's theme icon, else its initial.
    component EntryTile: Rectangle {
        id: tile

        property var entry: null
        property int iconSize: 22
        readonly property string glyph: entry && entry.glyph ? entry.glyph : ""
        readonly property string themeIcon: !glyph && entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""

        implicitWidth: 36
        implicitHeight: 36
        radius: Theme.radius.medium
        color: Theme.surface.raised

        IconImage {
            anchors.centerIn: parent
            visible: tile.themeIcon.length > 0
            implicitWidth: tile.iconSize
            implicitHeight: tile.iconSize
            source: tile.themeIcon
        }

        Icon {
            anchors.centerIn: parent
            visible: tile.glyph.length > 0
            name: tile.glyph
            size: Math.round(tile.iconSize * 0.8)
            color: Theme.text.soft
        }

        Label {
            anchors.centerIn: parent
            visible: tile.themeIcon.length === 0 && tile.glyph.length === 0
            text: tile.entry && tile.entry.label.length > 0 ? tile.entry.label.charAt(0).toUpperCase() : "?"
            variant: "heading"
            tone: "accent"
        }
    }

    footer: [
        Item {
            width: parent.width
            height: 16

            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: launcher.historyError.length > 0
                    ? launcher.historyError
                    : launcher.openCategory.length > 0 ? `${launcher.openCategory} · ${results.count - 1} apps`
                    : launcher.searchText.length > 0 ? `${results.count} ${results.count === 1 ? "match" : "matches"}`
                    : `${DesktopEntries.applications.values.length} apps`
                variant: "numeric"
                font.pixelSize: Theme.fontSize.caption
                font.weight: Font.Normal
                tone: launcher.historyError.length > 0 ? "warning" : "faint"
            }

            Label {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: launcher.searchText.length > 0 ? "↑↓ move · ←→ action · ↵ launch · esc close"
                    : launcher.openCategory.length > 0 ? "↑↓ move · ←→ action · ↵ launch · ⌫ back"
                    : "↑↓ move · ↵ open · type to search · esc close"
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
        height: launcher.launcherCardHeight - launcher.padding * 2 - launcher.card.footerHeight

        TextField {
            id: query

            // Runs before the input, so arrows, Enter and Ctrl+C drive the list.
            onKeyPressed: event => launcher.handleKey(event)

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            large: true
            icon: "search"
            placeholder: "Search applications…"

            onTextChanged: {
                launcher.searchText = text
                launcher.activationError = ""
                launcher.resetCurrentResult()
            }
        }

        Hairline {
            id: divider

            anchors {
                top: query.bottom
                left: parent.left
                right: parent.right
                topMargin: Theme.space.lg
            }
        }

        ListView {
            id: results

            anchors {
                top: divider.bottom
                left: parent.left
                right: previewDivider.left
                bottom: parent.bottom
                topMargin: Theme.space.sm
                rightMargin: Theme.space.lg
            }
            model: resultModel
            spacing: 2
            clip: true
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: launcher.actionIndex = 0

            delegate: Item {
                id: result

                required property var modelData
                required property int index
                property var entry: modelData
                readonly property bool current: ListView.isCurrentItem
                readonly property bool hasHeader: modelData.showGroupHeader === true

                width: results.width
                height: row.height + (hasHeader ? header.height + header.anchors.topMargin + Theme.space.xs : 0)

                SectionHeader {
                    id: header

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: result.index === 0 ? Theme.space.xs : Theme.space.md
                        leftMargin: Theme.space.sm
                    }
                    visible: result.hasHeader
                    text: result.modelData.group || ""
                }

                Item {
                    id: row

                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: 52

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.medium
                        color: result.current ? Theme.selected : rowMouse.containsMouse ? Theme.hover : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.motion.fast
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: result.current
                        width: 2
                        height: parent.height - Theme.space.lg
                        radius: 1
                        color: Theme.accent
                    }

                    EntryTile {
                        id: tile

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space.md
                        anchors.verticalCenter: parent.verticalCenter
                        entry: result.modelData
                    }

                    Column {
                        anchors {
                            left: tile.right
                            right: hint.visible ? hint.left : parent.right
                            leftMargin: Theme.space.md
                            rightMargin: Theme.space.md
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 2

                        Label {
                            width: parent.width
                            text: result.modelData.label
                            tone: result.current ? "base" : "soft"
                            font.weight: result.current ? Font.Medium : Font.Normal
                        }

                        Label {
                            width: parent.width
                            text: result.modelData.subtitle
                            variant: "small"
                            tone: "faint"
                            elide: Text.ElideRight
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space.md
                        anchors.verticalCenter: parent.verticalCenter
                        visible: result.modelData.kind === "category" && !result.current
                        spacing: Theme.space.sm

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(result.modelData.count || "")
                            variant: "numeric"
                            font.pixelSize: Theme.fontSize.small
                            tone: "faint"
                        }

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "chevron-right"
                            size: 14
                            color: Theme.text.faint
                        }
                    }

                    Label {
                        id: hint

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space.md
                        anchors.verticalCenter: parent.verticalCenter
                        visible: result.current
                        text: result.modelData.kind === "category" ? `↵ ${result.modelData.count} apps`
                            : result.modelData.kind === "back" ? "↵ back"
                            : `↵ ${launcher.currentAction ? launcher.currentAction.label.toLowerCase() : "open"}`
                        variant: "numeric"
                        font.pixelSize: Theme.fontSize.caption
                        font.weight: Font.Normal
                        tone: "faint"
                    }

                    MouseArea {
                        id: rowMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: results.currentIndex = result.index
                        onClicked: {
                            results.currentIndex = result.index
                            launcher.executeAction(result.modelData, { id: "primary" })
                        }
                    }
                }
            }
        }

        Label {
            anchors.centerIn: results
            width: results.width - Theme.space.xxl * 2
            visible: results.count === 0 || launcher.activationError.length > 0
            text: launcher.activationError.length > 0 ? launcher.activationError
                : launcher.searchText.length > 0 ? "No matching applications" : "No applications found"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            tone: launcher.activationError.length > 0 ? "danger" : "faint"
        }

        Hairline {
            id: previewDivider

            anchors {
                top: divider.bottom
                bottom: parent.bottom
                right: previewPane.left
                rightMargin: Theme.space.xl
            }
            vertical: true
        }

        Item {
            id: previewPane

            anchors {
                top: divider.bottom
                right: parent.right
                bottom: parent.bottom
                topMargin: Theme.space.lg
            }
            width: launcher.previewWidth

            Column {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                spacing: Theme.space.md

                Row {
                    width: parent.width
                    spacing: Theme.space.md

                    EntryTile {
                        width: 44
                        height: 44
                        iconSize: 28
                        entry: launcher.selectedEntry
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 44 - Theme.space.md
                        spacing: Theme.space.xs

                        Label {
                            width: parent.width
                            text: launcher.selectedEntry ? launcher.selectedEntry.label : "No app selected"
                            variant: "heading"
                        }

                        Label {
                            width: parent.width
                            text: !launcher.selectedEntry ? "Type to search"
                                : launcher.selectedEntry.kind === "category" ? `${launcher.selectedEntry.count} apps`
                                : launcher.selectedEntry.kind === "back" ? "Categories"
                                : `${launcher.selectedEntry.category}${launcher.selectedEntry.recent ? " · recent" : ""}${launcher.selectedEntry.usageCount > 0 ? ` · used ${launcher.selectedEntry.usageCount}×` : ""}`
                            variant: "label"
                            tone: launcher.selectedEntry && launcher.selectedEntry.recent ? "accent" : "faint"
                        }
                    }
                }

                Label {
                    width: parent.width
                    visible: text.length > 0
                    text: !launcher.selectedEntry ? ""
                        : launcher.selectedEntry.kind === "app" ? launcher.selectedEntry.preview
                        : launcher.selectedEntry.kind === "category" ? `For ${launcher.selectedEntry.subtitle}.`
                        : ""
                    tone: "soft"
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }

                Label {
                    width: parent.width
                    visible: text.length > 0
                    text: !launcher.selectedEntry ? ""
                        : launcher.selectedEntry.kind === "category" ? launcher.selectedEntry.members.join(" · ")
                        : launcher.selectedEntry.meta || ""
                    variant: "numeric"
                    font.pixelSize: Theme.fontSize.caption
                    font.weight: Font.Normal
                    tone: "faint"
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                SectionHeader {
                    visible: launcher.selectedActions.length > 0
                    width: parent.width
                    text: "Actions"
                }

                Column {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: launcher.selectedActions

                        delegate: ListItem {
                            required property var modelData
                            required property int index

                            width: parent ? parent.width : 0
                            implicitHeight: 34
                            icon: modelData.icon
                            title: modelData.label
                            trailing: index === launcher.actionIndex ? "↵" : ""
                            selected: index === launcher.actionIndex
                            onHoveredChanged: {
                                if (hovered)
                                    launcher.actionIndex = index
                            }
                            onClicked: launcher.executeAction(launcher.selectedEntry, modelData)
                        }
                    }
                }
            }
        }
    }
}
