import QtQuick
import qs.ui

PopupPanel {
    id: root

    required property var lab

    name: "lab"
    title: "Lab"
    subtitle: lab.status === "unknown" ? "checking…"
        : lab.issueCount === 0 ? "all systems healthy"
        : `${lab.issueCount} ${lab.issueCount === 1 ? "issue" : "issues"}`
    cardWidth: 460

    function percent(value): string {
        return value === null || value === undefined ? "—" : `${Math.round(value * 100)}%`
    }

    onOpening: {
        lab.active = true
        lab.refresh()
    }
    onShownChanged: {
        if (!shown)
            lab.active = false
    }

    headerTrailing: [
        IconButton {
            icon: "refresh-cw"
            onClicked: root.lab.refresh()
        }
    ]

    // One quiet status line: dot, label, value on the right.
    component StatusRow: Item {
        id: statusRow

        property string label
        property string value
        property string tone: "success"

        width: parent ? parent.width : 0
        height: 26

        Rectangle {
            id: dot

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: Theme.tone(statusRow.tone)
        }

        Label {
            anchors.left: dot.right
            anchors.leftMargin: Theme.space.md
            anchors.right: statusValue.left
            anchors.rightMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            text: statusRow.label
        }

        Label {
            id: statusValue

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: statusRow.value
            variant: "numeric"
            font.pixelSize: Theme.fontSize.small
            tone: statusRow.tone === "success" ? "soft" : statusRow.tone
        }
    }

    // Label + value over a thin meter.
    component MeterRow: Column {
        id: meterRow

        property string label
        property string value
        property real fraction: 0
        property color fillColor: Theme.secondary

        width: parent ? parent.width : 0
        spacing: Theme.space.xs + 2

        Item {
            width: parent.width
            height: 18

            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: meterRow.label
                variant: "small"
                font.pixelSize: Theme.fontSize.bar
            }

            Label {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: meterRow.value
                variant: "numeric"
                font.pixelSize: Theme.fontSize.small
            }
        }

        Meter {
            width: parent.width
            value: meterRow.fraction
            fillColor: meterRow.fillColor
        }
    }

    // ---- Storage ---------------------------------------------------------

    SectionHeader {
        width: parent.width
        text: "Storage"
        trailing: root.lab.nasHost.split("@")[1]
        trailingTone: root.lab.degradedPools.length > 0 ? "danger" : "faint"
    }

    Column {
        width: parent.width
        spacing: Theme.space.md

        Repeater {
            model: root.lab.pools

            delegate: MeterRow {
                required property var modelData

                label: `${modelData.name} · ${modelData.health.toLowerCase()}`
                value: `${modelData.alloc} / ${modelData.size}`
                fraction: modelData.capacity
                fillColor: modelData.health !== "ONLINE" ? Theme.danger : modelData.capacity > 0.85 ? Theme.warning : Theme.secondary
            }
        }

        Repeater {
            model: root.lab.poolProblems

            delegate: Rectangle {
                required property var modelData

                width: parent ? parent.width : 0
                height: problemText.implicitHeight + Theme.space.md * 2
                radius: Theme.radius.small
                color: Theme.dangerTint

                Row {
                    id: problemText

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.md

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "hard-drive"
                        color: Theme.danger
                    }

                    Column {
                        width: parent.width - 28
                        spacing: 2

                        Label {
                            width: parent.width
                            text: `${modelData.device} ${modelData.state.toLowerCase()}`
                            variant: "numeric"
                            font.pixelSize: Theme.fontSize.small
                            tone: "danger"
                            elide: Text.ElideMiddle
                        }

                        Label {
                            width: parent.width
                            text: `read/write/checksum errors ${modelData.errors}${modelData.note ? " · " + modelData.note : ""} — replace the drive, then zpool replace`
                            variant: "caption"
                            tone: "soft"
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }

        Label {
            visible: root.lab.zfsError !== "" || root.lab.pools.length === 0
            width: parent.width
            text: root.lab.zfsError || "Reading pool status…"
            variant: "small"
            tone: root.lab.zfsError ? "warning" : "faint"
        }
    }

    // ---- Cluster ---------------------------------------------------------

    SectionHeader {
        width: parent.width
        text: "Cluster"
        trailing: root.lab.nodes.length > 0 ? `k3s · ${root.lab.nodes[0].version}` : "k3s"
    }

    Column {
        width: parent.width
        spacing: 0

        StatusRow {
            label: "Nodes"
            value: `${root.lab.nodes.length - root.lab.notReadyNodes.length}/${root.lab.nodes.length} ready`
            tone: root.lab.nodes.length === 0 ? "faint" : root.lab.notReadyNodes.length > 0 ? "danger" : "success"
        }

        StatusRow {
            label: "Pods"
            value: `${root.lab.podsHealthy}/${root.lab.podCount} ready`
            tone: root.lab.podCount === 0 ? "faint" : root.lab.podProblems.length > 0 ? "warning" : "success"
        }

        Repeater {
            model: root.lab.podProblems

            delegate: Label {
                required property var modelData

                width: parent ? parent.width : 0
                leftPadding: Theme.space.md + 6
                bottomPadding: Theme.space.xs
                text: `${modelData.namespace}/${modelData.name} · ${modelData.reason}${modelData.restarts > 0 ? " · " + modelData.restarts + " restarts" : ""}`
                variant: "caption"
                tone: "warning"
                elide: Text.ElideMiddle
            }
        }

        StatusRow {
            visible: root.lab.apps.length > 0
            label: "Argo CD apps"
            value: `${root.lab.apps.length - root.lab.unsyncedApps.length}/${root.lab.apps.length} synced`
            tone: root.lab.unsyncedApps.length > 0 ? "warning" : "success"
        }

        Repeater {
            model: root.lab.unsyncedApps

            delegate: Label {
                required property var modelData

                width: parent ? parent.width : 0
                leftPadding: Theme.space.md + 6
                bottomPadding: Theme.space.xs
                text: `${modelData.name} · ${modelData.sync.toLowerCase()} · ${modelData.health.toLowerCase()}`
                variant: "caption"
                tone: "warning"
            }
        }

        StatusRow {
            visible: root.lab.kustomizations.length > 0
            label: "Flux"
            value: `${root.lab.kustomizations.length - root.lab.failingKustomizations.length}/${root.lab.kustomizations.length} applied`
            tone: root.lab.failingKustomizations.length > 0 ? "warning" : "success"
        }

        Repeater {
            model: root.lab.failingKustomizations

            delegate: Label {
                required property var modelData

                width: parent ? parent.width : 0
                leftPadding: Theme.space.md + 6
                bottomPadding: Theme.space.xs
                text: `${modelData.name} · ${modelData.message}`
                variant: "caption"
                tone: "warning"
                elide: Text.ElideRight
            }
        }

        Label {
            visible: root.lab.clusterError !== ""
            width: parent.width
            topPadding: Theme.space.xs
            text: root.lab.clusterError
            variant: "small"
            tone: "warning"
        }
    }

    // ---- System log ------------------------------------------------------

    SectionHeader {
        width: parent.width
        text: "System log"
        trailing: root.lab.journalProblems.length > 0 ? `${root.lab.journalProblems.length} to fix` : "journal"
        trailingTone: root.lab.journalProblems.length > 0 ? "warning" : "faint"
    }

    Column {
        readonly property var visibleItems: root.lab.journalItems.filter(item => !item.dismissed).slice(0, 8)

        width: parent.width
        spacing: Theme.space.xs

        Repeater {
            model: parent.visibleItems

            delegate: Item {
                required property var modelData
                readonly property string tone: modelData.verdict === "critical" ? "danger"
                    : modelData.verdict === "problem" ? "warning" : "faint"

                width: parent ? parent.width : 0
                height: journalText.implicitHeight + Theme.space.sm * 2

                Rectangle {
                    x: 0
                    y: Theme.space.sm + 6
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.tone(parent.tone)
                }

                Column {
                    id: journalText

                    anchors {
                        left: parent.left
                        right: dismiss.left
                        leftMargin: Theme.space.md + 6
                        rightMargin: Theme.space.sm
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    Label {
                        width: parent.width
                        text: modelData.summary
                        variant: "small"
                        font.pixelSize: Theme.fontSize.bar
                        tone: modelData.verdict === "minor" ? "soft" : "base"
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }

                    Label {
                        width: parent.width
                        text: `${modelData.unit} · ×${modelData.count} today · ${modelData.verdict}`
                        variant: "numeric"
                        font.pixelSize: Theme.fontSize.caption
                        font.weight: Font.Normal
                        tone: "faint"
                    }
                }

                IconButton {
                    id: dismiss

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 26
                    implicitHeight: 24
                    iconSize: 13
                    icon: "x"
                    tone: "faint"
                    onClicked: root.lab.dismissJournalItem(modelData.key)
                }
            }
        }

        Label {
            visible: parent.visibleItems.length === 0
            width: parent.width
            text: root.lab.journalItems.length > 0 ? "Everything in the journal is dismissed or noise" : "Nothing worth your attention in the journal"
            variant: "small"
            tone: "faint"
        }
    }

    // ---- Spark -----------------------------------------------------------

    SectionHeader {
        width: parent.width
        text: "Spark"
        trailing: root.lab.sparkOnline ? (root.lab.sparkRuntime || "openai api") : "offline"
        trailingTone: root.lab.sparkOnline ? "success" : "faint"
    }

    Column {
        width: parent.width
        spacing: Theme.space.md

        Repeater {
            model: root.lab.sparkModels

            delegate: Item {
                required property var modelData

                width: parent ? parent.width : 0
                height: 38

                Column {
                    anchors.left: parent.left
                    anchors.right: latency.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Label {
                        width: parent.width
                        text: modelData.id
                        font.weight: Font.Medium
                    }

                    Label {
                        width: parent.width
                        text: [modelData.context > 0 ? `${Math.round(modelData.context / 1024)}k context` : "", root.lab.sparkEndpoint.replace(/^https?:\/\//, "")]
                            .filter(part => part).join(" · ")
                        variant: "caption"
                        tone: "faint"
                    }
                }

                Label {
                    id: latency

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.lab.sparkLatency >= 0 ? `${root.lab.sparkLatency} ms` : ""
                    variant: "numeric"
                    font.pixelSize: Theme.fontSize.small
                    tone: "faint"
                }
            }
        }

        Label {
            visible: !root.lab.sparkOnline
            width: parent.width
            text: `Model server ${root.lab.sparkError ? root.lab.sparkError.toLowerCase() : "not checked yet"}`
                + (root.lab.sparkContainers.some(container => container.running) ? " · a container is running, it may still be loading" : "")
            variant: "small"
            tone: "faint"
            wrapMode: Text.Wrap
        }

        Row {
            visible: root.lab.sparkOnline
            width: parent.width
            spacing: Theme.space.sm

            Chip {
                interactive: false
                icon: "activity"
                text: root.lab.sparkStats.running !== null && root.lab.sparkStats.running !== undefined
                    ? `${root.lab.sparkStats.running} running` : "— running"
            }

            Chip {
                interactive: false
                icon: "hourglass"
                text: root.lab.sparkStats.waiting !== null && root.lab.sparkStats.waiting !== undefined
                    ? `${root.lab.sparkStats.waiting} queued` : "— queued"
                tone: root.lab.sparkStats.waiting > 0 ? "warning" : "neutral"
            }

            Chip {
                interactive: false
                icon: "zap"
                text: root.lab.tokensPerSecond >= 0 ? `${root.lab.tokensPerSecond.toFixed(1)} tok/s` : "— tok/s"
            }
        }

        MeterRow {
            visible: root.lab.sparkOnline && root.lab.sparkStats.cache !== null && root.lab.sparkStats.cache !== undefined
            label: "KV cache"
            value: root.percent(root.lab.sparkStats.cache)
            fraction: root.lab.sparkStats.cache || 0
        }

        MeterRow {
            visible: root.lab.sparkHostStats !== null && root.lab.sparkHostStats.gpuUtil !== null
            label: root.lab.sparkHostStats && root.lab.sparkHostStats.gpuTemp !== null
                ? `GPU · ${Math.round(root.lab.sparkHostStats.gpuTemp)}°C${root.lab.sparkHostStats.power !== null ? " · " + Math.round(root.lab.sparkHostStats.power) + " W" : ""}`
                : "GPU"
            value: root.lab.sparkHostStats ? root.percent(root.lab.sparkHostStats.gpuUtil) : "—"
            fraction: root.lab.sparkHostStats && root.lab.sparkHostStats.gpuUtil !== null ? root.lab.sparkHostStats.gpuUtil : 0
        }

        MeterRow {
            visible: root.lab.sparkHostStats !== null && root.lab.sparkHostStats.memTotal > 0
            label: "Unified memory"
            value: root.lab.sparkHostStats
                ? `${(root.lab.sparkHostStats.memUsed / 1024).toFixed(0)} / ${(root.lab.sparkHostStats.memTotal / 1024).toFixed(0)} GB`
                : "—"
            fraction: root.lab.sparkHostStats && root.lab.sparkHostStats.memTotal > 0
                ? root.lab.sparkHostStats.memUsed / root.lab.sparkHostStats.memTotal : 0
            fillColor: fraction > 0.9 ? Theme.warning : Theme.secondary
        }

        Column {
            width: parent.width
            spacing: 0

            Repeater {
                model: root.lab.sparkContainers

                delegate: StatusRow {
                    required property var modelData

                    label: modelData.name
                    value: modelData.state.toLowerCase().replace(/^exited \(\d+\) /, "stopped ")
                    tone: modelData.running ? "success" : "disabled"
                }
            }
        }

        Label {
            visible: root.lab.sparkHostError !== ""
            width: parent.width
            text: root.lab.sparkHostError
            variant: "small"
            tone: "warning"
        }
    }
}
