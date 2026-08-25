import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: calendar

    property date today: startOfDay(new Date())
    property date selectedDate: startOfDay(new Date())
    property date displayedMonth: startOfMonth(new Date())

    visible: PopupController.isOpen("calendar")
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
    WlrLayershell.namespace: "solitude-calendar"

    function startOfDay(value) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate())
    }

    function startOfMonth(value) {
        return new Date(value.getFullYear(), value.getMonth(), 1)
    }

    function sameDay(left, right) {
        return left.getFullYear() === right.getFullYear()
            && left.getMonth() === right.getMonth()
            && left.getDate() === right.getDate()
    }

    function dateForCell(index) {
        const firstWeekday = (displayedMonth.getDay() + 6) % 7
        return new Date(displayedMonth.getFullYear(), displayedMonth.getMonth(), 1 - firstWeekday + index)
    }

    function selectDate(value) {
        selectedDate = startOfDay(value)
        displayedMonth = startOfMonth(value)
    }

    function shiftSelection(days) {
        const nextDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate() + days)
        selectDate(nextDate)
    }

    function changeMonth(offset) {
        displayedMonth = new Date(displayedMonth.getFullYear(), displayedMonth.getMonth() + offset, 1)
    }

    function jumpToToday() {
        today = startOfDay(new Date())
        selectedDate = today
        displayedMonth = startOfMonth(today)
    }

    function open(): void {
        today = startOfDay(new Date())
        PopupController.open("calendar")
        Qt.callLater(() => keyboardScope.forceActiveFocus())
    }

    function toggle(): void {
        if (visible)
            close()
        else
            open()
    }

    function close(): void {
        PopupController.close("calendar")
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void {
            calendar.toggle()
        }

        function close(): void {
            calendar.close()
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: calendar.today = calendar.startOfDay(new Date())
    }

    FocusScope {
        id: keyboardScope

        anchors.fill: parent
        focus: calendar.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                calendar.close()
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                calendar.shiftSelection(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                calendar.shiftSelection(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                calendar.shiftSelection(-7)
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                calendar.shiftSelection(7)
                event.accepted = true
            } else if (event.key === Qt.Key_PageUp) {
                calendar.changeMonth(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
                calendar.changeMonth(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Home || event.key === Qt.Key_T) {
                calendar.jumpToToday()
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: calendar.close()
        }

        PanelCard {
            id: card

            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: Theme.outerMargin + Theme.barHeight + Theme.shellGap
            }
            width: Math.min(500, calendar.width - Theme.outerMargin * 2)
            height: Math.min(550, calendar.height - Theme.outerMargin * 2)

            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: header

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 20
                }
                height: 52

                Rectangle {
                    id: previousButton

                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    width: 40
                    height: 40
                    radius: Theme.radiusMedium
                    color: previousHover.containsMouse ? Theme.selection : "transparent"
                    border.color: previousHover.containsMouse ? Theme.border : "transparent"
                    border.width: Theme.borderWidth

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontTitle + 6
                    }

                    MouseArea {
                        id: previousHover

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: calendar.changeMonth(-1)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDate(calendar.displayedMonth, "MMMM yyyy")
                    color: Theme.foreground
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: nextButton

                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: 40
                    height: 40
                    radius: Theme.radiusMedium
                    color: nextHover.containsMouse ? Theme.selection : "transparent"
                    border.color: nextHover.containsMouse ? Theme.border : "transparent"
                    border.width: Theme.borderWidth

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: Theme.foreground
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontTitle + 6
                    }

                    MouseArea {
                        id: nextHover

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: calendar.changeMonth(1)
                    }
                }
            }

            Row {
                id: weekdayHeader

                anchors {
                    top: header.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 10
                    leftMargin: 20
                    rightMargin: 20
                }
                height: 30

                Repeater {
                    model: 7

                    Text {
                        required property int index

                        width: weekdayHeader.width / 7
                        height: weekdayHeader.height
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: Qt.formatDate(new Date(2024, 0, index + 1), "ddd").toUpperCase()
                        color: Theme.muted
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }
                }
            }

            Grid {
                id: monthGrid

                readonly property real cellWidth: (width - columnSpacing * 6) / 7
                readonly property real cellHeight: (height - rowSpacing * 5) / 6

                anchors {
                    top: weekdayHeader.bottom
                    left: parent.left
                    right: parent.right
                    bottom: footer.top
                    topMargin: 8
                    leftMargin: 20
                    rightMargin: 20
                    bottomMargin: 14
                }
                columns: 7
                columnSpacing: 6
                rowSpacing: 6

                Repeater {
                    model: 42

                    Rectangle {
                        id: dayCell

                        required property int index
                        readonly property date cellDate: calendar.dateForCell(index)
                        readonly property bool inDisplayedMonth: cellDate.getMonth() === calendar.displayedMonth.getMonth()
                            && cellDate.getFullYear() === calendar.displayedMonth.getFullYear()
                        readonly property bool isToday: calendar.sameDay(cellDate, calendar.today)
                        readonly property bool isSelected: calendar.sameDay(cellDate, calendar.selectedDate)

                        width: monthGrid.cellWidth
                        height: monthGrid.cellHeight
                        radius: Theme.radiusMedium
                        color: isSelected
                            ? Theme.selection
                            : isToday
                                ? Theme.withAlpha(Theme.accent, 0.16)
                                : dayHover.containsMouse
                                    ? Theme.backgroundDark
                                    : "transparent"
                        border.color: isSelected || isToday ? Theme.accent : "transparent"
                        border.width: isSelected || isToday ? Theme.borderWidth : 0

                        Text {
                            anchors.centerIn: parent
                            text: dayCell.cellDate.getDate()
                            color: dayCell.isSelected || dayCell.isToday
                                ? Theme.accent
                                : dayCell.inDisplayedMonth
                                    ? Theme.foreground
                                    : Theme.muted
                            opacity: dayCell.inDisplayedMonth || dayCell.isSelected ? 1 : 0.55
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontBody
                            font.weight: dayCell.isToday ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: dayHover

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: calendar.selectDate(dayCell.cellDate)
                        }
                    }
                }
            }

            Item {
                id: footer

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: 20
                    rightMargin: 20
                    bottomMargin: 18
                }
                height: 42

                Text {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    text: Qt.formatDate(calendar.selectedDate, "dddd, d MMMM yyyy")
                    color: Theme.foregroundSoft
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontCaption
                }

                Rectangle {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: 92
                    height: 36
                    radius: Theme.radiusMedium
                    color: todayHover.containsMouse ? Theme.selection : Theme.backgroundDark
                    border.color: Theme.border
                    border.width: Theme.borderWidth

                    Text {
                        anchors.centerIn: parent
                        text: "Today"
                        color: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: todayHover

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: calendar.jumpToToday()
                    }
                }
            }
        }
    }
}
