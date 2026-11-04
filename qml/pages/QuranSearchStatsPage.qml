import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: statsPage
    allowedOrientations: Orientation.All

    property string query: ""
    property int searchMode: 0
    property bool respectTashkeel: false
    property string searchEdition: "all"
    readonly property bool isRtl: prayerManager.isArabicLanguage
    property var statsData: null
    property int selectedView: 0 // 0: Chart (الرسم البياني), 1: Table (الجدول الإحصائي)
    property int sortMode: 0 // 0: By Occurrences (الأكثر تكراراً), 1: By Surah Order (ترتيب المصحف)

    function formatNum(val) {
        if (val === undefined || val === null) return ""
        return prayerManager.formatDigits(val.toString())
    }

    function formatPercent(val) {
        if (val === undefined || val === null) return ""
        var n = Number(val)
        var s = (n % 1 === 0) ? n.toFixed(0) : n.toFixed(1)
        if (isRtl && prayerManager.useHindiNumerals) {
            s = s.replace(".", "٫")
            return prayerManager.formatDigits(s) + " \u066A"
        }
        return s + "%"
    }

    function loadStats() {
        if (query.trim().length >= 2) {
            statsData = quranManager.getSearchStats(query, searchMode, respectTashkeel, searchEdition)
        }
    }

    Component.onCompleted: {
        loadStats()
    }

    readonly property var displaySurahs: {
        if (!statsData || !statsData.surahs) return []
        var arr = statsData.surahs.slice(0)
        if (sortMode === 1) {
            arr.sort(function(a, b) {
                return a.surah_number - b.surah_number
            })
        } else {
            arr.sort(function(a, b) {
                if (b.occurrence_count !== a.occurrence_count) {
                    return b.occurrence_count - a.occurrence_count
                }
                return a.surah_number - b.surah_number
            })
        }
        return arr
    }

    Connections {
        target: quranManager
        onRiwayahChanged: loadStats()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentCol.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: isRtl
                      ? ("الرواية: " + quranManager.riwayahName)
                      : qsTr("Riwayah: %1").arg(quranManager.riwayahName)
                onClicked: {
                    quranManager.riwayah = (quranManager.riwayah === 1) ? 2 : 1
                    loadStats()
                }
            }
            MenuItem {
                text: sortMode === 0
                      ? (isRtl ? ("الترتيب: حسب تسلسل السور (" + formatNum(1) + " ← " + formatNum(114) + ")") : qsTr("Sort: By Surah Order"))
                      : (isRtl ? "الترتيب: الأكثر تكراراً أولاً" : qsTr("Sort: By Highest Count"))
                onClicked: {
                    sortMode = (sortMode === 0) ? 1 : 0
                }
            }
            MenuItem {
                text: isRtl ? "تحديث الإحصائيات" : qsTr("Refresh Statistics")
                onClicked: loadStats()
            }
            MenuItem {
                text: isRtl ? "إحصائيات وسجل الاستماع" : qsTr("Listening Statistics")
                onClicked: pageStack.push(Qt.resolvedUrl("QuranListeningStatsPage.qml"))
            }
        }

        Column {
            id: contentCol
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: isRtl ? "إحصائيات البحث القرآني" : qsTr("Quran Search Statistics")
            }

            // Word Hero Banner
            Rectangle {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                height: wordBannerCol.height + Theme.paddingLarge * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)
                border.color: Theme.rgba(Theme.highlightColor, 0.35)
                border.width: 1

                Column {
                    id: wordBannerCol
                    anchors.centerIn: parent
                    width: parent.width - Theme.paddingLarge * 2
                    spacing: Theme.paddingSmall

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: isRtl ? "الكلمة / العبارة المبحوث عنها" : qsTr("Searched Word / Phrase")
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "« " + query + " »"
                        font.pixelSize: Theme.fontSizeLarge + 4
                        font.bold: true
                        color: Theme.highlightColor
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "[" + quranManager.riwayahName + "]"
                        font.pixelSize: Theme.fontSizeTiny
                        font.bold: true
                        color: Theme.secondaryColor
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.paddingSmall
                        visible: respectTashkeel

                        Rectangle {
                            height: Theme.fontSizeTiny + Theme.paddingSmall
                            width: tashkeelBadgeLbl.implicitWidth + Theme.paddingSmall * 2
                            radius: Theme.paddingSmall / 2
                            color: Theme.rgba(Theme.highlightColor, 0.2)
                            border.color: Theme.highlightColor
                            border.width: 1

                            Label {
                                id: tashkeelBadgeLbl
                                anchors.centerIn: parent
                                text: isRtl ? "مراعاة التشكيل والحركات" : qsTr("Exact Tashkeel / Diacritics")
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.highlightColor
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // Primary Summary Grid Cards
            Row {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall
                layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                // Card 1: Total Occurrences
                Rectangle {
                    width: (parent.width - Theme.paddingSmall * 2) / 3
                    height: Theme.itemSizeMedium * 1.05
                    radius: Theme.paddingSmall
                    color: Theme.rgba(Theme.primaryColor, 0.05)
                    border.color: Theme.rgba(Theme.highlightColor, 0.25)
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: formatNum(statsData ? statsData.totalOccurrences : 0)
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: true
                            color: Theme.highlightColor
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "إجمالي التكرار" : qsTr("Occurrences")
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.primaryColor
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "مرة بالقرآن" : qsTr("times")
                            font.pixelSize: Theme.fontSizeTiny * 0.85
                            color: Theme.secondaryColor
                        }
                    }
                }

                // Card 2: Total Ayahs
                Rectangle {
                    width: (parent.width - Theme.paddingSmall * 2) / 3
                    height: Theme.itemSizeMedium * 1.05
                    radius: Theme.paddingSmall
                    color: Theme.rgba(Theme.primaryColor, 0.05)
                    border.color: Theme.rgba(Theme.highlightColor, 0.25)
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: formatNum(statsData ? statsData.totalVerses : 0)
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: true
                            color: "#30d158"
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "عدد الآيات" : qsTr("Verses Count")
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.primaryColor
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "آية كريمة" : qsTr("Ayahs")
                            font.pixelSize: Theme.fontSizeTiny * 0.85
                            color: Theme.secondaryColor
                        }
                    }
                }

                // Card 3: Surahs Count
                Rectangle {
                    width: (parent.width - Theme.paddingSmall * 2) / 3
                    height: Theme.itemSizeMedium * 1.05
                    radius: Theme.paddingSmall
                    color: Theme.rgba(Theme.primaryColor, 0.05)
                    border.color: Theme.rgba(Theme.highlightColor, 0.25)
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: formatNum(statsData ? statsData.surahsCount : 0)
                            font.pixelSize: Theme.fontSizeLarge
                            font.bold: true
                            color: "#0a84ff"
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "عدد السور" : qsTr("Surahs Count")
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.primaryColor
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "سورة مباركة" : qsTr("Surahs")
                            font.pixelSize: Theme.fontSizeTiny * 0.85
                            color: Theme.secondaryColor
                        }
                    }
                }
            }

            // Makki vs Medinan Ratio Card
            Rectangle {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                height: revCol.height + Theme.paddingMedium * 2
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.primaryColor, 0.04)
                border.color: Theme.rgba(Theme.secondaryColor, 0.2)
                border.width: 1
                visible: statsData && statsData.totalOccurrences > 0

                Column {
                    id: revCol
                    anchors.centerIn: parent
                    width: parent.width - Theme.paddingMedium * 2
                    spacing: Theme.paddingSmall

                    Row {
                        width: parent.width
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                        Label {
                            text: isRtl ? "التوزيع حسب نوع السور (مكية / مدنية):" : qsTr("Revelation Distribution (Meccan / Medinan):")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Progress bar split
                    Item {
                        width: parent.width
                        height: 12

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: Theme.rgba(Theme.secondaryColor, 0.2)
                        }

                        // Makki Segment (Amber / Gold)
                        Rectangle {
                            id: makkiBar
                            anchors.left: isRtl ? undefined : parent.left
                            anchors.right: isRtl ? parent.right : undefined
                            height: parent.height
                            radius: 6
                            width: (statsData && statsData.totalOccurrences > 0)
                                   ? Math.max(6, parent.width * (statsData.makkiOccurrences / statsData.totalOccurrences))
                                   : 0
                            color: "#e5a93b"
                        }

                        // Medinan Segment (Teal / Green)
                        Rectangle {
                            anchors.left: isRtl ? parent.left : makkiBar.right
                            anchors.right: isRtl ? makkiBar.left : parent.right
                            height: parent.height
                            radius: 6
                            color: "#30d158"
                            visible: statsData && statsData.madaniOccurrences > 0
                        }
                    }

                    // Labels under the split bar (anchored symmetrically without fixed spacer)
                    Item {
                        width: parent.width
                        height: Math.max(makkiRow.height, madaniRow.height)

                        // Makki Label
                        Row {
                            id: makkiRow
                            anchors.left: isRtl ? undefined : parent.left
                            anchors.right: isRtl ? parent.right : undefined
                            spacing: Theme.paddingSmall / 2

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 2
                                color: "#e5a93b"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Label {
                                text: isRtl
                                      ? ("مكية: " + formatNum(statsData ? statsData.makkiOccurrences : 0) + " \u200E(" + formatPercent(statsData ? statsData.makkiPercentage : 0) + ")\u200E")
                                      : ("Meccan: " + (statsData ? statsData.makkiOccurrences : 0) + " (" + formatPercent(statsData ? statsData.makkiPercentage : 0) + ")")
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.primaryColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Medinan Label
                        Row {
                            id: madaniRow
                            anchors.left: isRtl ? parent.left : undefined
                            anchors.right: isRtl ? undefined : parent.right
                            spacing: Theme.paddingSmall / 2

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 2
                                color: "#30d158"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Label {
                                text: isRtl
                                      ? ("مدنية: " + formatNum(statsData ? statsData.madaniOccurrences : 0) + " \u200E(" + formatPercent(statsData ? statsData.madaniPercentage : 0) + ")\u200E")
                                      : ("Medinan: " + (statsData ? statsData.madaniOccurrences : 0) + " (" + formatPercent(statsData ? statsData.madaniPercentage : 0) + ")")
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.primaryColor
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // View Selector Tabs: [ الرسم البياني ] [ الجدول الإحصائي ]
            Row {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingMedium

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: isRtl ? "رسم بياني" : qsTr("Chart View")
                    color: selectedView === 0 ? Theme.highlightColor : Theme.secondaryColor
                    onClicked: selectedView = 0
                }

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: isRtl ? "جدول إحصائي" : qsTr("Table View")
                    color: selectedView === 1 ? Theme.highlightColor : Theme.secondaryColor
                    onClicked: selectedView = 1
                }
            }

            // =========================================================
            // VIEW 0: GRAPHICAL REPRESENTATION (CHARTS)
            // =========================================================
            Column {
                width: parent.width
                visible: selectedView === 0 && displaySurahs.length > 0
                spacing: Theme.paddingMedium

                SectionHeader {
                    text: isRtl
                          ? ("توزيع التكرار في السور (" + formatNum(displaySurahs.length) + " سورة)")
                          : ("Occurrences per Surah (" + displaySurahs.length + ")")
                }

                Repeater {
                    model: displaySurahs

                    delegate: BackgroundItem {
                        width: parent.width
                        height: chartItemCol.height + Theme.paddingMedium

                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("QuranReaderPage.qml"), {
                                surahNumber: modelData.surah_number,
                                startAyah: 1,
                                initialPage: modelData.start_page,
                                highlightTargetAyah: false
                            })
                        }

                        Column {
                            id: chartItemCol
                            width: parent.width - 2 * Theme.horizontalPageMargin
                            anchors.centerIn: parent
                            spacing: Theme.paddingSmall / 2

                            // 1. Top row: Surah name & revelation badge on right, count & percentage on left
                            Item {
                                width: parent.width
                                height: Math.max(sNameRow.height, countLabel.height)

                                Row {
                                    id: sNameRow
                                    anchors {
                                        left: isRtl ? undefined : parent.left
                                        right: isRtl ? parent.right : undefined
                                        verticalCenter: parent.verticalCenter
                                    }
                                    spacing: Theme.paddingSmall
                                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                                    Label {
                                        text: isRtl
                                              ? ("سورة " + modelData.name_ar + " (" + formatNum(modelData.surah_number) + ")")
                                              : (modelData.surah_number + ". Surah " + modelData.name_en)
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                        color: Theme.primaryColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: modelData.revelation_type === "Meccan" ? "#e5a93b" : "#30d158"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Label {
                                        text: modelData.revelation_type === "Meccan"
                                              ? (isRtl ? "مكية" : qsTr("Meccan"))
                                              : (isRtl ? "مدنية" : qsTr("Medinan"))
                                        font.pixelSize: Theme.fontSizeTiny
                                        color: modelData.revelation_type === "Meccan" ? "#e5a93b" : "#30d158"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Label {
                                    id: countLabel
                                    anchors {
                                        left: isRtl ? parent.left : undefined
                                        right: isRtl ? undefined : parent.right
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: isRtl
                                          ? (formatNum(modelData.occurrence_count) + " مرة \u200E(" + formatPercent(modelData.percentage) + ")\u200E")
                                          : (modelData.occurrence_count + " times (" + formatPercent(modelData.percentage) + ")")
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    font.bold: true
                                    color: Theme.highlightColor
                                }
                            }

                            // 2. Graphical Bar (Independent, sleek meter)
                            Rectangle {
                                width: parent.width
                                height: 10
                                radius: 5
                                color: Theme.rgba(Theme.secondaryColor, 0.12)

                                Rectangle {
                                    anchors.left: isRtl ? undefined : parent.left
                                    anchors.right: isRtl ? parent.right : undefined
                                    height: parent.height
                                    radius: 5
                                    width: Math.max(8, Math.round(parent.width * (Math.min(100.0, modelData.percentage) / 100.0)))
                                    color: modelData.revelation_type === "Meccan" ? "#e5a93b" : "#30d158"

                                    Behavior on width {
                                        NumberAnimation { duration: 400; easing.type: Easing.OutQuad }
                                    }
                                }
                            }

                            // 3. Bottom row: Ayah & Page information (under the bar, zero overlap)
                            Item {
                                width: parent.width
                                height: ayahPageLabel.height

                                Label {
                                    id: ayahPageLabel
                                    anchors {
                                        left: isRtl ? undefined : parent.left
                                        right: isRtl ? parent.right : undefined
                                    }
                                    text: isRtl
                                          ? (formatNum(modelData.ayah_count) + " آية في السورة • ص " + formatNum(modelData.start_page))
                                          : (modelData.ayah_count + " ayahs in surah • p. " + modelData.start_page)
                                    font.pixelSize: Theme.fontSizeTiny * 0.9
                                    color: Theme.secondaryColor
                                }
                            }
                        }
                    }
                }
            }

            // =========================================================
            // VIEW 1: STATISTICAL TABLE
            // =========================================================
            Column {
                width: parent.width
                visible: selectedView === 1 && displaySurahs.length > 0
                spacing: 0

                SectionHeader {
                    text: isRtl ? "الجدول الإحصائي الشامل للتكرار" : qsTr("Detailed Statistics Table")
                }

                // Table Header Row
                Rectangle {
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: Theme.itemSizeExtraSmall * 0.9
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                    radius: 4

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.paddingSmall
                        anchors.rightMargin: Theme.paddingSmall
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                        Label {
                            width: parent.width * 0.38
                            text: isRtl ? "السورة" : qsTr("Surah")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: true
                            color: Theme.highlightColor
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                        }

                        Label {
                            width: parent.width * 0.20
                            text: isRtl ? "النوع" : qsTr("Type")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: true
                            color: Theme.highlightColor
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Label {
                            width: parent.width * 0.22
                            text: isRtl ? "التكرار" : qsTr("Count")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: true
                            color: Theme.highlightColor
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Label {
                            width: parent.width * 0.20
                            text: isRtl ? "النسبة" : qsTr("Ratio")
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
                    model: displaySurahs

                    delegate: BackgroundItem {
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: Theme.itemSizeExtraSmall

                        Rectangle {
                            anchors.fill: parent
                            color: index % 2 === 0
                                   ? Theme.rgba(Theme.secondaryColor, 0.05)
                                   : "transparent"
                            radius: 2
                        }

                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("QuranReaderPage.qml"), {
                                surahNumber: modelData.surah_number,
                                startAyah: 1,
                                initialPage: modelData.start_page,
                                highlightTargetAyah: false
                            })
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.paddingSmall
                            anchors.rightMargin: Theme.paddingSmall
                            layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                            // 1. Surah Name
                            Label {
                                width: parent.width * 0.38
                                text: isRtl
                                      ? ("سورة " + modelData.name_ar + " (" + formatNum(modelData.surah_number) + ")")
                                      : (modelData.surah_number + ". " + modelData.name_en)
                                font.pixelSize: Theme.fontSizeExtraSmall
                                font.bold: true
                                color: Theme.primaryColor
                                anchors.verticalCenter: parent.verticalCenter
                                truncationMode: TruncationMode.Fade
                                horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                            }

                            // 2. Type: Meccan / Medinan
                            Label {
                                width: parent.width * 0.20
                                text: modelData.revelation_type === "Meccan"
                                      ? (isRtl ? "مكية" : qsTr("Meccan"))
                                      : (isRtl ? "مدنية" : qsTr("Medinan"))
                                font.pixelSize: Theme.fontSizeTiny
                                color: modelData.revelation_type === "Meccan" ? "#e5a93b" : "#30d158"
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                            }

                            // 3. Count
                            Label {
                                width: parent.width * 0.22
                                text: isRtl
                                      ? (formatNum(modelData.occurrence_count) + " (" + formatNum(modelData.ayah_count) + " آية)")
                                      : (modelData.occurrence_count + " (" + modelData.ayah_count + " v)")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                font.bold: true
                                color: Theme.highlightColor
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                            }

                            // 4. Percentage
                            Label {
                                width: parent.width * 0.20
                                text: formatPercent(modelData.percentage)
                                font.pixelSize: Theme.fontSizeExtraSmall
                                font.bold: true
                                color: Theme.primaryColor
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: isRtl ? Text.AlignLeft : Text.AlignRight
                            }
                        }
                    }
                }
            }

            // Empty state if no results found
            Label {
                visible: statsData && statsData.totalOccurrences === 0
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                text: isRtl ? "لم يتم العثور على أية نتائج إحصائية لهذه الكلمة." : qsTr("No statistical results found for this word.")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
