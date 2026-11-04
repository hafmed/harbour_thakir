import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: quranIndexPage
    allowedOrientations: Orientation.All

    readonly property bool isRtl: prayerManager.isArabicLanguage
    property int selectedTab: 0 // 0 = Surahs, 1 = Juz/Hizb, 2 = Bookmarks
    property string searchQuery: ""
    property string debouncedQuery: ""
    readonly property bool isSearching: debouncedQuery.trim().length >= 2

    Timer {
        id: searchDebounceTimer
        interval: 250
        repeat: false
        onTriggered: {
            debouncedQuery = searchQuery.trim()
        }
    }

    onSearchQueryChanged: {
        if (searchQuery.trim().length < 2) {
            searchDebounceTimer.stop()
            debouncedQuery = ""
        } else {
            searchDebounceTimer.restart()
        }
    }

    // Popular Search Options & Scopes
    property int searchMode: 0 // 0: Exact Word, 1: Partial Match, 2: Arabic Root, 3: Phrase, 4: Translation
    property int scopeType: 0  // 0: All Quran, 1: Surah, 2: Juz, 3: Page
    property int scopeSurah: 1
    property int scopeJuz: 1
    property int scopePage: 1
    property string searchEdition: "all"
    property bool respectTashkeel: false
    property bool showSearchOptions: false

    readonly property int activeRiwayah: quranManager.riwayah

    readonly property var searchResults: {
        if (!isSearching) return []
        var rId = activeRiwayah // Explicit reactive dependency on active Riwayah
        var effScopeVal = 0
        if (scopeType === 1) effScopeVal = scopeSurah
        else if (scopeType === 2) effScopeVal = scopeJuz
        else if (scopeType === 3) effScopeVal = scopePage

        return quranManager.searchAdvanced(
            debouncedQuery,
            searchMode,
            scopeType,
            effScopeVal,
            searchEdition,
            respectTashkeel
        )
    }

    property int displayLimit: 40

    onActiveRiwayahChanged: displayLimit = 40
    onDebouncedQueryChanged: displayLimit = 40
    onSearchModeChanged: displayLimit = 40
    onScopeTypeChanged: displayLimit = 40
    onScopeSurahChanged: displayLimit = 40
    onScopeJuzChanged: displayLimit = 40
    onScopePageChanged: displayLimit = 40
    onSearchEditionChanged: displayLimit = 40
    onRespectTashkeelChanged: displayLimit = 40

    readonly property var visibleSearchResults: {
        if (!searchResults || searchResults.length === 0) return []
        if (searchResults.length <= displayLimit) return searchResults
        return searchResults.slice(0, displayLimit)
    }

    property var surahsList: []
    property var juzsList: []
    property var bookmarksList: []

    function refreshData() {
        surahsList = quranManager.getSurahs()
        juzsList = quranManager.getJuzs()
        bookmarksList = quranManager.getBookmarks()
    }

    Component.onCompleted: {
        refreshData()
    }

    Connections {
        target: quranManager
        onRiwayahChanged: {
            refreshData()
            displayLimit = 40
        }
        onAlgeriaModeChanged: refreshData()
        onMushafNameChanged: refreshData()
        onBookmarksChanged: refreshData()
    }

    RemorsePopup {
        id: remorsePopup
    }

    SilicaFlickable {
        id: indexFlickable
        anchors.fill: parent
        contentHeight: column.height

        onAtYEndChanged: {
            if (atYEnd && isSearching && searchResults && searchResults.length > displayLimit) {
                displayLimit = Math.min(searchResults.length, displayLimit + 40)
            }
        }

        PullDownMenu {
            MenuItem {
                text: isRtl
                      ? ("الرواية: " + quranManager.riwayahName)
                      : qsTr("Riwayah: %1").arg(quranManager.riwayahName)
                onClicked: {
                    quranManager.riwayah = (quranManager.riwayah === 1) ? 2 : 1
                }
            }

            MenuItem {
                text: isRtl ? "إدارة التحميل والأوفلاين" : qsTr("Downloads & Offline")
                onClicked: pageStack.push(Qt.resolvedUrl("QuranDownloadPage.qml"))
            }

            MenuItem {
                text: isRtl ? "متابعة القراءة (آخر موضع)" : qsTr("Continue Reading")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("QuranReaderPage.qml"), {
                        surahNumber: quranManager.lastSurah,
                        startAyah: quranManager.lastAyah,
                        initialPage: quranManager.lastPage,
                        highlightTargetAyah: true
                    })
                }
            }

            MenuItem {
                text: isRtl ? "التفسير والترجمة (آخر موضع)" : qsTr("Tafsir & Translation (Last Position)")
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("QuranTafsirPage.qml"), {
                        surahNumber: quranManager.lastSurah,
                        ayahNumber: quranManager.lastAyah
                    })
                }
            }

            MenuItem {
                text: isRtl
                      ? ("نمط العرض: " + (quranManager.viewMode === 0 ? "نصي" : "مصحف مصور"))
                      : qsTr("View: %1").arg(quranManager.viewMode === 0 ? qsTr("Text") : qsTr("Mushaf Page"))
                onClicked: {
                    var newMode = (quranManager.viewMode === 0) ? 1 : 0
                    if (newMode === 0 && !quranManager.isTextModeDisclaimerConfirmed(prayerManager.appVersion)) {
                        var dialog = pageStack.push(Qt.resolvedUrl("TextModeDisclaimerDialog.qml"))
                        if (dialog) {
                            dialog.accepted.connect(function() {
                                quranManager.viewMode = 0
                            })
                        }
                    } else {
                        quranManager.viewMode = newMode
                    }
                }
            }

            MenuItem {
                text: quranManager.darkMode
                      ? (isRtl ? "الوضع النهاري (فاتح)" : qsTr("Light Reading Mode"))
                      : (isRtl ? "الوضع الليلي (داكن)" : qsTr("Dark Reading Mode"))
                onClicked: {
                    quranManager.darkMode = !quranManager.darkMode
                }
            }

            MenuItem {
                text: quranManager.tajweedMode
                      ? (isRtl ? "إيقاف مصحف التجويد الملون" : qsTr("Disable Colored Tajweed"))
                      : (isRtl ? (quranManager.riwayah === 1 ? "تفعيل مصحف التجويد الملون (متجهات)" : "تفعيل مصحف التجويد الملون") : qsTr("Enable Colored Tajweed"))
                onClicked: {
                    var activating = !quranManager.tajweedMode
                    quranManager.tajweedMode = activating
                    if (activating && quranManager.riwayah === 1 && quranManager.viewMode === 1) {
                        quranManager.viewMode = 0
                    }
                }
            }

            MenuItem {
                text: isRtl
                      ? ("القارئ: " + quranManager.selectedReciterName)
                      : qsTr("Reciter: %1").arg(quranManager.selectedReciterName)
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("ReciterPickerDialog.qml"))
                }
            }

            MenuItem {
                text: isRtl ? "إحصائيات وسجل الاستماع" : qsTr("Listening Statistics")
                onClicked: pageStack.push(Qt.resolvedUrl("QuranListeningStatsPage.qml"))
            }

            MenuItem {
                visible: selectedTab === 2 && bookmarksList.length > 0 && !isSearching
                text: isRtl ? "حذف جميع العلامات المرجعية" : qsTr("Clear All Bookmarks")
                onClicked: {
                    remorsePopup.execute(isRtl ? "جاري حذف جميع العلامات المرجعية..." : qsTr("Deleting all bookmarks..."), function() {
                        quranManager.clearAllBookmarks()
                    })
                }
            }
        }

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: isRtl ? "المصحف الشريف" : qsTr("Holy Quran")
                description: quranManager.riwayahName
            }

            // Quick Riwayah & Resume Card
            Item {
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: resumeRow.height + Theme.paddingSmall
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.paddingSmall
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                    border.color: Theme.rgba(Theme.highlightColor, 0.3)
                    border.width: 1
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("QuranReaderPage.qml"), {
                            surahNumber: quranManager.lastSurah,
                            startAyah: quranManager.lastAyah,
                            initialPage: quranManager.lastPage,
                            highlightTargetAyah: true
                        })
                    }
                }

                Row {
                    id: resumeRow
                    width: parent.width - 2 * Theme.paddingMedium
                    anchors.centerIn: parent
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                    spacing: Theme.paddingMedium

                    Icon {
                        source: Qt.resolvedUrl("../icons/quran.svg")
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.highlightColor
                    }

                    Column {
                        width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium - riwayahBtn.width
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            width: parent.width
                            text: isRtl ? "متابعة آخر قراءة" : qsTr("Resume Last Read")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.highlightColor
                            font.bold: true
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width
                            text: {
                                var sInfo = quranManager.getSurah(quranManager.lastSurah)
                                var sName = sInfo ? (isRtl ? ("سورة " + sInfo.name_ar) : sInfo.name_en) : ""
                                return isRtl
                                    ? (sName + " • آية " + prayerManager.formatDigits(quranManager.lastAyah.toString()) + " • صفحة " + prayerManager.formatDigits(quranManager.lastPage.toString()))
                                    : (sName + " • Ayah " + quranManager.lastAyah + " • Page " + quranManager.lastPage)
                            }
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                            truncationMode: TruncationMode.Fade
                        }
                    }

                    Button {
                        id: riwayahBtn
                        anchors.verticalCenter: parent.verticalCenter
                        text: quranManager.riwayah === 2 ? "ورش" : "حفص"
                        preferredWidth: Theme.buttonWidthExtraSmall * 0.95
                        onClicked: {
                            quranManager.riwayah = (quranManager.riwayah === 1) ? 2 : 1
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.paddingSmall }

            // Search Field
            SearchField {
                id: searchField
                width: parent.width
                placeholderText: {
                    if (searchMode === 0) return isRtl ? "بحث عن الكلمة ولواحقها (مثل: رب، كتاب، الأرض)..." : qsTr("Word & affixes search (e.g. Rabb, Kitaab)...")
                    if (searchMode === 1) return isRtl ? "بحث حرفي مجرد تماماً..." : qsTr("Exact literal search...")
                    if (searchMode === 2) return isRtl ? "بحث بأي حرف أو جزء من كلمة..." : qsTr("Partial match / substring...")
                    if (searchMode === 3) return isRtl ? "أدخل جذر الكلمة (مثال: كتب، رحم، علم)..." : qsTr("Enter Arabic root (e.g. كتب, رحم)...")
                    if (searchMode === 4) return isRtl ? "بحث عن عبارة أو جملة متتالية..." : qsTr("Search phrase or multiple words...")
                    if (searchMode === 5) return isRtl ? "بحث في الترجمة بالإنجليزية أو الفرنسية..." : qsTr("Search in translation text...")
                    return isRtl ? "بحث في آيات وسور القرآن..." : qsTr("Search Quran verses...")
                }
                text: searchQuery
                onTextChanged: {
                    searchQuery = text
                }
            }

            // Search Options & Scope Bar
            Item {
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: optionsBarRow.height + Theme.paddingSmall * 2
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.paddingSmall
                    color: showSearchOptions
                           ? Theme.rgba(Theme.highlightColor, 0.15)
                           : (quranManager.darkMode ? Theme.rgba("#1e2534", 0.75) : Theme.rgba(Theme.secondaryColor, 0.1))
                    border.color: showSearchOptions ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                    border.width: 1
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: showSearchOptions = !showSearchOptions
                }

                Row {
                    id: optionsBarRow
                    width: parent.width - 2 * Theme.paddingMedium
                    anchors.centerIn: parent
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                    spacing: Theme.paddingMedium

                    Icon {
                        source: "image://theme/icon-m-search"
                        anchors.verticalCenter: parent.verticalCenter
                        color: showSearchOptions ? Theme.highlightColor : Theme.primaryColor
                    }

                    Column {
                        width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium * 2 - expandIcon.width
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Label {
                            width: parent.width
                            text: isRtl ? "خيارات البحث ونطاق البحث" : qsTr("Search Options & Scope")
                            font.pixelSize: Theme.fontSizeSmall
                            color: showSearchOptions ? Theme.highlightColor : Theme.primaryColor
                            font.bold: true
                        }

                        Label {
                            width: parent.width
                            text: {
                                var modeName = ""
                                if (searchMode === 0) modeName = isRtl ? "الكلمة ولواحقها" : qsTr("Word & Affixes")
                                else if (searchMode === 1) modeName = isRtl ? "مطابقة مجردة" : qsTr("Exact Literal")
                                else if (searchMode === 2) modeName = isRtl ? "مطابقة جزئية" : qsTr("Partial Match")
                                else if (searchMode === 3) modeName = isRtl ? "جذر الكلمة" : qsTr("Arabic Root")
                                else if (searchMode === 4) modeName = isRtl ? "عبارة متتالية" : qsTr("Phrase Search")
                                else if (searchMode === 5) modeName = isRtl ? "بحث في الترجمة" : qsTr("Translation")

                                var scopeName = ""
                                if (scopeType === 0) scopeName = isRtl ? "كامل المصحف" : qsTr("All Quran")
                                else if (scopeType === 1) {
                                    var sInfo = quranManager.getSurah(scopeSurah)
                                    scopeName = isRtl ? ("سورة " + (sInfo ? sInfo.name_ar : scopeSurah)) : (sInfo ? sInfo.name_en : ("Surah " + scopeSurah))
                                } else if (scopeType === 2) {
                                    scopeName = isRtl ? ("الجزء " + prayerManager.formatDigits(scopeJuz.toString())) : ("Juz " + scopeJuz)
                                } else if (scopeType === 3) {
                                    scopeName = isRtl ? ("صفحة " + prayerManager.formatDigits(scopePage.toString())) : ("Page " + scopePage)
                                }

                                var tashkeelTag = (respectTashkeel && searchMode !== 5) ? (isRtl ? " • تشكيل" : " • Tashkeel") : ""
                                return modeName + tashkeelTag + " • " + scopeName
                            }
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.secondaryColor
                            truncationMode: TruncationMode.Fade
                        }
                    }

                    Icon {
                        id: expandIcon
                        source: showSearchOptions ? "image://theme/icon-m-up" : "image://theme/icon-m-down"
                        anchors.verticalCenter: parent.verticalCenter
                        color: showSearchOptions ? Theme.highlightColor : Theme.secondaryColor
                    }
                }
            }

            // Collapsible Search Options Panel
            Column {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                visible: showSearchOptions
                spacing: Theme.paddingSmall

                Item { width: 1; height: 2 }

                // Search Mode Selection
                Label {
                    text: isRtl ? "نوع البحث المطلوب:" : qsTr("Search Mode:")
                    font.pixelSize: Theme.fontSizeExtraSmall
                    font.bold: true
                    color: Theme.highlightColor
                }

                Flow {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    // 0: Word & Affixes (Lemma)
                    Rectangle {
                        width: affixesLbl.implicitWidth + Theme.paddingMedium * 2
                        height: Theme.itemSizeExtraSmall * 0.72
                        radius: Theme.paddingSmall
                        color: searchMode === 0
                               ? Theme.rgba(Theme.highlightColor, 0.25)
                               : (quranManager.darkMode ? Theme.rgba("#242c3d", 0.8) : Theme.rgba(Theme.secondaryColor, 0.12))
                        border.color: searchMode === 0 ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                        border.width: 1

                        Label {
                            id: affixesLbl
                            anchors.centerIn: parent
                            text: isRtl ? "الكلمة ولواحقها" : qsTr("Word & Affixes")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: searchMode === 0
                            color: searchMode === 0 ? Theme.highlightColor : Theme.primaryColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: searchMode = 0
                        }
                    }

                    // 1: Exact Literal
                    Rectangle {
                        width: literalLbl.implicitWidth + Theme.paddingMedium * 2
                        height: Theme.itemSizeExtraSmall * 0.72
                        radius: Theme.paddingSmall
                        color: searchMode === 1
                               ? Theme.rgba(Theme.highlightColor, 0.25)
                               : (quranManager.darkMode ? Theme.rgba("#242c3d", 0.8) : Theme.rgba(Theme.secondaryColor, 0.12))
                        border.color: searchMode === 1 ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                        border.width: 1

                        Label {
                            id: literalLbl
                            anchors.centerIn: parent
                            text: isRtl ? "مطابقة مجردة" : qsTr("Exact Literal")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: searchMode === 1
                            color: searchMode === 1 ? Theme.highlightColor : Theme.primaryColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: searchMode = 1
                        }
                    }

                    // 2: Partial Match
                    Rectangle {
                        width: partialLbl.implicitWidth + Theme.paddingMedium * 2
                        height: Theme.itemSizeExtraSmall * 0.72
                        radius: Theme.paddingSmall
                        color: searchMode === 2
                               ? Theme.rgba(Theme.highlightColor, 0.25)
                               : (quranManager.darkMode ? Theme.rgba("#242c3d", 0.8) : Theme.rgba(Theme.secondaryColor, 0.12))
                        border.color: searchMode === 2 ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                        border.width: 1

                        Label {
                            id: partialLbl
                            anchors.centerIn: parent
                            text: isRtl ? "مطابقة جزئية" : qsTr("Partial Match")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: searchMode === 2
                            color: searchMode === 2 ? Theme.highlightColor : Theme.primaryColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: searchMode = 2
                        }
                    }

                    // 3: Arabic Root
                    Rectangle {
                        width: rootLbl.implicitWidth + Theme.paddingMedium * 2
                        height: Theme.itemSizeExtraSmall * 0.72
                        radius: Theme.paddingSmall
                        color: searchMode === 3
                               ? Theme.rgba(Theme.highlightColor, 0.25)
                               : (quranManager.darkMode ? Theme.rgba("#242c3d", 0.8) : Theme.rgba(Theme.secondaryColor, 0.12))
                        border.color: searchMode === 3 ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                        border.width: 1

                        Label {
                            id: rootLbl
                            anchors.centerIn: parent
                            text: isRtl ? "جذر الكلمة" : qsTr("Arabic Root")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: searchMode === 3
                            color: searchMode === 3 ? Theme.highlightColor : Theme.primaryColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: searchMode = 3
                        }
                    }

                    // 4: Phrase Search
                    Rectangle {
                        width: phraseLbl.implicitWidth + Theme.paddingMedium * 2
                        height: Theme.itemSizeExtraSmall * 0.72
                        radius: Theme.paddingSmall
                        color: searchMode === 4
                               ? Theme.rgba(Theme.highlightColor, 0.25)
                               : (quranManager.darkMode ? Theme.rgba("#242c3d", 0.8) : Theme.rgba(Theme.secondaryColor, 0.12))
                        border.color: searchMode === 4 ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                        border.width: 1

                        Label {
                            id: phraseLbl
                            anchors.centerIn: parent
                            text: isRtl ? "عبارة متتالية" : qsTr("Phrase Search")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: searchMode === 4
                            color: searchMode === 4 ? Theme.highlightColor : Theme.primaryColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: searchMode = 4
                        }
                    }

                    // 5: Translation Search
                    Rectangle {
                        width: transLbl.implicitWidth + Theme.paddingMedium * 2
                        height: Theme.itemSizeExtraSmall * 0.72
                        radius: Theme.paddingSmall
                        color: searchMode === 5
                               ? Theme.rgba(Theme.highlightColor, 0.25)
                               : (quranManager.darkMode ? Theme.rgba("#242c3d", 0.8) : Theme.rgba(Theme.secondaryColor, 0.12))
                        border.color: searchMode === 5 ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                        border.width: 1

                        Label {
                            id: transLbl
                            anchors.centerIn: parent
                            text: isRtl ? "بحث في الترجمة" : qsTr("Translation")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: searchMode === 5
                            color: searchMode === 5 ? Theme.highlightColor : Theme.primaryColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: searchMode = 5
                        }
                    }
                }

                // Description of active search mode
                Label {
                    width: parent.width
                    text: {
                        if (searchMode === 0) return isRtl ? "• البحث عن الكلمة بجميع لواحقها وتصريفاتها القرآنية (كـ: رَبّ، رَبَّنَا، وَرَبُّكَ، بِالْكِتَاب) كما في معجم كلمات القرآن (QuranProgress)." : qsTr("• Find word with its Qur'anic affixes (al-, wa-, bi-, pronouns like Rabb, Rabbana, wa-Rabbuka) matching frequency statistics.")
                        if (searchMode === 1) return isRtl ? "• مطابقة الكلمة حرفياً تماماً دون أي حروف جر أو ضمائر متصلة بها." : qsTr("• Exact verbatim match without attached affixes or pronouns.")
                        if (searchMode === 2) return isRtl ? "• البحث عن أي حرف أو جزء من كلمة لإيجاد كافة المشتقات والصيغ." : qsTr("• Search for letters or partial words to find all matching variations.")
                        if (searchMode === 3) return isRtl ? "• البحث بالجذر (3 أو 4 أحرف) لإيجاد كل مشتقات الكلمة (مثل: كتب، رحم، علم، زلزل)." : qsTr("• Look up words based on their 3-letter or 4-letter Arabic roots.")
                        if (searchMode === 4) return isRtl ? "• البحث عن جملة أو تسلسل عدة كلمات متتالية معاً بالترتيب." : qsTr("• Search for a sequence of multiple words together.")
                        if (searchMode === 5) return isRtl ? "• البحث بالإنجليزية، الفرنسية، التركية، أو العربية في معاني الآيات وترجماتها." : qsTr("• Type words in English, French, or other languages to search within translated text.")
                        return ""
                    }
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.secondaryColor
                    wrapMode: Text.Wrap
                }

                // Translation edition selector (when Translation mode is active)
                ComboBox {
                    width: parent.width
                    visible: searchMode === 5
                    label: isRtl ? "لغة / ترجمة البحث:" : qsTr("Search In:")
                    currentIndex: 0
                    menu: ContextMenu {
                        MenuItem {
                            text: isRtl ? "جميع اللغات والترجمات" : qsTr("All Languages & Editions")
                            onClicked: searchEdition = "all"
                        }
                        MenuItem {
                            text: "Saheeh International (English)"
                            onClicked: searchEdition = "en.sahih"
                        }
                        MenuItem {
                            text: "Muhammad Hamidullah (Français)"
                            onClicked: searchEdition = "fr.hamidullah"
                        }
                        MenuItem {
                            text: "Diyanet İşleri (Türkçe)"
                            onClicked: searchEdition = "tr.diyanet"
                        }
                        MenuItem {
                            text: isRtl ? "التفسير الميسر (العربية)" : "Tafsir Al-Muyassar (Arabic)"
                            onClicked: searchEdition = "ar.muyassar"
                        }
                        MenuItem {
                            text: isRtl ? "تفسير الجلالين (العربية)" : "Tafsir Al-Jalalayn (Arabic)"
                            onClicked: searchEdition = "ar.jalalayn"
                        }
                    }
                }

                // Respect Tashkeel Option (Diacritics matching)
                Row {
                    width: parent.width
                    visible: searchMode !== 5
                    spacing: Theme.paddingMedium
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    Rectangle {
                        width: parent.width
                        height: tashkeelCol.height + Theme.paddingSmall * 2
                        radius: Theme.paddingSmall
                        color: respectTashkeel
                               ? Theme.rgba(Theme.highlightColor, 0.18)
                               : (quranManager.darkMode ? Theme.rgba("#242c3d", 0.6) : Theme.rgba(Theme.secondaryColor, 0.08))
                        border.color: respectTashkeel ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.25)
                        border.width: 1

                        Column {
                            id: tashkeelCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.paddingSmall / 2

                            Row {
                                width: parent.width
                                spacing: Theme.paddingSmall
                                layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                                Rectangle {
                                    width: Theme.paddingMedium * 1.4
                                    height: width
                                    radius: width / 2
                                    color: respectTashkeel ? Theme.highlightColor : "transparent"
                                    border.color: respectTashkeel ? Theme.highlightColor : Theme.secondaryColor
                                    border.width: 1.5
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: parent.width * 0.45
                                        height: width
                                        radius: width / 2
                                        color: "white"
                                        anchors.centerIn: parent
                                        visible: respectTashkeel
                                    }
                                }

                                Label {
                                    text: isRtl ? "مراعاة التشكيل والحركات (فَتْحَة، ضَمَّة، كَسْرَة، شَدَّة)" : qsTr("Respect Tashkeel / Diacritics (Exact Vowels)")
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: respectTashkeel
                                    color: respectTashkeel ? Theme.highlightColor : Theme.primaryColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Label {
                                width: parent.width
                                text: respectTashkeel
                                      ? (isRtl ? "• مُفَعَّل: سيتم حصر النتائج في الكلمات التي تُطابق نفس الحركات والتشكيل المدخل تماماً." : qsTr("• Active: Only verses matching exact vowels, sukoon, shaddah, and tanween will match."))
                                      : (isRtl ? "• غير مفعل: يتم تجاهل الحركات ومطابقة الأحرف المجردة." : qsTr("• Off: Diacritics are ignored during search."))
                                font.pixelSize: Theme.fontSizeTiny
                                color: respectTashkeel ? Theme.highlightColor : Theme.secondaryColor
                                wrapMode: Text.Wrap
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: respectTashkeel = !respectTashkeel
                        }
                    }
                }

                // Scoped Search Selection
                Label {
                    text: isRtl ? "نطاق البحث المحدد:" : qsTr("Search Scope:")
                    font.pixelSize: Theme.fontSizeExtraSmall
                    font.bold: true
                    color: Theme.highlightColor
                }

                Row {
                    width: parent.width
                    spacing: Theme.paddingSmall
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    // Scope 0: All
                    Rectangle {
                        width: (parent.width - 3 * Theme.paddingSmall) / 4
                        height: Theme.itemSizeExtraSmall * 0.72
                        radius: Theme.paddingSmall
                        color: scopeType === 0
                               ? Theme.rgba(Theme.highlightColor, 0.25)
                               : (quranManager.darkMode ? Theme.rgba("#242c3d", 0.8) : Theme.rgba(Theme.secondaryColor, 0.12))
                        border.color: scopeType === 0 ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                        border.width: 1

                        Label {
                            anchors.centerIn: parent
                            text: isRtl ? "المصحف" : qsTr("All")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: scopeType === 0
                            color: scopeType === 0 ? Theme.highlightColor : Theme.primaryColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: scopeType = 0
                        }
                    }

                    // Scope 1: Surah
                    Rectangle {
                        width: (parent.width - 3 * Theme.paddingSmall) / 4
                        height: Theme.itemSizeExtraSmall * 0.72
                        radius: Theme.paddingSmall
                        color: scopeType === 1
                               ? Theme.rgba(Theme.highlightColor, 0.25)
                               : (quranManager.darkMode ? Theme.rgba("#242c3d", 0.8) : Theme.rgba(Theme.secondaryColor, 0.12))
                        border.color: scopeType === 1 ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                        border.width: 1

                        Label {
                            anchors.centerIn: parent
                            text: isRtl ? "سورة" : qsTr("Surah")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: scopeType === 1
                            color: scopeType === 1 ? Theme.highlightColor : Theme.primaryColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: scopeType = 1
                        }
                    }

                    // Scope 2: Juz
                    Rectangle {
                        width: (parent.width - 3 * Theme.paddingSmall) / 4
                        height: Theme.itemSizeExtraSmall * 0.72
                        radius: Theme.paddingSmall
                        color: scopeType === 2
                               ? Theme.rgba(Theme.highlightColor, 0.25)
                               : (quranManager.darkMode ? Theme.rgba("#242c3d", 0.8) : Theme.rgba(Theme.secondaryColor, 0.12))
                        border.color: scopeType === 2 ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                        border.width: 1

                        Label {
                            anchors.centerIn: parent
                            text: isRtl ? "جزء" : qsTr("Juz")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: scopeType === 2
                            color: scopeType === 2 ? Theme.highlightColor : Theme.primaryColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: scopeType = 2
                        }
                    }

                    // Scope 3: Page
                    Rectangle {
                        width: (parent.width - 3 * Theme.paddingSmall) / 4
                        height: Theme.itemSizeExtraSmall * 0.72
                        radius: Theme.paddingSmall
                        color: scopeType === 3
                               ? Theme.rgba(Theme.highlightColor, 0.25)
                               : (quranManager.darkMode ? Theme.rgba("#242c3d", 0.8) : Theme.rgba(Theme.secondaryColor, 0.12))
                        border.color: scopeType === 3 ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                        border.width: 1

                        Label {
                            anchors.centerIn: parent
                            text: isRtl ? "صفحة" : qsTr("Page")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: scopeType === 3
                            color: scopeType === 3 ? Theme.highlightColor : Theme.primaryColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: scopeType = 3
                        }
                    }
                }

                // Scope: Surah picker
                ComboBox {
                    width: parent.width
                    visible: scopeType === 1
                    label: isRtl ? "السورة المحددة:" : qsTr("Select Surah:")
                    currentIndex: Math.max(0, scopeSurah - 1)
                    menu: ContextMenu {
                        Repeater {
                            model: surahsList
                            MenuItem {
                                text: (isRtl ? prayerManager.formatDigits(modelData.number.toString()) : modelData.number) + ". " + (isRtl ? modelData.name_ar : (modelData.name_en ? modelData.name_en : modelData.name_ar))
                                onClicked: scopeSurah = modelData.number
                            }
                        }
                    }
                }

                // Scope: Juz picker
                ComboBox {
                    width: parent.width
                    visible: scopeType === 2
                    label: isRtl ? "الجزء المحدد:" : qsTr("Select Juz:")
                    currentIndex: Math.max(0, scopeJuz - 1)
                    menu: ContextMenu {
                        Repeater {
                            model: juzsList
                            MenuItem {
                                text: isRtl ? (modelData.name_ar ? modelData.name_ar : ("الجزء " + prayerManager.formatDigits(modelData.number.toString()))) : ("Juz " + modelData.number)
                                onClicked: scopeJuz = modelData.number
                            }
                        }
                    }
                }

                // Scope: Page picker
                Slider {
                    width: parent.width
                    visible: scopeType === 3
                    label: isRtl ? "الصفحة المحددة:" : qsTr("Select Page:")
                    minimumValue: 1
                    maximumValue: quranManager.maxPages
                    stepSize: 1
                    value: Math.min(scopePage, quranManager.maxPages)
                    valueText: isRtl ? ("صفحة " + prayerManager.formatDigits(Math.round(value).toString())) : ("Page " + Math.round(value))
                    onValueChanged: scopePage = Math.round(value)
                }

                Item { width: 1; height: 4 }
            }

            Item { width: 1; height: Theme.paddingSmall }

            // Tab bar: 0: Surahs, 1: Juzs, 2: Bookmarks (hidden while searching)
            Row {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall
                visible: !isSearching

                Button {
                    width: (parent.width - 2 * Theme.paddingSmall) / 3
                    text: isRtl ? "السور" : qsTr("Surahs")
                    highlighted: selectedTab === 0
                    onClicked: selectedTab = 0
                }

                Button {
                    width: (parent.width - 2 * Theme.paddingSmall) / 3
                    text: isRtl ? "الأجزاء" : qsTr("Juz / Hizb")
                    highlighted: selectedTab === 1
                    onClicked: selectedTab = 1
                }

                Button {
                    width: (parent.width - 2 * Theme.paddingSmall) / 3
                    text: isRtl ? "العلامات" : qsTr("Bookmarks")
                    highlighted: selectedTab === 2
                    onClicked: selectedTab = 2
                }
            }

            Item { width: 1; height: Theme.paddingSmall }

            // ==================== SEARCH RESULTS ====================
            Column {
                width: parent.width
                visible: isSearching

                SectionHeader {
                    text: isRtl
                          ? ("نتائج البحث (" + prayerManager.formatDigits(searchResults.length.toString()) + " آية) • [" + quranManager.riwayahName + "]")
                          : qsTr("Search Results (%1 verses) • [%2]").arg(prayerManager.formatDigits(searchResults.length.toString())).arg(quranManager.riwayahName)
                }

                // Statistics Summary Card & Launcher
                BackgroundItem {
                    id: statsLauncherItem
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: statsBoxCol.height + Theme.paddingMedium * 2
                    visible: isSearching && searchResults.length > 0
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("QuranSearchStatsPage.qml"), {
                            query: debouncedQuery,
                            searchMode: searchMode,
                            respectTashkeel: respectTashkeel,
                            searchEdition: searchEdition
                        })
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingSmall
                        color: quranManager.darkMode ? Theme.rgba("#1a2232", 0.9) : Theme.rgba(Theme.highlightColor, 0.08)
                        border.color: Theme.rgba(Theme.highlightColor, 0.45)
                        border.width: 1
                    }

                    Row {
                        id: statsBoxCol
                        anchors.centerIn: parent
                        width: parent.width - Theme.paddingMedium * 2
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: Theme.paddingMedium

                        Icon {
                            source: "image://theme/icon-m-levels"
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.highlightColor
                        }

                        Column {
                            width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium * 2 - statsArrowIcon.width
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Label {
                                width: parent.width
                                text: isRtl ? "إحصائيات البحث والرسم البياني" : qsTr("Search Statistics & Chart")
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: Theme.highlightColor
                            }

                            Label {
                                width: parent.width
                                text: isRtl
                                      ? ("عرض تكرار كلمة «" + debouncedQuery + "» وجداول ورسوم بيانية بالنسب")
                                      : qsTr("View occurrences, tables and percentage charts")
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.secondaryColor
                                truncationMode: TruncationMode.Fade
                            }
                        }

                        Icon {
                            id: statsArrowIcon
                            source: isRtl ? "image://theme/icon-m-left" : "image://theme/icon-m-right"
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.highlightColor
                        }
                    }
                }

                Item {
                    width: 1
                    height: Theme.paddingSmall
                    visible: isSearching && searchResults.length > 0
                }

                // Empty State when no results found
                Item {
                    width: parent.width
                    height: emptyCol.height + Theme.paddingLarge * 2
                    visible: isSearching && searchResults.length === 0

                    Column {
                        id: emptyCol
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.centerIn: parent
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: isRtl ? "لم يتم العثور على نتائج مطابقة" : qsTr("No matching verses found")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.secondaryColor
                        }

                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: {
                                if (searchMode === 1) return isRtl ? "جرب استخدام خيار «الكلمة ولواحقها» للبحث مع حروف الجر والعطف والضمائر المتصلة (مثل: ربنا، ربكم)" : qsTr("Try Word & Affixes to match prefixes and pronouns")
                                if (searchMode === 3) return isRtl ? "تأكد من إدخال 3 أو 4 أحرف أصلية للجذر (مثل: كتب، رحم، علم، زلزل)" : qsTr("Ensure entering 3 or 4 root letters (e.g. كتب, رحم)")
                                return isRtl ? "تأكد من صحة الكلمات أو جرب تغيير نطاق البحث إلى كامل المصحف" : qsTr("Check spelling or change search scope to All Quran")
                            }
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.secondaryColor
                            wrapMode: Text.Wrap
                        }
                    }
                }

                // Search Results Repeater (progressively rendered to prevent ANR on large match sets)
                Repeater {
                    model: visibleSearchResults

                    delegate: BackgroundItem {
                        width: parent.width
                        height: searchItemCol.height + 2 * Theme.paddingMedium

                        Column {
                            id: searchItemCol
                            width: parent.width - 2 * Theme.horizontalPageMargin
                            anchors.centerIn: parent
                            spacing: Theme.paddingSmall / 2

                            Item {
                                width: parent.width
                                height: searchSurahLbl.height

                                Label {
                                    id: searchSurahLbl
                                    anchors {
                                        left: isRtl ? undefined : parent.left
                                        right: isRtl ? parent.right : undefined
                                    }
                                    text: isRtl
                                          ? ("سورة " + modelData.surah_name_ar + " • آية " + prayerManager.formatDigits(modelData.ayah_number.toString()))
                                          : ((modelData.surah_name_en ? modelData.surah_name_en : modelData.surah_name_ar) + " • Ayah " + modelData.ayah_number)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.highlightColor
                                    font.bold: true
                                }
                                Label {
                                    anchors {
                                        left: isRtl ? parent.left : undefined
                                        right: isRtl ? undefined : parent.right
                                        baseline: searchSurahLbl.baseline
                                    }
                                    text: "ص " + prayerManager.formatDigits(modelData.page_number.toString())
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.secondaryColor
                                }
                            }

                            // Matched root word badge
                            Row {
                                width: parent.width
                                visible: !!modelData.matched_word
                                spacing: Theme.paddingSmall
                                layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                                Rectangle {
                                    radius: 4
                                    height: matchedWordLbl.implicitHeight + 4
                                    width: matchedWordLbl.implicitWidth + Theme.paddingSmall * 2
                                    color: Theme.rgba(Theme.highlightColor, 0.2)
                                    border.color: Theme.rgba(Theme.highlightColor, 0.5)
                                    border.width: 1

                                    Label {
                                        id: matchedWordLbl
                                        anchors.centerIn: parent
                                        text: isRtl ? ("اللفظ المشتق: " + (modelData.matched_word ? modelData.matched_word : "")) : ("Matched Form: " + (modelData.matched_word ? modelData.matched_word : ""))
                                        font.pixelSize: Theme.fontSizeTiny
                                        color: Theme.highlightColor
                                        font.bold: true
                                    }
                                }
                            }

                            // Arabic Quran text with searched word highlighted
                            Label {
                                id: ayahTextLbl
                                width: parent.width
                                text: {
                                    if (modelData.highlighted_text) {
                                        return modelData.highlighted_text.replace(/%1/g, Theme.highlightColor)
                                    }
                                    if (modelData.text_uthmani) {
                                        return quranManager.highlightSearchAyah(
                                            modelData.text_uthmani,
                                            debouncedQuery,
                                            searchMode,
                                            respectTashkeel,
                                            Theme.highlightColor,
                                            modelData.matched_word ? modelData.matched_word : ""
                                        )
                                    }
                                    return ""
                                }
                                font.family: (quranManager.riwayah === 2 ? "KFGQPC Warsh Uthmanic Script" : "KFGQPC Uthmanic Script HAFS") + ", Naskh, UthmanTN, Amiri Quran, serif"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.primaryColor
                                wrapMode: Text.Wrap
                                horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                maximumLineCount: 4
                                textFormat: Text.StyledText
                                truncationMode: TruncationMode.Elide
                            }

                            // If the text in aya is not completed, put "..." in the end
                            Label {
                                id: ayahEllipsisLbl
                                visible: ayahTextLbl.truncated && !ayahTextLbl.text.endsWith("...") && !ayahTextLbl.text.endsWith("…")
                                text: "..."
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                                color: Theme.highlightColor
                                horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                width: parent.width
                            }

                            // Translation Snippet
                            Column {
                                width: parent.width
                                visible: !!modelData.translation_text
                                spacing: 2

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Theme.rgba(Theme.secondaryColor, 0.2)
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.paddingSmall
                                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                                    Label {
                                        text: {
                                            var ed = isRtl ? (modelData.edition_name_ar ? modelData.edition_name_ar : modelData.edition_name)
                                                           : (modelData.edition_name_en ? modelData.edition_name_en : modelData.edition_name)
                                            return ed ? ("[" + ed + "]") : ""
                                        }
                                        font.pixelSize: Theme.fontSizeTiny
                                        color: Theme.highlightColor
                                        font.bold: true
                                    }
                                }

                                Label {
                                    id: translationTextLbl
                                    width: parent.width
                                    text: {
                                        if (!modelData.translation_text) return ""
                                        if (searchMode === 5 && debouncedQuery.trim().length > 0) {
                                            var qEsc = debouncedQuery.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
                                            var rx = new RegExp("(" + qEsc + ")", "gi")
                                            return modelData.translation_text.replace(rx, "<font color='" + Theme.highlightColor + "'><b>$1</b></font>")
                                        }
                                        return modelData.translation_text
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.secondaryColor
                                    wrapMode: Text.Wrap
                                    textFormat: Text.StyledText
                                    horizontalAlignment: (modelData.language === "ar") ? (isRtl ? Text.AlignRight : Text.AlignLeft) : Text.AlignLeft
                                    maximumLineCount: 4
                                    truncationMode: TruncationMode.Elide
                                }

                                Label {
                                    visible: translationTextLbl.truncated && !translationTextLbl.text.endsWith("...") && !translationTextLbl.text.endsWith("…")
                                    text: "..."
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    color: Theme.highlightColor
                                    horizontalAlignment: (modelData.language === "ar") ? (isRtl ? Text.AlignRight : Text.AlignLeft) : Text.AlignLeft
                                    width: parent.width
                                }
                            }
                        }

                        onClicked: {
                            var p = quranManager.getPageForAyah(modelData.surah_number, modelData.ayah_number)
                            if (p <= 0) p = modelData.page_number
                            pageStack.push(Qt.resolvedUrl("QuranReaderPage.qml"), {
                                surahNumber: modelData.surah_number,
                                startAyah: modelData.ayah_number,
                                initialPage: p,
                                currentPage: p,
                                highlightTargetAyah: true
                            })
                        }
                    }
                }

                // Show more results button for smooth progressive loading
                BackgroundItem {
                    id: loadMoreResultsBtn
                    width: parent.width
                    height: Theme.itemSizeSmall
                    visible: isSearching && searchResults && searchResults.length > displayLimit
                    onClicked: {
                        displayLimit = Math.min(searchResults.length, displayLimit + 50)
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.paddingMedium
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                        Icon {
                            source: "image://theme/icon-m-down"
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.highlightColor
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: isRtl
                                  ? ("عرض المزيد من النتائج (" + prayerManager.formatDigits((searchResults.length - displayLimit).toString()) + " متبقية)...")
                                  : qsTr("Show more results (%1 remaining)...").arg(prayerManager.formatDigits((searchResults.length - displayLimit).toString()))
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: Theme.highlightColor
                        }
                    }
                }
            }

            // ==================== TAB 0: SURAHS LIST ====================
            Column {
                width: parent.width
                visible: !isSearching && selectedTab === 0

                Repeater {
                    model: surahsList

                    delegate: BackgroundItem {
                        id: surahItem
                        width: parent.width
                        height: Theme.itemSizeMedium

                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.horizontalPageMargin
                            layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                            spacing: Theme.paddingMedium

                            // Number Badge
                            Rectangle {
                                width: Theme.iconSizeMedium
                                height: Theme.iconSizeMedium
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.rgba(Theme.highlightBackgroundColor, 0.20)
                                border.color: Theme.rgba(Theme.highlightColor, 0.4)
                                border.width: 1

                                Label {
                                    anchors.centerIn: parent
                                    text: prayerManager.formatDigits(modelData.number.toString())
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    font.bold: true
                                    color: Theme.highlightColor
                                }
                            }

                            // Surah Details
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium - pageBadge.width - Theme.paddingMedium

                                Label {
                                    width: parent.width
                                    text: isRtl ? ("سورة " + modelData.name_ar) : modelData.name_en
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.bold: true
                                    color: Theme.primaryColor
                                    horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                    truncationMode: TruncationMode.Fade
                                }

                                Row {
                                    spacing: Theme.paddingSmall
                                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                                    Label {
                                        text: (modelData.revelation_type === "Meccan" ? (isRtl ? "مكية" : qsTr("Meccan")) : (isRtl ? "مدنية" : qsTr("Medinan")))
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: modelData.revelation_type === "Meccan" ? Theme.highlightColor : Theme.secondaryHighlightColor
                                    }

                                    Label {
                                        text: "•"
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: Theme.secondaryColor
                                    }

                                    Label {
                                        text: isRtl
                                              ? (prayerManager.formatDigits(modelData.total_verses.toString()) + " آيات")
                                              : qsTr("%1 verses").arg(prayerManager.formatDigits(modelData.total_verses.toString()))
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: Theme.secondaryColor
                                    }
                                }
                            }

                            // Start Page Indicator
                            Label {
                                id: pageBadge
                                anchors.verticalCenter: parent.verticalCenter
                                text: isRtl
                                      ? ("ص " + prayerManager.formatDigits(modelData.start_page.toString()))
                                      : ("p. " + modelData.start_page)
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                            }
                        }

                        onClicked: {
                            var p = quranManager.getPageForAyah(modelData.number, 1)
                            if (p <= 0) p = modelData.start_page
                            pageStack.push(Qt.resolvedUrl("QuranReaderPage.qml"), {
                                surahNumber: modelData.number,
                                startAyah: 1,
                                initialPage: p,
                                currentPage: p
                            })
                        }
                    }
                }
            }

            // ==================== TAB 1: JUZ / HIZB ====================
            Column {
                width: parent.width
                visible: !isSearching && selectedTab === 1

                SectionHeader {
                    text: isRtl ? ("الأجزاء (" + prayerManager.formatDigits("30") + " جزءاً)") : qsTr("Juz' (30 Parts)")
                }

                Repeater {
                    model: juzsList

                    delegate: BackgroundItem {
                        width: parent.width
                        height: Theme.itemSizeSmall

                        Row {
                            anchors.fill: parent
                            anchors.margins: Theme.horizontalPageMargin
                            layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                            spacing: Theme.paddingMedium

                            Rectangle {
                                width: Theme.iconSizeSmall
                                height: Theme.iconSizeSmall
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.rgba(Theme.highlightBackgroundColor, 0.20)
                                border.color: Theme.rgba(Theme.highlightColor, 0.4)
                                border.width: 1

                                Label {
                                    anchors.centerIn: parent
                                    text: prayerManager.formatDigits(modelData.number.toString())
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.highlightColor
                                    font.bold: true
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - Theme.iconSizeSmall - Theme.paddingMedium - 80

                                Label {
                                    text: isRtl ? ("الجزء " + prayerManager.formatDigits(modelData.number.toString())) : ("Juz' " + modelData.number)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    color: Theme.primaryColor
                                    horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                }

                                Label {
                                    text: isRtl
                                      ? ("سورة " + modelData.surah_name_ar + " • آية " + prayerManager.formatDigits(modelData.ayah_number.toString()))
                                      : ((modelData.surah_name_en ? modelData.surah_name_en : modelData.surah_name_ar) + " • Ayah " + modelData.ayah_number)
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.secondaryColor
                                    horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                }
                            }

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: isRtl
                                      ? ("ص " + prayerManager.formatDigits(modelData.start_page.toString()))
                                      : ("p. " + modelData.start_page)
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                            }
                        }

                        onClicked: {
                            var p = quranManager.getPageForAyah(modelData.surah_number, modelData.ayah_number)
                            if (p <= 0) p = modelData.start_page
                            pageStack.push(Qt.resolvedUrl("QuranReaderPage.qml"), {
                                surahNumber: modelData.surah_number,
                                startAyah: modelData.ayah_number,
                                initialPage: p,
                                currentPage: p,
                                highlightTargetAyah: true
                            })
                        }
                    }
                }
            }

            // ==================== TAB 2: BOOKMARKS ====================
            Column {
                width: parent.width
                visible: !isSearching && selectedTab === 2

                Item {
                    width: parent.width
                    height: Theme.itemSizeSmall

                    SectionHeader {
                        id: bmarkSectionTitle
                        anchors {
                            left: isRtl ? (clearAllBtn.visible ? clearAllBtn.right : parent.left) : parent.left
                            right: isRtl ? parent.right : (clearAllBtn.visible ? clearAllBtn.left : parent.right)
                            leftMargin: isRtl ? Theme.paddingMedium : Theme.horizontalPageMargin
                            rightMargin: isRtl ? Theme.horizontalPageMargin : Theme.paddingMedium
                            verticalCenter: parent.verticalCenter
                        }
                        text: isRtl ? "العلامات المرجعية المحفوظة" : qsTr("Saved Bookmarks")
                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                        truncationMode: TruncationMode.Fade
                    }

                    Button {
                        id: clearAllBtn
                        visible: bookmarksList.length > 0
                        anchors {
                            left: isRtl ? parent.left : undefined
                            right: isRtl ? undefined : parent.right
                            leftMargin: isRtl ? Theme.horizontalPageMargin : 0
                            rightMargin: isRtl ? 0 : Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }
                        preferredWidth: Theme.buttonWidthExtraSmall * 0.85
                        text: isRtl ? "حذف الكل" : qsTr("Clear All")
                        onClicked: {
                            remorsePopup.execute(isRtl ? "جاري حذف جميع العلامات المرجعية..." : qsTr("Deleting all bookmarks..."), function() {
                                quranManager.clearAllBookmarks()
                            })
                        }
                    }
                }

                Label {
                    visible: bookmarksList.length === 0
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: isRtl
                          ? "لا توجد علامات مرجعية محفوظة بعد.\nاضغط مطولاً على أي آية في شاشة القراءة لإضافتها إلى الإشارات المرجعية."
                          : qsTr("No bookmarks saved yet.\nLong press any ayah in the reader to bookmark it.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Repeater {
                    model: bookmarksList

                    delegate: ListItem {
                        id: bmarkItem
                        width: parent.width
                        contentHeight: bmarkCol.height + 2 * Theme.paddingMedium

                        menu: ContextMenu {
                            MenuItem {
                                text: isRtl ? "حذف من المفضلة" : qsTr("Remove Bookmark")
                                onClicked: {
                                    bmarkItem.remorseDelete(function() {
                                        quranManager.removeBookmark(modelData.surah_number, modelData.ayah_number)
                                    })
                                }
                            }
                        }

                        Column {
                            id: bmarkCol
                            width: parent.width - 2 * Theme.horizontalPageMargin
                            anchors.centerIn: parent
                            spacing: Theme.paddingSmall / 2

                            Item {
                                width: parent.width
                                height: Math.max(bmarkTitleRow.height, bmarkMetaRow.height)

                                Row {
                                    id: bmarkMetaRow
                                    anchors {
                                        left: isRtl ? parent.left : undefined
                                        right: isRtl ? undefined : parent.right
                                        verticalCenter: parent.verticalCenter
                                    }
                                    spacing: Theme.paddingSmall
                                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                                    Label {
                                        text: "ص " + prayerManager.formatDigits(modelData.page_number.toString())
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: Theme.secondaryColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    IconButton {
                                        icon.source: "image://theme/icon-m-clear"
                                        width: Theme.iconSizeSmall
                                        height: Theme.iconSizeSmall
                                        icon.width: Theme.iconSizeSmall
                                        icon.height: Theme.iconSizeSmall
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: {
                                            bmarkItem.remorseDelete(function() {
                                                quranManager.removeBookmark(modelData.surah_number, modelData.ayah_number)
                                            })
                                        }
                                    }
                                }

                                Row {
                                    id: bmarkTitleRow
                                    anchors {
                                        left: isRtl ? bmarkMetaRow.right : parent.left
                                        right: isRtl ? parent.right : bmarkMetaRow.left
                                        leftMargin: isRtl ? Theme.paddingSmall : 0
                                        rightMargin: isRtl ? 0 : Theme.paddingSmall
                                        verticalCenter: parent.verticalCenter
                                    }
                                    spacing: Theme.paddingSmall
                                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                                    Icon {
                                        source: "image://theme/icon-m-favorite-selected"
                                        color: Theme.highlightColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Label {
                                        text: isRtl
                                              ? ("سورة " + modelData.surah_name_ar + " • آية " + prayerManager.formatDigits(modelData.ayah_number.toString()))
                                              : ((modelData.surah_name_en ? modelData.surah_name_en : modelData.surah_name_ar) + " • Ayah " + modelData.ayah_number)
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                        color: Theme.highlightColor
                                        anchors.verticalCenter: parent.verticalCenter
                                        truncationMode: TruncationMode.Fade
                                        width: Math.max(0, parent.width - Theme.iconSizeSmall - Theme.paddingSmall)
                                    }
                                }
                            }

                            Label {
                                width: parent.width
                                text: modelData.text_uthmani
                                font.family: (quranManager.riwayah === 2 ? "KFGQPC Warsh Uthmanic Script" : "KFGQPC Uthmanic Script HAFS") + ", Naskh, UthmanTN, Amiri Quran, serif"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.primaryColor
                                wrapMode: Text.Wrap
                                horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                maximumLineCount: 2
                                truncationMode: TruncationMode.Elide
                            }
                        }

                        onClicked: {
                            var p = quranManager.getPageForAyah(modelData.surah_number, modelData.ayah_number)
                            if (p <= 0) p = modelData.page_number
                            pageStack.push(Qt.resolvedUrl("QuranReaderPage.qml"), {
                                surahNumber: modelData.surah_number,
                                startAyah: modelData.ayah_number,
                                initialPage: p,
                                currentPage: p,
                                highlightTargetAyah: true
                            })
                        }
                    }
                }
            }
        }
    }
}
