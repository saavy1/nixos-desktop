import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: launcher

    readonly property var modes: [
        { id: "applications", label: "Apps", shortLabel: "APP", prefix: "", hint: "Search applications…  ·  > @ / = ? #" },
        { id: "clipboard", label: "Clipboard", shortLabel: "CLIP", prefix: "#", hint: "Search clipboard history…" },
        { id: "files", label: "Files", shortLabel: "FILE", prefix: "/", hint: "Search files in your home directory…" },
        { id: "calculator", label: "Calculate", shortLabel: "CALC", prefix: "=", hint: "Calculate or convert units…" },
        { id: "commands", label: "Command", shortLabel: "CMD", prefix: ">", hint: "Enter a command and arguments…" },
        { id: "windows", label: "Windows", shortLabel: "WIN", prefix: "@", hint: "Search open windows…" },
        { id: "web", label: "Web", shortLabel: "WEB", prefix: "?", hint: "Search the web…" }
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
    property int actionIndex: 0
    property string confirmationKey: ""
    property string clipboardPreviewPath: ""
    property int clipboardPreviewRevision: 0
    readonly property int sourceLimit: 2500
    readonly property var calculation: calculate(searchText.trim())
    readonly property var parsedCommand: parseCommand(searchText.trim())
    readonly property string homeDirectory: Quickshell.env("HOME") || "/"
    readonly property string runtimeDirectory: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property var webProviders: parseWebProviders(Quickshell.env("SOLITUDE_WEB_SEARCH_PROVIDERS"))
    readonly property var selectedEntry: results.currentItem ? results.currentItem.entry : null
    readonly property var selectedActions: actionsFor(selectedEntry)
    readonly property string clipboardPreviewSource: clipboardPreviewPath.length > 0
        ? `file://${clipboardPreviewPath}?v=${clipboardPreviewRevision}`
        : ""

    readonly property var filteredValues: {
        const needle = normalize(searchText)
        let candidates = []

        if (mode === "applications") {
            const applications = DesktopEntries.applications.values.slice(0, sourceLimit)
            candidates = applications.map(entry => {
                const command = entry.command || []
                const stableId = entry.id || `${entry.name || "application"}|${command.join("\u001f")}`
                const keywords = Array.isArray(entry.keywords) ? entry.keywords.join(" ") : String(entry.keywords || "")
                const categories = Array.isArray(entry.categories) ? entry.categories.join(" ") : String(entry.categories || "")
                return {
                    kind: "application",
                    category: applicationCategory(entry),
                    key: `application:${stableId}`,
                    label: entry.name || "Unnamed application",
                    subtitle: entry.genericName || entry.comment || "Application",
                    searchable: `${entry.name || ""} ${entry.genericName || ""} ${entry.comment || ""} ${keywords} ${categories} ${applicationAliases(entry)} ${command.join(" ")}`,
                    icon: entry.icon || "",
                    payload: entry,
                    preview: entry.comment || entry.genericName || "Launch application",
                    meta: command.join(" ")
                }
            })
        } else if (mode === "clipboard") {
            candidates = clipboardEntries.slice(0, sourceLimit).map(raw => {
                const preview = raw.replace(/^\d+\s+/, "")
                const binary = /\[\[\s*binary data/i.test(preview)
                const image = binary && /(?:image\/|\bpng\b|\bjpe?g\b|\bwebp\b|\bgif\b|\bbmp\b)/i.test(preview)
                return {
                    kind: "clipboard",
                    key: `clipboard:${raw}`,
                    label: image ? "Clipboard image" : binary ? "Clipboard data" : preview || "Clipboard entry",
                    subtitle: image ? "Image from clipboard history" : "Copy from clipboard history",
                    searchable: `${preview} ${image ? "image picture screenshot" : ""}`,
                    icon: image ? "image-x-generic" : "edit-paste",
                    payload: raw,
                    image,
                    preview: image ? "Decoded image preview" : preview,
                    meta: raw.match(/^\d+/) ? `History entry ${raw.match(/^\d+/)[0]}` : "Clipboard history"
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
                    payload: path,
                    preview: "Open with the default application",
                    meta: path
                }
            })
        } else if (mode === "calculator") {
            if (searchText.trim().length > 0 && calculation.ok) {
                candidates = [{
                    kind: "calculator",
                    key: `calculator:${searchText.trim()}`,
                    label: calculation.text,
                    subtitle: `${calculation.detail || searchText.trim()}  ·  Enter copies result`,
                    searchable: searchText,
                    icon: "accessories-calculator",
                    payload: calculation.text,
                    preview: calculation.detail || searchText.trim(),
                    meta: "Copy result to clipboard"
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
                    historyValue: searchText.trim(),
                    preview: "Run directly without a shell",
                    meta: parsedCommand.argv.join("  ·  "),
                    dangerous: /^(?:rm|rmdir|shutdown|reboot|poweroff|systemctl|uwsm)$/i.test(parsedCommand.argv[0])
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
                    payload: window.address,
                    preview: `Focus ${appClass}`,
                    meta: `${workspaceName}  ·  ${window.address}`
                }
            })
        } else if (mode === "web" && searchText.trim().length > 0) {
            const request = webRequest(searchText)
            if (request.query.length > 0) {
                candidates = [{
                    kind: "web",
                    key: `web:${request.provider.key}:${request.query}`,
                    label: request.query,
                    subtitle: `Search ${request.provider.label}`,
                    searchable: `${searchText} ${request.query} ${request.provider.label} ${request.provider.key}`,
                    icon: "web-browser",
                    payload: request.provider.url + encodeURIComponent(request.query),
                    historyValue: `${request.provider.key} ${request.query}`,
                    preview: `Open results from ${request.provider.label}`,
                    meta: webProviders.map(provider => `${provider.key} ${provider.label}`).join("  ·  ")
                }]
            }
        }

        const resultLimit = mode === "applications" && needle.length === 0 ? 80 : Theme.launcherMaxResults
        const ranked = candidates
            .map(candidate => {
                const fuzzy = fuzzyScore(needle, normalize(candidate.searchable || candidate.label))
                const usage = historyEntry(candidate.key)
                candidate.usageCount = usage.count || 0
                candidate.lastUsed = usage.lastUsed || 0
                candidate.recent = candidate.lastUsed > Date.now() - 7 * 24 * 60 * 60 * 1000
                candidate.group = mode === "applications"
                    ? needle.length === 0 && candidate.usageCount > 0 ? "Frequent" : candidate.category
                    : modes[modeIndex].label
                return { candidate, score: fuzzy + historyScore(candidate.key) }
            })
            .filter(scored => scored.score > -1000000)
            .sort((left, right) => {
                if (mode === "applications" && needle.length === 0) {
                    const groupOrder = applicationCategoryOrder(left.candidate.group) - applicationCategoryOrder(right.candidate.group)
                    if (groupOrder !== 0)
                        return groupOrder
                }
                if (left.score !== right.score)
                    return right.score - left.score
                const leftHistory = historyEntry(left.candidate.key)
                const rightHistory = historyEntry(right.candidate.key)
                if (leftHistory.lastUsed !== rightHistory.lastUsed)
                    return rightHistory.lastUsed - leftHistory.lastUsed
                const labelOrder = left.candidate.label.localeCompare(right.candidate.label)
                return labelOrder !== 0 ? labelOrder : left.candidate.key.localeCompare(right.candidate.key)
            })
            .slice(0, resultLimit)
            .map(scored => scored.candidate)
        let previousGroup = ""
        ranked.forEach(candidate => {
            candidate.showGroupHeader = mode === "applications" && needle.length === 0 && candidate.group !== previousGroup
            previousGroup = candidate.group
        })
        return ranked
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
    function prefixMode(prefix) {
        const routes = { ">": "commands", "@": "windows", "/": "files", "=": "calculator", "?": "web", "#": "clipboard" }
        const target = routes[prefix]
        return target ? modes.findIndex(item => item.id === target) : -1
    }

    function parseWebProviders(raw) {
        const defaults = [
            { key: "ddg", label: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
            { key: "g", label: "Google", url: "https://www.google.com/search?q=" },
            { key: "gh", label: "GitHub", url: "https://github.com/search?q=" },
            { key: "nix", label: "Nix packages", url: "https://search.nixos.org/packages?query=" },
            { key: "crates", label: "crates.io", url: "https://crates.io/search?q=" },
            { key: "npm", label: "npm", url: "https://www.npmjs.com/search?q=" }
        ]
        if (!raw || String(raw).trim().length === 0)
            return defaults
        try {
            const parsed = JSON.parse(raw)
            const valid = Array.isArray(parsed) ? parsed.filter(item => item && /^[a-z0-9_-]+$/i.test(item.key || "")
                && String(item.label || "").length > 0 && /^https?:\/\//.test(item.url || "")) : []
            return valid.length > 0 ? valid : defaults
        } catch (error) {
            return defaults
        }
    }

    function webRequest(value) {
        const words = String(value || "").trim().split(/\s+/).filter(word => word.length > 0)
        let provider = webProviders[0]
        if (words.length > 1) {
            const matched = webProviders.find(item => item.key === words[0].toLowerCase())
            if (matched) {
                provider = matched
                words.shift()
            }
        }
        return { provider, query: words.join(" ") }
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
    function applicationCategory(entry) {
        const categories = normalize(Array.isArray(entry.categories) ? entry.categories.join(" ") : entry.categories)
        const combined = `${categories} ${normalize(entry.name)} ${applicationAliases(entry)}`
        if (/\bgame\b/.test(combined))
            return "Games"
        if (/audiovideo|\baudio\b|\bvideo\b|\bmusic\b|\bplayer\b/.test(combined))
            return "Media"
        if (/\bdevelopment\b|\bide\b|\beditor\b|\bcode\b/.test(combined))
            return "Development"
        if (/network|webbrowser|\bbrowser\b|\binternet\b|\bemail\b/.test(combined))
            return "Internet"
        if (/graphics|photography|2dgraphics|3dgraphics/.test(combined))
            return "Creative"
        if (/\boffice\b|wordprocessor|spreadsheet|presentation/.test(combined))
            return "Office"
        if (/\bsystem\b|\bsettings\b|\bsecurity\b|package manager/.test(combined))
            return "System"
        return "Utilities"
    }
    function applicationCategoryOrder(category) {
        const order = ["Frequent", "Development", "Internet", "Media", "Creative", "Games", "Office", "Utilities", "System"]
        const index = order.indexOf(category)
        return index >= 0 ? index : order.length
    }


    function actionToken(entry, actionId) {
        return entry ? `${entry.key}:${actionId}` : ""
    }

    function actionNeedsConfirmation(entry, actionId) {
        return entry && (actionId === "close" || actionId === "delete" || actionId === "primary" && entry.dangerous)
    }

    function actionsFor(entry) {
        if (!entry)
            return []
        function label(actionId, text) {
            return actionNeedsConfirmation(entry, actionId) && confirmationKey === actionToken(entry, actionId)
                ? `Confirm ${text.toLowerCase()}` : text
        }
        const primary = entry.kind === "calculator" || entry.kind === "clipboard" ? "Copy"
            : entry.kind === "command" ? "Run" : entry.kind === "window" ? "Focus" : "Open"
        const actions = [{ id: "primary", label: label("primary", primary) }]
        if (["application", "command", "file", "web"].includes(entry.kind))
            actions.push({ id: "copy", label: "Copy details" })
        if (entry.kind === "file")
            actions.push({ id: "reveal", label: "Reveal folder" })
        if (entry.kind === "clipboard")
            actions.push({ id: "delete", label: label("delete", "Delete history entry") })
        if (entry.kind === "window")
            actions.push({ id: "close", label: label("close", "Close window") })
        if (historyEntry(entry.key).count > 0)
            actions.push({ id: "forget", label: "Forget ranking" })
        return actions
    }

    function updateSelectedPreview() {
        actionIndex = 0
        confirmationKey = ""
        clipboardPreviewPath = ""
        const entry = selectedEntry
        if (!entry || entry.kind !== "clipboard" || !entry.image)
            return
        clipboardPreviewPath = `${runtimeDirectory}/solitude-clipboard-preview`
        clipboardPreviewProc.command = ["clipboard-preview", entry.payload, clipboardPreviewPath]
        clipboardPreviewProc.running = true
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
        const value = entries[key]
        return value || ({ count: 0, lastUsed: 0 })
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
                historyValue: entry.value,
                preview: "Previously successful command",
                meta: entry.value,
                dangerous: /^(?:rm|rmdir|shutdown|reboot|poweroff|systemctl|uwsm)$/i.test(parsed.argv[0])
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

    function convertUnits(text) {
        const match = String(text || "").trim().match(/^([+-]?(?:\d+(?:\.\d*)?|\.\d+))\s*([a-zA-Z°]+)\s+(?:to|in|->)\s+([a-zA-Z°]+)$/)
        if (!match)
            return null
        const aliases = {
            millimeter: "mm", millimeters: "mm", centimeter: "cm", centimeters: "cm",
            meter: "m", meters: "m", kilometer: "km", kilometers: "km",
            inch: "in", inches: "in", foot: "ft", feet: "ft", yard: "yd", yards: "yd", mile: "mi", miles: "mi",
            gram: "g", grams: "g", kilogram: "kg", kilograms: "kg", ounce: "oz", ounces: "oz",
            pound: "lb", pounds: "lb", lbs: "lb", second: "s", seconds: "s", minute: "min", minutes: "min",
            hour: "h", hours: "h", day: "d", days: "d", byte: "b", bytes: "b",
            celsius: "c", fahrenheit: "f", kelvin: "k", "°c": "c", "°f": "f"
        }
        function canonical(unit) {
            const clean = unit.toLowerCase()
            return aliases[clean] || clean
        }
        const value = Number(match[1])
        const from = canonical(match[2])
        const to = canonical(match[3])
        if (["c", "f", "k"].includes(from) && ["c", "f", "k"].includes(to)) {
            const kelvin = from === "c" ? value + 273.15 : from === "f" ? (value - 32) * 5 / 9 + 273.15 : value
            const converted = to === "c" ? kelvin - 273.15 : to === "f" ? (kelvin - 273.15) * 9 / 5 + 32 : kelvin
            return { ok: true, text: `${Number(converted.toPrecision(12))} ${to}`, detail: `${value} ${from} → ${to}` }
        }
        const groups = [
            { mm: 0.001, cm: 0.01, m: 1, km: 1000, in: 0.0254, ft: 0.3048, yd: 0.9144, mi: 1609.344 },
            { mg: 0.000001, g: 0.001, kg: 1, oz: 0.028349523125, lb: 0.45359237 },
            { ms: 0.001, s: 1, min: 60, h: 3600, d: 86400 },
            { b: 1, kb: 1000, mb: 1000000, gb: 1000000000, tb: 1000000000000, kib: 1024, mib: 1048576, gib: 1073741824 }
        ]
        const group = groups.find(candidate => candidate[from] !== undefined && candidate[to] !== undefined)
        if (!group)
            return { ok: false, error: `Cannot convert ${from} to ${to}` }
        const converted = value * group[from] / group[to]
        return { ok: true, text: `${Number(converted.toPrecision(12))} ${to}`, detail: `${value} ${from} → ${to}` }
    }

    function calculate(text) {
        if (text.length === 0)
            return { ok: false, error: "" }
        const conversion = convertUnits(text)
        if (conversion)
            return conversion

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
        results.currentIndex = -1
        clipboardPreviewPath = ""
        Qt.callLater(() => {
            results.currentIndex = results.count > 0 ? 0 : -1
            Qt.callLater(() => updateSelectedPreview())
        })
    }

    function setMode(nextIndex, clearQuery) {
        modeIndex = (nextIndex + modes.length) % modes.length
        activationError = ""
        confirmationKey = ""
        actionIndex = 0
        clipboardPreviewPath = ""
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
        confirmationKey = ""
        actionIndex = 0
        clipboardPreviewPath = ""
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
    function entryDetails(entry) {
        if (!entry)
            return ""
        if (entry.kind === "application")
            return (entry.payload.command || []).join(" ")
        if (entry.kind === "file" || entry.kind === "web")
            return entry.payload
        if (entry.kind === "window")
            return `${entry.label} ${entry.payload}`
        return entry.label
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

    function executeAction(entry, actionId) {
        if (!entry)
            return
        const token = actionToken(entry, actionId)
        if (actionNeedsConfirmation(entry, actionId) && confirmationKey !== token) {
            confirmationKey = token
            return
        }
        confirmationKey = ""
        if (actionId === "primary") {
            activate(entry)
        } else if (actionId === "copy") {
            Quickshell.execDetached(["wl-copy", entryDetails(entry)])
        } else if (actionId === "reveal") {
            const slash = String(entry.payload || "").lastIndexOf("/")
            Quickshell.execDetached(["xdg-open", slash > 0 ? entry.payload.slice(0, slash) : homeDirectory])
        } else if (actionId === "delete" && entry.kind === "clipboard") {
            clipboardDeleteProc.command = ["clipboard-delete", entry.payload]
            clipboardDeleteProc.running = true
        } else if (actionId === "close" && entry.kind === "window" && /^0x[0-9a-f]+$/i.test(entry.payload)) {
            Hyprland.dispatch(`closewindow address:${entry.payload}`)
            Qt.callLater(() => Hyprland.refreshToplevels())
        } else if (actionId === "forget") {
            forgetHistory(entry.key)
        }
    }

    function executeSelectedAction() {
        if (!selectedEntry || selectedActions.length === 0)
            return
        const index = Math.max(0, Math.min(selectedActions.length - 1, actionIndex))
        executeAction(selectedEntry, selectedActions[index].id)
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
            Quickshell.execDetached(["xdg-open", entry.payload])
        } else {
            activationError = "This result cannot be opened"
            return
        }

        recordSuccessful(entry)
        close()
    }

    function activateCurrent() {
        executeSelectedAction()
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { launcher.toggle() }
        function search(text: string): void {
            if (!launcher.visible)
                launcher.open("applications")
            query.text = text
            Qt.callLater(() => query.forceActiveFocus())
        }
        function state(): string {
            return JSON.stringify({
                mode: launcher.mode,
                query: launcher.searchText,
                results: results.count,
                selected: launcher.selectedEntry ? launcher.selectedEntry.label : "",
                actions: launcher.selectedActions.map(action => action.id)
            })
        }
        function activateSelected(): void { launcher.activateCurrent() }
        function refreshPreview(): void { launcher.updateSelectedPreview() }
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
        id: clipboardPreviewProc

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                launcher.clipboardPreviewRevision += 1
            else
                launcher.clipboardPreviewPath = ""
        }
    }

    Process {
        id: clipboardDeleteProc

        onExited: (exitCode, exitStatus) => {
            launcher.confirmationKey = ""
            if (exitCode === 0)
                launcher.loadClipboard()
            else
                launcher.activationError = "Clipboard entry could not be deleted"
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
                    const targetMode = text.length > 0 ? launcher.prefixMode(text.charAt(0)) : -1
                    if (targetMode >= 0) {
                        const remainder = text.slice(1).replace(/^\s+/, "")
                        launcher.setMode(targetMode, false)
                        if (text !== remainder) {
                            text = remainder
                            return
                        }
                    }
                    launcher.searchText = text
                    launcher.activationError = ""
                    launcher.confirmationKey = ""
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
                    } else if (event.key === Qt.Key_Left) {
                        launcher.actionIndex = Math.max(0, launcher.actionIndex - 1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right) {
                        launcher.actionIndex = Math.min(launcher.selectedActions.length - 1, launcher.actionIndex + 1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
                        const copyIndex = launcher.selectedActions.findIndex(action => action.id === "copy")
                        if (copyIndex >= 0)
                            launcher.executeAction(launcher.selectedEntry, "copy")
                        event.accepted = true
                    } else if (event.key === Qt.Key_Delete) {
                        const deleteIndex = launcher.selectedActions.findIndex(action => action.id === "delete")
                        if (deleteIndex >= 0)
                            launcher.executeAction(launcher.selectedEntry, "delete")
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
            visible: false
            height: 0
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

        Rectangle {
            id: previewPane
            anchors {
                top: searchBox.bottom
                right: parent.right
                bottom: footer.top
                topMargin: 9
                rightMargin: 16
                bottomMargin: 8
            }
            width: 340
            radius: Theme.radiusMedium
            color: Theme.backgroundDark
            border.color: Theme.backgroundDarker
            border.width: Theme.borderWidth

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 18
                }
                spacing: 12

                Row {
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        width: 42
                        height: 42
                        radius: Theme.radiusSmall
                        color: Theme.selection

                        IconImage {
                            anchors.centerIn: parent
                            implicitWidth: 28
                            implicitHeight: 28
                            source: launcher.selectedEntry && launcher.selectedEntry.icon
                                ? Quickshell.iconPath(launcher.selectedEntry.icon, true) : ""
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !launcher.selectedEntry || !launcher.selectedEntry.icon
                            text: launcher.selectedEntry ? launcher.selectedEntry.label.charAt(0).toUpperCase() : "?"
                            color: Theme.accent
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontBody + 2
                            font.weight: Font.Bold
                        }
                    }

                    Column {
                        width: parent.width - 52
                        spacing: 3

                        Text {
                            width: parent.width
                            text: launcher.selectedEntry ? launcher.selectedEntry.label : "No result selected"
                            color: Theme.foreground
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontBody + 1
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: launcher.selectedEntry
                                ? `${launcher.selectedEntry.kind.toUpperCase()}${launcher.selectedEntry.recent ? "  ·  RECENT" : ""}${launcher.selectedEntry.usageCount > 0 ? `  ·  USED ${launcher.selectedEntry.usageCount}×` : ""}`
                                : "Navigate results to preview"
                            color: launcher.selectedEntry && launcher.selectedEntry.recent ? Theme.accent : Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontCaption
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    visible: launcher.clipboardPreviewSource.length > 0
                    width: parent.width
                    height: visible ? 170 : 0
                    radius: Theme.radiusSmall
                    color: Theme.backgroundDarker
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 6
                        source: launcher.clipboardPreviewSource
                        fillMode: Image.PreserveAspectFit
                        cache: false
                    }
                }

                Text {
                    width: parent.width
                    text: launcher.selectedEntry ? launcher.selectedEntry.preview || launcher.selectedEntry.subtitle : ""
                    color: Theme.foregroundSoft
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontBody
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: launcher.selectedEntry ? launcher.selectedEntry.meta || launcher.selectedEntry.subtitle : ""
                    color: Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontCaption
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideMiddle
                }

                Text {
                    visible: launcher.confirmationKey.length > 0
                    width: parent.width
                    text: "Press Enter again to confirm this destructive action"
                    color: Theme.warning
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                    wrapMode: Text.Wrap
                }

                Column {
                    width: parent.width
                    spacing: 7

                    Repeater {
                        model: launcher.selectedActions

                        Rectangle {
                            required property var modelData
                            required property int index
                            width: parent ? parent.width : 0
                            height: 34
                            radius: Theme.radiusSmall
                            color: index === launcher.actionIndex ? Theme.selection : actionHover.containsMouse ? Theme.backgroundDarker : "transparent"
                            border.color: index === launcher.actionIndex ? Theme.accent : Theme.border
                            border.width: Theme.borderWidth

                            Text {
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10
                                }
                                text: parent.modelData.label
                                color: parent.index === launcher.actionIndex ? Theme.foreground : Theme.foregroundSoft
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontCaption
                                font.weight: parent.index === launcher.actionIndex ? Font.DemiBold : Font.Normal
                            }

                            Text {
                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    rightMargin: 10
                                }
                                text: parent.index === launcher.actionIndex ? "↵" : ""
                                color: Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontCaption
                            }

                            MouseArea {
                                id: actionHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: launcher.actionIndex = parent.index
                                onClicked: launcher.executeAction(launcher.selectedEntry, parent.modelData.id)
                            }
                        }
                    }
                }
            }
        }

        ListView {
            id: results
            anchors {
                top: searchBox.bottom
                left: parent.left
                right: previewPane.left
                bottom: footer.top
                topMargin: 9
                leftMargin: 16
                rightMargin: 8
                bottomMargin: 8
            }
            model: resultModel
            spacing: 3
            clip: true
            currentIndex: -1
            onCurrentIndexChanged: launcher.updateSelectedPreview()


            delegate: Rectangle {
                id: result
                required property var modelData
                required property int index
                property var entry: modelData
                width: results.width
                height: result.modelData.showGroupHeader === true ? 86 : 58
                radius: Theme.radiusMedium
                color: ListView.isCurrentItem ? Theme.selection : resultHover.containsMouse ? Theme.backgroundDark : "transparent"
                Text {
                    visible: result.modelData.showGroupHeader === true
                    anchors {
                        top: parent.top
                        left: parent.left
                        topMargin: 6
                        leftMargin: 10
                    }
                    text: result.modelData.group || ""
                    color: Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.DemiBold
                }


                IconImage {
                    id: resultIcon
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 12
                        verticalCenterOffset: result.modelData.showGroupHeader === true ? 14 : 0
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
                        verticalCenterOffset: result.modelData.showGroupHeader === true ? 14 : 0
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
                        verticalCenterOffset: result.modelData.showGroupHeader === true ? 14 : 0
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
                    onClicked: launcher.executeAction(result.modelData, "primary")
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
                text: "> command   @ window   / file   = calculate   ? web   # clipboard   ↑↓ navigate   ←→ action"
                color: Theme.muted
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontCaption
            }
        }
    }
}
