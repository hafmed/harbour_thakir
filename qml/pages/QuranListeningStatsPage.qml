import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: statsPage
    allowedOrientations: Orientation.All

    readonly property bool isRtl: prayerManager.isArabicLanguage
    property var statsList: []

    function formatNum(val) {
        if (val === undefined || val === null) return ""
        return prayerManager.formatDigits(val.toString())
    }

    function dayName(dOfWeek) {
        if (isRtl) {
            switch (dOfWeek) {
            case 1: return "الإثنين"
            case 2: return "الثلاثاء"
            case 3: return "الأربعاء"
            case 4: return "الخميس"
            case 5: return "الجمعة"
            case 6: return "السبت"
            case 7: return "الأحد"
            default: return ""
            }
        } else {
            switch (dOfWeek) {
            case 1: return "Monday"
            case 2: return "Tuesday"
            case 3: return "Wednesday"
            case 4: return "Thursday"
            case 5: return "Friday"
            case 6: return "Saturday"
            case 7: return "Sunday"
            default: return ""
            }
        }
    }

    function refreshStats() {
        statsList = quranManager.getDailyListeningStats()
    }

    Component.onCompleted: {
        refreshStats()
    }

    Connections {
        target: quranManager
        onListeningHistoryChanged: refreshStats()
    }

    RemorsePopup { id: remorse }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentCol.height + Theme.paddingLarge * 2

        PullDownMenu {
            MenuItem {
                text: isRtl ? "مسح سجل الاستماع" : qsTr("Clear Listening History")
                enabled: statsList.length > 0
                onClicked: {
                    remorse.execute(isRtl ? "جاري مسح سجل الاستماع..." : qsTr("Clearing listening history..."), function() {
                        quranManager.clearListeningHistory()
                        refreshStats()
                    })
                }
            }

            MenuItem {
                text: isRtl ? "تحديث الإحصائيات" : qsTr("Refresh Statistics")
                onClicked: refreshStats()
            }
        }

        Column {
            id: contentCol
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: isRtl ? "إحصائيات الاستماع للقرآن" : qsTr("Quran Listening Stats")
            }

            // Summary Grid Cards
            Row {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall
                layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                // Card 1: Today's non-repeated Ayahs
                Rectangle {
                    width: (parent.width - Theme.paddingSmall * 2) / 3
                    height: Theme.itemSizeMedium * 1.05
                    radius: Theme.paddingSmall
                    color: quranManager.darkMode ? "#141a24" : Theme.rgba(Theme.highlightColor, 0.05)
                    border.color: Theme.rgba(Theme.highlightColor, 0.25)
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: formatNum(quranManager.getTodayListenedCount())
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: true
                            color: Theme.highlightColor
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "آيات اليوم" : qsTr("Today's Ayahs")
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.primaryColor
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "غير مكررة" : qsTr("Non-repeated")
                            font.pixelSize: Theme.fontSizeTiny * 0.85
                            color: Theme.secondaryColor
                        }
                    }
                }

                // Card 2: Total unique Ayahs all-time
                Rectangle {
                    width: (parent.width - Theme.paddingSmall * 2) / 3
                    height: Theme.itemSizeMedium * 1.05
                    radius: Theme.paddingSmall
                    color: quranManager.darkMode ? "#141a24" : Theme.rgba(Theme.highlightColor, 0.05)
                    border.color: Theme.rgba(Theme.highlightColor, 0.25)
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: formatNum(quranManager.getTotalListenedCount())
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: true
                            color: "#30d158"
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "إجمالي الآيات" : qsTr("Total Unique")
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.primaryColor
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "آية فريدة" : qsTr("Unique Ayahs")
                            font.pixelSize: Theme.fontSizeTiny * 0.85
                            color: Theme.secondaryColor
                        }
                    }
                }

                // Card 3: Days recorded
                Rectangle {
                    width: (parent.width - Theme.paddingSmall * 2) / 3
                    height: Theme.itemSizeMedium * 1.05
                    radius: Theme.paddingSmall
                    color: quranManager.darkMode ? "#141a24" : Theme.rgba(Theme.highlightColor, 0.05)
                    border.color: Theme.rgba(Theme.highlightColor, 0.25)
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: formatNum(statsList.length)
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: true
                            color: "#0a84ff"
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "أيام الاستماع" : qsTr("Active Days")
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.primaryColor
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "يوم مسجل" : qsTr("Days recorded")
                            font.pixelSize: Theme.fontSizeTiny * 0.85
                            color: Theme.secondaryColor
                        }
                    }
                }
            }

            SectionHeader {
                text: isRtl ? "سجل الاستماع اليومي (عدد الآيات دون تكرار)" : qsTr("Daily Listening Table (Non-repeated)")
            }

            // Table Header Row
            Rectangle {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                height: Theme.itemSizeExtraSmall * 0.85
                color: quranManager.darkMode ? "#1b2230" : Theme.rgba(Theme.highlightColor, 0.15)
                radius: 4
                visible: statsList.length > 0

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.paddingMedium
                    anchors.rightMargin: Theme.paddingMedium
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    Label {
                        width: parent.width * 0.40
                        text: isRtl ? "التاريخ" : qsTr("Date")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        font.bold: true
                        color: Theme.highlightColor
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                    }

                    Label {
                        width: parent.width * 0.30
                        text: isRtl ? "اليوم" : qsTr("Day")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        font.bold: true
                        color: Theme.highlightColor
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Label {
                        width: parent.width * 0.30
                        text: isRtl ? "الآيات المستمعة" : qsTr("Ayahs Listened")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        font.bold: true
                        color: Theme.highlightColor
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: isRtl ? Text.AlignLeft : Text.AlignRight
                    }
                }
            }

            // Table Data Rows
            Repeater {
                model: statsList

                delegate: Item {
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: Theme.itemSizeExtraSmall

                    Rectangle {
                        anchors.fill: parent
                        color: index % 2 === 0
                               ? (quranManager.darkMode ? "#0e131d" : Theme.rgba(Theme.secondaryColor, 0.05))
                               : (quranManager.darkMode ? "#131924" : "transparent")
                        radius: 3
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.paddingMedium
                        anchors.rightMargin: Theme.paddingMedium
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                        // 1. Date
                        Label {
                            width: parent.width * 0.40
                            text: formatNum(modelData.date)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: true
                            color: Theme.primaryColor
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                        }

                        // 2. Day of Week
                        Label {
                            width: parent.width * 0.30
                            text: dayName(modelData.dayOfWeek)
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.secondaryColor
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // 3. Count (non-repeated)
                        Row {
                            width: parent.width * 0.30
                            layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                            spacing: Theme.paddingSmall / 2
                            anchors.verticalCenter: parent.verticalCenter

                            Item {
                                width: isRtl ? (parent.width - cntBadge.width) : 0
                                height: 1
                            }

                            Rectangle {
                                id: cntBadge
                                width: cntLabel.width + Theme.paddingSmall * 1.5
                                height: cntLabel.height + 4
                                radius: 4
                                color: Theme.rgba(Theme.highlightColor, 0.15)
                                border.color: Theme.rgba(Theme.highlightColor, 0.4)
                                border.width: 1

                                Label {
                                    id: cntLabel
                                    anchors.centerIn: parent
                                    text: isRtl
                                          ? (formatNum(modelData.count) + " آية")
                                          : (modelData.count + " v")
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    font.bold: true
                                    color: Theme.highlightColor
                                }
                            }
                        }
                    }
                }
            }

            // Empty State
            Item {
                visible: statsList.length === 0
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                height: emptyCol.height + Theme.paddingLarge * 2

                Column {
                    id: emptyCol
                    anchors.centerIn: parent
                    width: parent.width - Theme.paddingLarge * 2
                    spacing: Theme.paddingMedium

                    Icon {
                        source: "image://theme/icon-m-speaker"
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.secondaryColor
                    }

                    Label {
                        width: parent.width
                        text: isRtl
                              ? "لا يوجد سجل استماع مسجل بعد.\nيتم تسجيل كل آية كريمة تستمع إليها (دون تكرار) تلقائياً لكل يوم، وتبقى محفوظة في الإعدادات."
                              : qsTr("No listening history recorded yet.\nEvery unique ayah you listen to is recorded automatically each day and stored in settings.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }
            }

            // Clear Button at bottom
            Button {
                visible: statsList.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: isRtl ? "مسح سجل الاستماع" : qsTr("Clear History")
                onClicked: {
                    remorse.execute(isRtl ? "جاري مسح سجل الاستماع..." : qsTr("Clearing listening history..."), function() {
                        quranManager.clearListeningHistory()
                        refreshStats()
                    })
                }
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }
        }
    }
}
