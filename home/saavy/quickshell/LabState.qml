import Quickshell
import Quickshell.Io
import QtQuick

// Homelab health: ZFS on the NAS, the k3s cluster, and the model server on the
// DGX Spark. The Spark is probed through its OpenAI-compatible API so it works
// whichever runtime (vLLM, SGLang, …) is serving; host stats come over
// `tailscale ssh`. Shared by the bar chip and the Lab panel.
Item {
    id: lab

    property string nasHost: "saavy@superbloom"
    property string sparkHost: "saavy@spark"
    property string sparkEndpoint: "http://spark.tailc2db57.ts.net:8888"
    // Poll faster while the panel is open.
    property bool active: false

    // ZFS: [{ name, size, alloc, capacity, health }] and problem device lines.
    property var pools: []
    property var poolProblems: []
    property string zfsError: ""
    property double zfsUpdatedAt: 0

    // k3s
    property var nodes: []
    property int podCount: 0
    property int podsHealthy: 0
    property var podProblems: []
    property var apps: []
    property var kustomizations: []
    property string clusterError: ""

    // Journal warnings the journal-triage service rated above noise:
    // [{ key, unit, verdict, summary, sample, count, last_seen, dismissed }].
    property var journalItems: []

    // Spark model server
    property bool sparkOnline: false
    property string sparkError: ""
    property var sparkModels: []
    property int sparkLatency: -1
    property string sparkRuntime: ""
    property var sparkStats: ({})
    property double lastGenerated: -1
    property double lastGeneratedAt: 0
    property real tokensPerSecond: -1
    // Host: { gpuUtil, gpuTemp, power, memUsed, memTotal } and containers.
    property var sparkHostStats: null
    property var sparkContainers: []
    property string sparkHostError: ""

    readonly property var degradedPools: pools.filter(pool => pool.health !== "ONLINE")
    readonly property var notReadyNodes: nodes.filter(node => !node.ready)
    readonly property var unsyncedApps: apps.filter(app => app.sync !== "Synced" || app.health !== "Healthy")
    readonly property var failingKustomizations: kustomizations.filter(item => !item.ready)
    readonly property var journalProblems: journalItems.filter(item => !item.dismissed
        && (item.verdict === "problem" || item.verdict === "critical"))
    // "danger" | "warning" | "ok" | "unknown"
    readonly property string status: {
        if (degradedPools.length > 0 || notReadyNodes.length > 0 || journalProblems.some(item => item.verdict === "critical"))
            return "danger"
        if (podProblems.length > 0 || unsyncedApps.length > 0 || failingKustomizations.length > 0 || journalProblems.length > 0)
            return "warning"
        if (pools.length === 0 && nodes.length === 0)
            return "unknown"
        return "ok"
    }
    readonly property int issueCount: degradedPools.length + notReadyNodes.length + podProblems.length
        + unsyncedApps.length + failingKustomizations.length + journalProblems.length

    function dismissJournalItem(key): void {
        Quickshell.execDetached(["journal-triage", "dismiss", key])
    }

    function refresh(): void {
        for (const process of [zfsProc, nodesProc, podsProc, appsProc, fluxProc, sparkHostProc]) {
            if (!process.running)
                process.running = true
        }
        probeSpark()
    }

    // ---- ZFS -------------------------------------------------------------

    function parseZfs(text): void {
        const [listing, status] = text.split("\n---\n")
        pools = (listing || "").split("\n").filter(line => line.trim().length > 0).map(line => {
            const [name, size, alloc, capacity, health] = line.split("\t")
            return { name, size, alloc, capacity: parseInt(capacity) / 100, health }
        })
        // Device rows in the config table whose own state is bad; pool/vdev
        // rows only say DEGRADED as a consequence, so they're skipped.
        poolProblems = (status || "").split("\n")
            .map(line => line.trim())
            .filter(line => /^\S+\s+(FAULTED|UNAVAIL|REMOVED|OFFLINE)\s/.test(line))
            .map(line => {
                const [device, state, read, write, checksum, ...note] = line.split(/\s+/)
                return { device, state, errors: `${read}/${write}/${checksum}`, note: note.join(" ") }
            })
        zfsUpdatedAt = Date.now()
        zfsError = ""
    }

    // ---- k3s -------------------------------------------------------------

    function parseJson(text, onError) {
        try {
            return JSON.parse(text)
        } catch (error) {
            onError()
            return null
        }
    }

    function parseNodes(text): void {
        const data = parseJson(text, () => clusterError = "Could not read nodes")
        if (!data)
            return
        nodes = data.items.map(node => ({
            name: node.metadata.name,
            ready: (node.status.conditions || []).some(condition => condition.type === "Ready" && condition.status === "True"),
            version: node.status.nodeInfo ? node.status.nodeInfo.kubeletVersion : ""
        }))
        clusterError = ""
    }

    function parsePods(text): void {
        const data = parseJson(text, () => clusterError = "Could not read pods")
        if (!data)
            return
        const problems = []
        let healthy = 0
        for (const pod of data.items) {
            const phase = pod.status.phase
            if (phase === "Succeeded")
                continue
            const containers = pod.status.containerStatuses || []
            const ready = phase === "Running" && containers.length > 0 && containers.every(container => container.ready)
            if (ready) {
                healthy += 1
                continue
            }
            const waiting = containers.map(container => container.state && container.state.waiting ? container.state.waiting.reason : "")
                .find(reason => reason)
            problems.push({
                namespace: pod.metadata.namespace,
                name: pod.metadata.name,
                reason: waiting || phase || "NotReady",
                restarts: containers.reduce((total, container) => total + (container.restartCount || 0), 0)
            })
        }
        podCount = healthy + problems.length
        podsHealthy = healthy
        podProblems = problems
    }

    function parseApps(text): void {
        const data = parseJson(text, () => {})
        apps = data ? data.items.map(app => ({
            name: app.metadata.name,
            sync: app.status && app.status.sync ? app.status.sync.status : "Unknown",
            health: app.status && app.status.health ? app.status.health.status : "Unknown"
        })) : []
    }

    function parseFlux(text): void {
        const data = parseJson(text, () => {})
        kustomizations = data ? data.items.map(item => {
            const ready = (item.status && item.status.conditions || []).find(condition => condition.type === "Ready")
            return {
                name: item.metadata.name,
                ready: !!ready && ready.status === "True",
                message: ready ? ready.message : ""
            }
        }) : []
    }

    // ---- Spark -----------------------------------------------------------

    function request(path, onDone): void {
        const xhr = new XMLHttpRequest()
        const started = Date.now()
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE)
                onDone(xhr.status, xhr.responseText, Date.now() - started)
        }
        xhr.timeout = 5000
        xhr.open("GET", sparkEndpoint + path)
        xhr.send()
    }

    function probeSpark(): void {
        request("/v1/models", (status, text, elapsed) => {
            if (status !== 200) {
                sparkOnline = false
                sparkModels = []
                sparkLatency = -1
                sparkError = status === 0 ? "Not reachable" : `HTTP ${status}`
                return
            }
            const data = parseJson(text, () => {})
            sparkModels = data && data.data ? data.data.map(model => ({
                id: model.id,
                context: model.max_model_len || model.context_length || 0,
                owner: model.owned_by || ""
            })) : []
            sparkOnline = true
            sparkLatency = elapsed
            sparkError = ""
            request("/metrics", (metricsStatus, metricsText) => {
                if (metricsStatus === 200)
                    parseMetrics(metricsText)
            })
        })
    }

    // Sums Prometheus samples per metric name, ignoring labels.
    function parseMetrics(text): void {
        const sums = {}
        for (const line of text.split("\n")) {
            if (line.length === 0 || line[0] === "#")
                continue
            const match = line.match(/^([a-zA-Z_:][a-zA-Z0-9_:]*)(\{[^}]*\})?\s+([^\s]+)/)
            if (match)
                sums[match[1]] = (sums[match[1]] || 0) + Number(match[3])
        }
        const pick = (...names) => {
            for (const name of names) {
                if (sums[name] !== undefined && isFinite(sums[name]))
                    return sums[name]
            }
            return null
        }

        const runtime = Object.keys(sums).some(name => name.startsWith("vllm:")) ? "vllm"
            : Object.keys(sums).some(name => name.startsWith("sglang:")) ? "sglang"
            : ""
        sparkRuntime = runtime
        sparkStats = {
            running: pick("vllm:num_requests_running", "sglang:num_running_reqs"),
            waiting: pick("vllm:num_requests_waiting", "sglang:num_queue_reqs"),
            cache: pick("vllm:kv_cache_usage_perc", "vllm:gpu_cache_usage_perc", "sglang:token_usage")
        }

        const generated = pick("vllm:generation_tokens_total", "sglang:generation_tokens_total")
        const throughput = pick("sglang:gen_throughput")
        const now = Date.now()
        if (throughput !== null) {
            tokensPerSecond = throughput
        } else if (generated !== null && lastGenerated >= 0 && generated >= lastGenerated && now > lastGeneratedAt) {
            tokensPerSecond = (generated - lastGenerated) / ((now - lastGeneratedAt) / 1000)
        }
        if (generated !== null) {
            lastGenerated = generated
            lastGeneratedAt = now
        }
    }

    function parseSparkHost(text): void {
        const [gpu, memory, containers] = text.split("\n---\n")
        const gpuFields = (gpu || "").trim().split(",").map(field => parseFloat(field))
        const memLine = (memory || "").split("\n").find(line => line.startsWith("Mem:"))
        const mem = memLine ? memLine.split(/\s+/) : []
        sparkHostStats = {
            gpuUtil: isFinite(gpuFields[0]) ? gpuFields[0] / 100 : null,
            gpuTemp: isFinite(gpuFields[1]) ? gpuFields[1] : null,
            power: isFinite(gpuFields[2]) ? gpuFields[2] : null,
            memTotal: mem.length > 2 ? parseInt(mem[1]) : 0,
            memUsed: mem.length > 2 ? parseInt(mem[2]) : 0
        }
        sparkContainers = (containers || "").split("\n").filter(line => line.includes("|")).map(line => {
            const [name, image, state] = line.split("|")
            return { name, image, state, running: state.startsWith("Up") }
        })
        sparkHostError = ""
    }

    FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/journal-triage.json`
        preload: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                lab.journalItems = JSON.parse(text()).items || []
            } catch (error) {}
        }
    }

    Process {
        id: zfsProc

        command: ["tailscale", "ssh", lab.nasHost, "zpool list -H -o name,size,alloc,cap,health; echo ---; zpool status -x"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    lab.parseZfs(text)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                lab.zfsError = `Could not reach ${lab.nasHost.split("@")[1]}`
        }
    }

    Process {
        id: nodesProc

        command: ["kubectl", "get", "nodes", "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: lab.parseNodes(text)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                lab.clusterError = "kubectl could not reach the cluster"
        }
    }

    Process {
        id: podsProc

        command: ["kubectl", "get", "pods", "-A", "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: lab.parsePods(text)
        }
    }

    Process {
        id: appsProc

        command: ["kubectl", "get", "applications.argoproj.io", "-A", "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: lab.parseApps(text)
        }
    }

    Process {
        id: fluxProc

        command: ["kubectl", "get", "kustomizations.kustomize.toolkit.fluxcd.io", "-A", "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: lab.parseFlux(text)
        }
    }

    Process {
        id: sparkHostProc

        command: ["tailscale", "ssh", lab.sparkHost,
            "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw --format=csv,noheader,nounits; echo ---; free -m; echo ---; docker ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    lab.parseSparkHost(text)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                lab.sparkHostError = "Could not reach the Spark host"
        }
    }

    Timer {
        interval: lab.active ? 30000 : 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: lab.refresh()
    }

    // Model load/throughput changes quickly; poll the API more often when open.
    Timer {
        interval: 5000
        running: lab.active
        repeat: true
        onTriggered: lab.probeSpark()
    }
}
