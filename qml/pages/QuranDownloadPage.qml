import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: downloadPage
    allowedOrientations: Orientation.All

    readonly property bool isRtl: prayerManager.isArabicLanguage
    readonly property bool isOnline: (typeof quranManager.isOnline !== "undefined" ? quranManager.isOnline : true) && prayerManager.geocoder.isOnline

    property int pagesCount: quranManager.getDownloadedPagesCount(quranManager.riwayah)
    property var pagesSize: quranManager.getPagesCacheSize(quranManager.riwayah)

    property int tajweedSdCount: quranManager.getDownloadedTajweedPagesCount(quranManager.riwayah, false)
    property var tajweedSdSize: quranManager.getTajweedPagesCacheSize(quranManager.riwayah, false)
    property int tajweedHdCount: quranManager.getDownloadedTajweedPagesCount(quranManager.riwayah, true)
    property var tajweedHdSize: quranManager.getTajweedPagesCacheSize(quranManager.riwayah, true)
    property int tajweedPagesCount: quranManager.tajweedHdMode ? tajweedHdCount : tajweedSdCount
    property var tajweedPagesSize: quranManager.tajweedHdMode ? tajweedHdSize : tajweedSdSize

    property int algeriaPagesCount: quranManager.getDownloadedAlgeriaPagesCount()
    property var algeriaPagesSize: quranManager.getAlgeriaPagesCacheSize()

    property int audioCount: quranManager.getDownloadedAudioCount(quranManager.selectedReciterId)
    property var audioSize: quranManager.getAudioCacheSize(quranManager.selectedReciterId)

    function getSortedReciters() {
        var list = quranManager.getAvailableReciters()
        list.sort(function(a, b) {
            var fa = quranManager.isReciterFavorite(a.id)
            var fb = quranManager.isReciterFavorite(b.id)
            if (fa !== fb) return fa ? -1 : 1
            return 0
        })
        return list
    }

    property var recitersList: getSortedReciters()
    property var surahsList: []
    property int initialSurah: 1
    property int selectedSurahToDownload: (initialSurah > 0 && initialSurah <= 114) ? initialSurah : 1

    function refreshStats() {
        recitersList = getSortedReciters()
        pagesCount = quranManager.getDownloadedPagesCount(quranManager.riwayah)
        pagesSize = quranManager.getPagesCacheSize(quranManager.riwayah)
        tajweedSdCount = quranManager.getDownloadedTajweedPagesCount(quranManager.riwayah, false)
        tajweedSdSize = quranManager.getTajweedPagesCacheSize(quranManager.riwayah, false)
        tajweedHdCount = quranManager.getDownloadedTajweedPagesCount(quranManager.riwayah, true)
        tajweedHdSize = quranManager.getTajweedPagesCacheSize(quranManager.riwayah, true)
        tajweedPagesCount = quranManager.tajweedHdMode ? tajweedHdCount : tajweedSdCount
        tajweedPagesSize = quranManager.tajweedHdMode ? tajweedHdSize : tajweedSdSize
        algeriaPagesCount = quranManager.getDownloadedAlgeriaPagesCount()
        algeriaPagesSize = quranManager.getAlgeriaPagesCacheSize()
        audioCount = quranManager.getDownloadedAudioCount(quranManager.selectedReciterId)
        audioSize = quranManager.getAudioCacheSize(quranManager.selectedReciterId)
    }

    Component.onCompleted: {
        surahsList = quranManager.getSurahs()
        if (initialSurah > 0 && initialSurah <= 114) {
            selectedSurahToDownload = initialSurah
        }
        refreshStats()
    }

    Connections {
        target: quranManager
        onRiwayahChanged: {
            surahsList = quranManager.getSurahs()
            refreshStats()
        }
        onReciterChanged: refreshStats()
        onBulkPagesProgressChanged: refreshStats()
        onBulkTajweedPagesProgressChanged: refreshStats()
        onBulkAlgeriaPagesProgressChanged: refreshStats()
        onAlgeriaModeChanged: refreshStats()
        onTajweedHdModeChanged: refreshStats()
        onAudioDownloadProgressChanged: refreshStats()
        onPageCached: refreshStats()
        onOnlineStateChanged: refreshStats()
    }

    RemorsePopup { id: remorse }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentCol.height + Theme.paddingLarge * 2

        PullDownMenu {
            MenuItem {
                text: isRtl ? "تحديث الإحصائيات" : qsTr("Refresh Stats")
                onClicked: refreshStats()
            }
        }

        Column {
            id: contentCol
            width: parent.width - 2 * Theme.horizontalPageMargin
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingMedium

            PageHeader {
                title: isRtl ? "إدارة التحميل والأوفلاين" : qsTr("Downloads & Offline")
                description: isRtl ? "تحميل المصحف والتلاوات للاستخدام بدون إنترنت" : qsTr("Download Quran and recitations for offline use")
            }

            // Network Offline Warning Banner
            Rectangle {
                id: offlineBanner
                visible: !downloadPage.isOnline
                width: parent.width
                height: visible ? (offlineContent.height + Theme.paddingMedium * 2) : 0
                radius: Theme.paddingSmall
                color: Qt.rgba(1.0, 0.2, 0.2, 0.15)
                border.color: "#cc3333"
                border.width: 1

                Row {
                    id: offlineContent
                    width: parent.width - 2 * Theme.paddingMedium
                    anchors.centerIn: parent
                    spacing: Theme.paddingMedium
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    Icon {
                        source: "image://theme/icon-m-cloud-download"
                        color: "#ff5555"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                        width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: "#ff5555"
                        text: isRtl
                              ? "الاتصال بالإنترنت معطل حالياً. تم تعطيل أزرار التحميل حتى يتم تفعيل الاتصال بالإنترنت."
                              : qsTr("Internet connection is disabled. All download buttons are disabled until connection is restored.")
                    }
                }
            }

            // Info note
            Rectangle {
                width: parent.width
                height: infoText.paintedHeight + Theme.paddingMedium * 2
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)
                border.color: Theme.rgba(Theme.highlightColor, 0.3)
                border.width: 1

                Label {
                    id: infoText
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Theme.paddingMedium
                    }
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    text: isRtl
                          ? "• يمكنك استخدام التطبيق مباشرة عبر الإنترنت (أونلاين) حيث يتم حفظ الصفحات والتلاوات المستمع إليها تلقائياً في جهازك.\n• أو يمكنك هنا تحميل الصفحات والتلاوات كاملة بضغطة واحدة لاستخدام التطبيق دون اتصال (أوفلاين) في أي وقت."
                          : qsTr("• You can stream online on-demand (pages and played recitations are cached automatically).\n• Or you can download full Quran pages and recitations here for 100% offline use.")
                }
            }

            // ========================================================
            // SECTION 1: RIWAYAH SELECTION
            // ========================================================
            SectionHeader {
                text: isRtl ? "رواية المصحف الشريف" : qsTr("Holy Quran Riwayah")
            }

            ComboBox {
                width: parent.width
                label: isRtl ? "الرواية الحالية:" : qsTr("Current Riwayah:")
                currentIndex: quranManager.riwayah === 2 ? 1 : 0
                menu: ContextMenu {
                    MenuItem {
                        text: isRtl ? "حفص عن عاصم" : "Hafs 'an 'Asim"
                        onClicked: quranManager.riwayah = 1
                    }
                    MenuItem {
                        text: isRtl ? "ورش عن نافع (طريق الأزرق)" : "Warsh 'an Nafi'"
                        onClicked: quranManager.riwayah = 2
                    }
                }
            }

            // ========================================================
            // SECTION 2: MUSHAF PAGES (المصحف المصور)
            // ========================================================
            SectionHeader {
                text: isRtl ? "صفحات المصحف (المصحف المصور)" : qsTr("Quran Pages (Mushaf View)")
            }

            Rectangle {
                width: parent.width
                height: pagesCol.height + Theme.paddingMedium * 2
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.1)
                border.color: Theme.rgba(Theme.highlightColor, 0.25)
                border.width: 1

                Column {
                    id: pagesCol
                    width: parent.width - 2 * Theme.paddingMedium
                    anchors.centerIn: parent
                    spacing: Theme.paddingMedium

                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall

                        Label {
                            text: isRtl ? "الحالة:" : qsTr("Status:")
                            font.bold: true
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.highlightColor
                        }

                        Label {
                            width: parent.width - 80
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: pagesCount >= quranManager.maxPages ? "#4cd964" : (!downloadPage.isOnline ? Theme.secondaryColor : Theme.primaryColor)
                            text: {
                                var tot = quranManager.maxPages
                                var base = isRtl
                                      ? (prayerManager.formatDigits(pagesCount.toString()) + " / " + prayerManager.formatDigits(tot.toString()) + " صفحة محملة (" + quranManager.formatFileSize(pagesSize) + ")" + (pagesCount >= tot ? " • مكتمل وجاهز أوفلاين" : ""))
                                      : (pagesCount + " / " + tot + " pages downloaded (" + quranManager.formatFileSize(pagesSize) + ")" + (pagesCount >= tot ? " • Ready Offline" : ""))
                                if (!downloadPage.isOnline && pagesCount < tot) {
                                    base += isRtl ? " (الإنترنت معطل)" : " " + qsTr("(Internet disabled)")
                                }
                                return base
                            }
                        }
                    }

                    // Progress bar when downloading
                    Column {
                        width: parent.width
                        visible: quranManager.isDownloadingPages
                        spacing: Theme.paddingSmall

                        ProgressBar {
                            width: parent.width
                            minimumValue: 0
                            maximumValue: 1.0
                            value: quranManager.pagesDownloadProgress
                            label: isRtl ? "جاري تحميل صفحات المصحف..." : qsTr("Downloading Quran pages...")
                        }

                        Button {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "إيقاف التحميل" : qsTr("Stop Download")
                            onClicked: quranManager.cancelBulkPagesDownload()
                        }
                    }

                    // Download and Delete buttons
                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium
                        visible: !quranManager.isDownloadingPages

                        Button {
                            preferredWidth: (parent.width - Theme.paddingMedium) / (pagesCount > 0 ? 2 : 1)
                            text: isRtl
                                  ? (pagesCount >= quranManager.maxPages ? "إعادة فحص وتحديث" : ("تحميل كل الصفحات (" + prayerManager.formatDigits(quranManager.maxPages.toString()) + ")"))
                                  : (pagesCount >= quranManager.maxPages ? qsTr("Verify & Update") : qsTr("Download All Pages (%1)").arg(prayerManager.formatDigits(quranManager.maxPages.toString())))
                            enabled: (pagesCount < quranManager.maxPages) ? downloadPage.isOnline : true
                            onClicked: quranManager.startBulkPagesDownload(quranManager.riwayah)
                        }

                        Button {
                            visible: pagesCount > 0
                            preferredWidth: (parent.width - Theme.paddingMedium) / 2
                            text: isRtl ? "حذف الصفحات" : qsTr("Clear Pages")
                            onClicked: {
                                remorse.execute(
                                    isRtl ? "حذف صفحات المصحف المخزنة" : qsTr("Deleting cached pages"),
                                    function() {
                                        quranManager.clearPagesCache(quranManager.riwayah)
                                        refreshStats()
                                    }
                                )
                            }
                        }
                    }
                }
            }

            // ========================================================
            // SECTION 2B-HAFS: VECTOR TAJWEED MUSHAF (مصحف التجويد المتجهي لحفص)
            // ========================================================
            Rectangle {
                visible: quranManager.riwayah === 1
                width: parent.width
                radius: 12
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.1)
                border.color: Theme.rgba(Theme.highlightColor, 0.25)
                border.width: 1
                height: hafsTajweedCardCol.height + Theme.paddingLarge * 2

                Column {
                    id: hafsTajweedCardCol
                    width: parent.width - Theme.paddingLarge * 2
                    anchors.centerIn: parent
                    spacing: Theme.paddingMedium

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                        Label {
                            text: "✨"
                            font.pixelSize: Theme.fontSizeLarge
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - 60
                            spacing: 4

                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: isRtl
                                      ? "مصحف التجويد الملون المتجهي (حفص عن عاصم)"
                                      : qsTr("Vector Colored Tajweed Mushaf (Hafs)")
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.highlightColor
                            }

                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                text: isRtl
                                      ? "مصحف التجويد برواية حفص عن عاصم مدمج بالكامل بتقنية المتجهات فائقة الدقة (Vector Typography) مع خط مجمع الملك فهد العثماني، ويعمل في العرض النصي بدقة غير محدودة وبدون حاجة لتحميل أي ملفات (0 ميغابايت)."
                                      : qsTr("Hafs Tajweed is built-in with infinitely scalable vector graphics (Text View) using King Fahd Uthmanic font, completely offline with 0 MB download.")
                            }
                        }
                    }

                    Button {
                        preferredWidth: parent.width
                        text: quranManager.tajweedMode && quranManager.viewMode === 0
                              ? (isRtl ? "✓ نمط التجويد المتجهي مفعّل" : qsTr("✓ Vector Tajweed Active"))
                              : (isRtl ? "تفعيل نمط التجويد المتجهي لحفص" : qsTr("Enable Vector Tajweed for Hafs"))
                        color: (quranManager.tajweedMode && quranManager.viewMode === 0) ? Theme.highlightColor : Theme.primaryColor
                        onClicked: {
                            quranManager.tajweedMode = true
                            quranManager.viewMode = 0
                        }
                    }
                }
            }

            // ========================================================
            // SECTION 2B-WARSH: TAJWEED QURAN PAGES (مصحف التجويد الملون لورش)
            // ========================================================
            Rectangle {
                visible: quranManager.isTajweedMushafAvailable(quranManager.riwayah)
                width: parent.width
                radius: 12
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.1)
                border.color: Theme.rgba(Theme.highlightColor, 0.25)
                border.width: 1
                height: tajweedCardCol.height + Theme.paddingLarge * 2

                Column {
                    id: tajweedCardCol
                    width: parent.width - Theme.paddingLarge * 2
                    anchors.centerIn: parent
                    spacing: Theme.paddingMedium

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                        Label {
                            text: "📖"
                            font.pixelSize: Theme.fontSizeLarge
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - 60
                            spacing: 4

                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: isRtl
                                      ? "مصحف التجويد الملون (طبعة دار المعرفة)"
                                      : qsTr("Colored Tajweed Mushaf (Dar Al-Ma'rifah)")
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.highlightColor
                            }

                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                text: isRtl
                                      ? "صفحات مصحف التجويد برواية ورش عن نافع ملونة حسب أحكام التجويد المعتمدة."
                                      : qsTr("Authentic colored pages for Warsh riwayah color-coded with Tajweed rules.")
                            }
                        }
                    }

                    // HD Quality Toggle Switch
                    TextSwitch {
                        width: parent.width
                        text: isRtl ? "دقة عالية جداً (HD)" : qsTr("High Definition (HD)")
                        description: isRtl
                                     ? (checked
                                        ? "مفعل: صفحات 300+ DPI فائقة الوضوح للقراءة والطباعة (~690 ميغابايت للمصحف كاملاً)."
                                        : "معطل: دقة قياسية SD خفيفة وسريعة التحميل (~90 ميغابايت للمصحف كاملاً).")
                                     : (checked
                                        ? qsTr("Enabled: Crisp 300+ DPI quality (~690 MB total).")
                                        : qsTr("Disabled: Standard Definition SD, fast & light (~90 MB total)."))
                        checked: quranManager.tajweedHdMode
                        onCheckedChanged: {
                            if (quranManager.tajweedHdMode !== checked) {
                                quranManager.tajweedHdMode = checked
                                refreshStats()
                            }
                        }
                    }

                    // Status line for selected quality
                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                        Label {
                            text: tajweedPagesCount >= 604 ? "✓" : "⬇"
                            font.bold: true
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.highlightColor
                        }

                        Label {
                            width: parent.width - 80
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: tajweedPagesCount >= 604 ? "#4cd964" : (!downloadPage.isOnline ? Theme.secondaryColor : Theme.primaryColor)
                            text: {
                                var modeName = quranManager.tajweedHdMode ? "HD" : "SD"
                                var base = isRtl
                                      ? (prayerManager.formatDigits(tajweedPagesCount.toString()) + " / " + prayerManager.formatDigits("604") + " صفحة تجويد " + modeName + " محملة (" + quranManager.formatFileSize(tajweedPagesSize) + ")" + (tajweedPagesCount >= 604 ? " • مكتمل وجاهز أوفلاين" : ""))
                                      : (tajweedPagesCount + " / 604 Tajweed " + modeName + " pages downloaded (" + quranManager.formatFileSize(tajweedPagesSize) + ")" + (tajweedPagesCount >= 604 ? " • Ready Offline" : ""))
                                if (!downloadPage.isOnline && tajweedPagesCount < 604) {
                                    base += isRtl ? " (الإنترنت معطل)" : " " + qsTr("(Internet disabled)")
                                }
                                return base
                            }
                        }
                    }

                    // Dual-Resolution Summary Note
                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeTiny
                        color: Theme.secondaryColor
                        text: isRtl
                              ? ("• الدقة القياسية (SD): " + prayerManager.formatDigits(tajweedSdCount.toString()) + " / " + prayerManager.formatDigits("604") + " (" + quranManager.formatFileSize(tajweedSdSize) + ")\n"
                               + "• الدقة الفائقة (HD): " + prayerManager.formatDigits(tajweedHdCount.toString()) + " / " + prayerManager.formatDigits("604") + " (" + quranManager.formatFileSize(tajweedHdSize) + ")")
                              : ("• Standard (SD): " + tajweedSdCount + " / 604 (" + quranManager.formatFileSize(tajweedSdSize) + ")\n"
                               + "• High Def (HD): " + tajweedHdCount + " / 604 (" + quranManager.formatFileSize(tajweedHdSize) + ")")
                    }

                    // Progress bar when downloading
                    Column {
                        width: parent.width
                        visible: quranManager.isDownloadingTajweedPages
                        spacing: Theme.paddingSmall

                        ProgressBar {
                            width: parent.width
                            minimumValue: 0
                            maximumValue: 1.0
                            value: quranManager.tajweedPagesDownloadProgress
                            label: isRtl
                                   ? ("جاري تحميل صفحات مصحف التجويد (" + (quranManager.tajweedHdMode ? "HD" : "SD") + ")...")
                                   : qsTr("Downloading Tajweed pages (%1)...").arg(quranManager.tajweedHdMode ? "HD" : "SD")
                        }

                        Button {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "إيقاف التحميل" : qsTr("Stop Download")
                            onClicked: quranManager.cancelBulkTajweedPagesDownload()
                        }
                    }

                    // Download and Delete buttons
                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium
                        visible: !quranManager.isDownloadingTajweedPages

                        Button {
                            preferredWidth: (parent.width - Theme.paddingMedium) / (tajweedPagesCount > 0 ? 2 : 1)
                            text: {
                                var modeName = quranManager.tajweedHdMode ? "HD" : "SD"
                                 if (tajweedPagesCount >= 604) {
                                    return isRtl ? ("إعادة فحص وتحديث (" + modeName + ")") : qsTr("Verify & Update (%1)").arg(modeName)
                                } else {
                                    return isRtl ? ("تحميل صفحات التجويد " + modeName + " (" + prayerManager.formatDigits("604") + ")") : qsTr("Download %1 Pages (604)").arg(modeName)
                                }
                            }
                            enabled: downloadPage.isOnline && !quranManager.isDownloadingTajweedPages
                            onClicked: quranManager.startBulkTajweedPagesDownload(quranManager.riwayah, quranManager.tajweedHdMode)
                        }

                        Button {
                            visible: tajweedPagesCount > 0
                            preferredWidth: (parent.width - Theme.paddingMedium) / 2
                            text: isRtl ? ("حذف صفحات " + (quranManager.tajweedHdMode ? "HD" : "SD")) : qsTr("Clear %1 Pages").arg(quranManager.tajweedHdMode ? "HD" : "SD")
                            onClicked: {
                                var isHd = quranManager.tajweedHdMode
                                remorse.execute(
                                    isRtl ? ("حذف صفحات مصحف التجويد المخزنة (" + (isHd ? "HD" : "SD") + ")") : qsTr("Deleting cached Tajweed pages (%1)").arg(isHd ? "HD" : "SD"),
                                    function() {
                                        quranManager.clearTajweedPagesCache(quranManager.riwayah, isHd)
                                        refreshStats()
                                    }
                                )
                            }
                        }
                    }
                }
            }

            // ========================================================
            // SECTION 2C: ALGERIAN MUSHAF PAGES (مصحف الجزائر الرسمي)
            // ========================================================
            Rectangle {
                visible: quranManager.isAlgeriaMushafAvailable(quranManager.riwayah)
                width: parent.width
                radius: 12
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.1)
                border.color: Theme.rgba(Theme.highlightColor, 0.25)
                border.width: 1
                height: algeriaCardCol.height + Theme.paddingLarge * 2

                Column {
                    id: algeriaCardCol
                    width: parent.width - Theme.paddingLarge * 2
                    anchors.centerIn: parent
                    spacing: Theme.paddingMedium

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                        Label {
                            text: "🇩🇿"
                            font.pixelSize: Theme.fontSizeLarge
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - 60
                            spacing: 4

                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: isRtl
                                      ? "مصحف الجزائر (طبعة وزارة الشؤون الدينية)"
                                      : qsTr("Algerian Mushaf (Ministry of Religious Affairs)")
                                font.bold: true
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.highlightColor
                            }

                            Label {
                                width: parent.width
                                wrapMode: Text.Wrap
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                text: isRtl
                                      ? ("مصحف الجزائر الشريف برواية ورش بخط د. محمد سعيد شريفي (" + prayerManager.formatDigits("706") + " صفحة أصيلة بدقة عالية).")
                                      : qsTr("Official Algerian Mushaf (Warsh riwayah by Dr. Mohamed Said Cherifi, 706 pages).")
                            }
                        }
                    }

                    // Mode Toggle Switch
                    TextSwitch {
                        width: parent.width
                        text: isRtl ? "استخدام مصحف الجزائر للقراءة" : qsTr("Use Algerian Mushaf for Reading")
                        description: isRtl
                                     ? (checked ? ("مفعل: صفحات خط الدكتور شريفي الرسمية (" + prayerManager.formatDigits("706") + " صفحة)") : "معطل: المصحف الرقمي الافتراضي")
                                     : (checked ? qsTr("Enabled: Dr. Cherifi edition (706 pages)") : qsTr("Disabled: Default view"))
                        checked: quranManager.algeriaMode
                        onCheckedChanged: {
                            if (quranManager.algeriaMode !== checked) {
                                quranManager.algeriaMode = checked
                                refreshStats()
                            }
                        }
                    }

                    // Status line
                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                        Label {
                            text: algeriaPagesCount >= 706 ? "✓" : "⬇"
                            font.bold: true
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.highlightColor
                        }

                        Label {
                            width: parent.width - 80
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: algeriaPagesCount >= 706 ? "#4cd964" : (!downloadPage.isOnline ? Theme.secondaryColor : Theme.primaryColor)
                            text: {
                                var base = isRtl
                                      ? (prayerManager.formatDigits(algeriaPagesCount.toString()) + " / " + prayerManager.formatDigits("706") + " صفحة محملة (" + quranManager.formatFileSize(algeriaPagesSize) + ")" + (algeriaPagesCount >= 706 ? " • مكتمل وجاهز أوفلاين" : ""))
                                      : (algeriaPagesCount + " / 706 pages downloaded (" + quranManager.formatFileSize(algeriaPagesSize) + ")" + (algeriaPagesCount >= 706 ? " • Ready Offline" : ""))
                                if (!downloadPage.isOnline && algeriaPagesCount < 706) {
                                    base += isRtl ? " (الإنترنت معطل)" : " " + qsTr("(Internet disabled)")
                                }
                                return base
                            }
                        }
                    }

                    // Progress bar when downloading
                    Column {
                        width: parent.width
                        visible: quranManager.isDownloadingAlgeriaPages
                        spacing: Theme.paddingSmall

                        ProgressBar {
                            width: parent.width
                            minimumValue: 0
                            maximumValue: 1.0
                            value: quranManager.algeriaPagesDownloadProgress
                            label: isRtl
                                   ? "جاري تحميل صفحات مصحف الجزائر..."
                                   : qsTr("Downloading Algerian Mushaf pages...")
                        }

                        Button {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "إيقاف التحميل" : qsTr("Stop Download")
                            onClicked: quranManager.cancelBulkAlgeriaPagesDownload()
                        }
                    }

                    // Download and Delete buttons
                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium
                        visible: !quranManager.isDownloadingAlgeriaPages

                        Button {
                            preferredWidth: (parent.width - Theme.paddingMedium) / (algeriaPagesCount > 0 ? 2 : 1)
                            text: {
                                if (algeriaPagesCount >= 706) {
                                    return isRtl ? ("إعادة فحص وتحديث (" + prayerManager.formatDigits("706") + ")") : qsTr("Verify & Update (706)")
                                } else {
                                    return isRtl ? ("تحميل مصحف الجزائر (" + prayerManager.formatDigits("706") + ")") : qsTr("Download Algerian Mushaf (706)")
                                }
                            }
                            enabled: downloadPage.isOnline && !quranManager.isDownloadingAlgeriaPages
                            onClicked: quranManager.startBulkAlgeriaPagesDownload()
                        }

                        Button {
                            visible: algeriaPagesCount > 0
                            preferredWidth: (parent.width - Theme.paddingMedium) / 2
                            text: isRtl ? "حذف الصفحات" : qsTr("Clear Pages")
                            onClicked: {
                                remorse.execute(
                                    isRtl ? "حذف صفحات مصحف الجزائر المخزنة" : qsTr("Deleting cached Algerian Mushaf pages"),
                                    function() {
                                        quranManager.clearAlgeriaPagesCache()
                                        refreshStats()
                                    }
                                )
                            }
                        }
                    }
                }
            }

            // ========================================================
            // SECTION 3: RECITATION AUDIO (المصحف الصوتي)
            // ========================================================
            SectionHeader {
                text: isRtl ? "التلاوة الصوتية (المصحف الصوتي)" : qsTr("Audio Recitation")
            }

            ComboBox {
                id: reciterCombo
                width: parent.width
                label: isRtl ? "القارئ:" : qsTr("Reciter:")
                currentIndex: {
                    for (var i = 0; i < recitersList.length; ++i) {
                        if (recitersList[i].id === quranManager.selectedReciterId) {
                            return i
                        }
                    }
                    return 0
                }
                menu: ContextMenu {
                    Repeater {
                        model: recitersList
                        MenuItem {
                            text: (quranManager.isReciterFavorite(modelData.id) ? "★ " : "")
                                  + (isRtl ? modelData.name_ar : (modelData.name_en ? modelData.name_en : modelData.name_ar))
                            onClicked: {
                                quranManager.setReciter(modelData.id)
                                refreshStats()
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: audioCol.height + Theme.paddingMedium * 2
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.1)
                border.color: Theme.rgba(Theme.highlightColor, 0.25)
                border.width: 1

                Column {
                    id: audioCol
                    width: parent.width - 2 * Theme.paddingMedium
                    anchors.centerIn: parent
                    spacing: Theme.paddingMedium

                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall

                        Label {
                            text: isRtl ? "الحالة:" : qsTr("Status:")
                            font.bold: true
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.highlightColor
                        }

                        Label {
                            width: parent.width - 80
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: audioCount >= (quranManager.riwayah === 2 ? 6214 : 6236) ? "#4cd964" : (!downloadPage.isOnline ? Theme.secondaryColor : Theme.primaryColor)
                            text: {
                                var base = isRtl
                                      ? (prayerManager.formatDigits(audioCount.toString()) + " آية محملة (" + quranManager.formatFileSize(audioSize) + ")" + (audioCount >= (quranManager.riwayah === 2 ? 6214 : 6236) ? " • المصحف كامل جاهز أوفلاين" : ""))
                                      : (audioCount + " ayahs downloaded (" + quranManager.formatFileSize(audioSize) + ")")
                                if (!downloadPage.isOnline && audioCount < (quranManager.riwayah === 2 ? 6214 : 6236)) {
                                    base += isRtl ? " (الإنترنت معطل)" : " " + qsTr("(Internet disabled)")
                                }
                                return base
                            }
                        }
                    }

                    // Progress bar when downloading audio
                    Column {
                        width: parent.width
                        visible: quranManager.isDownloadingAudio
                        spacing: Theme.paddingSmall

                        ProgressBar {
                            width: parent.width
                            minimumValue: 0
                            maximumValue: 1.0
                            value: quranManager.audioDownloadProgress
                            label: quranManager.audioDownloadStatus
                        }

                        Button {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: isRtl ? "إيقاف التحميل" : qsTr("Stop Download")
                            onClicked: quranManager.cancelAudioDownload()
                        }
                    }

                    // Full recitation download button
                    Button {
                        width: parent.width
                        visible: !quranManager.isDownloadingAudio
                        text: isRtl ? "تحميل المصحف الصوتي كاملاً" : qsTr("Download Full Quran Audio")
                        enabled: downloadPage.isOnline && !quranManager.isDownloadingAudio
                        onClicked: quranManager.startFullAudioDownload(quranManager.selectedReciterId)
                    }

                    // Download by Surah section
                    Column {
                        width: parent.width
                        visible: !quranManager.isDownloadingAudio
                        spacing: Theme.paddingSmall

                        Label {
                            text: isRtl ? "أو تحميل سورة محددة للاستماع أوفلاين:" : qsTr("Or download specific Surah:")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.paddingSmall

                            ComboBox {
                                id: surahCombo
                                width: parent.width - downloadSurahBtn.width - Theme.paddingSmall
                                label: isRtl ? "السورة:" : qsTr("Surah:")
                                currentIndex: Math.max(0, selectedSurahToDownload - 1)
                                menu: ContextMenu {
                                    Repeater {
                                        model: surahsList
                                        MenuItem {
                                            text: prayerManager.formatDigits(modelData.number.toString()) + ". " + (isRtl ? modelData.name_ar : modelData.name_en)
                                            onClicked: selectedSurahToDownload = modelData.number
                                        }
                                    }
                                }
                            }

                            Button {
                                id: downloadSurahBtn
                                preferredWidth: Theme.buttonWidthSmall
                                anchors.verticalCenter: surahCombo.verticalCenter
                                text: isRtl ? "تحميل" : qsTr("Download")
                                enabled: downloadPage.isOnline && !quranManager.isDownloadingAudio
                                onClicked: quranManager.startSurahAudioDownload(selectedSurahToDownload, quranManager.selectedReciterId)
                            }
                        }
                    }

                    // Clear audio cache button
                    Button {
                        visible: !quranManager.isDownloadingAudio && audioCount > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: isRtl ? "حذف التلاوات المخزنة للقارئ" : qsTr("Clear Cached Audio")
                        onClicked: {
                            remorse.execute(
                                isRtl ? "حذف التلاوات المخزنة" : qsTr("Deleting cached audio"),
                                function() {
                                    quranManager.clearAudioCache(quranManager.selectedReciterId)
                                    refreshStats()
                                }
                            )
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
        }
    }
}
