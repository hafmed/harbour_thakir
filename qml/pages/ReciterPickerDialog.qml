import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: dialog

    readonly property bool isRtl: prayerManager.isArabicLanguage
    property string selectedReciterId: quranManager.selectedReciterId
    property string searchQuery: ""
    property var allReciters: []
    property bool filterOnlyFavorites: false
    property int sortMode: 0 // 0: Favorites First, 1: Alphabetical, 2: Default

    canAccept: true

    onAccepted: {
        if (selectedReciterId && selectedReciterId.length > 0) {
            quranManager.setReciter(selectedReciterId)
        }
    }

    Component.onCompleted: {
        refreshReciters()
    }

    onSearchQueryChanged: filterList()
    onFilterOnlyFavoritesChanged: filterList()
    onSortModeChanged: filterList()

    Connections {
        target: quranManager
        onFavoriteRecitersChanged: dialog.filterList()
    }

    function refreshReciters() {
        allReciters = quranManager.getAvailableReciters()
        filterList()
    }

    function filterList() {
        recitersModel.clear()
        var list = allReciters
        if (!list || list.length === 0) {
            list = quranManager.getAvailableReciters()
            allReciters = list
        }
        var query = searchQuery.trim().toLowerCase()
        var candidates = []
        for (var i = 0; i < list.length; ++i) {
            var r = list[i]
            var nameAr = r.name_ar || ""
            var nameEn = r.name_en || ""
            var rId = r.id || ""
            var isFav = quranManager.isReciterFavorite(rId)

            if (filterOnlyFavorites && !isFav) {
                continue
            }

            if (!query || nameAr.toLowerCase().indexOf(query) !== -1 || nameEn.toLowerCase().indexOf(query) !== -1) {
                candidates.push({
                    reciterId: rId,
                    nameAr: nameAr,
                    nameEn: nameEn,
                    isFavorite: isFav,
                    originalIndex: i
                })
            }
        }

        candidates.sort(function(a, b) {
            if (sortMode === 0) {
                // Favorites first, then original order
                if (a.isFavorite !== b.isFavorite) {
                    return a.isFavorite ? -1 : 1
                }
                return a.originalIndex - b.originalIndex
            } else if (sortMode === 1) {
                // Alphabetical (A-Z)
                var strA = isRtl ? a.nameAr : (a.nameEn || a.nameAr)
                var strB = isRtl ? b.nameAr : (b.nameEn || b.nameAr)
                return strA.localeCompare(strB, isRtl ? "ar" : "en")
            } else {
                // Default
                return a.originalIndex - b.originalIndex
            }
        })

        for (var j = 0; j < candidates.length; ++j) {
            recitersModel.append(candidates[j])
        }
    }

    ListModel {
        id: recitersModel
    }

    SilicaListView {
        id: listView
        anchors.fill: parent

        PullDownMenu {
            MenuItem {
                text: dialog.filterOnlyFavorites
                      ? (isRtl ? "عرض: جميع القراء" : qsTr("Show: All Reciters"))
                      : (isRtl ? "عرض: المفضلة فقط ★" : qsTr("Show: Favorites Only ★"))
                onClicked: dialog.filterOnlyFavorites = !dialog.filterOnlyFavorites
            }

            MenuItem {
                text: isRtl ? "ترتيب: المفضلة أولاً ★" : qsTr("Sort: Favorites First ★")
                onClicked: dialog.sortMode = 0
            }

            MenuItem {
                text: isRtl ? "ترتيب: أبجدياً (أ - ي)" : qsTr("Sort: Alphabetical (A-Z)")
                onClicked: dialog.sortMode = 1
            }

            MenuItem {
                text: isRtl ? "ترتيب: الترتيب الافتراضي" : qsTr("Sort: Default Order")
                onClicked: dialog.sortMode = 2
            }
        }

        header: Column {
            width: parent.width
            spacing: Theme.paddingSmall

            DialogHeader {
                title: isRtl
                       ? ("اختر القارئ (" + quranManager.riwayahName + ")")
                       : qsTr("Select Reciter (%1)").arg(quranManager.riwayahName)
                acceptText: isRtl ? "تأكيد" : qsTr("Confirm")
                cancelText: isRtl ? "إلغاء" : qsTr("Cancel")
            }

            SearchField {
                id: searchField
                width: parent.width
                placeholderText: isRtl ? "بحث عن قارئ..." : qsTr("Search reciter...")
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
                onTextChanged: dialog.searchQuery = text
            }

            // Filter Tabs & Sort Controls
            Row {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingSmall

                Button {
                    preferredWidth: Math.floor((parent.width - 2 * Theme.paddingSmall) * 0.33)
                    text: isRtl ? ("الكل (" + prayerManager.formatDigits(allReciters.length.toString()) + ")")
                                : qsTr("All (%1)").arg(prayerManager.formatDigits(allReciters.length.toString()))
                    color: !dialog.filterOnlyFavorites ? Theme.highlightColor : Theme.secondaryColor
                    onClicked: dialog.filterOnlyFavorites = false
                }

                Button {
                    preferredWidth: Math.floor((parent.width - 2 * Theme.paddingSmall) * 0.35)
                    text: {
                        var _dummy = quranManager.favoriteReciters
                        var favCount = 0
                        for (var f = 0; f < allReciters.length; ++f) {
                            if (quranManager.isReciterFavorite(allReciters[f].id)) favCount++
                        }
                        var favFormatted = prayerManager.formatDigits(favCount.toString())
                        return isRtl ? ("★ المفضلة (" + favFormatted + ")")
                                     : qsTr("★ Favs (%1)").arg(favFormatted)
                    }
                    color: dialog.filterOnlyFavorites ? Theme.highlightColor : Theme.secondaryColor
                    onClicked: dialog.filterOnlyFavorites = true
                }

                Button {
                    preferredWidth: parent.width - 2 * Theme.paddingSmall - Math.floor((parent.width - 2 * Theme.paddingSmall) * 0.33) - Math.floor((parent.width - 2 * Theme.paddingSmall) * 0.35)
                    text: {
                        if (dialog.sortMode === 0) return isRtl ? "★ أولاً" : "★ First"
                        if (dialog.sortMode === 1) return isRtl ? "أ - ي" : "A - Z"
                        return isRtl ? "افتراضي" : "Default"
                    }
                    color: Theme.highlightColor
                    onClicked: dialog.sortMode = (dialog.sortMode + 1) % 3
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: Theme.fontSizeTiny
                color: Theme.secondaryColor
                text: {
                    var sName = dialog.sortMode === 0
                                ? (isRtl ? "المفضلة أولاً" : "Favorites First")
                                : (dialog.sortMode === 1
                                   ? (isRtl ? "أبجدياً (أ - ي)" : "Alphabetical")
                                   : (isRtl ? "الترتيب الافتراضي" : "Default Order"))
                    var fName = dialog.filterOnlyFavorites
                                ? (isRtl ? "المفضلة فقط" : "Favorites only")
                                : (isRtl ? "جميع القراء" : "All reciters")
                    return isRtl ? ("العرض: " + fName + "   •   الترتيب: " + sName)
                                 : qsTr("View: %1   •   Sort: %2").arg(fName).arg(sName)
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingSmall
            }
        }

        model: recitersModel

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeMedium

            readonly property bool isCurrent: reciterId === dialog.selectedReciterId
            readonly property bool isFav: isFavorite

            highlighted: isCurrent || down

            Icon {
                id: speakerIcon
                anchors {
                    left: isRtl ? undefined : parent.left
                    right: isRtl ? parent.right : undefined
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                source: "image://theme/icon-m-speaker"
                color: item.isCurrent ? Theme.highlightColor : Theme.primaryColor
                opacity: item.isCurrent ? 1.0 : 0.35
            }

            Row {
                id: actionRow
                anchors {
                    left: isRtl ? parent.left : undefined
                    right: isRtl ? undefined : parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingSmall

                Icon {
                    id: checkIcon
                    source: "image://theme/icon-m-accept"
                    color: Theme.highlightColor
                    visible: item.isCurrent
                    anchors.verticalCenter: parent.verticalCenter
                }

                IconButton {
                    id: favBtn
                    icon.source: item.isFav ? "image://theme/icon-m-favorite-selected" : "image://theme/icon-m-favorite"
                    icon.color: item.isFav ? "#FFB300" : Theme.rgba(Theme.primaryColor, 0.4)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        quranManager.toggleReciterFavorite(reciterId)
                    }
                }
            }

            Column {
                anchors {
                    left: isRtl ? actionRow.right : speakerIcon.right
                    right: isRtl ? speakerIcon.left : actionRow.left
                    leftMargin: Theme.paddingMedium
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }

                Label {
                    width: parent.width
                    text: isRtl ? nameAr : (nameEn.length > 0 ? nameEn : nameAr)
                    color: item.isCurrent ? Theme.highlightColor : Theme.primaryColor
                    font.bold: item.isCurrent || item.isFav
                    truncationMode: TruncationMode.Fade
                    horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                }

                Label {
                    width: parent.width
                    visible: isRtl && nameEn.length > 0 && nameEn !== nameAr
                    text: nameEn
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                    horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                }
            }

            onClicked: {
                dialog.selectedReciterId = reciterId
                quranManager.setReciter(reciterId)
                dialog.accept()
            }
        }

        ViewPlaceholder {
            enabled: recitersModel.count === 0
            text: dialog.filterOnlyFavorites
                  ? (isRtl ? "لا يوجد قراء في المفضلة" : qsTr("No favorite reciters"))
                  : (isRtl ? "لم يتم العثور على أي قارئ" : qsTr("No reciters found"))
            hintText: dialog.filterOnlyFavorites
                      ? (isRtl ? "اضغط على رمز النجمة ★ بجانب أي قارئ لإضافته إلى المفضلة" : qsTr("Tap the ★ star icon next to any reciter to add them to favorites"))
                      : (isRtl ? "جرب البحث باسم آخر" : qsTr("Try a different search query"))
        }

        VerticalScrollDecorator {}
    }
}
