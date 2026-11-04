import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "aboutPage"

    readonly property bool isRtl: prayerManager.isArabicLanguage

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: page.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("About")
            }

            Item {
                width: parent.width
                height: Theme.paddingMedium
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: Qt.resolvedUrl("../icons/harbour-thakir.png")
                width: Theme.iconSizeExtraLarge
                height: Theme.iconSizeExtraLarge
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (prayerManager.appLanguage, qsTr("Thakir Athan"))
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                color: Theme.highlightColor
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: isRtl
                      ? "مواقيت الصلاة، الأذان، والمصحف الشريف لنظام سيلفيش"
                      : qsTr("Islamic prayer times, athan reminders and Holy Quran for Sailfish OS")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                width: parent.width
                height: Theme.paddingMedium
            }

            // ============================================================
            // APPLICATION INFORMATION
            // ============================================================
            SectionHeader {
                text: qsTr("Application information")
            }

            DetailItem {
                label: qsTr("Developer")
                value: qsTr("Mohamed HAFIANE")
            }

            ValueButton {
                width: parent.width
                label: qsTr("E-mail for feedback")
                value: "thakir.dz@gmail.com"
                description: qsTr("Tap to send an email")
                onClicked: {
                    var subject = "Thakir Athan (" + prayerManager.appVersion + ") on Sailfish OS"
                    if (prayerManager.osVersion.length > 0) {
                        subject += " " + prayerManager.osVersion
                    }
                    Qt.openUrlExternally("mailto:thakir.dz@gmail.com?subject=" + encodeURIComponent(subject))
                }
            }

            DetailItem {
                label: qsTr("Version")
                value: prayerManager.formatDigits(prayerManager.appVersion)
            }

            DetailItem {
                visible: prayerManager.osVersion.length > 0
                label: qsTr("Sailfish OS")
                value: prayerManager.formatDigits(prayerManager.osVersion)
            }

            DetailItem {
                label: qsTr("Date")
                value: prayerManager.buildDate
            }

            // ============================================================
            // 1. QURAN PAGES & MUSHAF SOURCES
            // ============================================================
            SectionHeader {
                text: isRtl ? "مصادر صفحات المصحف الشريف" : qsTr("Quran Pages & Mushaf Sources")
            }

            Repeater {
                model: [
                    {
                        title_ar: "مجمع الملك فهد لطباعة المصحف الشريف",
                        title_en: "King Fahd Glorious Quran Printing Complex (KFGQPC)",
                        desc_ar: "صفحات ورسوم مصحف المدينة النبوية بروايتي حفص وورش",
                        desc_en: "Official high-resolution Madinah Mushaf scans (Hafs & Warsh)",
                        url: "https://qurancomplex.gov.sa"
                    },
                    {
                        title_ar: "مشروع Quran.com",
                        title_en: "Quran.com Platform & API",
                        desc_ar: "واجهة برمجة تطبيقات صفحات وآيات القرآن الكريم عالية الدقة",
                        desc_en: "High-resolution Quran page imagery and metadata API",
                        url: "https://quran.com"
                    },
                    {
                        title_ar: "منصة قرآن بيديا (Quranpedia)",
                        title_en: "Quranpedia Platform",
                        desc_ar: "مرجع تدقيق ومطابقة ترتيب صفحات المصحف وتنسيقات النص",
                        desc_en: "Mushaf page layouts, indexing and text formatting reference",
                        url: "https://quranpedia.net"
                    }
                ]

                delegate: BackgroundItem {
                    width: parent.width
                    height: pSourceCol.height + Theme.paddingMedium * 2
                    onClicked: Qt.openUrlExternally(modelData.url)

                    Row {
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.centerIn: parent
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: Theme.paddingMedium

                        Icon {
                            source: "image://theme/icon-m-link"
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.highlightColor
                        }

                        Column {
                            id: pSourceCol
                            width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Label {
                                width: parent.width
                                text: isRtl ? modelData.title_ar : modelData.title_en
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: Theme.primaryColor
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: isRtl ? modelData.desc_ar : modelData.desc_en
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: modelData.url
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.highlightColor
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }
                }
            }

            // ============================================================
            // 2. AUDIO RECITATIONS SOURCES
            // ============================================================
            SectionHeader {
                text: isRtl ? "مصادر التلاوات الصوتية" : qsTr("Audio & Recitations Sources")
            }

            Repeater {
                model: [
                    {
                        title_ar: "مشروع EveryAyah",
                        title_en: "EveryAyah Project",
                        desc_ar: "مستودع التلاوات الصوتية المفتوحة آية بآية لكبار القراء",
                        desc_en: "Open-source verse-by-verse recitation audio repository",
                        url: "https://everyayah.com"
                    },
                    {
                        title_ar: "شبكة Quran.com الصوتية (CDN)",
                        title_en: "Quran.com Audio CDN",
                        desc_ar: "خدمة بث تلاوات السور والآيات عالية النقاوة",
                        desc_en: "High-quality audio streaming CDN for renowned reciters",
                        url: "https://audio.quran.com"
                    }
                ]

                delegate: BackgroundItem {
                    width: parent.width
                    height: aSourceCol.height + Theme.paddingMedium * 2
                    onClicked: Qt.openUrlExternally(modelData.url)

                    Row {
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.centerIn: parent
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: Theme.paddingMedium

                        Icon {
                            source: "image://theme/icon-m-link"
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.highlightColor
                        }

                        Column {
                            id: aSourceCol
                            width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Label {
                                width: parent.width
                                text: isRtl ? modelData.title_ar : modelData.title_en
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: Theme.primaryColor
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: isRtl ? modelData.desc_ar : modelData.desc_en
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: modelData.url
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.highlightColor
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }
                }
            }

            // ============================================================
            // 3. QURANIC FONTS & CALLIGRAPHY
            // ============================================================
            SectionHeader {
                text: isRtl ? "الخطوط القرآنية" : qsTr("Quranic Fonts & Calligraphy")
            }

            Repeater {
                model: [
                    {
                        title_ar: "خط عثمان طه النسخي (مجمع الملك فهد)",
                        title_en: "KFGQPC Uthman Taha Naskh Font",
                        desc_ar: "الخط الرقمي المعتمد للرسم العثماني لمصحف المدينة النبوية",
                        desc_en: "Official digital Uthmanic Naskh typeface from KFGQPC",
                        url: "https://qurancomplex.gov.sa"
                    },
                    {
                        title_ar: "خط أميري القرآني (Amiri Quran Font)",
                        title_en: "Amiri Quran Typeface",
                        desc_ar: "خط نسخي كلاسيكي رقمي مخصص لطباعة المصحف الشريف (خالد حسني)",
                        desc_en: "Classical digital Naskh typeface for Quran printing by Khaled Hosny",
                        url: "https://www.amirifont.org"
                    }
                ]

                delegate: BackgroundItem {
                    width: parent.width
                    height: fSourceCol.height + Theme.paddingMedium * 2
                    onClicked: Qt.openUrlExternally(modelData.url)

                    Row {
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.centerIn: parent
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: Theme.paddingMedium

                        Icon {
                            source: "image://theme/icon-m-link"
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.highlightColor
                        }

                        Column {
                            id: fSourceCol
                            width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Label {
                                width: parent.width
                                text: isRtl ? modelData.title_ar : modelData.title_en
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: Theme.primaryColor
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: isRtl ? modelData.desc_ar : modelData.desc_en
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: modelData.url
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.highlightColor
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }
                }
            }

            // ============================================================
            // 4. TAFSIR, TRANSLATIONS & CALCULATIONS
            // ============================================================
            SectionHeader {
                text: isRtl ? "التفاسير والترجمات وحساب المواقيت" : qsTr("Tafsir, Translations & Calculations")
            }

            Repeater {
                model: [
                    {
                        title_ar: "مشروع تنزيل (Tanzil Project)",
                        title_en: "Tanzil Project",
                        desc_ar: "النصوص القرآنية المعتمدة ومصادر التفاسير والترجمات الدولية",
                        desc_en: "Verified Quranic text, international translations and tafsir database",
                        url: "https://tanzil.net"
                    },
                    {
                        title_ar: "خوارزمية حساب مواقيت الصلاة (PrayTimes)",
                        title_en: "PrayTimes.org Calculation Algorithm",
                        desc_ar: "الحسابات الفلكية المعتمدة لمواقيت الصلاة واتجاه القبلة",
                        desc_en: "Astronomical algorithms for worldwide prayer times and Qibla direction",
                        url: "http://praytimes.org"
                    }
                ]

                delegate: BackgroundItem {
                    width: parent.width
                    height: tSourceCol.height + Theme.paddingMedium * 2
                    onClicked: Qt.openUrlExternally(modelData.url)

                    Row {
                        width: parent.width - 2 * Theme.horizontalPageMargin
                        anchors.centerIn: parent
                        layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: Theme.paddingMedium

                        Icon {
                            source: "image://theme/icon-m-link"
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.highlightColor
                        }

                        Column {
                            id: tSourceCol
                            width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Label {
                                width: parent.width
                                text: isRtl ? modelData.title_ar : modelData.title_en
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: Theme.primaryColor
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: isRtl ? modelData.desc_ar : modelData.desc_en
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.secondaryColor
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: modelData.url
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.highlightColor
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }
                }
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }
        }
    }
}
