import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import QtQml.Models

Scope {
    id: root

    property int maxHistory: 100
    property alias dnd: settingsAdapter.dnd
    readonly property bool inhibited: dnd
    readonly property int count: historyModel.count
    readonly property int popupCount: popupModel.count
    readonly property var history: historyModel
    readonly property var popups: popupModel


    function isCritical(notification): bool {
        return notification && notification.urgency === NotificationUrgency.Critical
    }

    function indexOf(model, notification): int {
        if (!notification)
            return -1
        for (let index = 0; index < model.count; ++index) {
            if (model.get(index).notification === notification)
                return index
        }
        return -1
    }

    function popupTimeout(notification): real {
        if (!notification || isCritical(notification))
            return 0

        const requested = Number(notification.expireTimeout)
        if (requested === 0)
            return 0
        if (isFinite(requested) && requested > 0)
            return Math.max(2, Math.min(requested, 30))
        return notification.urgency === NotificationUrgency.Low ? 4 : 7
    }

    function popupDeadline(notification): real {
        const seconds = popupTimeout(notification)
        return seconds > 0 ? Date.now() + seconds * 1000 : 0
    }

    function shouldPopup(notification): bool {
        return notification && (!dnd || isCritical(notification))
    }

    function addHistory(notification): void {
        if (!notification || notification.transient || indexOf(historyModel, notification) >= 0)
            return
        historyModel.insert(0, {
            notification: notification,
            receivedAt: Date.now()
        })
        enforceHistoryBound()
    }

    function addPopup(notification): void {
        if (!shouldPopup(notification) || indexOf(popupModel, notification) >= 0)
            return
        popupModel.insert(0, {
            notification: notification,
            deadline: popupDeadline(notification),
            receivedAt: Date.now()
        })
    }

    function receive(notification): void {
        if (!notification)
            return

        notification.tracked = true
        addHistory(notification)
        if (!notification.lastGeneration && shouldPopup(notification)) {
            addPopup(notification)
        } else if (notification.transient) {
            notification.expire()
        }
    }

    function refreshNotification(notification): void {
        if (!notification || !notification.tracked)
            return

        let historyIndex = indexOf(historyModel, notification)
        if (notification.transient) {
            if (historyIndex >= 0)
                historyModel.remove(historyIndex)
        } else if (historyIndex < 0) {
            addHistory(notification)
        } else {
            historyModel.setProperty(historyIndex, "receivedAt", Date.now())
            if (historyIndex > 0)
                historyModel.move(historyIndex, 0, 1)
        }

        let popupIndex = indexOf(popupModel, notification)
        if (!shouldPopup(notification)) {
            if (popupIndex >= 0)
                popupModel.remove(popupIndex)
            if (notification.transient && notification.tracked)
                notification.expire()
            return
        }

        if (popupIndex < 0) {
            addPopup(notification)
        } else {
            popupModel.setProperty(popupIndex, "deadline", popupDeadline(notification))
            popupModel.setProperty(popupIndex, "receivedAt", Date.now())
            if (popupIndex > 0)
                popupModel.move(popupIndex, 0, 1)
        }
    }

    function removeNotification(notification): void {
        let index = indexOf(popupModel, notification)
        if (index >= 0)
            popupModel.remove(index)
        index = indexOf(historyModel, notification)
        if (index >= 0)
            historyModel.remove(index)
    }

    function hidePopup(notification): void {
        const index = indexOf(popupModel, notification)
        if (index >= 0)
            popupModel.remove(index)
    }

    function expirePopup(notification): void {
        hidePopup(notification)
        if (notification && notification.transient && notification.tracked)
            notification.expire()
    }

    function dismiss(notification): void {
        if (notification && notification.tracked)
            notification.dismiss()
        else
            removeNotification(notification)
    }

    function invokeAction(notification, action): void {
        if (!notification || !action || !notification.tracked)
            return
        hidePopup(notification)
        action.invoke()
    }

    function sendReply(notification, text): bool {
        const reply = String(text).trim()
        if (!notification || !notification.tracked || !notification.hasInlineReply || reply.length === 0)
            return false
        hidePopup(notification)
        notification.sendInlineReply(reply)
        return true
    }

    function clear(): void {
        const notifications = []
        for (let index = 0; index < historyModel.count; ++index)
            notifications.push(historyModel.get(index).notification)
        for (let index = 0; index < popupModel.count; ++index) {
            const notification = popupModel.get(index).notification
            if (notifications.indexOf(notification) < 0)
                notifications.push(notification)
        }

        historyModel.clear()
        popupModel.clear()
        for (const notification of notifications) {
            if (notification && notification.tracked)
                notification.dismiss()
        }
    }

    function setDnd(enabled): void {
        settingsAdapter.dnd = Boolean(enabled)
    }

    function toggleDnd(): void {
        setDnd(!dnd)
    }
    function toggleCenter(): void {
        PopupController.toggle("notifications")
    }

    function closeCenter(): void {
        PopupController.close("notifications")
    }


    function enforceHistoryBound(): void {
        while (historyModel.count > maxHistory) {
            let evictIndex = historyModel.count - 1
            for (let index = historyModel.count - 1; index >= 0; --index) {
                if (!isCritical(historyModel.get(index).notification)) {
                    evictIndex = index
                    break
                }
            }

            const notification = historyModel.get(evictIndex).notification
            historyModel.remove(evictIndex)
            hidePopup(notification)
            if (notification && notification.tracked)
                notification.expire()
        }
    }

    function applyInhibition(): void {
        if (!dnd)
            return
        for (let index = popupModel.count - 1; index >= 0; --index) {
            const notification = popupModel.get(index).notification
            if (!isCritical(notification)) {
                popupModel.remove(index)
                if (notification.transient && notification.tracked)
                    notification.expire()
            }
        }
    }
    ListModel {
        id: historyModel
    }

    ListModel {
        id: popupModel
    }

    NotificationServer {
        id: server

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: false
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: notification => root.receive(notification)
    }

    Instantiator {
        model: server.trackedNotifications

        delegate: Connections {
            required property var modelData

            target: modelData
            ignoreUnknownSignals: true

            function onClosed(reason): void { root.removeNotification(modelData) }
            function onSummaryChanged(): void { root.refreshNotification(modelData) }
            function onBodyChanged(): void { root.refreshNotification(modelData) }
            function onImageChanged(): void { root.refreshNotification(modelData) }
            function onAppIconChanged(): void { root.refreshNotification(modelData) }
            function onAppNameChanged(): void { root.refreshNotification(modelData) }
            function onUrgencyChanged(): void { root.refreshNotification(modelData) }
            function onExpireTimeoutChanged(): void { root.refreshNotification(modelData) }
            function onTransientChanged(): void { root.refreshNotification(modelData) }
            function onActionsChanged(): void { root.refreshNotification(modelData) }
            function onHasInlineReplyChanged(): void { root.refreshNotification(modelData) }
            function onInlineReplyPlaceholderChanged(): void { root.refreshNotification(modelData) }
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: popupModel.count > 0

        onTriggered: {
            const now = Date.now()
            for (let index = popupModel.count - 1; index >= 0; --index) {
                const entry = popupModel.get(index)
                if (entry.deadline > 0 && entry.deadline <= now)
                    root.expirePopup(entry.notification)
            }
        }
    }

    FileView {
        path: Quickshell.statePath("notifications.json")
        preload: true
        atomicWrites: true
        printErrors: false
        adapter: JsonAdapter {
            id: settingsAdapter
            property bool dnd: false
        }
        onAdapterUpdated: writeAdapter()
    }
}
