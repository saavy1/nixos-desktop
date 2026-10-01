import Quickshell
import QtQuick
import qs.ui

PopupPanel {
    id: calendar

    property date today: startOfDay(new Date())
    property date selectedDate: startOfDay(new Date())
    property date displayedMonth: startOfMonth(new Date())

    name: "calendar"
    // Opens from the clock in the middle of the bar.
    placement: "center"
    cardWidth: 400
    scrollable: false
    title: Qt.formatDate(displayedMonth, "MMMM yyyy")
    subtitle: `today · ${Qt.formatDate(today, "ddd d MMM").toLowerCase()}`

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

    onOpening: today = startOfDay(new Date())

    onKeyPressed: event => {
        if (event.key === Qt.Key_Left) {
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

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: calendar.today = calendar.startOfDay(new Date())
    }

    headerTrailing: [
        IconButton {
            icon: "chevron-left"
            onClicked: calendar.changeMonth(-1)
        },
        IconButton {
            icon: "chevron-right"
            onClicked: calendar.changeMonth(1)
        }
    ]

    Column {
        width: parent.width
        spacing: Theme.space.sm

        Row {
            id: weekdayHeader

            width: parent.width
            height: 20

            Repeater {
                model: 7

                Label {
                    required property int index

                    width: weekdayHeader.width / 7
                    height: weekdayHeader.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Qt.formatDate(new Date(2024, 0, index + 1), "ddd")
                    variant: "label"
                    tone: "faint"
                }
            }
        }

        Hairline {
            width: parent.width
        }

        Grid {
            id: monthGrid

            readonly property real cellWidth: (width - columnSpacing * 6) / 7

            width: parent.width
            columns: 7
            columnSpacing: Theme.space.xs
            rowSpacing: Theme.space.xs

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
                    height: 38
                    radius: Theme.radius.small
                    color: isToday
                        ? (dayHover.containsMouse ? Qt.lighter(Theme.accent, 1.07) : Theme.accent)
                        : isSelected
                            ? Theme.selected
                            : dayHover.containsMouse ? Theme.hover : "transparent"
                    border.color: Theme.accent
                    border.width: isSelected && !isToday ? Theme.borderWidth : 0

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.motion.fast
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        text: dayCell.cellDate.getDate()
                        variant: "numeric"
                        font.weight: dayCell.isToday || dayCell.isSelected ? Font.DemiBold : Font.Normal
                        tone: dayCell.isToday
                            ? "accentText"
                            : dayCell.isSelected
                                ? "base"
                                : dayCell.inDisplayedMonth ? "soft" : "disabled"
                    }

                    MouseArea {
                        id: dayHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendar.selectDate(dayCell.cellDate)
                    }
                }
            }
        }
    }

    footer: [
        Item {
            width: parent.width
            height: todayButton.implicitHeight

            Label {
                anchors {
                    left: parent.left
                    right: todayButton.left
                    rightMargin: Theme.space.md
                    verticalCenter: parent.verticalCenter
                }
                text: Qt.formatDate(calendar.selectedDate, "dddd, d MMMM yyyy")
                variant: "small"
                tone: "soft"
            }

            Button {
                id: todayButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                compact: true
                icon: "calendar"
                text: "Today"
                onClicked: calendar.jumpToToday()
            }
        }
    ]
}
