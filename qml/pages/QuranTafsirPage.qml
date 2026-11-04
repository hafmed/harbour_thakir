import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Share 1.0

Page {
    id: quranTafsirPage
    allowedOrientations: Orientation.All

    property int surahNumber: 1
    property int ayahNumber: 1
    readonly property int tafsirFontSize: quranManager.tafsirFontSize

    readonly property bool isRtl: prayerManager.isArabicLanguage
    property var ayahData: null
    property var editionsList: []
    property string activeTafsirText: ""
    property bool isPlayingThisAyah: quranManager.isPlaying && quranManager.playingSurah === surahNumber && quranManager.playingAyah === ayahNumber
    property bool isAyahBookmarked: quranManager.isBookmarked(surahNumber, ayahNumber)

    ShareAction {
        id: shareAction
        mimeType: "text/plain"
    }

    FontLoader {
        id: quranWarshFont
        source: Qt.resolvedUrl("../fonts/UthmanicWarsh.ttf")
    }

    FontLoader {
        id: quranHafsFont
        source: Qt.resolvedUrl("../fonts/UthmanicHafs.otf")
    }

    FontLoader {
        id: quranUthmanFont
        source: Qt.resolvedUrl("../fonts/UthmanTN.ttf")
    }

    FontLoader {
        id: quranUthmanBoldFont
        source: Qt.resolvedUrl("../fonts/UthmanTN-Bold.ttf")
    }

    FontLoader {
        id: quranAmiriFont
        source: Qt.resolvedUrl("../fonts/AmiriQuran-Regular.ttf")
    }

    readonly property string quranFontFamily: {
        if (quranManager.riwayah === 2 && quranWarshFont.status === FontLoader.Ready && quranWarshFont.name.length > 0) {
            return quranWarshFont.name
        }
        if (quranHafsFont.status === FontLoader.Ready && quranHafsFont.name.length > 0) {
            return quranHafsFont.name
        }
        if (quranUthmanFont.status === FontLoader.Ready && quranUthmanFont.name.length > 0) {
            return quranUthmanFont.name
        }
        if (quranUthmanBoldFont.status === FontLoader.Ready && quranUthmanBoldFont.name.length > 0) {
            return quranUthmanBoldFont.name
        }
        if (quranAmiriFont.status === FontLoader.Ready && quranAmiriFont.name.length > 0) {
            return quranAmiriFont.name
        }
        return "Naskh, UthmanTN, serif"
    }

    function toArabicDigits(num) {
        if (num === undefined || num === null) return ""
        return prayerManager.formatDigits(num.toString())
    }

    function shareCurrentAyahAndTafsir() {
        var clip = ""
        if (ayahData && ayahData.text_uthmani) {
            clip += "﴿ " + ayahData.text_uthmani + " ﴾\n"
            clip += "[" + (ayahData.surah_name_ar || "") + ": " + ayahNumber + "]\n\n"
        }
        if (activeTafsirText.length > 0) {
            clip += activeTafsirText + "\n\n"
        }
        clip += "(تطبيق ذاكر • Thakir)"

        // 1. Copy to clipboard immediately
        Clipboard.text = clip
        copyToast.show(isRtl ? "تم نسخ الآية والتفسير إلى الحافظة" : qsTr("Ayah & Tafsir copied to clipboard"))

        // 2. Open native Sailfish OS Share dialog
        try {
            var shareTitle = (ayahData ? ayahData.surah_name_ar : "") + " - " + ayahNumber
            var filePath = quranManager.createTextShareFile(shareTitle, clip)
            if (filePath && filePath.length > 0) {
                shareAction.resources = [filePath]
                shareAction.title = isRtl ? "مشاركة الآية الكريمة" : qsTr("Share Ayah")
                shareAction.trigger()
            }
        } catch (e) {
            console.log("ShareAction error:", e)
        }
    }

    function loadAyahDetails() {
        ayahData = quranManager.getAyah(surahNumber, ayahNumber)
        isAyahBookmarked = quranManager.isBookmarked(surahNumber, ayahNumber)
        if (ayahData && ayahData.total_verses) {
            var maxV = ayahData.total_verses
            if (ayahNumber > maxV) {
                ayahNumber = maxV
                ayahData = quranManager.getAyah(surahNumber, ayahNumber)
                isAyahBookmarked = quranManager.isBookmarked(surahNumber, ayahNumber)
            } else if (ayahNumber < 1) {
                ayahNumber = 1
                ayahData = quranManager.getAyah(surahNumber, ayahNumber)
                isAyahBookmarked = quranManager.isBookmarked(surahNumber, ayahNumber)
            }
        }
        editionsList = quranManager.getAvailableTafsirEditions()
        updateTafsirText()
    }

    function updateTafsirText() {
        activeTafsirText = quranManager.getAyahTafsir(surahNumber, ayahNumber, quranManager.selectedTafsirEditionId)
    }

    function goToAyah(newAyah) {
        if (!ayahData) return
        var maxAyahs = ayahData.total_verses || 1
        var target = Math.max(1, Math.min(newAyah, maxAyahs))
        if (target !== ayahNumber) {
            ayahNumber = target
            loadAyahDetails()
            flickable.contentY = 0
        }
    }

    Component.onCompleted: {
        loadAyahDetails()
    }

    Connections {
        target: quranManager
        onBookmarksChanged: {
            isAyahBookmarked = quranManager.isBookmarked(surahNumber, ayahNumber)
        }
        onSelectedTafsirEditionChanged: {
            updateTafsirText()
        }
        onRiwayahChanged: {
            loadAyahDetails()
        }
        onAudioStreamingNotice: {
            copyToast.show(isRtl ? "🌐 يلزم الاتصال بالإنترنت للاستماع (الآية غير محملة بالجهاز)"
                                 : qsTr("🌐 Internet connection required to stream (ayah not cached)"))
        }
        onAudioPlaybackFailed: {
            if (isNetworkError) {
                copyToast.show(isRtl ? "⚠️ تعذر تشغيل الصوت. يرجى التأكد من تشغيل الإنترنت."
                                     : qsTr("⚠️ Playback failed. Please check internet connection."))
            } else {
                copyToast.show(isRtl ? "⚠️ تعذر تشغيل تلاوة الآية."
                                     : qsTr("⚠️ Ayah audio playback error."))
            }
        }
    }

    SilicaFlickable {
        id: flickable
        anchors.fill: parent
        contentHeight: mainColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: isRtl ? "الاستماع إلى الآية" : qsTr("Play Ayah Audio")
                onClicked: {
                    quranManager.playAyah(surahNumber, ayahNumber)
                }
            }

            MenuItem {
                text: isRtl ? "مشاركة الآية والتفسير" : qsTr("Share Ayah & Tafsir")
                onClicked: {
                    shareCurrentAyahAndTafsir()
                }
            }

            MenuItem {
                text: isRtl
                      ? ("الرواية: " + quranManager.riwayahName)
                      : qsTr("Riwayah: %1").arg(quranManager.riwayahName)
                onClicked: {
                    quranManager.riwayah = (quranManager.riwayah === 1) ? 2 : 1
                }
            }
        }

        Column {
            id: mainColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                id: pHeader
                title: isRtl ? "التفسير والترجمة" : qsTr("Tafsir & Translation")
                description: {
                    if (!ayahData) return ""
                    var sName = isRtl ? (ayahData.surah_name_ar || "") : (ayahData.surah_name_en || "")
                    var aNum = isRtl ? prayerManager.formatDigits(ayahNumber.toString()) : ayahNumber.toString()
                    return isRtl ? (sName + " • الآية " + aNum) : (sName + " • Verse " + aNum)
                }
            }

            // Top Navigation & Font Controls Bar
            Item {
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: Theme.itemSizeExtraSmall
                anchors.horizontalCenter: parent.horizontalCenter

                Row {
                    anchors {
                        left: isRtl ? parent.left : undefined
                        right: isRtl ? undefined : parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.paddingSmall
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    IconButton {
                        icon.source: "image://theme/icon-m-remove"
                        width: Theme.iconSizeSmall
                        height: Theme.iconSizeSmall
                        icon.width: Theme.iconSizeSmall
                        icon.height: Theme.iconSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            quranManager.tafsirFontSize = Math.max(16, quranManager.tafsirFontSize - 2)
                            copyToast.show(isRtl
                                           ? ("حجم الخط: " + prayerManager.formatDigits(quranManager.tafsirFontSize.toString()))
                                           : (qsTr("Font size: %1").arg(prayerManager.formatDigits(quranManager.tafsirFontSize.toString()))))
                        }
                    }

                    Label {
                        text: "A"
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.highlightColor
                        font.bold: true
                    }

                    IconButton {
                        icon.source: "image://theme/icon-m-add"
                        width: Theme.iconSizeSmall
                        height: Theme.iconSizeSmall
                        icon.width: Theme.iconSizeSmall
                        icon.height: Theme.iconSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            quranManager.tafsirFontSize = Math.min(48, quranManager.tafsirFontSize + 2)
                            copyToast.show(isRtl
                                           ? ("حجم الخط: " + prayerManager.formatDigits(quranManager.tafsirFontSize.toString()))
                                           : (qsTr("Font size: %1").arg(prayerManager.formatDigits(quranManager.tafsirFontSize.toString()))))
                        }
                    }
                }

                Row {
                    anchors {
                        left: isRtl ? undefined : parent.left
                        right: isRtl ? parent.right : undefined
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.paddingSmall
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    Label {
                        text: quranManager.riwayahName
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.highlightColor
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Ayah Quranic Text Box (Card)
            Rectangle {
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: ayahInnerCol.height + 2 * Theme.paddingMedium
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.paddingMedium
                color: isPlayingThisAyah
                       ? Theme.rgba(Theme.highlightBackgroundColor, 0.25)
                       : Theme.rgba(Theme.primaryColor, 0.05)
                border.color: isPlayingThisAyah
                              ? Theme.highlightColor
                              : Theme.rgba(Theme.highlightColor, 0.25)
                border.width: isPlayingThisAyah ? 2 : 1

                Column {
                    id: ayahInnerCol
                    width: parent.width - 2 * Theme.paddingLarge
                    anchors.centerIn: parent
                    spacing: Theme.paddingSmall

                    // Header row with Surah, Ayah, Page, and Play
                    Row {
                        width: parent.width
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: Theme.paddingSmall

                        Label {
                            text: {
                                if (!ayahData) return ""
                                return isRtl
                                    ? (ayahData.surah_name_ar + " ﴿" + prayerManager.formatDigits(ayahNumber.toString()) + "﴾")
                                    : (ayahData.surah_name_en + " (" + ayahNumber + ")")
                            }
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            color: Theme.highlightColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: Theme.paddingSmall; height: 1 }

                        Label {
                            visible: ayahData && ayahData.page_number
                            text: isRtl
                                  ? ("ص " + prayerManager.formatDigits((ayahData ? ayahData.page_number : 0).toString()))
                                  : ("p. " + (ayahData ? ayahData.page_number : 0))
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item {
                            // Spacer
                            width: 1
                            height: 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Uthmani Ayah Text
                    Text {
                        width: parent.width
                        text: (ayahData && ayahData.text_uthmani)
                              ? (ayahData.text_uthmani + " ﴿" + toArabicDigits(ayahNumber) + "﴾")
                              : ""
                        font.family: quranFontFamily
                        font.pixelSize: Math.max(22, Math.max(quranManager.fontSize - 4, quranManager.tafsirFontSize + 2))
                        color: isPlayingThisAyah ? Theme.highlightColor : Theme.primaryColor
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignRight
                        lineHeight: 1.4
                    }

                    // Action buttons bar inside card
                    Row {
                        width: parent.width
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: Theme.paddingMedium

                        IconButton {
                            icon.source: isPlayingThisAyah ? "image://theme/icon-m-pause" : "image://theme/icon-m-play"
                            width: Theme.iconSizeSmall
                            height: Theme.iconSizeSmall
                            icon.width: Theme.iconSizeSmall
                            icon.height: Theme.iconSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                if (isPlayingThisAyah) {
                                    quranManager.pauseAudio()
                                } else {
                                    quranManager.playAyah(surahNumber, ayahNumber)
                                }
                            }
                        }

                        IconButton {
                            icon.source: isAyahBookmarked ? "image://theme/icon-m-favorite-selected" : "image://theme/icon-m-favorite"
                            width: Theme.iconSizeSmall
                            height: Theme.iconSizeSmall
                            icon.width: Theme.iconSizeSmall
                            icon.height: Theme.iconSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                var nowBookmarked = quranManager.toggleBookmark(surahNumber, ayahNumber)
                                isAyahBookmarked = nowBookmarked
                                if (ayahData) {
                                    ayahData.isBookmarked = nowBookmarked
                                }
                                copyToast.show(nowBookmarked
                                               ? (isRtl ? "تمت إضافة الآية إلى المفضلة" : qsTr("Added to bookmarks"))
                                               : (isRtl ? "تمت إزالة الآية من المفضلة" : qsTr("Removed from bookmarks")))
                            }
                        }

                        IconButton {
                            icon.source: "image://theme/icon-m-share"
                            width: Theme.iconSizeSmall
                            height: Theme.iconSizeSmall
                            icon.width: Theme.iconSizeSmall
                            icon.height: Theme.iconSizeSmall
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                shareCurrentAyahAndTafsir()
                            }
                        }
                    }
                }
            }

            // Tafsir / Translation Edition Selector ComboBox
            ComboBox {
                id: editionComboBox
                width: parent.width
                label: isRtl ? "المصدر المعتمد:" : qsTr("Edition:")
                currentIndex: {
                    var curId = quranManager.selectedTafsirEditionId
                    for (var i = 0; i < editionsList.length; ++i) {
                        if (editionsList[i].id === curId) return i
                    }
                    return 0
                }

                menu: ContextMenu {
                    Repeater {
                        model: editionsList
                        MenuItem {
                            text: isRtl
                                  ? (modelData.name_ar + " (" + modelData.language.toUpperCase() + ")")
                                  : (modelData.name_en + " (" + modelData.language.toUpperCase() + ")")
                            onClicked: {
                                quranManager.selectedTafsirEditionId = modelData.id
                            }
                        }
                    }
                }
            }

            // Tafsir / Translation Text Container
            Rectangle {
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: tafsirContentCol.height + 2 * Theme.paddingLarge
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.primaryColor, 0.03)
                border.color: Theme.rgba(Theme.primaryColor, 0.12)
                border.width: 1

                Column {
                    id: tafsirContentCol
                    width: parent.width - 2 * Theme.paddingLarge
                    anchors.centerIn: parent
                    spacing: Theme.paddingMedium

                    // Title of the active edition
                    Row {
                        width: parent.width
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: Theme.paddingSmall

                        Label {
                            text: {
                                var curId = quranManager.selectedTafsirEditionId
                                for (var i = 0; i < editionsList.length; ++i) {
                                    if (editionsList[i].id === curId) {
                                        return isRtl ? editionsList[i].name_ar : editionsList[i].name_en
                                    }
                                }
                                return isRtl ? "التفسير الميسر" : "Tafsir Al-Muyassar"
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: Theme.highlightColor
                        }

                        Label {
                            text: {
                                var curId = quranManager.selectedTafsirEditionId
                                for (var i = 0; i < editionsList.length; ++i) {
                                    if (editionsList[i].id === curId) {
                                        return "[" + editionsList[i].language.toUpperCase() + "]"
                                    }
                                }
                                return "[AR]"
                            }
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                        }
                    }

                    // Actual Tafsir / Translation Text
                    Text {
                        id: tafsirTextItem
                        width: parent.width
                        text: activeTafsirText.length > 0
                              ? activeTafsirText
                              : (isRtl ? "لا يتوفر نص تفسير لهذه الآية." : qsTr("No text available for this verse."))
                        font.pixelSize: tafsirFontSize
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                        horizontalAlignment: {
                            var curId = quranManager.selectedTafsirEditionId
                            return (curId.indexOf("ar.") === 0) ? Text.AlignRight : Text.AlignLeft
                        }
                        lineHeight: 1.45
                    }
                }
            }

            // Bottom Ayah Navigation Buttons
            Item {
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: Theme.itemSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.paddingLarge
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    Button {
                        preferredWidth: Theme.buttonWidthSmall
                        text: isRtl ? "الآية السابقة" : qsTr("Previous")
                        enabled: ayahNumber > 1
                        onClicked: goToAyah(ayahNumber - 1)
                    }

                    Label {
                        text: {
                            var total = ayahData ? ayahData.total_verses : 1
                            return isRtl
                                ? (prayerManager.formatDigits(ayahNumber.toString()) + " / " + prayerManager.formatDigits(total.toString()))
                                : (ayahNumber + " / " + total)
                        }
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        color: Theme.highlightColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Button {
                        preferredWidth: Theme.buttonWidthSmall
                        text: isRtl ? "الآية التالية" : qsTr("Next")
                        enabled: ayahData && (ayahNumber < ayahData.total_verses)
                        onClicked: goToAyah(ayahNumber + 1)
                    }
                }
            }

            Item { width: 1; height: Theme.paddingLarge }
        }
    }

    // Floating Feedback Toast Banner
    Rectangle {
        id: copyToast
        anchors {
            bottom: parent.bottom
            bottomMargin: Theme.paddingLarge * 2
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.min(parent.width - Theme.horizontalPageMargin * 2, toastLabel.width + Theme.paddingLarge * 2)
        height: toastLabel.height + Theme.paddingMedium * 2
        radius: Theme.paddingMedium
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.95)
        border.color: Theme.highlightColor
        border.width: 1
        opacity: 0
        visible: opacity > 0
        z: 999

        Label {
            id: toastLabel
            anchors.centerIn: parent
            text: ""
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Timer {
            id: toastTimer
            interval: 2500
            onTriggered: copyToast.opacity = 0
        }

        function show(msg) {
            toastLabel.text = msg
            copyToast.opacity = 1
            toastTimer.restart()
        }
    }
}
