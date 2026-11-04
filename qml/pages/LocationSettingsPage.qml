import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "locationSettingsPage"

    function formatDigits(str) {
        var _ = prayerManager.useHindiNumerals
        return prayerManager.formatDigits(str)
    }

    Connections {
        target: prayerManager
        onMethodChanged: methodCombo.currentIndex = prayerManager.method
        onMadhabChanged: madhabCombo.currentIndex = prayerManager.madhab
        onHighLatitudeRuleChanged: hlRuleCombo.currentIndex = prayerManager.highLatitudeRule
        onDaylightSavingChanged: dstCombo.currentIndex = prayerManager.daylightSaving
        onAppLanguageChanged: languageCombo.currentIndex = languageCombo.langToIndex(prayerManager.appLanguage)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: page.width

            PageHeader { title: qsTr("Location Settings") }

            SectionHeader { text: qsTr("Location") }

            ValueButton {
                label: qsTr("Location")
                value: prayerManager.hasCity ? (prayerManager.cityName + (prayerManager.countryName ? (", " + prayerManager.countryName) : "")) : qsTr("Find a city")
                onClicked: pageStack.push(Qt.resolvedUrl("CitySearchPage.qml"))
            }

            ButtonLayout {
                width: parent.width

                Button {
                    text: qsTr("Change city")
                    onClicked: pageStack.push(Qt.resolvedUrl("CitySearchPage.qml"))
                }

                Button {
                    text: qsTr("Pick on map instead")
                    onClicked: pageStack.push(Qt.resolvedUrl("CityMapPage.qml"))
                }
            }

            SectionHeader { text: prayerManager.isArabicLanguage ? "التوقيت الصيفي" : qsTr("Daylight saving time") }

            ComboBox {
                id: dstCombo
                label: prayerManager.isArabicLanguage ? "التوقيت الصيفي" : qsTr("Daylight saving time")
                description: prayerManager.daylightSavingDescription
                width: parent.width
                currentIndex: prayerManager.daylightSaving
                menu: ContextMenu {
                    MenuItem { text: prayerManager.isArabicLanguage ? "تلقائي (بحسب الدولة والمدينة)" : qsTr("Automatic (by country & city)") }
                    MenuItem { text: prayerManager.isArabicLanguage ? "معطّل (التوقيت القياسي)" : qsTr("Disabled (Standard time)") }
                    MenuItem { text: prayerManager.isArabicLanguage ? prayerManager.formatDigits("مفعّل (+1 ساعة)") : qsTr("Enabled (+1 hour)") }
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex <= 2) {
                        prayerManager.daylightSaving = currentIndex
                    }
                }
            }

            SectionHeader { text: qsTr("Calculation method") }

            ComboBox {
                id: methodCombo
                label: qsTr("Calculation method")
                width: parent.width
                currentIndex: prayerManager.method
                menu: ContextMenu {
                    MenuItem { text: qsTr("Muslim World League") }
                    MenuItem { text: qsTr("Islamic Society of North America") }
                    MenuItem { text: qsTr("Egyptian General Authority") }
                    MenuItem { text: qsTr("Umm al-Qura, Makkah") }
                    MenuItem { text: qsTr("University of Islamic Sciences, Karachi") }
                    MenuItem { text: qsTr("Institute of Geophysics, Tehran") }
                    MenuItem { text: qsTr("Prayer Times for High Latitudes") }
                    MenuItem { text: qsTr("Ministry of Habous and Islamic Affairs, Morocco") }
                    MenuItem { text: qsTr("Fixed Isha Angle Interval") }
                    MenuItem { text: qsTr("Egyptian General Authority of Survey NEW") }
                    MenuItem { text: qsTr("Umm Al-Qura University, RAMADAN") }
                    MenuItem { text: qsTr("MOONSIGHTING_COMMITTEE") }
                    MenuItem { text: qsTr("FRANCE_UOIF") }
                    MenuItem { text: qsTr("MALAYSIA_JAKIM") }
                    MenuItem { text: qsTr("TURKEY_FAZILET") }
                    MenuItem { text: qsTr("TURKEY_TPRA") }
                    MenuItem { text: qsTr("TURKEY_DIYANET") }
                    MenuItem { text: qsTr("ENGLAND_BIRMINGHAM") }
                    MenuItem { text: qsTr("JORDAN_MAIAHPJ") }
                    MenuItem { text: qsTr("ALGERIA_MARWDZ") }
                    MenuItem { text: qsTr("TUNISIA_MAIAMTU") }
                    MenuItem { text: qsTr("OMAN_MARAOM") }
                    MenuItem { text: qsTr("KUWAIT_MARAKU") }
                    MenuItem { text: qsTr("LIBYA_MARALI") }
                    MenuItem { text: qsTr("QATAR_TAQWMQAT") }
                }
                onCurrentIndexChanged: prayerManager.method = currentIndex
            }

            ComboBox {
                id: hlRuleCombo
                label: qsTr("High latitude rule")
                description: qsTr("Rule used to adjust Fajr and Isha at high latitudes when twilight persists through the night.")
                width: parent.width
                visible: prayerManager.method === 6
                currentIndex: prayerManager.highLatitudeRule
                menu: ContextMenu {
                    MenuItem { text: qsTr("None") }
                    MenuItem { text: qsTr("Angle-based / Proportional (Recommended)") }
                    MenuItem { text: formatDigits(qsTr("Middle of the night (1/2)")) }
                    MenuItem { text: formatDigits(qsTr("One-seventh of the night (1/7)")) }
                }
                onCurrentIndexChanged: prayerManager.highLatitudeRule = currentIndex
            }

            ComboBox {
                id: madhabCombo
                label: qsTr("Asr calculation (madhab)")
                width: parent.width
                currentIndex: prayerManager.madhab
                menu: ContextMenu {
                    MenuItem { text: qsTr("Shafi’i / Maliki / Hanbali") }
                    MenuItem { text: qsTr("Hanafi") }
                }
                onCurrentIndexChanged: prayerManager.madhab = currentIndex
            }

            SectionHeader { text: qsTr("General") }

            ComboBox {
                id: languageCombo
                label: qsTr("Language")
                description: qsTr("Choose the application language, or follow the device system language.")
                width: parent.width

                function langToIndex(l) {
                    if (l === "ar") return 1
                    if (l === "fr") return 2
                    if (l === "tr") return 3
                    if (l === "en") return 4
                    return 0
                }

                currentIndex: langToIndex(prayerManager.appLanguage)

                menu: ContextMenu {
                    MenuItem { text: qsTr("Follow system") }
                    MenuItem { text: "العربية (Arabic)" }
                    MenuItem { text: "Français (French)" }
                    MenuItem { text: "Türkçe (Turkish)" }
                    MenuItem { text: "English" }
                }

                onCurrentIndexChanged: {
                    var langs = ["", "ar", "fr", "tr", "en"]
                    if (currentIndex >= 0 && currentIndex < langs.length) {
                        var selected = langs[currentIndex]
                        if (prayerManager.appLanguage !== selected) {
                            prayerManager.appLanguage = selected
                        }
                    }
                }
            }

            ComboBox {
                id: numberFormatCombo
                label: qsTr("Number format")
                description: qsTr("Choose between Arabic numerals (0, 1, 2...) and Hindi numerals (٠، ١، ٢...).")
                width: parent.width
                visible: prayerManager.isArabicLanguage
                currentIndex: prayerManager.useHindiNumerals ? 1 : 0
                menu: ContextMenu {
                    MenuItem { text: qsTr("Arabic numerals (0, 1, 2...)") }
                    MenuItem { text: qsTr("Hindi numerals (٠، ١، ٢...)") }
                }
                onCurrentIndexChanged: {
                    prayerManager.useHindiNumerals = (currentIndex === 1)
                }
                Binding {
                    target: numberFormatCombo
                    property: "currentIndex"
                    value: prayerManager.useHindiNumerals ? 1 : 0
                }
            }

            ComboBox {
                id: homeLayoutCombo
                label: qsTr("Home page layout")
                width: parent.width
                currentIndex: prayerManager.homeLayout
                menu: ContextMenu {
                    MenuItem { text: formatDigits(qsTr("All-in-One 3-Column")) }
                    MenuItem { text: formatDigits(qsTr("Classic 3-Column")) }
                    MenuItem { text: formatDigits(qsTr("2-Column Grid")) }
                    MenuItem { text: qsTr("Hero & List") }
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex <= 3) {
                        prayerManager.homeLayout = currentIndex
                    }
                }
            }

            SectionHeader { text: qsTr("Compass calibration") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: formatDigits(qsTr("Fine-tune the compass heading offset (±30°) to correct for local magnetic declination or device sensor bias."))
            }

            Slider {
                width: parent.width
                minimumValue: -30
                maximumValue: 30
                stepSize: 1
                value: prayerManager.compassCalibration
                label: qsTr("Heading offset")
                valueText: (value > 0 ? "+" : "") + formatDigits(Math.round(value).toString()) + "\u00B0"
                onSliderValueChanged: {
                    prayerManager.compassCalibration = Math.round(value)
                }
            }
        }
    }
}
