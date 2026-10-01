import Quickshell
import Quickshell.Io
import QtQuick

// Subscription limits (live, via `omp usage --json`) and today's token totals
// (from local session logs, via `agent-usage-today`). Shared by the bar chip
// and the Agents panel.
Item {
    id: usage

    // [{ provider, name, plan, account, fetchedAt, credits, limits: [{ id, label, usedFraction, resetsAt, status }] }]
    property var providers: []
    property double limitsFetchedAt: 0
    property string limitsError: ""
    property var today: null
    property string todayError: ""
    // Poll faster while someone is looking at the numbers.
    property bool active: false

    readonly property bool loading: limitsProc.running || todayProc.running
    // Highest used fraction among limits that are still usable; exhausted
    // accounts are reported in the panel but would pin the chip at 100%.
    readonly property var tightest: {
        let best = null
        for (const provider of providers) {
            for (const limit of provider.limits) {
                if (limit.status === "exhausted" || limit.usedFraction === null)
                    continue
                if (!best || limit.usedFraction > best.usedFraction)
                    best = Object.assign({ providerName: provider.name }, limit)
            }
        }
        return best
    }

    function providerName(id): string {
        switch (id) {
        case "anthropic":
            return "Claude"
        case "openai-codex":
            return "Codex"
        case "opencode-go":
            return "OpenCode Go"
        default:
            return id
        }
    }

    function windowLabel(limit): string {
        const label = limit.window && limit.window.label ? limit.window.label : limit.label
        const suffix = limit.label.match(/\(([^)]+)\)\s*$/)
        return suffix ? `${label} · ${suffix[1]}` : label
    }

    function parseLimits(text): void {
        let data
        try {
            data = JSON.parse(text)
        } catch (error) {
            limitsError = "Could not read omp usage output"
            return
        }

        const order = ["anthropic", "openai-codex"]
        const rank = id => order.indexOf(id) < 0 ? order.length : order.indexOf(id)
        providers = (data.reports || []).slice().sort((left, right) => rank(left.provider) - rank(right.provider)).map(report => {
            const metadata = report.metadata || {}
            return {
                provider: report.provider,
                name: providerName(report.provider),
                plan: metadata.planType || "",
                account: metadata.email || "",
                fetchedAt: report.fetchedAt || data.generatedAt || 0,
                credits: report.resetCredits ? report.resetCredits.availableCount || 0 : 0,
                limits: (report.limits || []).map(limit => ({
                    id: limit.id,
                    label: windowLabel(limit),
                    usedFraction: limit.amount && typeof limit.amount.usedFraction === "number" ? limit.amount.usedFraction : null,
                    resetsAt: limit.window && limit.window.resetsAt ? limit.window.resetsAt : 0,
                    status: limit.status || "ok"
                }))
            }
        })
        limitsFetchedAt = data.generatedAt || Date.now()
        limitsError = ""
    }

    function refresh(): void {
        if (!limitsProc.running)
            limitsProc.running = true
        if (!todayProc.running)
            todayProc.running = true
    }

    Process {
        id: limitsProc

        command: ["omp", "usage", "--json", "--redact"]
        workingDirectory: "/tmp"
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    usage.parseLimits(text)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                usage.limitsError = `omp usage exited with ${exitCode}`
        }
    }

    Process {
        id: todayProc

        command: ["agent-usage-today"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    usage.today = JSON.parse(text)
                    usage.todayError = ""
                } catch (error) {
                    usage.todayError = "Could not read session logs"
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                usage.todayError = `agent-usage-today exited with ${exitCode}`
        }
    }

    Timer {
        interval: usage.active ? 60000 : 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: usage.refresh()
    }
}
