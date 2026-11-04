import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "appearancePage"

    readonly property bool isRtl: Qt.application.layoutDirection === Qt.RightToLeft || prayerManager.isArabicLanguage

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentCol.height + Theme.paddingLarge

        VerticalScrollDecorator {}

        Column {
            id: contentCol
            width: page.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: isRtl ? "المظهر والخلفية" : qsTr("Appearance & Background")
            }

            SectionHeader {
                text: isRtl ? "خلفيات إسلامية فكتور (SVG) ولوحات فنية" : qsTr("Islamic Vector (SVG) & Art Backgrounds")
            }

            Column {
                width: parent.width - 2 * Theme.horizontalPageMargin
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingMedium

                Repeater {
                    model: [
                        {
                            idx: 1,
                            name: isRtl ? "غروب المسجد والمئذنة (فكتور SVG)" : qsTr("Mosque Sunset & Minaret (SVG)"),
                            desc: isRtl ? "شمس الغروب الدافئة مع ظلال مئذنة وقبة المسجد وأشجار" : qsTr("Warm golden sunset with minaret, dome silhouette & glowing sun"),
                            tag: "SVG",
                            image: "../Images/bg_mosque_sunset.svg"
                        },
                        {
                            idx: 2,
                            name: isRtl ? "غروب المسجد (صورة عالية الدقة)" : qsTr("Mosque Sunset (Photo HD)"),
                            desc: isRtl ? "صورة فوتوغرافية رائعة لغروب الشمس خلف المئذنة والقبة" : qsTr("Atmospheric photograph of sunset behind minaret & dome"),
                            tag: "HD",
                            image: "../Images/bg_mosque_sunset.jpg"
                        },
                        {
                            idx: 3,
                            name: isRtl ? "مآذن المسجد النبوي الشريف (صورة HD)" : qsTr("Prophet's Mosque Minarets (Photo HD)"),
                            desc: isRtl ? "مآذن وقباب المسجد النبوي الشريف بإضاءة ليلية مهيبة" : qsTr("Majestic illuminated minarets & domes of Al-Masjid an-Nabawi"),
                            tag: "HD",
                            image: "../Images/bg_minarets_nabawi.jpg"
                        },
                        {
                            idx: 4,
                            name: isRtl ? "قبة ذهبية ونخيل (صورة HD)" : qsTr("Golden Dome & Palm (Photo HD)"),
                            desc: isRtl ? "قبة مسجد ذهبية متألقة وسعف النخيل في سماء زرقاء" : qsTr("Gleaming golden mosque dome and palm tree against blue sky"),
                            tag: "HD",
                            image: "../Images/bg_golden_dome_palm.jpg"
                        },
                        {
                            idx: 5,
                            name: isRtl ? "المسجد العثماني والمآذن (صورة HD)" : qsTr("Ottoman Mosque & Minarets (Photo HD)"),
                            desc: isRtl ? "طراز معماري عثماني عريق بمآذن قلمية رشيقة وقباب متدرجة" : qsTr("Historic Ottoman style mosque with slender minarets & domes"),
                            tag: "HD",
                            image: "../Images/bg_ottoman_minarets.jpg"
                        },
                        {
                            idx: 6,
                            name: isRtl ? "مسجد الشفق وسحر الغروب (صورة HD)" : qsTr("Twilight Mosque & Palms (Photo HD)"),
                            desc: isRtl ? "ألوان الشفق البنفسجية والوردية الساحرة مع ظلال القباب والنخيل" : qsTr("Vibrant purple and pink twilight sky with mosque and palms"),
                            tag: "HD",
                            image: "../Images/bg_twilight_mosque.jpg"
                        },
                        {
                            idx: 7,
                            name: isRtl ? "مسجد النور الليلي وهلال (صورة HD)" : qsTr("Glowing Night Mosque (Photo HD)"),
                            desc: isRtl ? "إضاءة ليلية دافئة تعكس بهاء المسجد وقبابه مع هلال مضيء" : qsTr("Warm luminous night mosque with radiant crescent and domes"),
                            tag: "HD",
                            image: "../Images/bg_night_illuminated_mosque.jpg"
                        },
                        {
                            idx: 8,
                            name: isRtl ? ("نجمة " + prayerManager.formatDigits("8") + " إسلامية (فكتور SVG)") : qsTr("8-Star Girih Lattice (SVG)"),
                            desc: isRtl ? "زخرفة هندسية إسلامية ثمانية بنقوش ذهبية نقية" : qsTr("Authentic 8-pointed star Islamic girih vector"),
                            tag: "SVG",
                            image: "../Images/bg_islamic_star_8.svg"
                        },
                        {
                            idx: 9,
                            name: isRtl ? "محراب الصلاة وفانوس (فكتور SVG)" : qsTr("Mihrab Arch & Lantern (SVG)"),
                            desc: isRtl ? "محراب مسجد زمردي مع فانوس رمضاني مضيء" : qsTr("Mosque mihrab arch with glowing hanging lantern"),
                            tag: "SVG",
                            image: "../Images/bg_islamic_mihrab_arch.svg"
                        },
                        {
                            idx: 10,
                            name: isRtl ? ("أرابيسك أندلسي " + prayerManager.formatDigits("12") + " (فكتور SVG)") : qsTr("Andalusian 12-Star Rosette (SVG)"),
                            desc: isRtl ? "طراز قصر الحمراء الأندلسي بنجوم اثنا عشرية" : qsTr("Alhambra Moorish 12-pointed star rosettes"),
                            tag: "SVG",
                            image: "../Images/bg_islamic_andalusian_12.svg"
                        },
                        {
                            idx: 11,
                            name: isRtl ? "هلال ومساجد ليلية (فكتور SVG)" : qsTr("Crescent Moon & Mosque (SVG)"),
                            desc: isRtl ? "قباب ومآذن مساجد مع هلال إسلامي مضيء وسماء منقوشة" : qsTr("Mosque skyline, domes and crescent moon with celestial lattice"),
                            tag: "SVG",
                            image: "../Images/bg_islamic_crescent_mosque.svg"
                        },
                        {
                            idx: 12,
                            name: isRtl ? "الأزرق الليلي الفاخر (صورة)" : qsTr("Midnight Teal Girih (Art)"),
                            desc: isRtl ? "لوحة فنية داكنة بتدرج أزرق مخضر ونقوش ذهبية" : qsTr("Atmospheric midnight teal with gold filigree"),
                            tag: "ART",
                            image: "../Images/bg_geometric_1.jpg"
                        },
                        {
                            idx: 13,
                            name: isRtl ? "محراب التراث الملكي (صورة)" : qsTr("Royal Mihrab Arch (Art)"),
                            desc: isRtl ? "محراب مزخرف بنقوش نباتية دمشقية ذهبية" : qsTr("Antique gold Damascus floral arabesque arch"),
                            tag: "ART",
                            image: "../Images/bg_geometric_2.jpg"
                        },
                        {
                            idx: 14,
                            name: isRtl ? "أرابيسك أزرق ملكي (صورة)" : qsTr("Arabesque Tessellation (Art)"),
                            desc: isRtl ? "تكرار هندسي متناسق بنقوش ذهبية هادئة" : qsTr("Clean geometric star polygons on ocean blue"),
                            tag: "ART",
                            image: "../Images/bg_geometric_3.jpg"
                        },
                        {
                            idx: 15,
                            name: isRtl ? "الفن الإسلامي المتناسق للواجهة (فكتور SVG)" : qsTr("Harmonious Home Islamic Art (SVG)"),
                            desc: isRtl ? "تصميم فكتور خاص متناسق مع عناصر الواجهة: قوس أندلسي ومصباح مذهب بالأعلى، مئذنتان تؤطران الجوانب، شمسة هندسية، وقبة المسجد بالأسفل" : qsTr("Custom vector tailored to home layout: top Moorish arch with lantern, framing side minarets, subtle central girih, and bottom mosque dome"),
                            tag: "SVG",
                            image: "../Images/bg_islamic_art_layout.svg"
                        },
                        {
                            idx: 16,
                            name: isRtl ? "سجادة المسجد الزمردية (فكتور SVG)" : qsTr("Mosque Carpet Emerald (SVG)"),
                            desc: isRtl ? "تصميم فكتور مستوحى من سجادة صلاة المسجد: شريط الصف العاجي، أزهار بقلب ياقوتي، وإطارات متناسقة مع واجهة التطبيق" : qsTr("Vector inspired by mosque prayer carpet: ivory cartouche row bands, ruby-centered floral medallions, and layout-aligned borders"),
                            tag: "SVG",
                            image: "../Images/bg_mosque_carpet.svg"
                        },
                        {
                            idx: 17,
                            name: isRtl ? "جامع الجزائر الأعظم (صورة HD)" : qsTr("Great Mosque of Algiers (Photo HD)"),
                            desc: isRtl ? "صرح جامع الجزائر الأعظم بمئذنته الشاهقة وقبته الكبرى وإطلالته على خليج الجزائر (افتراضي للجزائر)" : qsTr("Djamaa el Djazaïr with its iconic soaring minaret and grand dome overlooking the Bay of Algiers (Default for Algeria)"),
                            tag: "HD",
                            image: "../Images/bg_djamaa_el_djazair.jpg"
                        },
                        {
                            idx: 0,
                            name: isRtl ? "بدون خلفية (النمط الافتراضي)" : qsTr("None (Default Ambiance)"),
                            desc: isRtl ? "استخدام لون نظام سيلفيش الافتراضي" : qsTr("Use standard Sailfish OS system ambiance"),
                            tag: "",
                            image: ""
                        }
                    ]

                    delegate: BackgroundItem {
                        id: bgChoiceItem
                        width: parent.width
                        height: Theme.itemSizeMedium * 1.15
                        highlighted: down || isSelected
                        property bool isSelected: prayerManager.backgroundImage === modelData.idx

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.paddingSmall
                            color: isSelected ? Theme.rgba(Theme.highlightBackgroundColor, 0.20) : Theme.rgba(Theme.primaryColor, 0.05)
                            border.color: isSelected ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.25)
                            border.width: isSelected ? 2 : 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.paddingSmall
                                spacing: Theme.paddingMedium
                                layoutDirection: isRtl ? Qt.RightToLeft : Qt.LeftToRight

                                // Thumbnail preview
                                Rectangle {
                                    width: height * 0.65
                                    height: parent.height
                                    radius: Theme.paddingSmall / 2
                                    clip: true
                                    color: "#0a141e"
                                    border.color: isSelected ? Theme.highlightColor : Theme.rgba(Theme.secondaryColor, 0.3)
                                    border.width: 1

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.image.length > 0 ? Qt.resolvedUrl(modelData.image) : ""
                                        visible: modelData.image.length > 0
                                        sourceSize: Qt.size(width * 2, height * 2)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    Label {
                                        visible: modelData.image.length === 0
                                        anchors.centerIn: parent
                                        text: "✕"
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.secondaryColor
                                    }

                                    Rectangle {
                                        visible: modelData.tag && modelData.tag.length > 0
                                        anchors {
                                            top: parent.top
                                            right: parent.right
                                            margins: 2
                                        }
                                        width: 28
                                        height: 14
                                        radius: 2
                                        color: modelData.tag === "SVG" ? "#e0a93b" : (modelData.tag === "HD" ? "#4caf50" : Theme.rgba(Theme.highlightColor, 0.7))

                                        Label {
                                            anchors.centerIn: parent
                                            text: modelData.tag ? modelData.tag : ""
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: "#000000"
                                        }
                                    }
                                }

                                // Details
                                Column {
                                    width: parent.width - (parent.height * 0.65) - selectIcon.width - Theme.paddingMedium * 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Label {
                                        width: parent.width
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: isSelected
                                        color: isSelected ? Theme.highlightColor : Theme.primaryColor
                                        truncationMode: TruncationMode.Fade
                                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                    }

                                    Label {
                                        width: parent.width
                                        text: modelData.desc
                                        font.pixelSize: Theme.fontSizeExtraSmall
                                        color: Theme.secondaryColor
                                        truncationMode: TruncationMode.Fade
                                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                                    }
                                }

                                // Selection check icon
                                HighlightImage {
                                    id: selectIcon
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: isSelected ? "image://theme/icon-m-accept" : ""
                                    color: Theme.highlightColor
                                    width: Theme.iconSizeSmall
                                    height: Theme.iconSizeSmall
                                }
                            }
                        }

                        onClicked: {
                            prayerManager.backgroundImage = modelData.idx
                        }
                    }
                }
            }

            // Opacity slider (only visible if a background is selected)
            Column {
                width: parent.width
                visible: prayerManager.backgroundImage > 0
                spacing: Theme.paddingSmall

                SectionHeader {
                    text: isRtl ? "شفافية الخلفية" : qsTr("Background Opacity")
                }

                Slider {
                    width: parent.width
                    label: isRtl ? "درجة وضوح الخلفية" : qsTr("Opacity")
                    minimumValue: 0.10
                    maximumValue: 0.85
                    stepSize: 0.05
                    value: prayerManager.backgroundOpacity
                    valueText: prayerManager.formatDigits(Math.round(value * 100).toString()) + "%"
                    onValueChanged: {
                        prayerManager.backgroundOpacity = value
                    }
                }

                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                    text: isRtl
                          ? prayerManager.formatDigits("تلميح: درجة شفافية بين 25% و 45% تمنح مظهراً راقياً ومريحاً للعين دون التأثير على وضوح أوقات الصلاة.")
                          : qsTr("Tip: An opacity between 25% and 45% delivers a crisp luxury look while keeping all prayer texts perfectly readable.")
                }
            }

            // Quran Reader Display / Blanking settings
            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                SectionHeader {
                    text: isRtl ? "شاشة قراءة القرآن" : qsTr("Quran Reader Screen")
                }

                ComboBox {
                    width: parent.width
                    label: isRtl ? "إيقاف تشغيل الشاشة" : qsTr("Screen blanking")
                    description: isRtl
                                 ? "معطل: إبقاء الشاشة مضاءة أثناء تصفح وقراءة المصحف فقط (صفحات أو نص أو تجويد)"
                                 : qsTr("disabled: Keep screen awake only while reading Quran (pages, text, or tajweed)")
                    currentIndex: quranManager.screenBlankingDisabled ? 1 : 0
                    menu: ContextMenu {
                        MenuItem { text: isRtl ? "حسب النظام" : qsTr("system") }
                        MenuItem { text: isRtl ? "معطل" : qsTr("disabled") }
                    }
                    onCurrentIndexChanged: {
                        quranManager.screenBlankingDisabled = (currentIndex === 1)
                    }
                }
            }
        }
    }
}
