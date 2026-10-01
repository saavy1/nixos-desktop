import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.ui

// Clipboard history (cliphist): newest first, substring search, keyboard
// navigation, text/image preview, copy, delete and clear all. Entries the
// clip-guard service flags as secrets are masked until revealed.
PopupPanel {
    id: root

    name: "clipboard"
    title: "Clipboard"
    subtitle: {
        if (status === "loading" && entries.length === 0)
            return "loading…";
        if (status === "error")
            return "history unavailable";
        const total = `${entries.length} ${entries.length === 1 ? "item" : "items"}`;
        if (query.length > 0)
            return `${matchCount} of ${total} · newest first`;
        return `${total} · newest first`;
    }
    placement: "center"
    cardWidth: 760
    scrollable: false
    // Sit a little above centre, like the launcher (card ≈ body + header).
    topOffset: Math.max(Theme.outerMargin + Theme.barHeight + Theme.shellGap,
        Math.round(((screen ? screen.height : 900) - bodyHeight - 140) * 0.42))

    readonly property int renderLimit: 500
    readonly property int bodyHeight: 540
    readonly property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string cacheDirectory: `${runtimeDirectory}/quickshell-clipboard`

    // Parsed `cliphist list` lines, newest first — never re-sorted.
    property var entries: []
    property string status: "idle" // idle | loading | ready | error
    property string errorText: ""
    property string query: ""
    property int matchCount: 0
    property var matches: []
    property int selectedIndex: 0
    property int reloadIndex: -1
    // Entry ids whose decoded image already exists in cacheDirectory.
    property var decoded: ({})
    property bool confirmClear: false
    property string actionError: ""

    // clip-guard state: { entries: { id: { secret, p, hash, first_seen } }, allow: [hash], expire_after }.
    property var guard: ({ entries: {}, allow: [], expire_after: 0 })
    // Entry ids revealed in this session.
    property var revealed: ({})
    property double now: Date.now()

    readonly property var selectedEntry: selectedIndex >= 0 && selectedIndex < matches.length ? matches[selectedIndex] : null
    property string previewText: ""
    property bool previewLoading: false

    function parseEntry(raw: string, position: int): var {
        const tab = raw.indexOf("\t");
        const id = tab >= 0 ? raw.slice(0, tab) : "";
        const preview = tab >= 0 ? raw.slice(tab + 1) : raw;
        const binary = preview.match(/^\[\[\s*binary data\s+(.+?)\s*\]\]$/i);
        let kind = "text";
        let format = "";
        let size = "";
        let dims = "";
        if (binary) {
            const parts = binary[1].split(/\s+/);
            // "416 KiB png 518x886"
            size = parts.length >= 2 ? `${parts[0]} ${parts[1]}` : parts[0] || "";
            format = parts[2] || "";
            dims = parts[3] || "";
            kind = /^(png|jpe?g|webp|gif|bmp|tiff?|avif|svg|image\/.*)$/i.test(format) ? "image" : "binary";
        }
        const firstLine = preview.split("\n")[0].trim();
        const title = kind === "image" ? "Image" : kind === "binary" ? "Binary data" : firstLine.length > 0 ? firstLine : "(whitespace)";
        const meta = kind === "text" ? "" : [format.replace(/^image\//, "").toUpperCase(), dims.replace("x", "×"), size].filter(s => s.length > 0).join(" · ");
        return {
            raw: raw,
            id: id,
            position: position,
            kind: kind,
            title: title,
            meta: meta,
            preview: preview,
            searchable: (preview + (kind === "image" ? " image picture screenshot" : "")).toLowerCase()
        };
    }

    function guardInfo(entry: var): var {
        return entry ? (guard.entries || {})[entry.id] || null : null;
    }

    // Flagged as a secret and not marked "not a secret".
    function isFlagged(entry: var): bool {
        const info = guardInfo(entry);
        return !!info && info.secret && (guard.allow || []).indexOf(info.hash) < 0;
    }

    function isMasked(entry: var): bool {
        return isFlagged(entry) && !revealed[entry.id];
    }

    function guardNote(entry: var): string {
        const info = guardInfo(entry);
        if (!info)
            return "";
        const confidence = `${Math.round(info.p * 100)}% sure`;
        if (!(guard.expire_after > 0))
            return `looks like a secret · ${confidence}`;
        const remaining = (info.first_seen + guard.expire_after) * 1000 - now;
        const minutes = Math.max(0, Math.ceil(remaining / 60000));
        return `expires in ${minutes < 60 ? minutes + "m" : Math.floor(minutes / 60) + "h " + minutes % 60 + "m"} · ${confidence}`;
    }

    function setRevealed(entry: var, shown: bool): void {
        if (!entry)
            return;
        const next = Object.assign({}, revealed);
        if (shown)
            next[entry.id] = true;
        else
            delete next[entry.id];
        revealed = next;
        loadPreview();
    }

    function markNotSecret(entry: var): void {
        if (entry)
            Quickshell.execDetached(["clip-guard", "allow", entry.id]);
    }

    function refilter(keepIndex: int): void {
        const needle = query.trim().toLowerCase();
        const result = [];
        let count = 0;
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            // Hidden entries only match "secret", never their contents.
            const haystack = isFlagged(entry) ? "secret hidden" : entry.searchable;
            if (needle.length > 0 && haystack.indexOf(needle) < 0)
                continue;
            count++;
            if (result.length < renderLimit)
                result.push(entry);
        }
        matchCount = count;
        matches = result;
        selectedIndex = result.length === 0 ? -1 : Math.max(0, Math.min(keepIndex, result.length - 1));
        list.positionViewAtIndex(Math.max(0, selectedIndex), ListView.Contain);
        schedulePreview();
    }

    function reload(keepIndex: int): void {
        reloadIndex = keepIndex;
        status = "loading";
        errorText = "";
        listProc.running = false;
        listProc.running = true;
    }

    function move(delta: int): void {
        if (matches.length === 0)
            return;
        selectedIndex = Math.max(0, Math.min(matches.length - 1, selectedIndex + delta));
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
        schedulePreview();
    }

    function copyEntry(entry: var): void {
        if (!entry)
            return;
        Quickshell.execDetached(["clipboard-select", entry.raw]);
        close();
    }

    function deleteEntry(entry: var): void {
        if (!entry || deleteProc.running)
            return;
        actionError = "";
        const index = matches.indexOf(entry);
        reloadIndex = index >= 0 ? index : selectedIndex;
        deleteProc.command = ["sh", "-c", 'clipboard-delete "$1" && rm -f "$2"', "sh", entry.raw, `${cacheDirectory}/${entry.id}`];
        deleteProc.running = true;
    }

    function requestClear(): void {
        if (!confirmClear) {
            confirmClear = true;
            clearTimer.restart();
            return;
        }
        confirmClear = false;
        clearTimer.stop();
        actionError = "";
        wipeProc.running = true;
    }

    function imageSource(entry: var): string {
        return entry && decoded[entry.id] ? `file://${cacheDirectory}/${entry.id}` : "";
    }

    function requestDecode(entry: var, urgent: bool): void {
        if (!entry || entry.kind !== "image" || entry.id === "" || decoded[entry.id])
            return;
        const queued = decodeQueue.indexOf(entry.raw);
        if (urgent) {
            if (queued >= 0)
                decodeQueue.splice(queued, 1);
            decodeQueue.unshift(entry.raw);
        } else if (queued < 0) {
            decodeQueue.push(entry.raw);
        }
        pumpDecode();
    }

    property var decodeQueue: []

    function pumpDecode(): void {
        if (decodeProc.running || decodeQueue.length === 0)
            return;
        const raw = decodeQueue.shift();
        const id = raw.slice(0, raw.indexOf("\t"));
        if (decoded[id]) {
            pumpDecode();
            return;
        }
        decodeProc.entryId = id;
        const file = `${cacheDirectory}/${id}`;
        decodeProc.command = ["sh", "-c", 'mkdir -p "$3" && { test -s "$2" || clipboard-preview "$1" "$2"; }', "sh", raw, file, cacheDirectory];
        decodeProc.running = true;
    }

    function schedulePreview(): void {
        previewTimer.restart();
    }

    function loadPreview(): void {
        const entry = selectedEntry;
        previewText = "";
        textProc.running = false;
        previewLoading = false;
        if (!entry)
            return;
        if (entry.kind === "image") {
            requestDecode(entry, true);
            return;
        }
        if (entry.kind !== "text" || isMasked(entry))
            return;
        // cliphist list truncates long entries; decode the full text (capped).
        previewLoading = true;
        textProc.entryId = entry.id;
        textProc.command = ["sh", "-c", 'printf "%s" "$1" | cliphist decode | head -c 20000', "sh", entry.raw];
        textProc.running = true;
    }

    function looksLikeCode(text: string): bool {
        return /^\s{2,}\S|[{};]\s*$|^\s*[$#>] |^(sudo|nix|git|cd|ls|cat|grep|curl) /m.test(text);
    }

    onOpening: {
        revealed = {};
        now = Date.now();
        // Classify anything copied since the last sweep.
        Quickshell.execDetached(["systemctl", "--user", "start", "--no-block", "clip-guard.service"]);
        query = "";
        search.text = "";
        confirmClear = false;
        actionError = "";
        previewText = "";
        reload(0);
        Qt.callLater(() => search.forceInputFocus());
    }

    onKeyPressed: event => handleKey(event)

    function handleKey(event: var): void {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J) || (ctrl && event.key === Qt.Key_N)) {
            move(1);
        } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K) || (ctrl && event.key === Qt.Key_P)) {
            move(-1);
        } else if (event.key === Qt.Key_PageDown) {
            move(Math.max(1, Math.floor(list.height / 52)));
        } else if (event.key === Qt.Key_PageUp) {
            move(-Math.max(1, Math.floor(list.height / 52)));
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            copyEntry(selectedEntry);
        } else if ((shift && event.key === Qt.Key_Delete) || (ctrl && event.key === Qt.Key_D)) {
            deleteEntry(selectedEntry);
        } else {
            return;
        }
        event.accepted = true;
    }

    Timer {
        id: previewTimer

        interval: 60
        onTriggered: root.loadPreview()
    }

    Timer {
        interval: 30000
        running: root.shown
        repeat: true
        onTriggered: root.now = Date.now()
    }

    FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/clip-guard.json`
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.guard = JSON.parse(text());
            } catch (error) {
                return;
            }
            if (root.status === "ready")
                root.refilter(root.selectedIndex);
        }
    }

    Timer {
        id: clearTimer

        interval: 4000
        onTriggered: root.confirmClear = false
    }

    Process {
        id: listProc

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(line => line.length > 0);
                const parsed = [];
                for (let i = 0; i < lines.length; i++)
                    parsed.push(root.parseEntry(lines[i], i + 1));
                root.entries = parsed;
                root.status = "ready";
                root.refilter(root.reloadIndex >= 0 ? root.reloadIndex : 0);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.errorText = text.trim().split("\n")[0];
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.status = "error";
                if (root.errorText.length === 0)
                    root.errorText = `cliphist list failed (${exitCode})`;
            }
        }
    }

    Process {
        id: textProc

        property string entryId

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.selectedEntry && root.selectedEntry.id === textProc.entryId) {
                    root.previewText = text;
                    root.previewLoading = false;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.previewLoading = false;
        }
    }

    Process {
        id: decodeProc

        property string entryId

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                const next = Object.assign({}, root.decoded);
                next[entryId] = true;
                root.decoded = next;
            }
            Qt.callLater(() => root.pumpDecode());
        }
    }

    Process {
        id: deleteProc

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.reload(root.reloadIndex);
            else
                root.actionError = "Entry could not be deleted";
        }
    }

    Process {
        id: wipeProc

        command: ["sh", "-c", 'cliphist wipe && rm -rf "$1"', "sh", root.cacheDirectory]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.actionError = "Clipboard history could not be cleared";
            root.decoded = {};
            root.reload(0);
        }
    }

    headerTrailing: [
        Button {
            visible: root.entries.length > 0
            text: root.confirmClear ? "Confirm clear" : "Clear all"
            icon: "trash-2"
            variant: root.confirmClear ? "danger" : "ghost"
            compact: true
            onClicked: root.requestClear()
        }
    ]

    Item {
        width: parent.width
        height: root.bodyHeight

        TextField {
            id: search

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            large: true
            icon: "search"
            placeholder: "Search clipboard history…"
            onTextEdited: {
                root.query = text;
                root.refilter(0);
            }
            onKeyPressed: event => root.handleKey(event)
        }

        Item {
            id: listPane

            anchors {
                left: parent.left
                top: search.bottom
                bottom: footer.top
                topMargin: Theme.space.md
                bottomMargin: Theme.space.sm
            }
            width: Math.round(parent.width * 0.52)

            ListView {
                id: list

                anchors.fill: parent
                clip: true
                model: root.matches
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 200
                currentIndex: root.selectedIndex
                highlightFollowsCurrentItem: false

                delegate: ClipRow {
                    required property var modelData
                    required property int index

                    width: ListView.view.width - (scrollbar.visible ? 8 : 0)
                    entry: modelData
                    selected: index === root.selectedIndex
                    onActivated: root.copyEntry(modelData)
                    onRemoveRequested: root.deleteEntry(modelData)
                }
            }

            Rectangle {
                id: scrollbar

                visible: list.contentHeight > list.height
                anchors.right: parent.right
                y: list.visibleArea.yPosition * list.height
                width: 3
                height: Math.max(24, list.visibleArea.heightRatio * list.height)
                radius: 1.5
                color: Theme.lineStrong
            }

            // Loading / empty / error states.
            Column {
                anchors.centerIn: parent
                width: parent.width - Theme.space.xl * 2
                visible: root.matches.length === 0
                spacing: Theme.space.sm

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.status === "error" ? "clipboard-x" : root.status === "loading" ? "refresh-cw" : root.query.length > 0 ? "search" : "clipboard"
                    size: 26
                    color: root.status === "error" ? Theme.danger : Theme.text.disabled
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.status === "error" ? "Could not load clipboard history"
                        : root.status === "loading" || root.status === "idle" ? "Loading clipboard history…"
                        : root.query.length > 0 ? "No matching entries"
                        : "Clipboard history is empty"
                    tone: "soft"
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: text.length > 0
                    text: root.status === "error" ? root.errorText
                        : root.status === "ready" && root.query.length === 0 ? "Copied text and images will appear here"
                        : ""
                    variant: "small"
                    tone: root.status === "error" ? "danger" : "faint"
                    wrapMode: Text.Wrap
                }
            }
        }

        Hairline {
            id: divider

            vertical: true
            anchors {
                left: listPane.right
                top: listPane.top
                bottom: listPane.bottom
                leftMargin: Theme.space.lg
            }
        }

        // Preview of the selected entry.
        Item {
            id: previewPane

            anchors {
                left: divider.right
                right: parent.right
                top: listPane.top
                bottom: listPane.bottom
                leftMargin: Theme.space.lg
            }

            readonly property var entry: root.selectedEntry

            Column {
                id: previewHeader

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                spacing: Theme.space.xs
                visible: previewPane.entry !== null

                Label {
                    width: parent.width
                    text: !previewPane.entry ? ""
                        : root.isMasked(previewPane.entry) ? "Hidden secret"
                        : previewPane.entry.kind === "image" ? "Image"
                        : previewPane.entry.kind === "binary" ? "Binary data"
                        : "Text"
                    variant: "heading"
                }

                Label {
                    width: parent.width
                    text: {
                        const e = previewPane.entry;
                        if (!e)
                            return "";
                        const parts = [`#${e.id}`];
                        if (root.isFlagged(e)) {
                            parts.push(root.guardNote(e));
                        } else if (e.kind === "text") {
                            const body = root.previewText.length > 0 ? root.previewText : e.preview;
                            const lines = body.split("\n").length;
                            parts.push(`${body.length}${body.length >= 20000 ? "+" : ""} chars`);
                            if (lines > 1)
                                parts.push(`${lines} lines`);
                        } else if (e.meta.length > 0) {
                            parts.push(e.meta);
                        }
                        if (e.position === 1)
                            parts.push("latest");
                        return parts.join(" · ");
                    }
                    variant: "numeric"
                    font.pixelSize: Theme.fontSize.caption
                    font.weight: Font.Normal
                    tone: "faint"
                }
            }

            // Secret controls, right under the header so they sit with the entry.
            Row {
                id: guardActions

                visible: previewPane.entry !== null && root.isFlagged(previewPane.entry)
                anchors {
                    left: parent.left
                    top: previewHeader.bottom
                    topMargin: Theme.space.sm
                }
                height: visible ? implicitHeight : 0
                spacing: Theme.space.sm

                Button {
                    text: root.isMasked(previewPane.entry) ? "Reveal" : "Hide"
                    icon: root.isMasked(previewPane.entry) ? "eye" : "eye-off"
                    compact: true
                    variant: "ghost"
                    onClicked: root.setRevealed(previewPane.entry, root.isMasked(previewPane.entry))
                }

                Button {
                    text: "Not a secret"
                    icon: "shield-off"
                    compact: true
                    variant: "ghost"
                    onClicked: root.markNotSecret(previewPane.entry)
                }
            }

            // Aspect-fit box for the decoded image (RoundedImage crops to fill).
            Item {
                id: imageBox

                visible: previewPane.entry !== null && previewPane.entry.kind === "image"
                anchors {
                    left: parent.left
                    right: parent.right
                    top: previewHeader.bottom
                    bottom: previewActions.top
                    topMargin: Theme.space.md
                    bottomMargin: Theme.space.md
                }

                readonly property var dims: {
                    const e = previewPane.entry;
                    const m = e ? e.meta.match(/(\d+)×(\d+)/) : null;
                    return m ? { w: Number(m[1]), h: Number(m[2]) } : { w: width, h: height };
                }
                readonly property real fit: Math.min(1, width / Math.max(1, dims.w), height / Math.max(1, dims.h))

                RoundedImage {
                    anchors.centerIn: parent
                    width: Math.max(48, Math.round(imageBox.dims.w * imageBox.fit))
                    height: Math.max(48, Math.round(imageBox.dims.h * imageBox.fit))
                    bordered: true
                    placeholderIcon: "image"
                    source: imageBox.visible ? root.imageSource(previewPane.entry) : ""
                    sourceSize.width: 1024
                    sourceSize.height: 1024
                }
            }

            Rectangle {
                visible: previewPane.entry !== null && root.isMasked(previewPane.entry)
                anchors {
                    left: parent.left
                    right: parent.right
                    top: guardActions.bottom
                    topMargin: Theme.space.md
                }
                height: maskedColumn.implicitHeight + Theme.space.xl * 2
                radius: Theme.radius.medium
                color: Theme.surface.sunk

                Column {
                    id: maskedColumn

                    anchors.centerIn: parent
                    width: parent.width - Theme.space.xl * 2
                    spacing: Theme.space.sm

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "lock"
                        size: 22
                        color: Theme.text.soft
                    }

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "••••••••••••••••"
                        variant: "numeric"
                        tone: "soft"
                    }

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "This looks like a password, key or token. Enter still copies it."
                        variant: "small"
                        tone: "faint"
                        wrapMode: Text.Wrap
                    }
                }
            }

            Flickable {
                id: textFlick

                visible: previewPane.entry !== null && previewPane.entry.kind !== "image" && !root.isMasked(previewPane.entry)
                anchors {
                    left: parent.left
                    right: parent.right
                    top: guardActions.bottom
                    topMargin: Theme.space.md
                }
                height: Math.min(contentHeight, previewActions.y - Theme.space.md - y)
                clip: true
                contentWidth: width
                contentHeight: previewBody.implicitHeight + Theme.space.md * 2
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Rectangle {
                    width: textFlick.width
                    height: textFlick.contentHeight
                    radius: Theme.radius.medium
                    color: Theme.surface.sunk
                }

                Label {
                    id: previewBody

                    readonly property string body: !previewPane.entry ? ""
                        : previewPane.entry.kind === "binary" ? "Binary content can't be previewed. Press Enter to copy it back to the clipboard."
                        : root.previewText.length > 0 ? root.previewText.replace(/\n+$/, "")
                        : previewPane.entry.preview

                    x: Theme.space.md
                    y: Theme.space.md
                    width: textFlick.width - Theme.space.md * 2
                    text: body
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    tone: previewPane.entry && previewPane.entry.kind === "binary" ? "faint" : "base"
                    variant: previewPane.entry && previewPane.entry.kind === "text" && root.looksLikeCode(body) ? "numeric" : "body"
                    font.weight: Font.Normal
                    lineHeight: 1.15
                }
            }

            Rectangle {
                visible: textFlick.visible && textFlick.contentHeight > textFlick.height
                anchors.right: textFlick.right
                anchors.rightMargin: 3
                y: textFlick.y + textFlick.visibleArea.yPosition * textFlick.height
                width: 3
                height: Math.max(24, textFlick.visibleArea.heightRatio * textFlick.height)
                radius: 1.5
                color: Theme.lineStrong
            }

            Row {
                id: previewActions

                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                spacing: Theme.space.sm
                visible: previewPane.entry !== null

                Button {
                    text: "Delete"
                    icon: "trash-2"
                    compact: true
                    variant: "ghost"
                    onClicked: root.deleteEntry(root.selectedEntry)
                }

                Button {
                    text: "Copy"
                    icon: "copy"
                    compact: true
                    variant: "primary"
                    onClicked: root.copyEntry(root.selectedEntry)
                }
            }

            Label {
                anchors.centerIn: parent
                visible: previewPane.entry === null && root.status === "ready" && root.entries.length > 0
                text: "Nothing selected"
                tone: "faint"
            }
        }

        // Key hints, or the last action error.
        Row {
            id: footer

            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 22
            spacing: Theme.space.lg

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.actionError.length > 0
                text: root.actionError
                variant: "small"
                tone: "danger"
            }

            Repeater {
                model: root.actionError.length > 0 ? [] : [
                    { keys: ["↑", "↓"], label: "Navigate" },
                    { keys: ["Enter"], label: "Copy" },
                    { keys: ["Shift", "Del"], label: "Delete" },
                    { keys: ["Esc"], label: "Close" }
                ]

                delegate: Row {
                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.sm

                    KeyCombo {
                        anchors.verticalCenter: parent.verticalCenter
                        tokens: parent.modelData.keys
                        tone: "soft"
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.label
                        variant: "small"
                        tone: "faint"
                    }
                }
            }
        }
    }

    // One history row: thumbnail or icon, first line / image metadata, id tag,
    // hover delete button.
    component ClipRow: Item {
        id: row

        property var entry
        property bool selected: false
        readonly property bool hovered: rowMouse.containsMouse || removeButton.hovered
        readonly property bool isImage: entry && entry.kind === "image"
        readonly property bool masked: root.isMasked(entry)

        signal activated
        signal removeRequested

        height: 48

        Component.onCompleted: {
            if (isImage)
                root.requestDecode(entry, false);
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.small
            color: row.selected ? Theme.selected : row.hovered ? Theme.hover : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Theme.motion.fast
                }
            }
        }

        Rectangle {
            visible: row.selected
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: 3
            height: parent.height - Theme.space.md * 2 + 4
            radius: 1.5
            color: Theme.accent
        }

        MouseArea {
            id: rowMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }

        Item {
            id: thumb

            anchors {
                left: parent.left
                leftMargin: Theme.space.md
                verticalCenter: parent.verticalCenter
            }
            width: 32
            height: 32

            RoundedImage {
                anchors.fill: parent
                visible: row.isImage
                radius: Theme.radius.small
                bordered: true
                placeholderIcon: "image"
                source: row.isImage ? root.imageSource(row.entry) : ""
                sourceSize.width: 64
                sourceSize.height: 64
            }

            Icon {
                anchors.centerIn: parent
                visible: !row.isImage
                name: row.masked ? "lock" : row.entry && row.entry.kind === "binary" ? "file" : "type"
                size: 16
                color: row.selected ? Theme.text.base : Theme.text.faint
            }
        }

        Column {
            anchors {
                left: thumb.right
                leftMargin: Theme.space.md
                right: trailing.left
                rightMargin: Theme.space.md
                verticalCenter: parent.verticalCenter
            }
            spacing: 2

            Label {
                width: parent.width
                text: row.masked ? "••••••••••••" : row.entry ? row.entry.title : ""
                tone: row.selected ? "base" : "soft"
                font.weight: row.selected ? Font.Medium : Font.Normal
                maximumLineCount: 1
            }

            Label {
                width: parent.width
                visible: text.length > 0
                text: row.masked ? root.guardNote(row.entry) : row.entry ? row.entry.meta : ""
                variant: "numeric"
                font.pixelSize: Theme.fontSize.caption
                font.weight: Font.Normal
                tone: "faint"
            }
        }

        Item {
            id: trailing

            anchors {
                right: parent.right
                rightMargin: Theme.space.sm
                verticalCenter: parent.verticalCenter
            }
            width: Math.max(idLabel.implicitWidth, removeButton.width)
            height: 30

            Label {
                id: idLabel

                anchors.right: parent.right
                anchors.rightMargin: Theme.space.xs
                anchors.verticalCenter: parent.verticalCenter
                visible: !row.hovered
                text: row.entry ? `#${row.entry.id}` : ""
                variant: "numeric"
                font.pixelSize: Theme.fontSize.caption
                font.weight: Font.Normal
                tone: "disabled"
            }

            IconButton {
                id: removeButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                opacity: row.hovered ? 1 : 0
                icon: "trash-2"
                iconSize: 14
                tone: hovered ? "danger" : "faint"
                onClicked: row.removeRequested()
            }
        }
    }
}
