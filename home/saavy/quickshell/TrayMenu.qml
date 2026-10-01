import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.ui

// Themed context menu for a system tray item, drawn from the app's own DBus
// menu (so Quit/Show/Settings etc. appear exactly as the app defines them).
// Submenus open in place with a back row. Like the panels, it's a transparent
// fullscreen overlay: clicking outside the card or pressing Escape closes it.
PanelWindow {
    id: menu

    property var trayItem: null
    // Right edge of the card, in screen coordinates.
    property real anchorRight: 0
    // Entries whose submenu is open, innermost last; empty means the root menu.
    property var stack: []
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : trayItem ? trayItem.menu : null

    function openFor(item, anchorItem): void {
        trayItem = item
        stack = []
        // The bar sits outerMargin in from the screen edge.
        anchorRight = Theme.outerMargin + anchorItem.mapToItem(null, anchorItem.width, 0).x
        visible = true
        Qt.callLater(() => keys.forceActiveFocus())
    }

    function close(): void {
        visible = false
        stack = []
    }

    function cleanText(text): string {
        // DBus menus mark mnemonics with "_" ("_Quit"); "__" is a literal underscore.
        return String(text || "").replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_")
    }

    visible: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: visible

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "qs-tray-menu"

    onVisibleChanged: {
        if (!visible)
            stack = []
    }

    QsMenuOpener {
        id: opener

        menu: menu.current
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (menu.stack.length > 0)
                menu.stack = menu.stack.slice(0, -1)
            else
                menu.close()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: menu.close()
        }
    }

    Card {
        id: card

        width: 260
        x: Math.max(Theme.outerMargin, Math.min(menu.width - width - Theme.outerMargin, menu.anchorRight - width))
        y: Theme.outerMargin + Theme.barHeight + Theme.space.sm
        height: entries.implicitHeight + Theme.space.xs * 2

        // Swallow clicks so they don't reach the close-on-outside area.
        MouseArea {
            anchors.fill: parent
        }
        radius: Theme.radius.medium
        grain: false

        Column {
            id: entries

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.space.xs
            }

            ListItem {
                visible: menu.stack.length > 0
                width: parent.width
                implicitHeight: 32
                icon: "chevron-left"
                title: "Back"
                onClicked: menu.stack = menu.stack.slice(0, -1)
            }

            Hairline {
                visible: menu.stack.length > 0
                width: parent.width
            }

            Repeater {
                model: opener.children

                delegate: Item {
                    id: entry

                    required property var modelData
                    readonly property bool checkable: modelData.buttonType !== QsMenuButtonType.None
                    readonly property bool checked: modelData.checkState === Qt.Checked

                    width: parent ? parent.width : 0
                    height: modelData.isSeparator ? Theme.space.sm + 1 : 32
                    opacity: modelData.enabled ? 1 : Theme.alpha.disabled

                    Hairline {
                        visible: entry.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - Theme.space.md * 2
                    }

                    Rectangle {
                        visible: !entry.modelData.isSeparator
                        anchors.fill: parent
                        radius: Theme.radius.small
                        color: mouse.containsMouse && entry.modelData.enabled ? Theme.hover : "transparent"
                    }

                    Row {
                        visible: !entry.modelData.isSeparator
                        anchors {
                            left: parent.left
                            right: chevron.left
                            leftMargin: Theme.space.md
                            rightMargin: Theme.space.sm
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: Theme.space.sm + 2

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16

                            Icon {
                                anchors.centerIn: parent
                                visible: entry.checkable && entry.checked
                                name: entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "dot" : "check"
                                size: 14
                                color: Theme.accent
                            }

                            Image {
                                anchors.fill: parent
                                visible: !entry.checkable && String(entry.modelData.icon).length > 0
                                source: entry.modelData.icon
                                sourceSize.width: 16
                                sourceSize.height: 16
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 26
                            text: menu.cleanText(entry.modelData.text)
                            variant: "small"
                            font.pixelSize: Theme.fontSize.bar
                            tone: /^(quit|exit|close)/i.test(text) ? "danger" : "base"
                        }
                    }

                    Icon {
                        id: chevron

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space.sm
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entry.modelData.hasChildren
                        name: "chevron-right"
                        size: 14
                        color: Theme.text.faint
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        enabled: !entry.modelData.isSeparator && entry.modelData.enabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (entry.modelData.hasChildren) {
                                menu.stack = menu.stack.concat([entry.modelData])
                            } else {
                                entry.modelData.triggered()
                                menu.close()
                            }
                        }
                    }
                }
            }

            Label {
                visible: opener.children && opener.children.values && opener.children.values.length === 0
                width: parent.width
                padding: Theme.space.md
                text: "This app has no menu"
                variant: "small"
                tone: "faint"
            }
        }
    }
}
