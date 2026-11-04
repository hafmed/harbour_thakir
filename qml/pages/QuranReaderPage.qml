import QtQuick 2.6
import Sailfish.Silica 1.0
import Sailfish.Share 1.0

Page {
    id: quranReaderPage
    allowedOrientations: Orientation.All
    backNavigation: !isPageFullscreen

    property int surahNumber: 1
    property int startAyah: 1
    property int initialPage: 1
    property int currentPage: initialPage
    property bool highlightTargetAyah: false
    property int targetHighlightAyah: (highlightTargetAyah || startAyah > 1) ? startAyah : 0
    property int targetHighlightSurah: (highlightTargetAyah || startAyah > 1) ? surahNumber : 0

    readonly property bool isRtl: prayerManager.isArabicLanguage
    property var surahInfo: null
    property var ayahsList: []
    property var surahPagesList: []
    property int selectedTextAyah: 0
    property int bookmarkUpdateTrigger: 0
    readonly property bool isSelectedAyahBookmarked: {
        bookmarkUpdateTrigger
        if (selectedTextAyah > 0 && effectiveSelectedSurah > 0) {
            return quranManager.isBookmarked(effectiveSelectedSurah, selectedTextAyah)
        }
        return false
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
        id: quranTitlesFont
        source: Qt.resolvedUrl("../fonts/titles.ttf")
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

    readonly property string quranTitleFontFamily: {
        if (quranTitlesFont.status === FontLoader.Ready && quranTitlesFont.name.length > 0) {
            return quranTitlesFont.name
        }
        return quranFontFamily
    }

    function toArabicDigits(num) {
        if (num === undefined || num === null) return ""
        return prayerManager.formatDigits(num.toString())
    }

    property var pageAyahsList: []
    readonly property string currentPageSurahName: {
        if (pageAyahsList && pageAyahsList.length > 0) {
            var names = []
            for (var i = 0; i < pageAyahsList.length; ++i) {
                var it = pageAyahsList[i]
                var n = isRtl ? ("سورة " + it.surah_name_ar) : ("Surah " + (it.surah_name_en ? it.surah_name_en : it.surah_name_ar))
                if (names.indexOf(n) === -1) {
                    names.push(n)
                }
            }
            if (names.length > 0) return names.join(" • ")
        }
        var sInfo = (surahNumber > 0 && surahInfo) ? surahInfo : quranManager.getSurah(surahNumber)
        if (sInfo) {
            return isRtl ? ("سورة " + sInfo.name_ar) : ("Surah " + (sInfo.name_en ? sInfo.name_en : sInfo.name_ar))
        }
        return ""
    }
    property bool activeAyahBannerExpanded: true
    property int pageCacheToken: 0
    property bool pageDownloadFailedVisible: false
    property bool isPageFullscreen: false
    property bool fullscreenFillMode: true
    property bool tajweedLegendExpanded: false
    readonly property bool isTajweedBottomLegendActive: {
        return !isPageFullscreen && quranManager.viewMode === 0 && quranManager.tajweedMode && (quranManager.isPlaying || quranManager.playingAyah > 0)
    }

    readonly property var tajweedRulesSummary: [
        { name: isRtl ? ("مد " + prayerManager.formatDigits("6") + " حركات") : "Madd 6", color: quranManager.darkMode ? "#506FFF" : "#000EBC" },
        { name: isRtl ? ("مد " + prayerManager.formatDigits("4-5") + " حركات") : "Madd 4-5", color: quranManager.darkMode ? "#5F7DF5" : "#2144C1" },
        { name: isRtl ? ("مد " + prayerManager.formatDigits("2") + " حركتان") : "Madd 2", color: quranManager.darkMode ? "#7BA0FF" : "#537FFF" },
        { name: isRtl ? "غنة مشددة" : "Ghunnah", color: quranManager.darkMode ? "#FFA540" : "#FF7E1E" },
        { name: isRtl ? "قلقلة" : "Qalqalah", color: quranManager.darkMode ? "#FF5555" : "#DD0008" },
        { name: isRtl ? "إخفاء" : "Ikhfa", color: quranManager.darkMode ? "#D055E8" : "#9400A8" },
        { name: isRtl ? "إدغام" : "Idgham", color: quranManager.darkMode ? "#4ED436" : "#169200" },
        { name: isRtl ? "إقلاب" : "Iqlab", color: quranManager.darkMode ? "#60D5FF" : "#26BFFD" },
        { name: isRtl ? "لا ينطق" : "Silent", color: quranManager.darkMode ? "#888888" : "#999999" }
    ]

    readonly property var tajweedRulesDetails: [
        {
            title: isRtl ? ("المد اللازم (" + prayerManager.formatDigits("6") + " حركات)") : "Madd Lazim (6 beats)",
            desc: isRtl ? prayerManager.formatDigits("اللون الأزرق الغامق: يمد بمقدار 6 حركات وجوباً، مثل: ﴿الضَّآلِّينَ﴾، ﴿الٓمٓ﴾.") : "Dark Blue: Prolonged for 6 beats, e.g., Surat Al-Fatiha 1:7.",
            color: quranManager.darkMode ? "#506FFF" : "#000EBC"
        },
        {
            title: isRtl ? ("المد المتصل والمنفصل (" + prayerManager.formatDigits("4") + " أو " + prayerManager.formatDigits("5") + " حركات)") : "Madd Wajib / Munfasil (4-5 beats)",
            desc: isRtl ? prayerManager.formatDigits("اللون الأزرق الفاتح: مد واجب متصل أو جائز منفصل، مثل: ﴿جَآءَ﴾، ﴿بِمَآ أُنزِلَ﴾.") : "Blue: Prolonged 4 or 5 beats.",
            color: quranManager.darkMode ? "#5F7DF5" : "#2144C1"
        },
        {
            title: isRtl ? ("المد الطبيعي والعارض (" + prayerManager.formatDigits("2") + " حركتان)") : "Madd Tabii / Aaridh (2 beats)",
            desc: isRtl ? prayerManager.formatDigits("اللون الأزرق السماوي: مد طبيعي بمقدار حركتين، وعارض للسكون عند الوقف (2 أو 4 أو 6 حركات).") : "Light Blue: Natural prolongation of 2 beats.",
            color: quranManager.darkMode ? "#7BA0FF" : "#537FFF"
        },
        {
            title: isRtl ? ("الغنة المشددة (" + prayerManager.formatDigits("2") + " حركتان)") : "Ghunnah (2 beats)",
            desc: isRtl ? prayerManager.formatDigits("اللون البرتقالي: النون والميم المشددتان، مثل: ﴿إِنَّ﴾، ﴿عَمَّ﴾.") : "Orange: Nun and Meem with Shaddah, prolonged 2 beats with nasalization.",
            color: quranManager.darkMode ? "#FFA540" : "#FF7E1E"
        },
        {
            title: isRtl ? "القلقلة" : "Qalqalah",
            desc: isRtl ? "اللون الأحمر: حروف (ق، ط، ب، ج، د) عند سكونها، مثل: ﴿يَجْعَلْ﴾، ﴿أَحَدٌ﴾." : "Red: The letters (ق، ط، ب، ج، د) when silent, produced with bouncing sound.",
            color: quranManager.darkMode ? "#FF5555" : "#DD0008"
        },
        {
            title: isRtl ? "الإدغام (بغنة وبغير غنة)" : "Idgham (with & without Ghunnah)",
            desc: isRtl ? "اللون الأخضر: إدغام النون الساكنة أو التنوين في حروف (ي، ر، م، ل، و، ن)، وإدغام المتماثلين." : "Green: Merging letters (Yaa, Raa, Meem, Laam, Waw, Nun).",
            color: quranManager.darkMode ? "#4ED436" : "#169200"
        },
        {
            title: isRtl ? "الإخفاء والإخفاء الشفوي" : "Ikhfa & Oral Ikhfa",
            desc: isRtl ? prayerManager.formatDigits("اللون البنفسجي: إخفاء النون الساكنة والتنوين عند حروف الإخفاء الـ 15، وإخفاء الميم الساكنة عند الباء.") : "Purple / Magenta: Concealment of Nun/Tanween before 15 letters.",
            color: quranManager.darkMode ? "#D055E8" : "#9400A8"
        },
        {
            title: isRtl ? "الإقلاب" : "Iqlab",
            desc: isRtl ? "اللون الأزرق الفاتح / التركوازي: قلب النون الساكنة أو التنوين ميماً مخفاة مع الغنة عند حرف الباء." : "Cyan: Changing Nun/Tanween to hidden Meem before Baa.",
            color: quranManager.darkMode ? "#60D5FF" : "#26BFFD"
        },
        {
            title: isRtl ? "حروف لا تنطق" : "Silent letters",
            desc: isRtl ? "اللون الرمادي: همزة الوصل، اللام الشمسية، الألف الفارقة والحروف التي تسقط وصلاً." : "Gray: Hamzat Wasl, Solar Laam, and silent letters not pronounced.",
            color: quranManager.darkMode ? "#888888" : "#999999"
        }
    ]

    function toggleFullscreen() {
        if (quranManager.viewMode === 1) {
            isPageFullscreen = !isPageFullscreen
            flickable.contentY = 0
            if (isPageFullscreen && typeof pageImageContainer !== "undefined") {
                pageImageContainer.resetZoom()
            }
        }
    }

    ShareAction {
        id: shareAction
        mimeType: "text/plain"
    }

    function shareAyah(sNum, aNum, uthmaniText) {
        if (!uthmaniText || uthmaniText.length === 0) {
            var aObj = quranManager.getAyah(sNum, aNum)
            if (aObj && aObj.text_uthmani) {
                uthmaniText = aObj.text_uthmani
            }
        }
        var sInfo = surahInfo ? surahInfo : quranManager.getSurah(sNum)
        var sName = isRtl ? (sInfo ? sInfo.name_ar : "") : (sInfo ? sInfo.name_en : "")
        var clip = "﴿ " + (uthmaniText ? uthmaniText : "") + " ﴾\n"
        clip += "[" + (isRtl ? ("سورة " + sName) : sName) + ": " + (isRtl ? prayerManager.formatDigits(aNum.toString()) : aNum) + "]\n\n"
        clip += "(تطبيق ذاكر • Thakir)"

        Clipboard.text = clip
        copyToast.show(isRtl ? "تم نسخ الآية الكريمة إلى الحافظة" : qsTr("Ayah copied to clipboard"))

        try {
            var shareTitle = sName + " - " + aNum
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

    readonly property bool isCurrentPageCached: {
        var token = pageCacheToken
        var r = quranManager.riwayah
        var taj = quranManager.tajweedMode
        var alg = quranManager.algeriaMode
        return (currentPage > 0) && quranManager.isPageCached(currentPage)
    }

    readonly property int effectiveSelectedSurah: {
        if (targetHighlightSurah > 0) return targetHighlightSurah
        if (pageAyahsList && pageAyahsList.length > 0 && selectedTextAyah > 0) {
            for (var i = 0; i < pageAyahsList.length; ++i) {
                if (pageAyahsList[i].ayah_number === selectedTextAyah) {
                    return pageAyahsList[i].surah_number
                }
            }
        }
        return surahNumber
    }

    readonly property int effectiveHighlightSurah: {
        if (quranManager.isPlaying && quranManager.playingSurah > 0) {
            return quranManager.playingSurah
        }
        var sNum = (selectedTextAyah > 0) ? effectiveSelectedSurah : targetHighlightSurah
        var aNum = (selectedTextAyah > 0) ? selectedTextAyah : targetHighlightAyah
        if (aNum > 0 && sNum > 0) {
            if (pageAyahsList && pageAyahsList.length > 0) {
                for (var i = 0; i < pageAyahsList.length; ++i) {
                    if (pageAyahsList[i].surah_number === sNum &&
                        pageAyahsList[i].ayah_number === aNum) {
                        return sNum
                    }
                }
            } else {
                return sNum
            }
        }
        return 0
    }

    readonly property int effectiveHighlightAyah: {
        if (quranManager.isPlaying && quranManager.playingAyah > 0) {
            return quranManager.playingAyah
        }
        var sNum = (selectedTextAyah > 0) ? effectiveSelectedSurah : targetHighlightSurah
        var aNum = (selectedTextAyah > 0) ? selectedTextAyah : targetHighlightAyah
        if (aNum > 0 && sNum > 0) {
            if (pageAyahsList && pageAyahsList.length > 0) {
                for (var i = 0; i < pageAyahsList.length; ++i) {
                    if (pageAyahsList[i].surah_number === sNum &&
                        pageAyahsList[i].ayah_number === aNum) {
                        return aNum
                    }
                }
            } else {
                return aNum
            }
        }
        return 0
    }

    readonly property string activePageUrl: {
        var token = pageCacheToken
        var r = quranManager.riwayah
        var taj = (quranManager.tajweedMode ? 1 : 0)
        var hd = (quranManager.tajweedHdMode ? 1 : 0)
        var alg = (quranManager.algeriaMode ? 1 : 0)
        if (currentPage <= 0 || !isCurrentPageCached) return ""
        return "image://quranpage/" + currentPage + "_" + effectiveHighlightSurah + "_" + effectiveHighlightAyah + "_" + (quranManager.darkMode ? 1 : 0) + "_" + r + "_" + taj + "_" + hd + "_" + alg + "_" + token
    }

    function updatePageAyahs() {
        if (currentPage > 0) {
            pageAyahsList = quranManager.getAyahsForPage(currentPage)
            if (!quranManager.isPageCached(currentPage)) {
                quranManager.preloadPage(currentPage)
            }
            if (currentPage < quranManager.maxPages && !quranManager.isPageCached(currentPage + 1)) {
                quranManager.preloadPage(currentPage + 1)
            }
            if (currentPage > 1 && !quranManager.isPageCached(currentPage - 1)) {
                quranManager.preloadPage(currentPage - 1)
            }
        }
    }

    function savePagePosition(pNum) {
        var pAyahs = quranManager.getAyahsForPage(pNum)
        var sNum = (pAyahs && pAyahs.length > 0) ? pAyahs[0].surah_number : surahNumber
        var aNum = (pAyahs && pAyahs.length > 0) ? pAyahs[0].ayah_number : 1
        quranManager.saveLastPosition(sNum, aNum, pNum)
    }

    onSurahNumberChanged: {
        reloadData()
        if (startAyah <= 1 && targetHighlightAyah <= 0) {
            flickable.cancelFlick()
            flickable.contentY = 0
            if (flickable.scrollToTop) {
                flickable.scrollToTop()
            }
        }
    }

    onCurrentPageChanged: {
        pageDownloadFailedVisible = false
        if (typeof pageImageContainer !== "undefined" && pageImageContainer.resetZoom) {
            pageImageContainer.resetZoom()
        }
        updatePageAyahs()
        if (targetHighlightAyah > 0 && pageAyahsList && pageAyahsList.length > 0) {
            var found = false
            for (var i = 0; i < pageAyahsList.length; ++i) {
                if (pageAyahsList[i].surah_number === targetHighlightSurah &&
                    pageAyahsList[i].ayah_number === targetHighlightAyah) {
                    found = true
                    break
                }
            }
            if (!found) {
                targetHighlightAyah = 0
                targetHighlightSurah = 0
                selectedTextAyah = 0
            }
        }
        if (isPageFullscreen && fullscreenOverlayHud) {
            fullscreenOverlayHud.hudVisible = true
            fullscreenHudFadeTimer.restart()
        }
    }

    onIsPageFullscreenChanged: {
        if (isPageFullscreen && fullscreenOverlayHud) {
            fullscreenOverlayHud.hudVisible = true
            fullscreenHudFadeTimer.restart()
        }
    }

    readonly property var currentPlayingAyahData: {
        if (quranManager.playingAyah <= 0 || !pageAyahsList || pageAyahsList.length === 0) return null
        for (var i = 0; i < pageAyahsList.length; ++i) {
            var item = pageAyahsList[i]
            if (item.surah_number === quranManager.playingSurah && item.ayah_number === quranManager.playingAyah) {
                return item
            }
        }
        return null
    }

    readonly property var activePageAyahData: {
        if (quranManager.playingAyah > 0 && currentPlayingAyahData) {
            return currentPlayingAyahData
        }
        if (effectiveHighlightAyah > 0 && effectiveHighlightSurah > 0 && pageAyahsList) {
            for (var i = 0; i < pageAyahsList.length; ++i) {
                var it = pageAyahsList[i]
                if (it.surah_number === effectiveHighlightSurah && it.ayah_number === effectiveHighlightAyah) {
                    return it
                }
            }
        }
        return null
    }

    readonly property var selectedAyahData: {
        if (selectedTextAyah <= 0) return null
        if (pageAyahsList && pageAyahsList.length > 0) {
            for (var i = 0; i < pageAyahsList.length; ++i) {
                if (pageAyahsList[i].surah_number === effectiveSelectedSurah &&
                    pageAyahsList[i].ayah_number === selectedTextAyah) {
                    return pageAyahsList[i]
                }
            }
        }
        if (ayahsList && ayahsList.length > 0 && surahNumber === effectiveSelectedSurah) {
            for (var j = 0; j < ayahsList.length; ++j) {
                if (ayahsList[j].ayah_number === selectedTextAyah) {
                    return ayahsList[j]
                }
            }
        }
        return quranManager.getAyah(effectiveSelectedSurah, selectedTextAyah)
    }

    function computeSurahPages(list) {
        if (!list || list.length === 0) return []
        var pages = []
        var curPageNum = -1
        var curPageObj = null

        for (var i = 0; i < list.length; ++i) {
            var a = list[i]
            var pNum = a.page_number
            if (pNum !== curPageNum) {
                if (curPageObj !== null) {
                    pages.push(curPageObj)
                }
                curPageNum = pNum
                curPageObj = {
                    pageNumber: pNum,
                    isFirstPageOfSurah: (pages.length === 0),
                    ayahs: []
                }
            }
            curPageObj.ayahs.push(a)
        }
        if (curPageObj !== null) {
            pages.push(curPageObj)
        }
        return pages
    }

    function getPageIndexForAyah(aNum) {
        if (!surahPagesList) return -1
        for (var i = 0; i < surahPagesList.length; ++i) {
            var pageAyahs = surahPagesList[i].ayahs
            for (var j = 0; j < pageAyahs.length; ++j) {
                if (pageAyahs[j].ayah_number === aNum) {
                    return i
                }
            }
        }
        return -1
    }

    function getPageIndexForPageNumber(pNum) {
        if (!surahPagesList) return -1
        for (var i = 0; i < surahPagesList.length; ++i) {
            if (surahPagesList[i].pageNumber === pNum) {
                return i
            }
        }
        return -1
    }

    function getFirstAyahOfPage(pNum) {
        if (!surahPagesList) return 0
        for (var i = 0; i < surahPagesList.length; ++i) {
            if (surahPagesList[i].pageNumber === pNum && surahPagesList[i].ayahs && surahPagesList[i].ayahs.length > 0) {
                return surahPagesList[i].ayahs[0].ayah_number
            }
        }
        return 0
    }

    function getTargetAyahNumber() {
        var aNum = (targetHighlightAyah > 0) ? targetHighlightAyah : startAyah
        if (aNum > 0) return aNum
        if (currentPage > 0) {
            var f = getFirstAyahOfPage(currentPage)
            if (f > 0) return f
        }
        return 1
    }

    function cleanUthmaniText(text) {
        if (!text || text.length === 0) return ""
        var res = text
        if (quranManager.riwayah !== 2) {
            // Replace Urdu Yeh Barree (0x06D2 / 0x06D3) with standard Arabic Yeh
            res = res.replace(/[\u06d2\u06d3]/g, "\u064a")
            // Normalize Iqlab low meem to high meem
            res = res.replace(/\u06ed/g, "\u06e2")
            // Remove Tashil and stop marks that render as dotted circles in Arabic fonts
            res = res.replace(/[\u06ec\u06ea\u06eb]/g, "")
        }
        // Normalize connective tatweel + hamza before non-final alef (ـَٔا / ـَٔا / ٔـَا as in مَآرِب, مَآب, فَآمَن, بِآيَات, سَآتِيكُم)
        res = res.replace(/(?:[\u0640\uE000]\u064E?[\u0654\u0655]|[\u0640\uE000][\u0654\u0655]\u064E?|[\u0654\u0655]\u064E?[\u0640\uE000])\u064E?\u0627(?=[\u0621-\u064A])/g, "\u0622")
        // Also specifically normalize any remaining ma'ab (مَـَٔاب / مَـَٔاب / ٱلْمَـَٔابِ) forms
        res = res.replace(/\u0645[\u064E]?[\u0640\u064E\u0654\uE000]*[\u0654\u0655][\u0640\u064E\u0654\uE000]*\u0627(\u0628[\u064B-\u065F\u06D6-\u06ED\u08F0-\u08F2\u200C-\u200F]*)/g, "\u0645\u064E\u0622$1")
        // Protect tatweels in Uthmanic hamza ligatures (e.g. ـٔ, ـَٔ, ٔـ as in يَسْـَٔلُونَ, شَيْـًٔا)
        res = res.replace(/(\u0640[\u064B-\u065F]*[\u0654\u0655]|[\u0654\u0655][\u064B-\u065F]*\u0640)/g, function(m) {
            return m.replace(/\u0640/g, "\uE000")
        })
        if (quranManager.riwayah !== 2) {
            // Fix yaa + tatweel + hamza (يـٔ -> ئ)
            res = res.replace(/\u064a[\u0640\uE000]\u0654/g, "\u0626")
            res = res.replace(/\u064a\u0654/g, "\u0626")
        }
        // Remove leftover isolated tatweels (\u0640)
        res = res.replace(/\u0640/g, "")
        // Restore protected tatweels in hamza ligatures
        res = res.replace(/\uE000/g, "\u0640")
        return res
    }

    function getPageCardHtml(ayahs, isDark, curPlayingAyah, selAyah) {
        if (!ayahs || ayahs.length === 0) return ""
        var family = quranFontFamily
        var html = "<div dir='rtl' style='line-height: 125%; text-align: justify; text-justify: inter-word; font-family: \"" + family + "\", \"Naskh\", \"UthmanTN\", \"Amiri Quran\", serif;'>"
        for (var i = 0; i < ayahs.length; ++i) {
            var a = ayahs[i]
            var isPlaying = (curPlayingAyah > 0 && curPlayingAyah === a.ayah_number)
            var isSelected = (selAyah > 0 && selAyah === a.ayah_number)

            var bg = ""
            var fg = ""
            var border = ""
            if (isPlaying) {
                bg = isDark ? "background-color: #3d2f13;" : "background-color: #fbf2d5;"
                fg = isDark ? "color: #ffd700;" : "color: #875400;"
                border = isDark ? "outline: 1px solid #7a6027;" : "outline: 1px solid #d4af37;"
            } else if (isSelected) {
                bg = isDark ? "background-color: #172b45;" : "background-color: #deeeff;"
                fg = isDark ? "color: #90cdff;" : "color: #0b4e8c;"
                border = isDark ? "outline: 1px solid #2e598a;" : "outline: 1px solid #8ec8f6;"
            } else {
                fg = isDark ? "color: #f5f6f8;" : "color: #12141a;"
            }

            var spanStyle = "border-radius: 4px; padding: 2px 4px;"
            if (bg !== "") spanStyle += " " + bg
            if (fg !== "") spanStyle += " " + fg
            if (border !== "") spanStyle += " " + border
            if (isPlaying) spanStyle += " font-weight: bold;"

            var aNumStr = toArabicDigits(a.ayah_number)
            var markerColor = isPlaying ? (isDark ? "#ffd700" : "#875400") : (isDark ? "#c8a148" : "#8f6723")
            var marker = "&nbsp;<span style='color: " + markerColor + "; font-size: 88%; font-weight: normal;'>﴿" + aNumStr + "﴾</span>&nbsp;"

            var cleanedAyahText = ""
            if (quranManager.tajweedMode && a.text_tajweed && a.text_tajweed.length > 0) {
                cleanedAyahText = quranManager.formatTajweedHtml(a.text_tajweed, isDark)
            } else {
                cleanedAyahText = cleanUthmaniText(a.text_uthmani)
            }

            var postAyahBr = ""
            if (surahNumber === 1 && a.ayah_number === 1) {
                // In Surah Al-Fatihah, ensure there is a line break immediately after the Basmalah
                var hamdRx = /(\s+)([\u0671\u0627\u0625\u06ec]?\s*[\u0644\u064e\u0650\u0652]*\u062d[\u064e\u065f]?\u0645[\u0652\u065f]?\u062f)/
                if (hamdRx.test(cleanedAyahText)) {
                    // Warsh Ayah 1 contains both Basmalah and Hamd: break before Hamd
                    cleanedAyahText = cleanedAyahText.replace(hamdRx, "<br/>$2")
                } else if (!/ب[\u064e\u0650\u0652\u0670]*س[\u064e\u0650\u0652\u0670]*م/.test(cleanedAyahText)) {
                    // Warsh plain text without embedded Basmalah: prepend Basmalah with a break
                    cleanedAyahText = "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ<br/>" + cleanedAyahText
                } else {
                    // Hafs Ayah 1 is the Basmalah itself: break after Ayah 1
                    postAyahBr = "<br/>"
                }
            }

            html += "<a href='ayah:" + a.ayah_number + "' style='text-decoration: none; color: inherit;'>"
            html += "<span style='" + spanStyle + "'>"
            html += cleanedAyahText + marker
            html += "</span></a>" + postAyahBr + " "
        }
        html += "</div>"
        return html
    }

    function reloadData() {
        surahInfo = quranManager.getSurah(surahNumber)
        ayahsList = quranManager.getAyahsForSurah(surahNumber)
        surahPagesList = computeSurahPages(ayahsList)
        if (currentPage <= 0 && surahInfo) {
            currentPage = surahInfo.start_page
        }
        updatePageAyahs()
    }

    property int pendingScrollAyah: 0
    property int scrollAttemptCount: 0

    Timer {
        id: scrollRetryTimer
        interval: 35
        repeat: true
        onTriggered: {
            if (pendingScrollAyah <= 0 || quranManager.viewMode !== 0) {
                stop()
                return
            }
            scrollAttemptCount++
            var success = doScrollToAyah(pendingScrollAyah, false)
            if (success || scrollAttemptCount >= 45) {
                stop()
                pendingScrollAyah = 0
            }
        }
    }

    function doScrollToAyah(ayahNumber, animate) {
        if (quranManager.viewMode !== 0) return false

        var pageIdx = getPageIndexForAyah(ayahNumber)
        if (pageIdx < 0 && currentPage > 0) {
            pageIdx = getPageIndexForPageNumber(currentPage)
        }
        if (pageIdx < 0) return true

        if (pageIdx >= pagesRepeater.count) return false
        var item = pagesRepeater.itemAt(pageIdx)
        if (!item || item.height <= 0) return false

        var pos = item.mapToItem(flickable.contentItem, 0, 0)
        if (pageIdx > 0 && pos.y <= 50) return false
        if (flickable.contentHeight < pos.y + item.height) return false

        var targetContentY = pos.y - Theme.paddingMedium
        if (item.height <= flickable.height) {
            targetContentY = pos.y + item.height / 2 - (flickable.height / 2)
        } else {
            var pageAyahs = (surahPagesList && pageIdx < surahPagesList.length) ? surahPagesList[pageIdx].ayahs : []
            if (pageAyahs && pageAyahs.length > 1) {
                var aIdx = -1
                for (var k = 0; k < pageAyahs.length; ++k) {
                    if (pageAyahs[k].ayah_number === ayahNumber) {
                        aIdx = k
                        break
                    }
                }
                if (aIdx > 0) {
                    var ratio = aIdx / (pageAyahs.length - 1)
                    targetContentY = pos.y + ratio * Math.max(0, item.height - flickable.height * 0.7)
                }
            }
        }

        var maxContentY = Math.max(0, flickable.contentHeight - flickable.height)
        targetContentY = Math.max(0, Math.min(targetContentY, maxContentY))

        if (animate) {
            scrollAnim.stop()
            scrollAnim.to = targetContentY
            scrollAnim.start()
        } else {
            scrollAnim.stop()
            flickable.contentY = targetContentY
        }
        return true
    }

    function scrollToAyah(ayahNumber, animate) {
        if (quranManager.viewMode !== 0 || ayahNumber <= 0) return
        var success = doScrollToAyah(ayahNumber, animate)
        if (!success) {
            pendingScrollAyah = ayahNumber
            scrollAttemptCount = 0
            scrollRetryTimer.restart()
        }
    }

    NumberAnimation {
        id: scrollAnim
        target: flickable
        property: "contentY"
        duration: 450
        easing.type: Easing.InOutQuad
    }

    Timer {
        id: resetScrollTimer
        interval: 35
        repeat: true
        property int attemptCount: 0
        onTriggered: {
            attemptCount++
            flickable.cancelFlick()
            flickable.contentY = 0
            if (flickable.scrollToTop) {
                flickable.scrollToTop()
            }
            if (attemptCount >= 15) {
                stop()
                attemptCount = 0
            }
        }
    }

    function goToSurahBeginning(newSurah) {
        if (newSurah < 1 || newSurah > 114) return

        scrollAnim.stop()
        pendingScrollAyah = 0
        scrollRetryTimer.stop()

        startAyah = 1
        targetHighlightAyah = 0
        targetHighlightSurah = 0
        selectedTextAyah = 0

        var s = quranManager.getSurah(newSurah)
        var firstPage = s ? s.start_page : 1
        if (firstPage <= 0) firstPage = 1

        currentPage = firstPage
        surahNumber = newSurah

        reloadData()
        quranManager.saveLastPosition(newSurah, 1, firstPage)

        flickable.cancelFlick()
        flickable.contentY = 0
        if (flickable.scrollToTop) {
            flickable.scrollToTop()
        }

        resetScrollTimer.attemptCount = 0
        resetScrollTimer.restart()
    }

    function switchToTextMode(sNum, aNum) {
        if (sNum > 0 && sNum !== surahNumber) {
            surahNumber = sNum
        }
        if (aNum > 0) {
            targetHighlightAyah = aNum
            targetHighlightSurah = sNum
        }
        quranManager.viewMode = 0
        if (aNum > 0) {
            Qt.callLater(function() {
                scrollToAyah(aNum, false)
            })
        }
    }

    function requestSwitchToTextMode(sNum, aNum, forceDisclaimer) {
        var isConfirmed = quranManager.isTextModeDisclaimerConfirmed(prayerManager.appVersion)
        var shouldShow = (!isConfirmed) || forceDisclaimer || quranManager.shouldShowTextModeDisclaimer(prayerManager.appVersion)

        if (pageStack.currentPage && pageStack.currentPage.objectName === "textModeDisclaimerDialog") {
            return
        }

        if (shouldShow) {
            var dialog = pageStack.push(Qt.resolvedUrl("TextModeDisclaimerDialog.qml"))
            if (dialog) {
                dialog.accepted.connect(function() {
                    switchToTextMode(sNum, aNum)
                })
                dialog.switchToMushafRequested.connect(function() {
                    updatePageAyahs()
                    quranManager.viewMode = 1
                })
            }
        } else {
            switchToTextMode(sNum, aNum)
        }
    }

    function checkTextModeDisclaimer() {
        if (!quranManager.isTextModeDisclaimerConfirmed(prayerManager.appVersion) || quranManager.shouldShowTextModeDisclaimer(prayerManager.appVersion)) {
            requestSwitchToTextMode(surahNumber, 0, false)
        }
    }

    function updateReaderBlanking() {
        var active = (status === PageStatus.Active) && (Qt.application.state === Qt.ApplicationActive)
        quranManager.setReaderActive(active)
    }

    onStatusChanged: {
        updateReaderBlanking()
        if (status === PageStatus.Active && quranManager.viewMode === 0) {
            var targetAyah = getTargetAyahNumber()
            if (targetAyah > 1 || getPageIndexForAyah(targetAyah) > 0) {
                doScrollToAyah(targetAyah, false)
            }
        }
    }

    Connections {
        target: Qt.application
        onStateChanged: updateReaderBlanking()
    }

    Component.onCompleted: {
        reloadData()
        var targetAyah = getTargetAyahNumber()
        if (highlightTargetAyah || targetHighlightAyah > 0 || startAyah > 1) {
            selectedTextAyah = targetAyah
        }
        var ayahPage = quranManager.getPageForAyah(surahNumber, targetAyah)
        if (ayahPage > 0) {
            currentPage = ayahPage
        }
        quranManager.saveLastPosition(surahNumber, targetAyah, currentPage)
        if (targetAyah > 1 || getPageIndexForAyah(targetAyah) > 0) {
            scrollToAyah(targetAyah, false)
        }
    }

    Component.onDestruction: {
        quranManager.setReaderActive(false)
        var aNum = (selectedTextAyah > 0) ? selectedTextAyah : startAyah
        var pNum = quranManager.getPageForAyah(surahNumber, aNum)
        if (pNum > 0) {
            currentPage = pNum
        }
        quranManager.saveLastPosition(surahNumber, aNum, currentPage)
    }

    Connections {
        target: quranManager
        onRiwayahChanged: {
            pageDownloadFailedVisible = false
            pageCacheToken += 1
            reloadData()
            if (currentPage > 0 && !quranManager.isPageCached(currentPage)) {
                quranManager.preloadPage(currentPage)
            }
        }
        onBookmarksChanged: {
            bookmarkUpdateTrigger += 1
            reloadData()
        }
        onTajweedModeChanged: {
            var targetA = (targetHighlightAyah > 0) ? targetHighlightAyah : getFirstAyahOfPage(currentPage)
            var targetS = (targetHighlightSurah > 0) ? targetHighlightSurah : surahNumber
            if (targetS > 0 && targetA > 0) {
                var newP = quranManager.getPageForAyah(targetS, targetA)
                if (newP > 0) {
                    currentPage = newP
                }
            }
            if (currentPage > quranManager.maxPages) {
                currentPage = quranManager.maxPages
            }
            pageCacheToken += 1
            reloadData()
            updatePageAyahs()
        }
        onAlgeriaModeChanged: {
            var targetA = (targetHighlightAyah > 0) ? targetHighlightAyah : getFirstAyahOfPage(currentPage)
            var targetS = (targetHighlightSurah > 0) ? targetHighlightSurah : surahNumber
            if (targetS > 0 && targetA > 0) {
                var newP = quranManager.getPageForAyah(targetS, targetA)
                if (newP > 0) {
                    currentPage = newP
                }
            }
            if (currentPage > quranManager.maxPages) {
                currentPage = quranManager.maxPages
            }
            pageCacheToken += 1
            reloadData()
            updatePageAyahs()
        }
        onTajweedHdModeChanged: {
            pageCacheToken += 1
            reloadData()
            updatePageAyahs()
        }
        onPlayingAyahChanged: {
            if (quranManager.isPlaying && quranManager.playingAyah > 0) {
                if (quranManager.playingSurah !== surahNumber && quranManager.playingSurah > 0) {
                    surahNumber = quranManager.playingSurah
                    startAyah = quranManager.playingAyah
                    reloadData()
                    Qt.callLater(function() {
                        scrollToAyah(quranManager.playingAyah, true)
                    })
                } else if (!flickable.dragging) {
                    scrollToAyah(quranManager.playingAyah, true)
                }

                // Keep current page and last read position synchronized with playing ayah
                if (quranManager.playingSurah === surahNumber) {
                    var pNum = quranManager.getPageForAyah(surahNumber, quranManager.playingAyah)
                    if (pNum > 0 && currentPage !== pNum) {
                        currentPage = pNum
                    }
                    startAyah = quranManager.playingAyah
                    quranManager.saveLastPosition(surahNumber, quranManager.playingAyah, currentPage)
                }
            }
        }
        onAudioStateChanged: {
            if (quranManager.isPlaying && quranManager.playingAyah > 0) {
                if (quranManager.playingSurah === surahNumber && !flickable.dragging) {
                    scrollToAyah(quranManager.playingAyah, true)
                }
            }
        }
        onViewModeChanged: {
            isPageFullscreen = false
            if (quranManager.viewMode === 0) {
                var targetAyah = (quranManager.isPlaying && quranManager.playingAyah > 0)
                    ? quranManager.playingAyah
                    : (selectedTextAyah > 0 ? selectedTextAyah : (startAyah > 0 ? startAyah : 0))
                if (targetAyah <= 0 && currentPage > 0) {
                    targetAyah = getFirstAyahOfPage(currentPage)
                }
                if (targetAyah > 0) {
                    scrollToAyah(targetAyah, false)
                }
            } else if (quranManager.viewMode === 1) {
                if (selectedAyahData && selectedAyahData.page_number) {
                    currentPage = selectedAyahData.page_number
                }
                updatePageAyahs()
            }
        }
        onPageCached: {
            if (pageNumber === currentPage) {
                pageDownloadFailedVisible = false
                pageCacheToken += 1
            }
        }
        onPageDownloadFailed: {
            if (pageNumber === currentPage) {
                pageDownloadFailedVisible = true
                copyToast.show(isRtl ? "⚠️ يلزم تفعيل الإنترنت لتحميل صفحة المصحف"
                                     : qsTr("⚠️ Internet connection required to download page"))
            }
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
        onDarkModeChanged: {
            pageCacheToken += 1
        }
    }

    // Fullscreen Dark Cinema Backdrop (pure black top & bottom letterboxing even in light mode)
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        visible: isPageFullscreen
        z: -1
    }

    // Main Flickable Container
    SilicaFlickable {
        id: flickable
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: isTajweedBottomLegendActive
                    ? tajweedBottomBar.top
                    : ((isPageFullscreen || !audioBar.visible) ? parent.bottom : audioBar.top)
        }
        contentHeight: isPageFullscreen
                       ? quranReaderPage.height
                       : (quranManager.viewMode === 0 ? textContentCol.height : pageViewCol.height)
        interactive: !isPageFullscreen && (quranManager.viewMode !== 1 || (typeof pageImageContainer !== "undefined" && pageImageContainer.pageZoomScale <= 1.05))

        onMovementEnded: {
            if (quranManager.viewMode === 0 && pagesRepeater.count > 0) {
                var visiblePage = -1
                var firstAyahOnVisPage = 1
                for (var i = 0; i < pagesRepeater.count; ++i) {
                    var itm = pagesRepeater.itemAt(i)
                    if (!itm) continue
                    var p = itm.mapToItem(flickable.contentItem, 0, 0)
                    if (p.y + itm.height > flickable.contentY + Theme.itemSizeMedium) {
                        if (surahPagesList && i < surahPagesList.length) {
                            visiblePage = surahPagesList[i].pageNumber
                            if (surahPagesList[i].ayahs && surahPagesList[i].ayahs.length > 0) {
                                firstAyahOnVisPage = surahPagesList[i].ayahs[0].ayah_number
                            }
                        }
                        break
                    }
                }
                if (visiblePage > 0) {
                    currentPage = visiblePage
                    var curAyah = (selectedTextAyah > 0 && getPageIndexForAyah(selectedTextAyah) === getPageIndexForPageNumber(visiblePage))
                        ? selectedTextAyah
                        : firstAyahOnVisPage
                    startAyah = curAyah
                    quranManager.saveLastPosition(surahNumber, curAyah, visiblePage)
                }
            }
        }

        PullDownMenu {
            visible: !isPageFullscreen

            MenuItem {
                visible: quranManager.viewMode === 1
                text: isRtl ? "عرض ملء الشاشة" : qsTr("Fullscreen View")
                onClicked: toggleFullscreen()
            }

            MenuItem {
                text: isRtl ? "التفسير والترجمة" : qsTr("Tafsir & Translation")
                onClicked: {
                    var sNum = surahNumber
                    var aNum = 1
                    var maxAyahs = surahInfo ? surahInfo.total_verses : 286

                    if (quranManager.viewMode === 0) {
                        if (quranManager.playingSurah === surahNumber && quranManager.playingAyah > 0) {
                            aNum = quranManager.playingAyah
                        } else if (startAyah > 0 && startAyah <= maxAyahs) {
                            aNum = startAyah
                        } else {
                            aNum = 1
                        }
                    } else {
                        if (activePageAyahData) {
                            sNum = activePageAyahData.surah_number
                            aNum = activePageAyahData.ayah_number
                        } else if (pageAyahsList && pageAyahsList.length > 0) {
                            sNum = pageAyahsList[0].surah_number
                            aNum = pageAyahsList[0].ayah_number
                        } else {
                            sNum = surahNumber
                            aNum = 1
                        }
                    }

                    pageStack.push(Qt.resolvedUrl("QuranTafsirPage.qml"), {
                        surahNumber: sNum,
                        ayahNumber: aNum
                    })
                }
            }

            MenuItem {
                text: isRtl ? "مشاركة الآية" : qsTr("Share Ayah")
                onClicked: {
                    var sNum = surahNumber
                    var aNum = 1
                    var uText = ""
                    var maxAyahs = surahInfo ? surahInfo.total_verses : 286

                    if (quranManager.viewMode === 0) {
                        if (quranManager.playingSurah === surahNumber && quranManager.playingAyah > 0) {
                            aNum = quranManager.playingAyah
                        } else if (startAyah > 0 && startAyah <= maxAyahs) {
                            aNum = startAyah
                        } else {
                            aNum = 1
                        }
                        if (ayahsList && ayahsList.length >= aNum) {
                            uText = ayahsList[aNum - 1].text_uthmani
                        }
                    } else {
                        if (activePageAyahData) {
                            sNum = activePageAyahData.surah_number
                            aNum = activePageAyahData.ayah_number
                            uText = activePageAyahData.text_uthmani
                        } else if (pageAyahsList && pageAyahsList.length > 0) {
                            sNum = pageAyahsList[0].surah_number
                            aNum = pageAyahsList[0].ayah_number
                            uText = pageAyahsList[0].text_uthmani
                        } else {
                            sNum = surahNumber
                            aNum = 1
                        }
                    }
                    shareAyah(sNum, aNum, uText)
                }
            }

            MenuItem {
                text: isRtl ? "تحميل الصفحات والتلاوة (أوفلاين)" : qsTr("Downloads & Offline")
                onClicked: pageStack.push(Qt.resolvedUrl("QuranDownloadPage.qml"), {
                    initialSurah: surahNumber
                })
            }

            MenuItem {
                text: isRtl ? "إحصائيات وسجل الاستماع" : qsTr("Listening Statistics")
                onClicked: pageStack.push(Qt.resolvedUrl("QuranListeningStatsPage.qml"))
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
                text: quranManager.algeriaMode
                      ? (isRtl ? "إيقاف مصحف الجزائر (خط شريفي)" : qsTr("Disable Algerian Mushaf"))
                      : (isRtl ? "تفعيل مصحف الجزائر (خط شريفي)" : qsTr("Enable Algerian Mushaf"))
                onClicked: {
                    quranManager.algeriaMode = !quranManager.algeriaMode
                }
            }

            MenuItem {
                visible: quranManager.tajweedMode && quranManager.isTajweedMushafAvailable(quranManager.riwayah)
                text: quranManager.tajweedHdMode
                      ? (isRtl ? "جودة صفحات التجويد: فائقة الدقة (HD) ✓" : qsTr("Tajweed Quality: High Definition (HD) ✓"))
                      : (isRtl ? "جودة صفحات التجويد: قياسية (SD)" : qsTr("Tajweed Quality: Standard (SD)"))
                onClicked: {
                    quranManager.tajweedHdMode = !quranManager.tajweedHdMode
                }
            }

            MenuItem {
                text: isRtl
                      ? ("إيقاف تشغيل الشاشة: " + (quranManager.screenBlankingDisabled ? "معطل" : "حسب النظام"))
                      : qsTr("Screen blanking: %1").arg(quranManager.screenBlankingDisabled ? qsTr("disabled") : qsTr("system"))
                onClicked: {
                    quranManager.screenBlankingDisabled = !quranManager.screenBlankingDisabled
                }
            }

            MenuItem {
                text: isRtl
                      ? ("التبديل إلى: " + (quranManager.viewMode === 0 ? "المصحف المصور (صفحات)" : "العرض النصي"))
                      : qsTr("Switch to: %1").arg(quranManager.viewMode === 0 ? qsTr("Mushaf Page View") : qsTr("Text View"))
                onClicked: {
                    quranManager.viewMode = (quranManager.viewMode === 0) ? 1 : 0
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

            MenuItem {
                text: isRtl
                      ? ("القارئ: " + quranManager.selectedReciterName)
                      : qsTr("Reciter: %1").arg(quranManager.selectedReciterName)
                onClicked: {
                    pageStack.push(Qt.resolvedUrl("ReciterPickerDialog.qml"))
                }
            }

            MenuItem {
                text: quranManager.isPlaying
                      ? (isRtl ? "إيقاف التلاوة" : qsTr("Stop Recitation"))
                      : (isRtl ? "استماع للسورة كاملة" : qsTr("Play Surah Audio"))
                onClicked: {
                    if (quranManager.isPlaying) {
                        quranManager.stopAudio()
                    } else {
                        quranManager.playSurah(surahNumber, 1)
                    }
                }
            }

            MenuItem {
                text: isRtl ? "السورة السابقة" : qsTr("Previous Surah")
                enabled: surahNumber > 1
                onClicked: goToSurahBeginning(surahNumber - 1)
            }

            MenuItem {
                text: isRtl ? "السورة التالية" : qsTr("Next Surah")
                enabled: surahNumber < 114
                onClicked: goToSurahBeginning(surahNumber + 1)
            }
        }

        PushUpMenu {
            id: readerPushUpMenu

            MenuItem {
                text: isRtl ? "السورة التالية" : qsTr("Next Surah")
                enabled: surahNumber < 114
                onClicked: goToSurahBeginning(surahNumber + 1)
            }

            MenuItem {
                text: isRtl ? "السورة السابقة" : qsTr("Previous Surah")
                enabled: surahNumber > 1
                onClicked: goToSurahBeginning(surahNumber - 1)
            }
        }

        // ================================================================
        // MODE 0: TEXT VIEW (العرض النصي للآيات)
        // ================================================================
        Column {
            id: textContentCol
            width: parent.width
            visible: quranManager.viewMode === 0

            PageHeader {
                title: surahInfo ? ("سورة " + surahInfo.name_ar) : ""
                description: {
                    if (!surahInfo) return ""
                    var typeStr = surahInfo.revelation_type === "Meccan" ? (isRtl ? "مكية" : qsTr("Meccan")) : (isRtl ? "مدنية" : qsTr("Medinan"))
                    return isRtl
                        ? (typeStr + " • " + prayerManager.formatDigits(surahInfo.total_verses.toString()) + " آيات • [" + quranManager.riwayahName + "]")
                        : (typeStr + " • " + surahInfo.total_verses + " verses • [" + quranManager.riwayahCode + "]")
                }
            }

            // Top Controls: Segmented Switcher Pill & Font Size Adjuster (matching quranpedia.net)
            Column {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingMedium

                // Segmented Switcher Pill [ صفحات المصحف ] [ نصي ]
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, Theme.buttonWidthLarge * 1.15)
                    height: Theme.itemSizeExtraSmall
                    radius: height / 2
                    color: Theme.rgba(Theme.primaryColor, 0.08)
                    border.color: Theme.rgba(Theme.primaryColor, 0.2)
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.margins: 3

                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            radius: parent.height / 2
                            color: (quranManager.viewMode === 1) ? Theme.rgba(Theme.highlightBackgroundColor, 0.3) : "transparent"

                            Label {
                                anchors.centerIn: parent
                                text: isRtl ? "صفحات المصحف" : qsTr("Mushaf Pages")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                font.bold: quranManager.viewMode === 1
                                color: (quranManager.viewMode === 1) ? Theme.highlightColor : Theme.secondaryColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    updatePageAyahs()
                                    quranManager.viewMode = 1
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            radius: parent.height / 2
                            color: (quranManager.viewMode === 0) ? Theme.rgba(Theme.highlightBackgroundColor, 0.3) : "transparent"

                            Label {
                                anchors.centerIn: parent
                                text: isRtl ? "نصي" : qsTr("Text Mode")
                                font.pixelSize: Theme.fontSizeExtraSmall
                                font.bold: quranManager.viewMode === 0
                                color: (quranManager.viewMode === 0) ? Theme.highlightColor : Theme.secondaryColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    requestSwitchToTextMode(surahNumber, 0, false)
                                }
                            }
                        }
                    }
                }

                // Font size adjuster bar
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.paddingMedium
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    Label {
                        text: isRtl ? "حجم الخط:" : qsTr("Font size:")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.secondaryColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    IconButton {
                        icon.source: "image://theme/icon-m-remove"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: quranManager.fontSize = Math.max(20, quranManager.fontSize - 2)
                    }

                    Label {
                        text: prayerManager.formatDigits(quranManager.fontSize.toString())
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Theme.highlightColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    IconButton {
                        icon.source: "image://theme/icon-m-add"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: quranManager.fontSize = Math.min(75, quranManager.fontSize + 2)
                    }
                }

                // Tajweed Mode Toggle Pill
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    preferredWidth: Math.min(parent.width, Theme.buttonWidthLarge * 1.15)
                    text: quranManager.tajweedMode
                          ? (isRtl ? "✓ مصحف التجويد الملون (مفعل)" : qsTr("✓ Colored Tajweed (Active)"))
                          : (isRtl ? (quranManager.riwayah === 1 ? "مصحف التجويد الملون (متجهات)" : "مصحف التجويد الملون") : qsTr("Colored Tajweed Mode"))
                    color: quranManager.tajweedMode ? Theme.highlightColor : Theme.primaryColor
                    onClicked: {
                        var activating = !quranManager.tajweedMode
                        quranManager.tajweedMode = activating
                        if (activating) {
                            if (quranManager.riwayah === 1 && quranManager.viewMode === 1) {
                                quranManager.viewMode = 0
                            }
                            checkTextModeDisclaimer()
                        }
                    }
                }

                // Tajweed Legend / دليل أحكام التجويد Banner (matching Quranpedia)
                Rectangle {
                    visible: quranManager.tajweedMode && !isTajweedBottomLegendActive
                    width: parent.width
                    radius: 12
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                    border.color: Theme.rgba(Theme.highlightColor, 0.3)
                    border.width: 1
                    height: tajweedBannerCol.height + Theme.paddingMedium * 2

                    Column {
                        id: tajweedBannerCol
                        width: parent.width - 2 * Theme.paddingMedium
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Theme.paddingMedium
                        spacing: Theme.paddingSmall

                        // Header / Toggle
                        BackgroundItem {
                            width: parent.width
                            height: Theme.itemSizeExtraSmall
                            onClicked: tajweedLegendExpanded = !tajweedLegendExpanded

                            Row {
                                anchors.fill: parent
                                layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                                spacing: Theme.paddingSmall

                                Label {
                                    text: isRtl ? "دليل أحكام التجويد الملون" : qsTr("Tajweed Rules Guide")
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    color: Theme.highlightColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item { width: Theme.paddingSmall; height: 1 }

                                Label {
                                    text: tajweedLegendExpanded ? (isRtl ? "▲ إخفاء" : qsTr("▲ Hide")) : (isRtl ? "▼ تفاصيل" : qsTr("▼ Details"))
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.secondaryColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Compact Color Dots Row (always visible when Tajweed is active)
                        Flow {
                            width: parent.width
                            spacing: Theme.paddingMedium
                            layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                            Repeater {
                                model: tajweedRulesSummary

                                delegate: Row {
                                    spacing: Theme.paddingSmall
                                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                                    Rectangle {
                                        width: 16; height: 16; radius: 8
                                        color: modelData.color
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Label {
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                        color: Theme.primaryColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // Detailed Explanations (visible when expanded)
                        Column {
                            visible: tajweedLegendExpanded
                            width: parent.width
                            spacing: Theme.paddingSmall

                            Item {
                                width: parent.width
                                height: 1
                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.rgba(Theme.secondaryColor, 0.2)
                                }
                            }

                            Repeater {
                                model: tajweedRulesDetails

                                delegate: Row {
                                    width: parent.width
                                    spacing: Theme.paddingSmall
                                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                                    Rectangle {
                                        width: 16; height: 16; radius: 8
                                        color: modelData.color
                                        y: 4
                                    }

                                    Column {
                                        width: parent.width - 24
                                        spacing: 2
                                        Label {
                                            text: modelData.title
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.bold: true
                                            color: modelData.color
                                        }
                                        Label {
                                            text: modelData.desc
                                            width: parent.width
                                            font.pixelSize: Theme.fontSizeExtraSmall
                                            color: Theme.secondaryColor
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            // Page Cards Repeater (grouped by Mushaf page, identical to quranpedia presentation)
            Repeater {
                id: pagesRepeater
                model: (quranManager.viewMode === 0) ? surahPagesList : []

                delegate: Item {
                    id: pageCardItem
                    width: parent.width
                    height: cardFrame.height + Theme.paddingLarge

                    Rectangle {
                        id: cardFrame
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Theme.paddingSmall
                        height: cardContentCol.height + Theme.paddingLarge * 2
                        radius: 16
                        color: quranManager.darkMode ? "#121520" : "#fdfbf7"
                        border.color: quranManager.darkMode ? "#283147" : "#dfd8cd"
                        border.width: 1

                        Column {
                            id: cardContentCol
                            width: parent.width - 2 * Theme.paddingLarge
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Theme.paddingLarge
                            spacing: Theme.paddingLarge

                            // Basmalah on the first page of the Surah (except At-Tawbah 9, Al-Fatihah 1)
                            Item {
                                width: parent.width
                                height: basmalahCardLabel.height + Theme.paddingSmall
                                visible: modelData.isFirstPageOfSurah && surahNumber !== 9 && surahNumber !== 1

                                Text {
                                    id: basmalahCardLabel
                                    anchors.centerIn: parent
                                    textFormat: Text.RichText
                                    text: quranManager.tajweedMode
                                          ? quranManager.formatTajweedHtml("بِسۡمِ [h:788[ٱ]للَّهِ [h:788[ٱ]ل[l[رّ]َحۡ[n[مَٰ]نِ [h:788[ٱ]ل[l[رّ]َح[p[ِي]مِ", quranManager.darkMode)
                                          : "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ"
                                    font.pixelSize: Math.max(Theme.fontSizeLarge + 6, quranManager.fontSize + 2)
                                    font.family: quranFontFamily
                                    color: quranManager.darkMode ? "#f5f6f8" : "#12141a"
                                }
                            }

                            // Continuous Quranic Text with highlighted active/selected ayah
                            Text {
                                id: pageCardText
                                width: parent.width
                                textFormat: Text.RichText
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignJustify
                                font.pixelSize: quranManager.fontSize
                                font.family: quranFontFamily
                                text: getPageCardHtml(
                                    modelData.ayahs,
                                    quranManager.darkMode,
                                    (quranManager.isPlaying && quranManager.playingSurah === surahNumber) ? quranManager.playingAyah : 0,
                                    selectedTextAyah
                                )
                                onLinkActivated: function(link) {
                                    var parts = link.split(":")
                                    if (parts.length === 2) {
                                        var aNum = parseInt(parts[1])
                                        if (selectedTextAyah === aNum) {
                                            selectedTextAyah = 0
                                        } else {
                                            selectedTextAyah = aNum
                                            startAyah = aNum
                                            var pIdx = getPageIndexForAyah(aNum)
                                            if (pIdx >= 0 && pIdx < surahPagesList.length) {
                                                currentPage = surahPagesList[pIdx].pageNumber
                                            } else {
                                                var p = quranManager.getPageForAyah(surahNumber, aNum)
                                                if (p > 0) currentPage = p
                                            }
                                            quranManager.saveLastPosition(surahNumber, aNum, currentPage)
                                        }
                                    }
                                }
                            }

                            // Bottom Decorative Page Badge: ─── ۞ ٢ ۞ ───
                            Item {
                                width: parent.width
                                height: Theme.itemSizeExtraSmall

                                Row {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    spacing: Theme.paddingMedium

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: (parent.width - pageBadgeRect.width - Theme.paddingMedium * 2) / 2
                                        height: 1
                                        color: quranManager.darkMode ? "#343d57" : "#d8d1c5"
                                    }

                                    Rectangle {
                                        id: pageBadgeRect
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: pageBadgeLabel.width + Theme.paddingLarge * 1.5
                                        height: Theme.itemSizeExtraSmall * 0.75
                                        radius: 8
                                        color: quranManager.darkMode ? "#1c2233" : "#ede7db"
                                        border.color: quranManager.darkMode ? "#3e4a6d" : "#ccc3b2"
                                        border.width: 1

                                        Label {
                                            id: pageBadgeLabel
                                            anchors.centerIn: parent
                                            text: "۞ " + prayerManager.formatDigits(modelData.pageNumber.toString()) + " ۞"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.bold: true
                                            color: quranManager.darkMode ? Theme.highlightColor : "#633c00"
                                        }
                                    }

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: (parent.width - pageBadgeRect.width - Theme.paddingMedium * 2) / 2
                                        height: 1
                                        color: quranManager.darkMode ? "#343d57" : "#d8d1c5"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Extra bottom spacing so the last ayahs can also be scrolled to middle height of screen
            Item {
                width: 1
                height: Math.max(Theme.paddingLarge * 2, flickable.height / 2)
            }
        }

        // ================================================================
        // MODE 1: MUSHAF PAGE VIEW (المصحف المصور - صفحات عالية الدقة)
        // ================================================================
        Column {
            id: pageViewCol
            width: parent.width
            visible: quranManager.viewMode === 1

            PageHeader {
                id: pageHeaderView
                visible: !isPageFullscreen
                height: isPageFullscreen ? 0 : implicitHeight
                opacity: isPageFullscreen ? 0.0 : 1.0
                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
                title: isRtl ? ("المصحف الشريف • ص " + prayerManager.formatDigits(currentPage.toString())) : ("Holy Quran • Page " + currentPage)
                description: {
                    var parts = []
                    if (currentPageSurahName !== "") parts.push(currentPageSurahName)
                    var mName = isRtl ? quranManager.mushafName : quranManager.mushafDisplayName
                    if (mName && mName !== "") parts.push(mName)
                    if (quranManager.riwayahName !== "") parts.push(quranManager.riwayahName)
                    return parts.join(" • ")
                }
            }

            // Page Navigation Controls Bar
            Item {
                id: pageNavContainer
                visible: !isPageFullscreen
                height: isPageFullscreen ? 0 : Theme.itemSizeSmall
                opacity: isPageFullscreen ? 0.0 : 1.0
                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter

                Row {
                    id: navRightControls
                    anchors {
                        left: isRtl ? parent.left : undefined
                        right: isRtl ? undefined : parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: Theme.paddingSmall
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    // Tajweed Mode Toggle Pill
                    Rectangle {
                        id: tajweedPill
                        height: Theme.itemSizeExtraSmall * 0.8
                        width: tajweedLabel.width + Theme.paddingMedium * 1.4
                        radius: height / 2
                        color: quranManager.tajweedMode ? Theme.rgba("#ffd700", 0.22) : Theme.rgba(Theme.highlightBackgroundColor, 0.15)
                        border.color: quranManager.tajweedMode ? "#ffd700" : Theme.rgba(Theme.primaryColor, 0.35)
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            id: tajweedLabel
                            text: quranManager.tajweedMode
                                  ? (isRtl ? "بدون تجويد" : qsTr("No Tajweed"))
                                  : (isRtl ? "تجويد" : qsTr("Tajweed"))
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: quranManager.tajweedMode
                            color: quranManager.tajweedMode ? "#ffd700" : Theme.primaryColor
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var activating = !quranManager.tajweedMode
                                quranManager.tajweedMode = activating
                                if (activating && quranManager.riwayah === 1 && quranManager.viewMode === 1) {
                                    quranManager.viewMode = 0
                                }
                            }
                        }
                    }

                    IconButton {
                        icon.source: quranManager.darkMode ? "image://theme/icon-m-day" : "image://theme/icon-m-night"
                        width: Theme.iconSizeMedium
                        height: Theme.iconSizeMedium
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: quranManager.darkMode = !quranManager.darkMode
                    }

                    // Text Mode Switch Pill
                    Rectangle {
                        id: textModePill
                        height: Theme.itemSizeExtraSmall * 0.8
                        width: textModeLabel.width + Theme.paddingMedium * 1.4
                        radius: height / 2
                        color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)
                        border.color: Theme.rgba(Theme.primaryColor, 0.35)
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            id: textModeLabel
                            text: isRtl ? "نصي" : qsTr("Text")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.primaryColor
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                requestSwitchToTextMode(surahNumber, 0, false)
                            }
                        }
                    }
                }

                Row {
                    id: pageNavRow
                    anchors {
                        left: isRtl ? undefined : parent.left
                        right: isRtl ? parent.right : undefined
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 0
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    IconButton {
                        icon.source: isRtl ? "image://theme/icon-m-right" : "image://theme/icon-m-left"
                        enabled: currentPage > 1
                        width: Theme.iconSizeMedium
                        height: Theme.iconSizeMedium
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            if (currentPage > 1) {
                                currentPage -= 1
                                savePagePosition(currentPage)
                            }
                        }
                    }

                    Label {
                        text: "\u200E" + prayerManager.formatDigits(currentPage.toString()) + " / " + prayerManager.formatDigits(quranManager.maxPages.toString()) + "\u200E"
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Theme.highlightColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    IconButton {
                        icon.source: isRtl ? "image://theme/icon-m-left" : "image://theme/icon-m-right"
                        enabled: currentPage < quranManager.maxPages
                        width: Theme.iconSizeMedium
                        height: Theme.iconSizeMedium
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            if (currentPage < quranManager.maxPages) {
                                currentPage += 1
                                savePagePosition(currentPage)
                            }
                        }
                    }
                }
            }

            Item {
                visible: !isPageFullscreen
                width: 1
                height: isPageFullscreen ? 0 : Theme.paddingSmall
            }

            // Quick-action banner when Hafs Tajweed is active while viewing Mushaf pages
            BackgroundItem {
                visible: !isPageFullscreen && quranManager.riwayah === 1 && quranManager.tajweedMode && quranManager.viewMode === 1
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                height: Theme.itemSizeExtraSmall * 0.85
                onClicked: quranManager.viewMode = 0

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.2)
                    border.color: Theme.rgba(Theme.highlightColor, 0.45)
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.paddingSmall

                        Label {
                            text: "✨"
                            font.pixelSize: Theme.fontSizeExtraSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: isRtl
                                  ? "مصحف التجويد لحفص متوفر بالعرض المتجهي • اضغط هنا للعرض"
                                  : qsTr("Hafs Tajweed is available in Vector View • Tap to display")
                            font.pixelSize: Theme.fontSizeTiny
                            font.bold: true
                            color: Theme.highlightColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // High-Resolution Mushaf Page Container
                // High-Resolution Mushaf Page Container
            Item {
                id: pageImageContainer
                readonly property bool isLandscapeMode: quranReaderPage.isLandscape
                readonly property real pageAspect: (pageImage.implicitHeight > 0 && pageImage.implicitWidth > 0)
                                                    ? (pageImage.implicitHeight / pageImage.implicitWidth)
                                                    : 1.56
                clip: true

                property real pageZoomScale: 1.0
                property real pagePanX: 0.0
                property real pagePanY: 0.0

                Behavior on pageZoomScale {
                    enabled: !pagePinchArea.isPinching
                    NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                }
                Behavior on pagePanX {
                    enabled: !pageGestureArea.isPanning
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
                Behavior on pagePanY {
                    enabled: !pageGestureArea.isPanning
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }

                function resetZoom() {
                    pageZoomScale = 1.0
                    pagePanX = 0
                    pagePanY = 0
                }

                function zoomIn() {
                    var s = Math.min(3.5, pageZoomScale + 0.35)
                    pageZoomScale = s
                    clampPan()
                }

                function zoomOut() {
                    var s = Math.max(1.0, pageZoomScale - 0.35)
                    pageZoomScale = s
                    if (s <= 1.05) {
                        resetZoom()
                    } else {
                        clampPan()
                    }
                }

                function zoomTo(targetScale, focusX, focusY) {
                    var s = Math.max(1.0, Math.min(3.5, targetScale))
                    pageZoomScale = s
                    if (s <= 1.05) {
                        resetZoom()
                    } else {
                        var midX = width / 2
                        var midY = height / 2
                        var dx = (midX - focusX) * (s - 1.0) * 0.8
                        var dy = (midY - focusY) * (s - 1.0) * 0.8
                        var maxPanX = Math.max(0, (width * (s - 1.0)) / 2) + 20
                        var maxPanY = Math.max(0, (height * (s - 1.0)) / 2) + 30
                        pagePanX = Math.max(-maxPanX, Math.min(maxPanX, dx))
                        pagePanY = Math.max(-maxPanY, Math.min(maxPanY, dy))
                    }
                }

                function clampPan() {
                    if (pageZoomScale <= 1.05) {
                        pagePanX = 0
                        pagePanY = 0
                        return
                    }
                    var maxPanX = Math.max(0, (width * (pageZoomScale - 1.0)) / 2) + 20
                    var maxPanY = Math.max(0, (height * (pageZoomScale - 1.0)) / 2) + 30
                    pagePanX = Math.max(-maxPanX, Math.min(maxPanX, pagePanX))
                    pagePanY = Math.max(-maxPanY, Math.min(maxPanY, pagePanY))
                }

                // In fullscreen mode, fill the entire screen (edge-to-edge).
                // In landscape mode, fit by height so the entire page is visible without stretching.
                // In portrait mode, fit by width to give a full-width reading view.
                height: isPageFullscreen
                        ? quranReaderPage.height
                        : (isLandscapeMode
                            ? Math.max(300, Math.round(quranReaderPage.height * 0.82))
                            : Math.max(400, Math.round((parent.width - 2 * Theme.horizontalPageMargin) * pageAspect)))

                width: isPageFullscreen
                       ? quranReaderPage.width
                       : (isLandscapeMode
                            ? Math.round(height / pageAspect)
                            : (parent.width - 2 * Theme.horizontalPageMargin))

                anchors.horizontalCenter: parent.horizontalCenter

                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                Rectangle {
                    anchors.fill: parent
                    radius: isPageFullscreen ? 0 : Theme.paddingSmall
                    color: (isPageFullscreen || quranManager.darkMode) ? "#000000" : "#fffdf5"
                    border.color: isPageFullscreen ? "transparent" : Theme.rgba(Theme.highlightColor, 0.4)
                    border.width: isPageFullscreen ? 0 : 1
                }

                // Loading Indicator & Status (Smooth non-blocking background render)
                Column {
                    anchors.centerIn: parent
                    width: parent.width - Theme.paddingLarge * 2
                    visible: (!isCurrentPageCached || (pageImage.status !== Image.Ready && !pageImage.paintedWidth)) && !pageDownloadFailedVisible
                    spacing: Theme.paddingMedium

                    BusyIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        running: true
                        size: BusyIndicatorSize.Large
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: !isCurrentPageCached
                              ? (isRtl ? "جاري تحميل صفحة المصحف الشريف..." : qsTr("Downloading Holy Quran page..."))
                              : (isRtl ? "جاري تجهيز الصفحة..." : qsTr("Preparing page..."))
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !isCurrentPageCached
                        text: isRtl ? "🌐 يلزم تفعيل الإنترنت لتحميل الصفحة وحفظها بالجهاز"
                                    : qsTr("🌐 Internet connection required to download and cache page")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        width: parent.width
                    }
                }

                // Inner Scalable & Pannable Container
                Item {
                    id: zoomContent
                    width: pageImageContainer.width
                    height: pageImageContainer.height
                    transformOrigin: Item.Center
                    scale: pageImageContainer.pageZoomScale
                    transform: Translate {
                        x: pageImageContainer.pagePanX
                        y: pageImageContainer.pagePanY
                    }

                    // 1. Current Displayed Image (keeps current texture visible on screen with ZERO blanking)
                    Image {
                        id: pageImage
                        anchors.fill: parent
                        anchors.margins: isPageFullscreen ? 0 : 1
                        fillMode: (isPageFullscreen && fullscreenFillMode) ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        smooth: true
                        mipmap: true
                        visible: isCurrentPageCached && pageImage.status !== Image.Error && !pageDownloadFailedVisible
                    }

                    // 2. Offscreen Background Image Loader (double-buffering: preloads new ayah/page in background)
                    Image {
                        id: pendingPageImage
                        anchors.fill: parent
                        anchors.margins: isPageFullscreen ? 0 : 1
                        fillMode: (isPageFullscreen && fullscreenFillMode) ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        smooth: true
                        mipmap: true
                        visible: false
                        source: activePageUrl

                        onStatusChanged: {
                            if (status === Image.Ready) {
                                pageImage.source = pendingPageImage.source
                            }
                        }
                        onSourceChanged: {
                            if (status === Image.Ready) {
                                pageImage.source = source
                            }
                        }
                    }
                }

                // Error fallback & Retry button
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    spacing: Theme.paddingMedium
                    visible: pageDownloadFailedVisible || (isCurrentPageCached && (pageImage.status === Image.Error || pendingPageImage.status === Image.Error))

                    Label {
                        width: parent.width
                        text: isRtl
                              ? "تعذر تحميل صفحة المصحف لأول مرة.\nيرجى التأكد من تشغيل الإنترنت والضغط على إعادة المحاولة."
                              : qsTr("Could not load Quran page.\nPlease ensure internet is connected and tap Retry.")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: isRtl ? "إعادة المحاولة" : qsTr("Retry")
                        onClicked: {
                            pageDownloadFailedVisible = false
                            quranManager.preloadPage(currentPage)
                            pageCacheToken += 1
                        }
                    }
                }

                // Active Ayah Side Position Indicator
                Item {
                    visible: !isPageFullscreen && activePageAyahData !== null && pageAyahsList.length > 0
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        right: isRtl ? parent.right : undefined
                        left: isRtl ? undefined : parent.left
                        topMargin: Theme.paddingMedium
                        bottomMargin: Theme.paddingMedium
                    }
                    width: 4

                    Rectangle {
                        property int ayahIdx: {
                            if (!activePageAyahData) return 0
                            for (var i = 0; i < pageAyahsList.length; ++i) {
                                if (pageAyahsList[i].ayah_number === activePageAyahData.ayah_number &&
                                    pageAyahsList[i].surah_number === activePageAyahData.surah_number) return i
                            }
                            return 0
                        }
                        width: 4
                        height: Math.max(30, parent.height / Math.max(1, pageAyahsList.length))
                        y: parent.height * (ayahIdx / Math.max(1, pageAyahsList.length))
                        color: Theme.highlightColor
                        radius: 2

                        Behavior on y {
                            NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                // Timer to distinguish single tap from double tap
                Timer {
                    id: singleTapTimer
                    interval: 280
                    repeat: false
                    onTriggered: {
                        if (selectedTextAyah > 0) {
                            selectedTextAyah = 0
                        } else {
                            toggleFullscreen()
                        }
                    }
                }

                // Pinch-to-zoom multi-touch gesture area
                PinchArea {
                    id: pagePinchArea
                    anchors.fill: parent
                    pinch.target: null
                    property bool isPinching: false
                    property real initialScale: 1.0
                    property real initialPanX: 0
                    property real initialPanY: 0

                    onPinchStarted: {
                        isPinching = true
                        singleTapTimer.stop()
                        initialScale = pageImageContainer.pageZoomScale
                        initialPanX = pageImageContainer.pagePanX
                        initialPanY = pageImageContainer.pagePanY
                    }
                    onPinchUpdated: {
                        var targetScale = Math.max(1.0, Math.min(3.5, initialScale * pinch.scale))
                        pageImageContainer.pageZoomScale = targetScale
                        pageImageContainer.pagePanX = initialPanX + (pinch.center.x - pinch.startCenter.x)
                        pageImageContainer.pagePanY = initialPanY + (pinch.center.y - pinch.startCenter.y)
                    }
                    onPinchFinished: {
                        isPinching = false
                        if (pageImageContainer.pageZoomScale < 1.08) {
                            pageImageContainer.resetZoom()
                        } else {
                            pageImageContainer.clampPan()
                        }
                    }

                    // Swipe gestures, pan when zoomed, tap/double-tap, and ayah selection
                    MouseArea {
                        id: pageGestureArea
                        anchors.fill: parent
                        property real startX: 0
                        property real startY: 0
                        property real lastX: 0
                        property real lastY: 0
                        property bool isPanning: false
                        property real lastTapTime: 0
                        property real lastTapX: 0
                        property real lastTapY: 0
                        property bool wasPressAndHold: false

                        onPressed: {
                            startX = mouse.x
                            startY = mouse.y
                            lastX = mouse.x
                            lastY = mouse.y
                            wasPressAndHold = false

                            if (pageImageContainer.pageZoomScale > 1.05) {
                                isPanning = true
                                preventStealing = true
                            } else {
                                isPanning = false
                                preventStealing = false
                            }
                        }

                        onPositionChanged: {
                            if (pageImageContainer.pageZoomScale > 1.05) {
                                isPanning = true
                                preventStealing = true
                                var dx = mouse.x - lastX
                                var dy = mouse.y - lastY
                                pageImageContainer.pagePanX += dx
                                pageImageContainer.pagePanY += dy
                                lastX = mouse.x
                                lastY = mouse.y
                                return
                            }

                            var diff = mouse.x - startX
                            var diffY = mouse.y - startY
                            if (Math.abs(diff) > 30 && Math.abs(diff) > Math.abs(diffY) * 1.2) {
                                preventStealing = true
                            }
                        }

                        onPressAndHold: {
                            singleTapTimer.stop()
                            wasPressAndHold = true
                            if (isPageFullscreen) {
                                isPageFullscreen = false
                            }

                            // Calculate unscaled coordinates taking zoom and pan into account
                            var midX = pageImageContainer.width / 2
                            var midY = pageImageContainer.height / 2
                            var cx = mouse.x - midX - pageImageContainer.pagePanX
                            var cy = mouse.y - midY - pageImageContainer.pagePanY
                            var unscaledX = midX + cx / pageImageContainer.pageZoomScale
                            var unscaledY = midY + cy / pageImageContainer.pageZoomScale

                            var pw = pageImage.paintedWidth > 0 ? pageImage.paintedWidth : pageImage.width
                            var ph = pageImage.paintedHeight > 0 ? pageImage.paintedHeight : pageImage.height
                            var imgX = (pageImage.width - pw) / 2
                            var imgY = (pageImage.height - ph) / 2
                            var relX = Math.max(0.0, Math.min(1.0, (unscaledX - imgX) / pw))
                            var relY = Math.max(0.0, Math.min(1.0, (unscaledY - imgY) / ph))

                            var hit = quranManager.getAyahAtCoordinate(currentPage, relX, relY, quranManager.riwayah)
                            var aNum = (hit && hit.ayah > 0) ? hit.ayah : 0
                            var sNum = (hit && hit.surah > 0) ? hit.surah : 0

                            // Proportional Y fallback if coordinate check misses
                            if (aNum <= 0 && pageAyahsList && pageAyahsList.length > 0) {
                                var idx = Math.floor(relY * pageAyahsList.length)
                                idx = Math.max(0, Math.min(pageAyahsList.length - 1, idx))
                                aNum = pageAyahsList[idx].ayah_number
                                sNum = pageAyahsList[idx].surah_number
                            }

                            if (aNum > 0) {
                                if (selectedTextAyah === aNum && targetHighlightSurah === sNum) {
                                    selectedTextAyah = 0
                                } else {
                                    targetHighlightSurah = sNum
                                    targetHighlightAyah = aNum
                                    selectedTextAyah = aNum
                                    startAyah = aNum
                                    quranManager.saveLastPosition(sNum, aNum, currentPage)
                                }
                            }
                        }

                        onReleased: {
                            var diff = mouse.x - startX
                            var diffY = mouse.y - startY
                            preventStealing = false
                            var wasPan = isPanning
                            isPanning = false

                            if (wasPressAndHold) {
                                wasPressAndHold = false
                                return
                            }

                            // If we were zoomed in and panned noticeably, clamp smoothly and don't trigger tap
                            if (pageImageContainer.pageZoomScale > 1.05) {
                                pageImageContainer.clampPan()
                                if (wasPan && (Math.abs(diff) > 10 || Math.abs(diffY) > 10)) {
                                    return
                                }
                            }

                            // Detect double-tap
                            var currentTime = new Date().getTime()
                            if (currentTime - lastTapTime < 320 && Math.abs(mouse.x - lastTapX) < 35 && Math.abs(mouse.y - lastTapY) < 35) {
                                singleTapTimer.stop()
                                lastTapTime = 0
                                if (pageImageContainer.pageZoomScale > 1.1) {
                                    pageImageContainer.resetZoom()
                                } else {
                                    pageImageContainer.zoomTo(2.0, mouse.x, mouse.y)
                                }
                                return
                            }
                            lastTapTime = currentTime
                            lastTapX = mouse.x
                            lastTapY = mouse.y

                            // Swipe gestures (page flip) when not zoomed in
                            if (pageImageContainer.pageZoomScale <= 1.05 && Math.abs(diff) > 50 && Math.abs(diff) > Math.abs(diffY)) {
                                singleTapTimer.stop()
                                if (diff > 0 && currentPage < quranManager.maxPages) {
                                    currentPage += 1
                                    savePagePosition(currentPage)
                                } else if (diff < 0 && currentPage > 1) {
                                    currentPage -= 1
                                    savePagePosition(currentPage)
                                }
                            } else if (Math.abs(diff) < 20 && Math.abs(diffY) < 20) {
                                // Schedule single tap action with debounce to allow double-tap check
                                singleTapTimer.restart()
                            }
                        }

                        onCanceled: {
                            preventStealing = false
                            wasPressAndHold = false
                            isPanning = false
                            singleTapTimer.stop()
                        }
                    }
                }

                // Floating Fullscreen Indicator Capsule
                Rectangle {
                    id: fullscreenOverlayHud
                    property bool hudVisible: true
                    z: 90
                    anchors {
                        top: parent.top
                        topMargin: Theme.paddingLarge
                        horizontalCenter: parent.horizontalCenter
                    }
                    width: hudRow.width + 2 * Theme.paddingMedium
                    height: Theme.itemSizeExtraSmall * 0.85
                    radius: height / 2
                    color: Theme.rgba("#111622", 0.90)
                    border.color: Theme.rgba("#ffd700", 0.6)
                    border.width: 1
                    visible: isPageFullscreen
                    opacity: (isPageFullscreen && hudVisible) ? 1.0 : 0.0

                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    Timer {
                        id: fullscreenHudFadeTimer
                        interval: 3500
                        repeat: false
                        onTriggered: fullscreenOverlayHud.hudVisible = false
                    }

                    Row {
                        id: hudRow
                        anchors.centerIn: parent
                        spacing: Theme.paddingSmall
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                        Label {
                            text: "\u200E" + prayerManager.formatDigits(currentPage.toString()) + " / " + prayerManager.formatDigits(quranManager.maxPages.toString()) + "\u200E"
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: true
                            color: "#ffd700"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: "•"
                            color: "#ffd700"
                            font.pixelSize: Theme.fontSizeExtraSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: fullscreenFillMode ? (isRtl ? "ملء الشاشة ⛶" : "Fill Screen ⛶") : (isRtl ? "احتواء ⊡" : "Fit Page ⊡")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: true
                            color: "#ffd700"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: "•"
                            color: "#ffd700"
                            font.pixelSize: Theme.fontSizeExtraSmall
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            text: isRtl ? "المس للخروج" : qsTr("Tap to exit")
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: true
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: toggleFullscreen()
                    }
                }

                // Floating Zoom HUD Pill: [-] 150% [+] ↺
                Rectangle {
                    id: floatingZoomPill
                    z: 95
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: Theme.paddingLarge
                        horizontalCenter: parent.horizontalCenter
                    }
                    visible: pageImageContainer.pageZoomScale > 1.05 || isPageFullscreen
                    height: Theme.itemSizeExtraSmall * 0.85
                    width: zoomPillRow.width + Theme.paddingMedium * 2
                    radius: height / 2
                    color: Theme.rgba("#111622", 0.90)
                    border.color: Theme.rgba(Theme.highlightColor, 0.6)
                    border.width: 1

                    Row {
                        id: zoomPillRow
                        anchors.centerIn: parent
                        spacing: Theme.paddingSmall
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                        // Zoom Out button (-)
                        Rectangle {
                            width: Theme.itemSizeExtraSmall * 0.65
                            height: width
                            radius: width / 2
                            color: zoomOutArea.pressed ? Theme.rgba(Theme.highlightColor, 0.3) : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                anchors.centerIn: parent
                                text: "−"
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: pageImageContainer.pageZoomScale > 1.05 ? "#ffffff" : Theme.rgba("#ffffff", 0.4)
                            }
                            MouseArea {
                                id: zoomOutArea
                                anchors.fill: parent
                                onClicked: pageImageContainer.zoomOut()
                            }
                        }

                        // Percentage Label
                        Label {
                            text: prayerManager.formatDigits(Math.round(pageImageContainer.pageZoomScale * 100).toString()) + "%"
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: true
                            color: "#ffd700"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Zoom In button (+)
                        Rectangle {
                            width: Theme.itemSizeExtraSmall * 0.65
                            height: width
                            radius: width / 2
                            color: zoomInArea.pressed ? Theme.rgba(Theme.highlightColor, 0.3) : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: pageImageContainer.pageZoomScale < 3.45 ? "#ffffff" : Theme.rgba("#ffffff", 0.4)
                            }
                            MouseArea {
                                id: zoomInArea
                                anchors.fill: parent
                                onClicked: pageImageContainer.zoomIn()
                            }
                        }

                        // Fill / Fit Toggle (⛶ / ⊡)
                        Rectangle {
                            visible: isPageFullscreen
                            width: Theme.itemSizeExtraSmall * 0.70
                            height: width
                            radius: width / 2
                            color: fullscreenFillMode ? Theme.rgba(Theme.highlightColor, 0.40) : "transparent"
                            border.color: Theme.rgba(Theme.highlightColor, 0.6)
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                anchors.centerIn: parent
                                text: fullscreenFillMode ? "⛶" : "⊡"
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: "#ffd700"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: fullscreenFillMode = !fullscreenFillMode
                            }
                        }

                        // Reset button (↺) visible when zoomed in
                        Rectangle {
                            visible: pageImageContainer.pageZoomScale > 1.05
                            width: Theme.itemSizeExtraSmall * 0.65
                            height: width
                            radius: width / 2
                            color: zoomResetArea.pressed ? Theme.rgba(Theme.highlightColor, 0.3) : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                anchors.centerIn: parent
                                text: "↺"
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: "#ffd700"
                            }
                            MouseArea {
                                id: zoomResetArea
                                anchors.fill: parent
                                onClicked: pageImageContainer.resetZoom()
                            }
                        }
                    }
                }
            }

            Item {
                visible: !isPageFullscreen
                width: 1
                height: isPageFullscreen ? 0 : Theme.paddingMedium
            }
        }
    }

    // ================================================================
    // FLOATING / DOCKED AUDIO PLAYER BAR
    // ================================================================
    Rectangle {
        id: audioBar
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        height: (!isPageFullscreen && (quranManager.isPlaying || quranManager.playingAyah > 0)) ? (Theme.itemSizeMedium * 1.1) : 0
        visible: !isPageFullscreen && height > 0
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.95)
        border.color: Theme.rgba(Theme.highlightColor, 0.3)
        border.width: 1
        z: 900

        readonly property color audioIconColor: Theme.primaryColor
        readonly property color audioIconHighlightColor: Theme.highlightColor

        Behavior on height {
            NumberAnimation { duration: 200 }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.paddingSmall
            spacing: 2

            // Progress Line
            Rectangle {
                width: parent.width
                height: 3
                color: Theme.rgba(Theme.primaryColor, 0.2)

                Rectangle {
                    anchors.left: isRtl ? undefined : parent.left
                    anchors.right: isRtl ? parent.right : undefined
                    width: parent.width * quranManager.audioProgress
                    height: parent.height
                    color: Theme.highlightColor
                }
            }

            Item {
                width: parent.width
                height: parent.height - 6

                Row {
                    id: audioControlsRow
                    anchors {
                        right: isRtl ? undefined : parent.right
                        left: isRtl ? parent.left : undefined
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 0
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                    // Previous Ayah
                    IconButton {
                        icon.source: isRtl ? "image://theme/icon-m-next" : "image://theme/icon-m-previous"
                        icon.color: audioBar.audioIconColor
                        icon.highlightColor: audioBar.audioIconHighlightColor
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: quranManager.playingAyah > 1 || quranManager.playingSurah > 1
                        onClicked: {
                            if (quranManager.playingAyah > 1) {
                                quranManager.playAyah(quranManager.playingSurah, quranManager.playingAyah - 1)
                            } else if (quranManager.playingSurah > 1) {
                                var prevS = quranManager.getSurah(quranManager.playingSurah - 1)
                                var prevTotal = prevS ? prevS.total_verses : 1
                                quranManager.playAyah(quranManager.playingSurah - 1, prevTotal)
                            }
                        }
                    }

                    // Play / Pause
                    IconButton {
                        icon.source: quranManager.isPlaying ? "image://theme/icon-m-pause" : "image://theme/icon-m-play"
                        icon.color: audioBar.audioIconColor
                        icon.highlightColor: audioBar.audioIconHighlightColor
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            if (quranManager.isPlaying) {
                                quranManager.pauseAudio()
                            } else {
                                quranManager.resumeAudio()
                            }
                        }
                    }

                    // Next Ayah
                    IconButton {
                        icon.source: isRtl ? "image://theme/icon-m-previous" : "image://theme/icon-m-next"
                        icon.color: audioBar.audioIconColor
                        icon.highlightColor: audioBar.audioIconHighlightColor
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: {
                            if (quranManager.playingSurah <= 0 || quranManager.playingAyah <= 0) return false
                            if (quranManager.playingSurah < 114) return true
                            var curS = quranManager.getSurah(quranManager.playingSurah)
                            var curTotal = curS ? curS.total_verses : 0
                            return quranManager.playingAyah < curTotal
                        }
                        onClicked: {
                            var curS = quranManager.getSurah(quranManager.playingSurah)
                            var curTotal = curS ? curS.total_verses : 0
                            if (quranManager.playingAyah < curTotal) {
                                quranManager.playAyah(quranManager.playingSurah, quranManager.playingAyah + 1)
                            } else if (quranManager.playingSurah < 114) {
                                quranManager.playAyah(quranManager.playingSurah + 1, 1)
                            }
                        }
                    }

                    // Tafsir / Translation
                    IconButton {
                        icon.source: "image://theme/icon-m-about"
                        icon.color: audioBar.audioIconColor
                        icon.highlightColor: audioBar.audioIconHighlightColor
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: quranManager.playingSurah > 0 && quranManager.playingAyah > 0
                        onClicked: {
                            if (quranManager.playingSurah > 0 && quranManager.playingAyah > 0) {
                                pageStack.push(Qt.resolvedUrl("QuranTafsirPage.qml"), {
                                    surahNumber: quranManager.playingSurah,
                                    ayahNumber: quranManager.playingAyah
                                })
                            }
                        }
                    }

                    // Stop / Close
                    IconButton {
                        icon.source: "image://theme/icon-m-clear"
                        icon.color: audioBar.audioIconColor
                        icon.highlightColor: audioBar.audioIconHighlightColor
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            quranManager.stopAudio()
                        }
                    }
                }

                // Reciter & Ayah details
                Column {
                    anchors {
                        left: isRtl ? audioControlsRow.right : parent.left
                        right: isRtl ? parent.right : audioControlsRow.left
                        leftMargin: isRtl ? Theme.paddingSmall : 0
                        rightMargin: isRtl ? 0 : Theme.paddingSmall
                        verticalCenter: parent.verticalCenter
                    }

                    Label {
                        width: parent.width
                        text: {
                            var s = quranManager.getSurah(quranManager.playingSurah)
                            var sName = s ? (isRtl ? s.name_ar : s.name_en) : ""
                            return isRtl
                                ? ("سورة " + sName + " • آية " + prayerManager.formatDigits(quranManager.playingAyah.toString()))
                                : (sName + " • Ayah " + quranManager.playingAyah)
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Theme.highlightColor
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width
                        text: {
                            var reciterText = quranManager.selectedReciterName + " [" + quranManager.riwayahName + "]"
                            if (quranManager.isPlaying && quranManager.playingAyah > 0) {
                                var isCached = quranManager.isAyahAudioCached(quranManager.playingSurah, quranManager.playingAyah)
                                if (!isCached) {
                                    return reciterText + (isRtl ? " • 🌐 مباشر (إنترنت)" : qsTr(" • 🌐 Online stream"))
                                }
                            }
                            return reciterText
                        }
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        truncationMode: TruncationMode.Fade
                    }
                }
            }
        }
    }

    // ================================================================
    // DOCKED TAJWEED LEGEND BAR (Fixed at bottom during playback in Text Mode)
    // ================================================================
    Rectangle {
        id: tajweedBottomBar
        visible: isTajweedBottomLegendActive
        anchors {
            left: parent.left
            right: parent.right
            bottom: audioBar.visible ? audioBar.top : parent.bottom
        }
        height: isTajweedBottomLegendActive ? (tajweedBottomCol.height + Theme.paddingSmall * 2) : 0
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.95)
        border.color: Theme.rgba(Theme.highlightColor, 0.3)
        border.width: 1
        z: 800

        Column {
            id: tajweedBottomCol
            width: parent.width - 2 * Theme.paddingMedium
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.paddingSmall
            spacing: Theme.paddingSmall

            // Header / Toggle
            BackgroundItem {
                width: parent.width
                height: Theme.itemSizeExtraSmall
                onClicked: tajweedLegendExpanded = !tajweedLegendExpanded

                Row {
                    anchors.fill: parent
                    layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                    spacing: Theme.paddingSmall

                    Label {
                        text: isRtl ? "دليل أحكام التجويد الملون" : qsTr("Tajweed Rules Guide")
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Theme.highlightColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: Theme.paddingSmall; height: 1 }

                    Label {
                        text: tajweedLegendExpanded ? (isRtl ? "▲ إخفاء" : qsTr("▲ Hide")) : (isRtl ? "▼ تفاصيل" : qsTr("▼ Details"))
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Compact Color Dots Row (always visible when Tajweed is active)
            Flow {
                width: parent.width
                spacing: Theme.paddingMedium
                layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                Repeater {
                    model: tajweedRulesSummary

                    delegate: Row {
                        spacing: Theme.paddingSmall
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                        Rectangle {
                            width: 16; height: 16; radius: 8
                            color: modelData.color
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Label {
                            text: modelData.name
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: Theme.primaryColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Detailed Explanations (visible when expanded, scrollable if tall)
            SilicaFlickable {
                visible: tajweedLegendExpanded
                width: parent.width
                height: Math.min(tajweedBottomDetailsCol.height, quranReaderPage.height * 0.35)
                contentHeight: tajweedBottomDetailsCol.height
                clip: true
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: tajweedBottomDetailsCol
                    width: parent.width
                    spacing: Theme.paddingSmall

                    Item {
                        width: parent.width
                        height: 1
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.rgba(Theme.secondaryColor, 0.2)
                        }
                    }

                    Repeater {
                        model: tajweedRulesDetails

                        delegate: Row {
                            width: parent.width
                            spacing: Theme.paddingSmall
                            layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                            Rectangle {
                                width: 16; height: 16; radius: 8
                                color: modelData.color
                                y: 4
                            }

                            Column {
                                width: parent.width - 24
                                spacing: 2
                                Label {
                                    text: modelData.title
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    color: modelData.color
                                }
                                Label {
                                    text: modelData.desc
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.secondaryColor
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Floating Ayah Action Panel (Available in both Text Mode and Page Mode)
    Rectangle {
        id: ayahActionPanel
        visible: !isPageFullscreen && selectedTextAyah > 0
        anchors {
            left: parent.left
            right: parent.right
            bottom: isTajweedBottomLegendActive
                    ? tajweedBottomBar.top
                    : (audioBar.visible ? audioBar.top : parent.bottom)
            margins: Theme.paddingMedium
        }
        height: actionPanelCol.height + Theme.paddingMedium * 2
        radius: 14
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.95)
        border.color: Theme.rgba(Theme.highlightColor, 0.4)
        border.width: 1
        z: 850

        readonly property color btnTextColor: Theme.primaryColor
        readonly property color btnBgColor: Theme.rgba(Theme.primaryColor, Theme.opacityFaint)
        readonly property color btnHighlightColor: Theme.highlightColor
        readonly property color btnHighlightBgColor: Theme.rgba(Theme.highlightBackgroundColor, Theme.opacityFaint)

        Column {
            id: actionPanelCol
            width: parent.width - 2 * Theme.paddingMedium
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.paddingMedium
            spacing: Theme.paddingSmall

            // Header Row: Title & Close Button
            Item {
                width: parent.width
                height: Math.max(actionPanelTitle.height, closeActionBtn.height, reciterBadge.height)

                Label {
                    id: actionPanelTitle
                    anchors {
                        left: isRtl ? undefined : parent.left
                        right: isRtl ? parent.right : undefined
                        verticalCenter: parent.verticalCenter
                    }
                    width: Math.min(implicitWidth, parent.width * 0.45)
                    text: {
                        var sInfo = (effectiveSelectedSurah === surahNumber && surahInfo) ? surahInfo : quranManager.getSurah(effectiveSelectedSurah)
                        var sName = sInfo ? (isRtl ? ("سورة " + sInfo.name_ar) : sInfo.name_en) : ""
                        var aStr = isRtl ? ("الآية " + prayerManager.formatDigits(selectedTextAyah.toString())) : ("Ayah " + selectedTextAyah)
                        return sName + " • " + aStr
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    color: Theme.highlightColor
                    truncationMode: TruncationMode.Fade
                }

                // Riwayah & Reciter Pill Badge
                Rectangle {
                    id: reciterBadge
                    anchors {
                        left: isRtl ? closeActionBtn.right : actionPanelTitle.right
                        right: isRtl ? actionPanelTitle.left : closeActionBtn.left
                        leftMargin: Theme.paddingSmall
                        rightMargin: Theme.paddingSmall
                        verticalCenter: parent.verticalCenter
                    }
                    height: Math.round(Theme.itemSizeExtraSmall * 0.65)
                    radius: height / 2
                    color: Theme.rgba(Theme.primaryColor, 0.1)
                    border.color: Theme.rgba(Theme.primaryColor, 0.2)
                    border.width: 1

                    Label {
                        id: reciterBadgeLabel
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - Theme.paddingSmall * 2)
                        text: {
                            var rName = (quranManager.riwayah === 2)
                                        ? (isRtl ? "ورش" : "Warsh")
                                        : (isRtl ? "حفص" : "Hafs")
                            var recName = quranManager.selectedReciterName
                            if (recName && recName.length > 0) {
                                return rName + " • " + recName
                            }
                            return rName
                        }
                        font.pixelSize: Theme.fontSizeExtraSmall * 0.95
                        color: Theme.highlightColor
                        font.bold: true
                        truncationMode: TruncationMode.Fade
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("ReciterPickerDialog.qml"))
                        }
                    }
                }

                IconButton {
                    id: closeActionBtn
                    anchors {
                        left: isRtl ? parent.left : undefined
                        right: isRtl ? undefined : parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    icon.source: "image://theme/icon-m-clear"
                    icon.color: ayahActionPanel.btnTextColor
                    icon.highlightColor: ayahActionPanel.btnHighlightColor
                    onClicked: {
                        selectedTextAyah = 0
                        targetHighlightAyah = 0
                        targetHighlightSurah = 0
                    }
                }
            }

            // Action Buttons - Row 1: Play & Tafsir
            Row {
                width: parent.width
                spacing: Theme.paddingSmall
                layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                Button {
                    preferredWidth: (parent.width - Theme.paddingSmall) / 2
                    color: ayahActionPanel.btnTextColor
                    backgroundColor: ayahActionPanel.btnBgColor
                    highlightColor: ayahActionPanel.btnHighlightColor
                    highlightBackgroundColor: ayahActionPanel.btnHighlightBgColor
                    text: (quranManager.isPlaying && quranManager.playingSurah === effectiveSelectedSurah && quranManager.playingAyah === selectedTextAyah)
                          ? (isRtl ? "إيقاف التلاوة" : qsTr("Pause"))
                          : (isRtl ? "القراءة من هذه الآية" : qsTr("Play from this Aya"))
                    onClicked: {
                        if (quranManager.isPlaying && quranManager.playingSurah === effectiveSelectedSurah && quranManager.playingAyah === selectedTextAyah) {
                            quranManager.pauseAudio()
                        } else {
                            quranManager.playAyah(effectiveSelectedSurah, selectedTextAyah)
                        }
                    }
                }

                Button {
                    preferredWidth: (parent.width - Theme.paddingSmall) / 2
                    color: ayahActionPanel.btnTextColor
                    backgroundColor: ayahActionPanel.btnBgColor
                    highlightColor: ayahActionPanel.btnHighlightColor
                    highlightBackgroundColor: ayahActionPanel.btnHighlightBgColor
                    text: isRtl ? "التفسير والترجمة" : qsTr("Tafsir & Translation")
                    onClicked: {
                        var sel = selectedTextAyah
                        var sNum = effectiveSelectedSurah
                        pageStack.push(Qt.resolvedUrl("QuranTafsirPage.qml"), {
                            surahNumber: sNum,
                            ayahNumber: sel
                        })
                    }
                }
            }

            // Action Buttons - Row 2: Mode Toggle, Share, Bookmark
            Row {
                width: parent.width
                spacing: Theme.paddingSmall
                layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                Button {
                    id: modeToggleBtn
                    preferredWidth: Math.floor((parent.width - 2 * Theme.paddingSmall) * 0.38)
                    color: ayahActionPanel.btnTextColor
                    backgroundColor: ayahActionPanel.btnBgColor
                    highlightColor: ayahActionPanel.btnHighlightColor
                    highlightBackgroundColor: ayahActionPanel.btnHighlightBgColor
                    text: (quranManager.viewMode === 0)
                          ? (isRtl ? "صفحات المصحف" : qsTr("Mushaf Pages"))
                          : (isRtl ? "العرض النصي" : qsTr("Text Mode"))
                    onClicked: {
                        if (quranManager.viewMode === 0) {
                            if (selectedAyahData && selectedAyahData.page_number) {
                                currentPage = selectedAyahData.page_number
                            } else {
                                var aIdx = selectedTextAyah - 1
                                if (ayahsList && aIdx >= 0 && aIdx < ayahsList.length) {
                                    currentPage = ayahsList[aIdx].page_number
                                }
                            }
                            targetHighlightAyah = selectedTextAyah
                            targetHighlightSurah = effectiveSelectedSurah
                            savePagePosition(currentPage)
                            quranManager.viewMode = 1
                        } else {
                            var aNum = selectedTextAyah
                            var sNum = effectiveSelectedSurah
                            requestSwitchToTextMode(sNum, aNum, false)
                        }
                    }
                }

                Button {
                    id: shareBtn
                    preferredWidth: Math.floor((parent.width - 2 * Theme.paddingSmall) * 0.24)
                    color: ayahActionPanel.btnTextColor
                    backgroundColor: ayahActionPanel.btnBgColor
                    highlightColor: ayahActionPanel.btnHighlightColor
                    highlightBackgroundColor: ayahActionPanel.btnHighlightBgColor
                    text: isRtl ? "مشاركة" : qsTr("Share")
                    onClicked: {
                        var aData = selectedAyahData
                        shareAyah(effectiveSelectedSurah, selectedTextAyah, aData ? aData.text_uthmani : "")
                    }
                }

                Button {
                    id: bookmarkBtn
                    preferredWidth: parent.width - 2 * Theme.paddingSmall - modeToggleBtn.preferredWidth - shareBtn.preferredWidth
                    color: ayahActionPanel.btnTextColor
                    backgroundColor: ayahActionPanel.btnBgColor
                    highlightColor: ayahActionPanel.btnHighlightColor
                    highlightBackgroundColor: ayahActionPanel.btnHighlightBgColor
                    text: isSelectedAyahBookmarked
                          ? (isRtl ? "★ في المفضلة" : qsTr("★ Bookmarked"))
                          : (isRtl ? "☆ أضف للمفضلة" : qsTr("☆ Bookmark"))
                    onClicked: {
                        var nowBookmarked = quranManager.toggleBookmark(effectiveSelectedSurah, selectedTextAyah)
                        bookmarkUpdateTrigger += 1
                        if (selectedAyahData) {
                            selectedAyahData.isBookmarked = nowBookmarked
                        }
                        copyToast.show(nowBookmarked
                                       ? (isRtl ? "تمت إضافة الآية إلى المفضلة" : qsTr("Added to bookmarks"))
                                       : (isRtl ? "تمت إزالة الآية من المفضلة" : qsTr("Removed from bookmarks")))
                    }
                }
            }
        }
    }

    // Floating Feedback Toast Banner
    Rectangle {
        id: copyToast
        anchors {
            bottom: isTajweedBottomLegendActive
                    ? tajweedBottomBar.top
                    : (audioBar.visible ? audioBar.top : parent.bottom)
            bottomMargin: Theme.paddingLarge
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
            width: Math.min(implicitWidth, copyToast.parent ? (copyToast.parent.width - Theme.paddingLarge * 4) : implicitWidth)
            text: ""
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
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

