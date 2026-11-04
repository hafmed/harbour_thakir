import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "mainPage"

    onStatusChanged: {
        if (status === PageStatus.Active) {
            if (quranManager.isPlaying || quranManager.playingAyah > 0) {
                quranManager.stopAudio()
            }
        }
    }

    property var currentTime: new Date()
    property string countdownText: ""
    property real progressValue: 0.0
    property int remainingPercent: 0
    property bool inPreAlert: false
    property string dailyWisdomText: prayerManager.isArabicLanguage ? prayerManager.dailyWisdom : ""
    readonly property bool isRtl: Qt.application.layoutDirection === Qt.RightToLeft || prayerManager.isArabicLanguage
    readonly property string currentNextPrayer: {
        var _t = currentTime
        var _ = prayerManager.appLanguage
        return prayerManager.nextPrayerName
    }
    readonly property bool currentIsTomorrow: {
        var _t = currentTime
        return prayerManager.isNextPrayerTomorrow
    }
    readonly property string currentNextPrayerTime: {
        var _t = currentTime
        var _ = prayerManager.appLanguage
        return prayerManager.nextPrayerTime
    }

    Connections {
        target: prayerManager
        onUseHindiNumeralsChanged: updateCountdown()
        onAppLanguageChanged: updateCountdown()
        onTimesChanged: updateCountdown()
    }

    // Vertical spacing and scaling calculations:
    // Page height equals device height minus bottomBar.height so content
    // fills the entire height of the device perfectly without scrolling overflow.
    readonly property real availableContentHeight: page.height - bottomBar.height

    readonly property bool hasImsak: prayerManager.hasCity && (prayerManager.isRamadan || prayerManager.showImsakAlways) && prayerManager.todayTimes["imsak"]
    readonly property bool hasImsakBanner: hasImsak && prayerManager.homeLayout !== 3
    readonly property bool hasWisdom: prayerManager.hasCity && prayerManager.isArabicLanguage && dailyWisdomText.length > 0
    readonly property bool hasCountdown: prayerManager.hasCity && prayerManager.homeLayout !== 3 && currentNextPrayer.length > 0
    readonly property bool hasEvent: prayerManager.hasCity && prayerManager.hasIslamicEvent

    // Dynamic item heights scaling with available screen height
    readonly property real buttonHeight0: Math.max(Theme.itemSizeExtraSmall * 0.70, Math.min(Theme.itemSizeMedium * 1.15, availableContentHeight * (hasImsakBanner ? (hasEvent ? 0.072 : 0.082) : (hasEvent ? 0.085 : 0.098))))
    readonly property real buttonHeight1: Math.max(Theme.itemSizeExtraSmall * 0.65, Math.min(Theme.itemSizeMedium * 0.95, availableContentHeight * (hasImsakBanner ? (hasEvent ? 0.058 : 0.065) : (hasEvent ? 0.070 : 0.080))))
    readonly property real rowHeight1: buttonHeight1 + Theme.fontSizeSmall + Theme.paddingSmall
    readonly property real buttonHeight2: Math.max(Theme.itemSizeExtraSmall * 0.65, Math.min(Theme.itemSizeMedium * 0.95, availableContentHeight * (hasImsakBanner ? (hasEvent ? 0.058 : 0.065) : (hasEvent ? 0.070 : 0.080))))
    readonly property real heroHeight3: Math.max(140, Math.min(210, availableContentHeight * (hasImsak ? 0.16 : 0.18)))
    readonly property real listItemHeight3: Math.max(38, Math.min(50, availableContentHeight * (hasImsak ? 0.044 : 0.048)))
    readonly property real listSpacing3: prayerManager.homeLayout === 3 ? Math.max(2, totalFreeSpace * 0.012) : 0

    readonly property real baseItemsHeight: {
        var h = headerCol.height > 0 ? headerCol.height : (Theme.fontSizeLarge + 2 * Theme.fontSizeMedium + Theme.paddingSmall)
        if (!prayerManager.hasCity) return h

        if (hasImsakBanner) {
            h += ramadanImsakCard.height > 0 ? ramadanImsakCard.height : Math.round(Theme.itemSizeExtraSmall * 0.72)
        }

        switch (prayerManager.homeLayout) {
        case 0:
            h += 3 * buttonHeight0
            break
        case 1:
            h += 3 * rowHeight1
            break
        case 2:
            h += 4 * buttonHeight2
            break
        case 3:
            h += heroHeight3 + (hasImsak ? 9 : 8) * listItemHeight3
            break
        default:
            h += 3 * buttonHeight0
            break
        }

        // Progress bar and countdown for layouts 0, 1, 2
        if (hasCountdown) {
            h += 6 // progress bar
            h += countdownCol.height > 0 ? countdownCol.height : (Theme.fontSizeMedium + Theme.itemSizeSmall + Theme.paddingSmall)
        }

        // Wisdom container
        if (hasWisdom) {
            h += wisdomContainer.height > 0 ? wisdomContainer.height : (Theme.fontSizeExtraSmall * 2 + Theme.paddingSmall * 2)
        }

        // Islamic Event container
        if (hasEvent) {
            h += eventContainer.height > 0 ? eventContainer.height : (Theme.fontSizeSmall + Theme.fontSizeExtraSmall + Theme.paddingSmall * 2)
        }

        return h
    }

    readonly property real totalFreeSpace: Math.max(0, availableContentHeight - baseItemsHeight)

    readonly property real spacerTop: totalFreeSpace * 0.06

    readonly property real spacerHeaderTop: hasImsakBanner ? totalFreeSpace * 0.05 : totalFreeSpace * 0.12
    readonly property real spacerHeaderBottom: hasImsakBanner ? totalFreeSpace * 0.05 : 0

    readonly property real layoutRowSpacing: {
        switch (prayerManager.homeLayout) {
        case 2: return totalFreeSpace * 0.045
        case 3: return 0
        default: return totalFreeSpace * 0.065
        }
    }

    readonly property real spacerProgressTop: hasCountdown ? totalFreeSpace * 0.08 : 0
    readonly property real spacerProgressBottom: hasCountdown ? totalFreeSpace * 0.08 : 0

    readonly property real spacerWisdom: hasWisdom ? totalFreeSpace * 0.10 : 0
    readonly property real spacerEvent: hasEvent ? totalFreeSpace * 0.08 : 0

    readonly property real spacerBottom: {
        var used = spacerTop + spacerHeaderTop + spacerHeaderBottom
        if (prayerManager.homeLayout === 2) {
            used += 3 * layoutRowSpacing
        } else if (prayerManager.homeLayout === 3) {
            used += (hasImsak ? 8 : 7) * listSpacing3
        } else {
            used += 2 * layoutRowSpacing
        }
        used += spacerProgressTop + spacerProgressBottom + spacerWisdom + spacerEvent
        return Math.max(Theme.paddingSmall, totalFreeSpace - used)
    }

    function layoutName(idx) {
        var _ = prayerManager.appLanguage
        switch (idx) {
        case 0: return qsTr("All-in-One 3-Column")
        case 1: return qsTr("Classic 3-Column")
        case 2: return qsTr("2-Column Grid")
        case 3: return qsTr("Hero & List")
        default: return qsTr("All-in-One 3-Column")
        }
    }

    function backgroundName(idx) {
        var _ = prayerManager.appLanguage
        switch (idx) {
        case 0: return isRtl ? "بدون خلفية" : qsTr("None")
        case 1: return isRtl ? "غروب المسجد (فكتور SVG)" : qsTr("Mosque Sunset (SVG)")
        case 2: return isRtl ? "غروب المسجد (صورة HD)" : qsTr("Mosque Sunset (Photo)")
        case 3: return isRtl ? "المسجد النبوي" : qsTr("Prophet's Mosque")
        case 4: return isRtl ? "قبة ذهبية ونخيل" : qsTr("Golden Dome & Palm")
        case 5: return isRtl ? "المسجد العثماني" : qsTr("Ottoman Mosque")
        case 6: return isRtl ? "مسجد الشفق" : qsTr("Twilight Mosque")
        case 7: return isRtl ? "مسجد النور" : qsTr("Glowing Mosque")
        case 8: return isRtl ? ("نجمة " + prayerManager.formatDigits("8") + " (فكتور SVG)") : qsTr("8-Star Girih (SVG)")
        case 9: return isRtl ? "محراب وفانوس (فكتور SVG)" : qsTr("Mihrab & Lantern (SVG)")
        case 10: return isRtl ? ("أندلسي " + prayerManager.formatDigits("12") + " (فكتور SVG)") : qsTr("Andalusian 12 (SVG)")
        case 11: return isRtl ? "هلال ومساجد (فكتور SVG)" : qsTr("Crescent & Mosque (SVG)")
        case 12: return isRtl ? "الأزرق الليلي (صورة)" : qsTr("Midnight Teal (Art)")
        case 13: return isRtl ? "محراب ملكي (صورة)" : qsTr("Royal Arch (Art)")
        case 14: return isRtl ? "أرابيسك (صورة)" : qsTr("Arabesque (Art)")
        case 15: return isRtl ? "الفن الإسلامي المتناسق (فكتور SVG)" : qsTr("Harmonious Islamic Art (SVG)")
        case 16: return isRtl ? "سجادة المسجد (فكتور SVG)" : qsTr("Mosque Carpet (SVG)")
        case 17: return isRtl ? "جامع الجزائر الأعظم (الجزائر)" : qsTr("Great Mosque of Algiers")
        default: return isRtl ? "بدون خلفية" : qsTr("None")
        }
    }

    function updateCountdown() {
        prayerManager.checkNextPrayer()
        currentTime = new Date()
        countdownText = prayerManager.nextPrayerCountdown()
        progressValue = prayerManager.nextPrayerProgress()
        remainingPercent = prayerManager.nextPrayerRemainingPercentage()
        inPreAlert = prayerManager.isPreAlertWindow()
        dailyWisdomText = prayerManager.isArabicLanguage ? prayerManager.dailyWisdom : ""
    }

    function formatPrayerTime(timeStr) {
        var _ = prayerManager.appLanguage
        if (!timeStr || timeStr.indexOf(":") === -1) return "--:--"
        if (prayerManager.use24HourFormat) {
            return prayerManager.formatDigits(timeStr)
        }
        var parts = timeStr.split(":")
        var h = parseInt(parts[0], 10)
        var m = parts[1]
        var ampm = h >= 12 ? (isRtl ? "م" : "pm") : (isRtl ? "ص" : "am")
        var h12 = h % 12
        if (h12 === 0) h12 = 12
        var hStr = (h12 < 10 ? "0" : "") + h12
        return prayerManager.formatDigits(hStr + ":" + m) + " " + ampm
    }

    function formatTime12(timeStr) {
        return formatPrayerTime(timeStr)
    }

    function prayerDisplayName(prayerKey) {
        var _ = prayerManager.appLanguage
        if (prayerKey === "dhuhr") {
            var d = new Date()
            if (currentIsTomorrow && prayerKey === currentNextPrayer) {
                d.setDate(d.getDate() + 1)
            }
            if (d.getDay() === 5) {
                return qsTr("Friday prayer")
            }
        }
        switch (prayerKey) {
        case "imsak": return qsTr("Imsak")
        case "fajr": return qsTr("Fajr")
        case "sunrise": return qsTr("Chourouq")
        case "dhuhr": return qsTr("Dhouhr")
        case "asr": return qsTr("Assar")
        case "maghrib": return qsTr("Maghreb")
        case "isha": return qsTr("Ishaa")
        case "midnight": return qsTr("Midnight")
        case "lastThird": return qsTr("Last 1/3 Night Begins")
        default:
            if (!prayerKey || prayerKey.length === 0) return "--"
            return prayerKey.charAt(0).toUpperCase() + prayerKey.slice(1)
        }
    }

    function getCountdownBadge() {
        var _ = prayerManager.useHindiNumerals
        var _lang = prayerManager.appLanguage
        var _t = currentTime
        var secs = prayerManager.nextPrayerRemainingSeconds()
        if (secs < 0) return "--:--"
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        var hStr = (h < 10 ? "0" : "") + h
        var mStr = (m < 10 ? "0" : "") + m
        return prayerManager.formatDigits(hStr + ":" + mStr)
    }

    function formatCountdownText(str) {
        var _ = prayerManager.useHindiNumerals
        var _lang = prayerManager.appLanguage
        if (!str) return ""
        var hMatch = str.match(/(\d+)h/)
        var mMatch = str.match(/(\d+)m/)
        var h = hMatch ? parseInt(hMatch[1], 10) : 0
        var m = mMatch ? parseInt(mMatch[1], 10) : 0
        if (h > 0) {
            return qsTr("%1h %2m").arg(prayerManager.formatDigits(h.toString())).arg(prayerManager.formatDigits(m.toString()))
        }
        return qsTr("%1m").arg(prayerManager.formatDigits(m.toString()))
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updateCountdown()
    }

    Connections {
        target: prayerManager
        onTimesChanged: updateCountdown()
        onUse24HourFormatChanged: updateCountdown()
        onHomeLayoutChanged: updateCountdown()
        onUseHindiNumeralsChanged: updateCountdown()
        onAppLanguageChanged: updateCountdown()
    }

    Image {
        id: bgImage
        anchors.fill: parent
        visible: prayerManager.backgroundImage > 0
        source: {
            switch (prayerManager.backgroundImage) {
            case 1: return Qt.resolvedUrl("../Images/bg_mosque_sunset.svg")
            case 2: return Qt.resolvedUrl("../Images/bg_mosque_sunset.jpg")
            case 3: return Qt.resolvedUrl("../Images/bg_minarets_nabawi.jpg")
            case 4: return Qt.resolvedUrl("../Images/bg_golden_dome_palm.jpg")
            case 5: return Qt.resolvedUrl("../Images/bg_ottoman_minarets.jpg")
            case 6: return Qt.resolvedUrl("../Images/bg_twilight_mosque.jpg")
            case 7: return Qt.resolvedUrl("../Images/bg_night_illuminated_mosque.jpg")
            case 8: return Qt.resolvedUrl("../Images/bg_islamic_star_8.svg")
            case 9: return Qt.resolvedUrl("../Images/bg_islamic_mihrab_arch.svg")
            case 10: return Qt.resolvedUrl("../Images/bg_islamic_andalusian_12.svg")
            case 11: return Qt.resolvedUrl("../Images/bg_islamic_crescent_mosque.svg")
            case 12: return Qt.resolvedUrl("../Images/bg_geometric_1.jpg")
            case 13: return Qt.resolvedUrl("../Images/bg_geometric_2.jpg")
            case 14: return Qt.resolvedUrl("../Images/bg_geometric_3.jpg")
            case 15: return Qt.resolvedUrl("../Images/bg_islamic_art_layout.svg")
            case 16: return Qt.resolvedUrl("../Images/bg_mosque_carpet.svg")
            case 17: return Qt.resolvedUrl("../Images/bg_djamaa_el_djazair.jpg")
            default: return ""
            }
        }
        sourceSize: Qt.size(page.width, page.height)
        fillMode: (prayerManager.backgroundImage === 1
                   || (prayerManager.backgroundImage >= 8 && prayerManager.backgroundImage <= 11)
                   || prayerManager.backgroundImage === 15
                   || prayerManager.backgroundImage === 16)
                  ? Image.Stretch
                  : Image.PreserveAspectCrop
        opacity: prayerManager.backgroundOpacity
        asynchronous: true
    }

    SilicaFlickable {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
        }
        contentHeight: Math.max(availableContentHeight, contentColumn.height)

        PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: isRtl
                      ? ("الخلفية : " + backgroundName(prayerManager.backgroundImage))
                      : qsTr("Background: %1").arg(backgroundName(prayerManager.backgroundImage))
                onClicked: {
                    prayerManager.backgroundImage = (prayerManager.backgroundImage + 1) % 18
                }
            }
            MenuItem {
                text: qsTr("Layout: %1").arg(layoutName(prayerManager.homeLayout))
                onClicked: {
                    prayerManager.homeLayout = (prayerManager.homeLayout + 1) % 4
                }
            }
            MenuItem {
                text: qsTr("Qibla direction")
                enabled: prayerManager.hasCity
                onClicked: pageStack.push(Qt.resolvedUrl("QiblaPage.qml"))
            }
            MenuItem {
                text: isRtl ? "القرآن الكريم" : qsTr("Holy Quran")
                onClicked: pageStack.push(Qt.resolvedUrl("QuranIndexPage.qml"))
            }
            MenuItem {
                text: qsTr("Favorites")
                onClicked: pageStack.push(Qt.resolvedUrl("FavoritesPage.qml"))
            }
            MenuItem {
                text: qsTr("Change city")
                onClicked: pageStack.push(Qt.resolvedUrl("CitySearchPage.qml"))
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
        }

        Column {
            id: contentColumn
            width: page.width

            Item {
                width: parent.width
                height: spacerTop
            }

            // Top Header: Prayer Times for City, Date/Time, Hijri Date
            Column {
                id: headerCol
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall / 2

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: prayerManager.hasCity ? qsTr("Prayer Times for: %1").arg(prayerManager.cityName) : qsTr("Prayer Times")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.highlightColor
                    font.bold: true
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: prayerManager.formatCurrentDateTime(currentTime)
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.highlightColor
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: prayerManager.hijriDate ? (prayerManager.hijriDate + (isRtl ? " هـ" : " H.Y")) : ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.highlightColor
                    visible: text.length > 0
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !prayerManager.hasCity
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    text: qsTr("No city selected yet. Pull down and choose \u201cChange city\u201d to search any city in the world.")
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Item {
                width: parent.width
                height: spacerHeaderTop
                visible: prayerManager.hasCity
            }

            // Ramadan Imsak Card (Visible only during Ramadan months or when enabled, for Layouts 0, 1, 2)
            Rectangle {
                id: ramadanImsakCard
                visible: hasImsakBanner
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 2 * Theme.horizontalPageMargin,
                                Math.max(page.width * 0.72, imsakRow.implicitWidth + Theme.paddingLarge * 2))
                height: Math.max(Math.round(Theme.itemSizeExtraSmall * 0.72), imsakRow.implicitHeight + Theme.paddingSmall * 2)
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)
                border.color: Theme.rgba(Theme.highlightColor, 0.45)
                border.width: 1

                Row {
                    id: imsakRow
                    anchors.centerIn: parent
                    spacing: Theme.paddingMedium
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    Label {
                        text: isRtl ? "🌙 وقت الإمساك:" : qsTr("🌙 Imsak (Stop Eating):")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.highlightColor
                        font.bold: true
                    }

                    Label {
                        text: formatTime12(prayerManager.todayTimes["imsak"])
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.primaryColor
                        font.bold: true
                    }
                }
            }

            Item {
                width: parent.width
                height: spacerHeaderBottom
                visible: hasImsakBanner
            }

            // =========================================================
            // LAYOUT 0: All-in-One 3-Column Buttons (Name + Time inside Button)
            // =========================================================
            Column {
                id: layout0Container
                visible: prayerManager.hasCity && prayerManager.homeLayout === 0
                width: parent.width
                spacing: layoutRowSpacing

                // Row 1: Fajr, Chourouq, Dhouhr
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingSmall
                    property real itemWidth: (page.width - 2 * Theme.horizontalPageMargin - 2 * spacing) / 3

                    Repeater {
                        model: isRtl ? ["dhuhr", "sunrise", "fajr"] : ["fajr", "sunrise", "dhuhr"]
                        delegate: MouseArea {
                            id: l0Row1Item
                            property bool isNext: modelData === currentNextPrayer
                            width: parent.itemWidth
                            height: buttonHeight0

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.paddingSmall
                                color: l0Row1Item.isNext ? Theme.rgba(Theme.highlightBackgroundColor, 0.15) : Theme.rgba(Theme.primaryColor, 0.06)
                                border.color: l0Row1Item.isNext ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                                border.width: l0Row1Item.isNext ? 2 : 1

                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - Theme.paddingSmall * 2
                                    spacing: 4

                                    Label {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: prayerDisplayName(modelData)
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: l0Row1Item.isNext ? Theme.highlightColor : Theme.secondaryColor
                                        font.bold: l0Row1Item.isNext
                                        truncationMode: TruncationMode.Fade
                                    }

                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: formatTime12(prayerManager.todayTimes[modelData])
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: l0Row1Item.isNext ? Theme.highlightColor : Theme.primaryColor
                                        font.bold: l0Row1Item.isNext
                                    }
                                }
                            }
                        }
                    }
                }

                // Row 2: Assar, Maghreb, Ishaa
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingSmall
                    property real itemWidth: (page.width - 2 * Theme.horizontalPageMargin - 2 * spacing) / 3

                    Repeater {
                        model: isRtl ? ["isha", "maghrib", "asr"] : ["asr", "maghrib", "isha"]
                        delegate: MouseArea {
                            id: l0Row2Item
                            property bool isNext: modelData === currentNextPrayer
                            width: parent.itemWidth
                            height: buttonHeight0

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.paddingSmall
                                color: l0Row2Item.isNext ? Theme.rgba(Theme.highlightBackgroundColor, 0.15) : Theme.rgba(Theme.primaryColor, 0.06)
                                border.color: l0Row2Item.isNext ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                                border.width: l0Row2Item.isNext ? 2 : 1

                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - Theme.paddingSmall * 2
                                    spacing: 4

                                    Label {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: prayerDisplayName(modelData)
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: l0Row2Item.isNext ? Theme.highlightColor : Theme.secondaryColor
                                        font.bold: l0Row2Item.isNext
                                        truncationMode: TruncationMode.Fade
                                    }

                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: formatTime12(prayerManager.todayTimes[modelData])
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: l0Row2Item.isNext ? Theme.highlightColor : Theme.primaryColor
                                        font.bold: l0Row2Item.isNext
                                    }
                                }
                            }
                        }
                    }
                }

                // Row 3: Midnight, Last 1/3 Night Begins
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingSmall
                    property real itemWidth: (page.width - 2 * Theme.horizontalPageMargin - spacing) / 2

                    Repeater {
                        model: isRtl ? ["lastThird", "midnight"] : ["midnight", "lastThird"]
                        delegate: MouseArea {
                            width: parent.itemWidth
                            height: buttonHeight0

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.paddingSmall
                                color: Theme.rgba(Theme.primaryColor, 0.06)
                                border.color: Theme.rgba(Theme.secondaryColor, 0.3)
                                border.width: 1

                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - Theme.paddingSmall * 2
                                    spacing: 4

                                    Label {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData === "midnight" ? qsTr("Midnight") : qsTr("Last 1/3 Night Begins")
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: Theme.secondaryColor
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        fontSizeMode: Text.Fit
                                        minimumPixelSize: Theme.fontSizeTiny
                                    }

                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: formatTime12(prayerManager.nightTimes[modelData])
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.primaryColor
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // =========================================================
            // LAYOUT 1: Classic 3-Column with Labels
            // =========================================================
            Column {
                id: layout1Container
                visible: prayerManager.hasCity && prayerManager.homeLayout === 1
                width: parent.width
                spacing: layoutRowSpacing

                // Row 1: Fajr, Chourouq, Dhouhr
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingSmall
                    property real itemWidth: (page.width - 2 * Theme.horizontalPageMargin - 2 * spacing) / 3

                    Repeater {
                        model: isRtl ? ["dhuhr", "sunrise", "fajr"] : ["fajr", "sunrise", "dhuhr"]
                        delegate: Column {
                            id: l1Col1Item
                            width: parent.itemWidth
                            spacing: Theme.paddingSmall
                            property bool isNext: modelData === currentNextPrayer

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: prayerDisplayName(modelData)
                                font.pixelSize: Theme.fontSizeSmall
                                color: l1Col1Item.isNext ? Theme.highlightColor : Theme.primaryColor
                                font.bold: l1Col1Item.isNext
                            }

                            Button {
                                anchors.horizontalCenter: parent.horizontalCenter
                                preferredWidth: parent.width
                                height: buttonHeight1
                                text: formatTime12(prayerManager.todayTimes[modelData])
                                color: l1Col1Item.isNext ? Theme.highlightColor : Theme.primaryColor
                                border.color: l1Col1Item.isNext ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.25)
                            }
                        }
                    }
                }

                // Row 2: Assar, Maghreb, Ishaa
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingSmall
                    property real itemWidth: (page.width - 2 * Theme.horizontalPageMargin - 2 * spacing) / 3

                    Repeater {
                        model: isRtl ? ["isha", "maghrib", "asr"] : ["asr", "maghrib", "isha"]
                        delegate: Column {
                            id: l1Col2Item
                            width: parent.itemWidth
                            spacing: Theme.paddingSmall
                            property bool isNext: modelData === currentNextPrayer

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: prayerDisplayName(modelData)
                                font.pixelSize: Theme.fontSizeSmall
                                color: l1Col2Item.isNext ? Theme.highlightColor : Theme.primaryColor
                                font.bold: l1Col2Item.isNext
                            }

                            Button {
                                anchors.horizontalCenter: parent.horizontalCenter
                                preferredWidth: parent.width
                                height: buttonHeight1
                                text: formatTime12(prayerManager.todayTimes[modelData])
                                color: l1Col2Item.isNext ? Theme.highlightColor : Theme.primaryColor
                                border.color: l1Col2Item.isNext ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.25)
                            }
                        }
                    }
                }

                // Row 3: Midnight, Last 1/3 Night Begins
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingSmall
                    property real itemWidth: (page.width - 2 * Theme.horizontalPageMargin - spacing) / 2

                    Repeater {
                        model: isRtl ? ["lastThird", "midnight"] : ["midnight", "lastThird"]
                        delegate: Column {
                            width: parent.itemWidth
                            spacing: Theme.paddingSmall

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData === "midnight" ? qsTr("Midnight") : qsTr("Last 1/3 Night Begins")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primaryColor
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                fontSizeMode: Text.Fit
                                minimumPixelSize: Theme.fontSizeTiny
                            }

                            Button {
                                anchors.horizontalCenter: parent.horizontalCenter
                                preferredWidth: parent.width
                                height: buttonHeight1
                                text: formatTime12(prayerManager.nightTimes[modelData])
                                color: Theme.primaryColor
                                border.color: Theme.rgba(Theme.secondaryColor, 0.25)
                            }
                        }
                    }
                }
            }

            // =========================================================
            // LAYOUT 2: 2-Column Grid (4 Paired Rows)
            // =========================================================
            Column {
                id: layout2Container
                visible: prayerManager.hasCity && prayerManager.homeLayout === 2
                width: parent.width
                spacing: layoutRowSpacing
                property real itemWidth: (page.width - 2 * Theme.horizontalPageMargin - Theme.paddingSmall) / 2

                Repeater {
                    model: isRtl ? [
                        { p1: "sunrise", p2: "fajr", n1: false, n2: false },
                        { p1: "asr", p2: "dhuhr", n1: false, n2: false },
                        { p1: "isha", p2: "maghrib", n1: false, n2: false },
                        { p1: "lastThird", p2: "midnight", n1: true, n2: true }
                    ] : [
                        { p1: "fajr", p2: "sunrise", n1: false, n2: false },
                        { p1: "dhuhr", p2: "asr", n1: false, n2: false },
                        { p1: "maghrib", p2: "isha", n1: false, n2: false },
                        { p1: "midnight", p2: "lastThird", n1: true, n2: true }
                    ]
                    delegate: Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.paddingSmall

                        // Item 1
                        MouseArea {
                            id: l2Item1
                            property bool isNext: !modelData.n1 && modelData.p1 === currentNextPrayer
                            width: layout2Container.itemWidth
                            height: buttonHeight2

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.paddingSmall
                                color: l2Item1.isNext ? Theme.rgba(Theme.highlightBackgroundColor, 0.15) : Theme.rgba(Theme.primaryColor, 0.06)
                                border.color: l2Item1.isNext ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                                border.width: l2Item1.isNext ? 2 : 1

                                Column {
                                    visible: modelData.p1 === "lastThird"
                                    anchors {
                                        left: isRtl ? p1TimeLabel.right : parent.left
                                        leftMargin: isRtl ? Theme.paddingSmall : Theme.paddingMedium
                                        right: isRtl ? parent.right : p1TimeLabel.left
                                        rightMargin: isRtl ? Theme.paddingMedium : Theme.paddingSmall
                                        verticalCenter: parent.verticalCenter
                                    }
                                    spacing: 1

                                    Label {
                                        width: parent.width
                                        text: qsTr("Last 1/3")
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: l2Item1.isNext ? Theme.highlightColor : Theme.primaryColor
                                        font.bold: l2Item1.isNext
                                        truncationMode: TruncationMode.Fade
                                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                    }

                                    Label {
                                        width: parent.width
                                        text: qsTr("Night Begins")
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: l2Item1.isNext ? Theme.highlightColor : Theme.secondaryColor
                                        truncationMode: TruncationMode.Fade
                                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                    }
                                }

                                Label {
                                    id: p1NameLabel
                                    visible: modelData.p1 !== "lastThird"
                                    anchors {
                                        left: isRtl ? p1TimeLabel.right : parent.left
                                        leftMargin: isRtl ? Theme.paddingSmall : Theme.paddingMedium
                                        right: isRtl ? parent.right : p1TimeLabel.left
                                        rightMargin: isRtl ? Theme.paddingMedium : Theme.paddingSmall
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: prayerDisplayName(modelData.p1)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: l2Item1.isNext ? Theme.highlightColor : Theme.primaryColor
                                    font.bold: l2Item1.isNext
                                    truncationMode: TruncationMode.Fade
                                    horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                }

                                Label {
                                    id: p1TimeLabel
                                    anchors {
                                        left: isRtl ? parent.left : undefined
                                        right: isRtl ? undefined : parent.right
                                        leftMargin: isRtl ? Theme.paddingMedium : 0
                                        rightMargin: isRtl ? 0 : Theme.paddingMedium
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: modelData.n1 ? formatTime12(prayerManager.nightTimes[modelData.p1])
                                                       : formatTime12(prayerManager.todayTimes[modelData.p1])
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: l2Item1.isNext ? Theme.highlightColor : Theme.primaryColor
                                    font.bold: l2Item1.isNext
                                }
                            }
                        }

                        // Item 2
                        MouseArea {
                            id: l2Item2
                            property bool isNext: !modelData.n2 && modelData.p2 === currentNextPrayer
                            width: layout2Container.itemWidth
                            height: buttonHeight2

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.paddingSmall
                                color: l2Item2.isNext ? Theme.rgba(Theme.highlightBackgroundColor, 0.15) : Theme.rgba(Theme.primaryColor, 0.06)
                                border.color: l2Item2.isNext ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                                border.width: l2Item2.isNext ? 2 : 1

                                Column {
                                    visible: modelData.p2 === "lastThird"
                                    anchors {
                                        left: isRtl ? p2TimeLabel.right : parent.left
                                        leftMargin: isRtl ? Theme.paddingSmall : Theme.paddingMedium
                                        right: isRtl ? parent.right : p2TimeLabel.left
                                        rightMargin: isRtl ? Theme.paddingMedium : Theme.paddingSmall
                                        verticalCenter: parent.verticalCenter
                                    }
                                    spacing: 1

                                    Label {
                                        width: parent.width
                                        text: qsTr("Last 1/3")
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: l2Item2.isNext ? Theme.highlightColor : Theme.primaryColor
                                        font.bold: l2Item2.isNext
                                        truncationMode: TruncationMode.Fade
                                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                    }

                                    Label {
                                        width: parent.width
                                        text: qsTr("Night Begins")
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: l2Item2.isNext ? Theme.highlightColor : Theme.secondaryColor
                                        truncationMode: TruncationMode.Fade
                                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                    }
                                }

                                Label {
                                    id: p2NameLabel
                                    visible: modelData.p2 !== "lastThird"
                                    anchors {
                                        left: isRtl ? p2TimeLabel.right : parent.left
                                        leftMargin: isRtl ? Theme.paddingSmall : Theme.paddingMedium
                                        right: isRtl ? parent.right : p2TimeLabel.left
                                        rightMargin: isRtl ? Theme.paddingMedium : Theme.paddingSmall
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: prayerDisplayName(modelData.p2)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: l2Item2.isNext ? Theme.highlightColor : Theme.primaryColor
                                    font.bold: l2Item2.isNext
                                    truncationMode: TruncationMode.Fade
                                    horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                }

                                Label {
                                    id: p2TimeLabel
                                    anchors {
                                        left: isRtl ? parent.left : undefined
                                        right: isRtl ? undefined : parent.right
                                        leftMargin: isRtl ? Theme.paddingMedium : 0
                                        rightMargin: isRtl ? 0 : Theme.paddingMedium
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: modelData.n2 ? formatTime12(prayerManager.nightTimes[modelData.p2])
                                                       : formatTime12(prayerManager.todayTimes[modelData.p2])
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: l2Item2.isNext ? Theme.highlightColor : Theme.primaryColor
                                    font.bold: l2Item2.isNext
                                }
                            }
                        }
                    }
                }
            }

            // =========================================================
            // LAYOUT 3: Hero & List (Sailfish Native Glanceable)
            // =========================================================
            Column {
                id: layout3Container
                visible: prayerManager.hasCity && prayerManager.homeLayout === 3
                width: parent.width
                spacing: layoutRowSpacing

                // Hero Card
                Rectangle {
                    id: heroCard
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: Math.max(heroCol.implicitHeight + Theme.paddingMedium * 2, heroHeight3)
                    radius: Theme.paddingMedium
                    color: inPreAlert ? Theme.rgba("#f44336", 0.18) : Theme.rgba(Theme.highlightColor, 0.12)
                    border.color: inPreAlert ? "#f44336" : Theme.rgba(Theme.highlightColor, 0.4)
                    border.width: 1

                    Column {
                        id: heroCol
                        anchors.centerIn: parent
                        spacing: Theme.paddingSmall / 2
                        width: parent.width - 2 * Theme.paddingMedium

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (currentIsTomorrow && currentNextPrayer === "fajr")
                                  ? qsTr("UPCOMING: TOMORROW'S FAJR")
                                  : qsTr("UPCOMING: %1").arg((currentIsTomorrow
                                      ? qsTr("Tomorrow's %1").arg(prayerDisplayName(currentNextPrayer))
                                      : prayerDisplayName(currentNextPrayer)).toUpperCase())
                            font.pixelSize: Theme.fontSizeSmall
                            color: inPreAlert ? "#f44336" : Theme.highlightColor
                            font.bold: true
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: currentNextPrayerTime
                            font.pixelSize: Theme.fontSizeHuge
                            color: Theme.primaryColor
                            font.bold: true
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Remaining: %1").arg(formatCountdownText(countdownText))
                            font.pixelSize: Theme.fontSizeMedium
                            color: inPreAlert ? "#f44336" : Theme.secondaryColor
                        }

                        // Mini progress bar in Hero card
                        Item {
                            width: parent.width * 0.8
                            height: 4
                            anchors.horizontalCenter: parent.horizontalCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: 2
                                color: Theme.rgba(Theme.primaryColor, 0.15)
                            }
                            Rectangle {
                                anchors.left: isRtl ? undefined : parent.left
                                anchors.right: isRtl ? parent.right : undefined
                                width: parent.width * Math.max(0.0, Math.min(1.0, progressValue))
                                height: parent.height
                                radius: 2
                                color: inPreAlert ? "#f44336" : "#29b6f6"
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }
                    }
                }

                // Vertical List of Times
                Column {
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: listSpacing3

                    Repeater {
                        model: {
                            var list = []
                            if (prayerManager.isRamadan || prayerManager.showImsakAlways) {
                                list.push({ key: "imsak", isNight: false })
                            }
                            list.push({ key: "fajr", isNight: false })
                            list.push({ key: "sunrise", isNight: false })
                            list.push({ key: "dhuhr", isNight: false })
                            list.push({ key: "asr", isNight: false })
                            list.push({ key: "maghrib", isNight: false })
                            list.push({ key: "isha", isNight: false })
                            list.push({ key: "midnight", isNight: true })
                            list.push({ key: "lastThird", isNight: true })
                            return list
                        }
                        delegate: Rectangle {
                            id: l3Item
                            property bool isNext: !modelData.isNight && modelData.key !== "imsak" && modelData.key === currentNextPrayer
                            width: parent.width
                            height: listItemHeight3
                            radius: Theme.paddingSmall
                            color: l3Item.isNext ? Theme.rgba(Theme.highlightColor, 0.2) : "transparent"
                            border.color: l3Item.isNext ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.15)
                            border.width: l3Item.isNext ? 1 : 0

                            Label {
                                anchors {
                                    left: isRtl ? l3TimeLabel.right : parent.left
                                    leftMargin: isRtl ? Theme.paddingSmall : Theme.paddingMedium
                                    right: isRtl ? parent.right : l3TimeLabel.left
                                    rightMargin: isRtl ? Theme.paddingMedium : Theme.paddingSmall
                                    verticalCenter: parent.verticalCenter
                                }
                                text: prayerDisplayName(modelData.key)
                                font.pixelSize: Theme.fontSizeSmall
                                color: l3Item.isNext ? Theme.highlightColor : Theme.primaryColor
                                font.bold: l3Item.isNext
                                truncationMode: TruncationMode.Fade
                                horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                            }

                            Label {
                                id: l3TimeLabel
                                anchors {
                                    left: isRtl ? parent.left : undefined
                                    right: isRtl ? undefined : parent.right
                                    leftMargin: isRtl ? Theme.paddingMedium : 0
                                    rightMargin: isRtl ? 0 : Theme.paddingMedium
                                    verticalCenter: parent.verticalCenter
                                }
                                text: modelData.isNight ? formatTime12(prayerManager.nightTimes[modelData.key])
                                                        : formatTime12(prayerManager.todayTimes[modelData.key])
                                font.pixelSize: Theme.fontSizeMedium
                                color: l3Item.isNext ? Theme.highlightColor : Theme.primaryColor
                                font.bold: l3Item.isNext
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: spacerProgressTop
                visible: hasCountdown
            }

            // Progress bar (for Layouts 0, 1, 2)
            Item {
                visible: hasCountdown
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: 6
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: "#16222f"
                }

                Rectangle {
                    anchors.left: isRtl ? undefined : parent.left
                    anchors.right: isRtl ? parent.right : undefined
                    width: parent.width * Math.max(0.0, Math.min(1.0, progressValue))
                    height: parent.height
                    radius: 3
                    color: inPreAlert ? "#f44336" : "#29b6f6"
                    Behavior on color {
                        ColorAnimation { duration: 300 }
                    }
                }
            }

            Item {
                width: parent.width
                height: spacerProgressBottom
                visible: hasCountdown
            }

            // Remaining time until: <PrayerName> (for Layouts 0, 1, 2)
            Column {
                id: countdownCol
                visible: hasCountdown
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (currentIsTomorrow && currentNextPrayer === "fajr")
                          ? qsTr("Remaining time until: Tomorrow's Fajr")
                          : (currentIsTomorrow
                             ? qsTr("Remaining time until: Tomorrow's %1").arg(prayerDisplayName(currentNextPrayer))
                             : qsTr("Remaining time until: %1").arg(prayerDisplayName(currentNextPrayer)))
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.primaryColor
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(160, page.width * 0.42)
                    height: Math.round(Theme.itemSizeSmall * 0.85)
                    radius: Theme.paddingSmall
                    color: inPreAlert ? Theme.rgba("#f44336", 0.15) : Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                    border.color: inPreAlert ? "#f44336" : Theme.rgba(Theme.highlightColor, 0.4)
                    border.width: 1

                    Label {
                        anchors.centerIn: parent
                        text: getCountdownBadge()
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        color: inPreAlert ? "#f44336" : Theme.primaryColor
                    }
                }
            }

            Item {
                width: parent.width
                height: spacerWisdom
                visible: hasWisdom
            }

            // Daily Wisdom (حكمة اليوم)
            Item {
                id: wisdomContainer
                visible: hasWisdom
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                height: wisdomCard.height

                Rectangle {
                    id: wisdomCard
                    width: parent.width
                    height: Math.max(Math.round(Theme.itemSizeExtraSmall * 0.75), wisdomLabel.implicitHeight + Theme.paddingSmall * 2)
                    anchors.centerIn: parent
                    radius: Theme.paddingSmall
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.08)
                    border.color: Theme.rgba(Theme.highlightColor, 0.2)
                    border.width: 1

                    Label {
                        id: wisdomLabel
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: Theme.paddingSmall
                        }
                        text: dailyWisdomText
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.highlightColor
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Item {
                width: parent.width
                height: spacerEvent
                visible: hasEvent
            }

            // Islamic Event Card (حدث اليوم / Today's Event)
            Item {
                id: eventContainer
                visible: hasEvent
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                height: eventCard.height

                Rectangle {
                    id: eventCard
                    width: parent.width
                    height: Math.max(Math.round(Theme.itemSizeExtraSmall * 0.8), eventCol.implicitHeight + Theme.paddingSmall * 2)
                    anchors.centerIn: parent
                    radius: Theme.paddingSmall
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                    border.color: Theme.rgba("#e0a93b", 0.6)
                    border.width: 1

                    BackgroundItem {
                        anchors.fill: parent
                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("IslamicEventPage.qml"), {
                                "eventTitle": prayerManager.islamicEventTitle,
                                "eventBanner": prayerManager.islamicEventBanner,
                                "eventContent": prayerManager.islamicEventContent
                            })
                        }

                        Column {
                            id: eventCol
                            anchors {
                                left: parent.left
                                right: parent.right
                                leftMargin: Theme.paddingMedium
                                rightMargin: Theme.paddingMedium
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: Theme.paddingSmall / 2

                            Item {
                                id: eventHeaderRow
                                width: parent.width
                                height: Math.max(eventIcon.height, eventTitleLabel.height)

                                Label {
                                    id: eventIcon
                                    anchors {
                                        left: isRtl ? undefined : parent.left
                                        right: isRtl ? parent.right : undefined
                                        top: parent.top
                                    }
                                    text: "🕌"
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                Label {
                                    id: eventTitleLabel
                                    anchors {
                                        left: isRtl ? parent.left : eventIcon.right
                                        right: isRtl ? eventIcon.left : parent.right
                                        leftMargin: isRtl ? 0 : Theme.paddingSmall
                                        rightMargin: isRtl ? Theme.paddingSmall : 0
                                        top: parent.top
                                    }
                                    text: prayerManager.isArabicLanguage ? prayerManager.islamicEventTitle : prayerManager.islamicEventBanner
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: "#e0a93b"
                                    font.bold: true
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                }
                            }

                            Label {
                                width: parent.width
                                text: isRtl ? "انقر هنا لقراءة المزيد..." : qsTr("Tap to read details...")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                wrapMode: Text.Wrap
                                horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: spacerBottom
            }
        }
    }

    // Bottom Navigation Bar
    Rectangle {
        id: bottomBar
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        height: Theme.itemSizeMedium
        color: "#08131d"

        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: 1
            color: Theme.rgba(Theme.highlightColor, 0.15)
        }

        Row {
            anchors.fill: parent
            // 0. Athkar Button
            BackgroundItem {
                width: parent.width / 5
                height: parent.height
                onClicked: pageStack.push(Qt.resolvedUrl("Athkar.qml"))
                Icon {
                    id: athkarIcon
                    anchors.centerIn: parent
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    sourceSize.width: Theme.iconSizeMedium
                    sourceSize.height: Theme.iconSizeMedium
                    fillMode: Image.PreserveAspectFit
                    source: Qt.resolvedUrl("Images/Doaa.png")
                    highlighted: parent.highlighted
                    onStatusChanged: {
                        if (status === Image.Error && source != Qt.resolvedUrl("../Images/Doaa.png")) {
                            source = Qt.resolvedUrl("../Images/Doaa.png")
                        }
                    }
                }
            }

            // 1. Quran Button (المصحف الشريف)
            BackgroundItem {
                width: parent.width / 5
                height: parent.height
                onClicked: pageStack.push(Qt.resolvedUrl("QuranIndexPage.qml"))
                Icon {
                    id: quranIcon
                    anchors.centerIn: parent
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    sourceSize.width: Theme.iconSizeMedium
                    sourceSize.height: Theme.iconSizeMedium
                    fillMode: Image.PreserveAspectFit
                    source: Qt.resolvedUrl("../icons/quran.svg")
                    highlighted: parent.highlighted
                    onStatusChanged: {
                        if (status === Image.Error && source != Qt.resolvedUrl("Images/Quran-icon.png")) {
                            source = Qt.resolvedUrl("Images/Quran-icon.png")
                        }
                    }
                }
            }

            // 2. Favorites Button
            BackgroundItem {
                width: parent.width / 5
                height: parent.height
                onClicked: pageStack.push(Qt.resolvedUrl("FavoritesPage.qml"))

                Icon {
                    anchors.centerIn: parent
                    source: "image://theme/icon-m-favorite"
                    highlighted: parent.highlighted
                }
            }

            // 3. Qibla / Location Button
            BackgroundItem {
                width: parent.width / 5
                height: parent.height
                onClicked: pageStack.push(Qt.resolvedUrl("QiblaPage.qml"))

                Icon {
                    id: qiblaIcon
                    anchors.centerIn: parent
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    sourceSize.width: Theme.iconSizeMedium
                    sourceSize.height: Theme.iconSizeMedium
                    fillMode: Image.PreserveAspectFit
                    source: Qt.resolvedUrl("../icons/kaaba.svg")
                    highlighted: parent.highlighted
                    onStatusChanged: {
                        if (status === Image.Error && source != Qt.resolvedUrl("Images/kaaba.svg")) {
                            source = Qt.resolvedUrl("Images/kaaba.svg")
                        }
                    }
                }
            }

            // 4. Settings Button
            BackgroundItem {
                width: parent.width / 5
                height: parent.height
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))

                Icon {
                    id: settingsIcon
                    anchors.centerIn: parent
                    source: "image://theme/icon-m-setting"
                    highlighted: parent.highlighted
                    onStatusChanged: {
                        if (status === Image.Error && source == "image://theme/icon-m-setting") {
                            source = "image://theme/icon-m-settings"
                        }
                    }
                }
            }
        }
    }
}
