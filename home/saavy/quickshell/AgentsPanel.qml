import QtQuick
import qs.ui

PopupPanel {
    id: root

    required property var usage
    property double now: Date.now()

    name: "agents"
    title: "Agents"
    subtitle: usage.limitsFetchedAt > 0
        ? `live limits · updated ${ago(usage.limitsFetchedAt)}`
        : usage.loading ? "fetching limits…" : "limits unavailable"
    cardWidth: 440

    function formatTokens(count): string {
        if (count >= 1e9)
            return `${(count / 1e9).toFixed(1)}B`
        if (count >= 1e8)
            return `${Math.round(count / 1e6)}M`
        if (count >= 1e6)
            return `${(count / 1e6).toFixed(1)}M`
        if (count >= 1e3)
            return `${(count / 1e3).toFixed(1)}k`
        return String(count)
    }

    function span(ms): string {
        const minutes = Math.max(0, Math.round(ms / 60000))
        if (minutes < 60)
            return `${minutes}m`
        const hours = Math.floor(minutes / 60)
        if (hours < 48)
            return `${hours}h ${minutes % 60}m`
        return `${Math.floor(hours / 24)}d ${hours % 24}h`
    }

    function ago(stamp): string {
        const ms = now - stamp
        return ms < 60000 ? "just now" : `${span(ms)} ago`
    }

    function limitTone(limit): string {
        if (limit.status === "exhausted" || limit.usedFraction >= 0.9)
            return "danger"
        if (limit.usedFraction >= 0.7)
            return "warning"
        return "base"
    }

    onOpening: {
        usage.active = true
        usage.refresh()
    }
    onShownChanged: {
        if (!shown)
            usage.active = false
    }

    Timer {
        interval: 30000
        running: root.shown
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    headerTrailing: [
        IconButton {
            icon: "refresh-cw"
            tone: root.usage.loading ? "faint" : "soft"
            enabled: !root.usage.loading
            onClicked: root.usage.refresh()
        }
    ]

    component LimitRow: Column {
        id: row

        required property var modelData
        readonly property string tone: root.limitTone(modelData)
        readonly property bool known: modelData.usedFraction !== null

        width: parent ? parent.width : 0
        spacing: Theme.space.xs + 2

        Item {
            width: parent.width
            height: 20

            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.label
                variant: "small"
                font.pixelSize: Theme.fontSize.bar
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.sm

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.modelData.resetsAt > 0
                    text: `resets in ${root.span(row.modelData.resetsAt - root.now)}`
                    variant: "caption"
                    tone: "faint"
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.status === "exhausted" ? "EXHAUSTED"
                        : row.known ? `${Math.round(row.modelData.usedFraction * 100)}%` : "—"
                    variant: row.modelData.status === "exhausted" ? "label" : "numeric"
                    tone: row.tone
                }
            }
        }

        Meter {
            width: parent.width
            value: row.known ? row.modelData.usedFraction : 0
            fillColor: row.tone === "base" ? Theme.secondary : Theme.tone(row.tone)
        }
    }

    Repeater {
        model: root.usage.providers

        delegate: Column {
            id: provider

            required property var modelData

            width: parent ? parent.width : 0
            spacing: Theme.space.md

            SectionHeader {
                width: parent.width
                text: provider.modelData.name
                trailing: [provider.modelData.plan, provider.modelData.account]
                    .filter(part => part && part.toLowerCase() !== provider.modelData.name.toLowerCase())
                    .join(" · ")
            }

            Repeater {
                model: provider.modelData.limits

                delegate: LimitRow {}
            }

            Label {
                visible: provider.modelData.credits > 0
                width: parent.width
                text: `${provider.modelData.credits} reset ${provider.modelData.credits === 1 ? "credit" : "credits"} available`
                variant: "small"
                tone: "faint"
            }
        }
    }

    Label {
        visible: root.usage.limitsError !== ""
        width: parent.width
        text: root.usage.limitsError
        variant: "small"
        tone: "warning"
        wrapMode: Text.Wrap
    }

    SectionHeader {
        width: parent.width
        text: "Today"
        trailing: "new tokens"
    }

    Column {
        readonly property var tools: root.usage.today ? root.usage.today.tools.filter(tool => tool.requests > 0) : []

        width: parent.width
        spacing: Theme.space.sm

        Repeater {
            model: parent.tools

            delegate: Item {
                required property var modelData

                width: parent ? parent.width : 0
                height: 36

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Label {
                        text: modelData.name
                        font.weight: Font.Medium
                    }

                    Label {
                        text: `${modelData.sessions} ${modelData.sessions === 1 ? "session" : "sessions"} · ${modelData.requests} requests · ${root.formatTokens(modelData.cacheRead)} cached`
                        variant: "caption"
                        tone: "faint"
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Label {
                        anchors.right: parent.right
                        text: root.formatTokens(modelData.fresh)
                        variant: "numeric"
                        font.pixelSize: Theme.fontSize.heading
                    }

                    Label {
                        anchors.right: parent.right
                        visible: modelData.cost !== null
                        text: modelData.cost !== null ? `$${modelData.cost.toFixed(2)}` : ""
                        variant: "caption"
                        tone: "faint"
                    }
                }
            }
        }

        Label {
            visible: parent.tools.length === 0
            width: parent.width
            text: root.usage.todayError !== "" ? root.usage.todayError
                : root.usage.today ? "No agent activity yet today" : "Reading session logs…"
            variant: "small"
            tone: root.usage.todayError !== "" ? "warning" : "faint"
        }
    }

    SectionHeader {
        visible: models.count > 0
        width: parent.width
        text: "Models"
    }

    Column {
        width: parent.width
        spacing: Theme.space.sm

        Repeater {
            id: models

            readonly property double peak: root.usage.today && root.usage.today.models.length > 0 ? Math.max(1, root.usage.today.models[0].fresh) : 1

            model: root.usage.today ? root.usage.today.models.filter(entry => entry.fresh > 0).slice(0, 5) : []

            delegate: Column {
                required property var modelData

                width: parent ? parent.width : 0
                spacing: Theme.space.xs

                Item {
                    width: parent.width
                    height: 18

                    Label {
                        anchors.left: parent.left
                        anchors.right: modelValue.left
                        anchors.rightMargin: Theme.space.sm
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.model
                        variant: "small"
                        tone: "soft"
                    }

                    Label {
                        id: modelValue

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatTokens(modelData.fresh)
                        variant: "numeric"
                        font.pixelSize: Theme.fontSize.small
                        tone: "faint"
                    }
                }

                Meter {
                    width: parent.width
                    height: 3
                    value: modelData.fresh / models.peak
                }
            }
        }
    }
}
