import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "silentModeSettingsPage"

    property int silentUpdateCounter: 0

    function prayerDisplayName(prayerKey) {
        var _ = prayerManager.appLanguage
        switch (prayerKey) {
        case "fajr": return qsTr("Fajr")
        case "sunrise": return qsTr("Chourouq")
        case "dhuhr": return qsTr("Dhouhr")
        case "asr": return qsTr("Assar")
        case "maghrib": return qsTr("Maghreb")
        case "isha": return qsTr("Ishaa")
        default: return prayerKey ? (prayerKey.charAt(0).toUpperCase() + prayerKey.slice(1)) : ""
        }
    }

    function formatDigits(str) {
        var _ = prayerManager.useHindiNumerals
        return prayerManager.formatDigits(str)
    }

    Connections {
        target: prayerManager
        onSilentSettingsChanged: silentUpdateCounter++
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: page.width

            PageHeader { title: qsTr("Silent Mode Settings") }

            SectionHeader { text: qsTr("Silent mode during prayer") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Automatically switch the phone to Silent for a while during prayer, then switch back. A beep confirms each switch.")
            }

            Repeater {
                model: ["fajr", "dhuhr", "asr", "maghrib", "isha"]
                delegate: Column {
                    width: page.width

                    TextSwitch {
                        width: parent.width
                        text: prayerDisplayName(modelData)
                        checked: {
                            var _ = silentUpdateCounter
                            return prayerManager.silentEnabled(modelData)
                        }
                        onCheckedChanged: {
                            if (checked !== prayerManager.silentEnabled(modelData)) {
                                prayerManager.setSilentEnabled(modelData, checked)
                            }
                        }
                    }

                    ComboBox {
                        width: parent.width
                        enabled: prayerManager.silentEnabled(modelData)
                        label: qsTr("Starts (minutes after athan)")
                        property var minuteValues: [0, 5, 10, 15, 20, 30]
                        currentIndex: {
                            var _ = silentUpdateCounter
                            var m = prayerManager.silentDelayMinutes(modelData)
                            var idx = minuteValues.indexOf(m)
                            return idx >= 0 ? idx : 2
                        }
                        menu: ContextMenu {
                            MenuItem { text: qsTr("Immediately") }
                            MenuItem { text: formatDigits(qsTr("5 minutes after")) }
                            MenuItem { text: formatDigits(qsTr("10 minutes after")) }
                            MenuItem { text: formatDigits(qsTr("15 minutes after")) }
                            MenuItem { text: formatDigits(qsTr("20 minutes after")) }
                            MenuItem { text: formatDigits(qsTr("30 minutes after")) }
                        }
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < minuteValues.length) {
                                prayerManager.setSilentDelayMinutes(modelData, minuteValues[currentIndex])
                            }
                        }
                    }

                    ComboBox {
                        width: parent.width
                        enabled: prayerManager.silentEnabled(modelData)
                        label: qsTr("Duration")
                        property var durationValues: [5, 10, 15, 20, 30, 45, 60]
                        currentIndex: {
                            var _ = silentUpdateCounter
                            var d = prayerManager.silentDurationMinutes(modelData)
                            var idx = durationValues.indexOf(d)
                            return idx >= 0 ? idx : 2
                        }
                        menu: ContextMenu {
                            MenuItem { text: formatDigits(qsTr("5 minutes")) }
                            MenuItem { text: formatDigits(qsTr("10 minutes")) }
                            MenuItem { text: formatDigits(qsTr("15 minutes")) }
                            MenuItem { text: formatDigits(qsTr("20 minutes")) }
                            MenuItem { text: formatDigits(qsTr("30 minutes")) }
                            MenuItem { text: formatDigits(qsTr("45 minutes")) }
                            MenuItem { text: formatDigits(qsTr("60 minutes")) }
                        }
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < durationValues.length) {
                                prayerManager.setSilentDurationMinutes(modelData, durationValues[currentIndex])
                            }
                        }
                    }
                }
            }

            SectionHeader { text: qsTr("Friday prayer silent mode") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Only on Fridays: automatically switch the phone to Silent before Friday athan and keep it silent after Friday athan.")
            }

            TextSwitch {
                width: page.width
                text: qsTr("Switch to silent before Friday athan")
                checked: prayerManager.fridaySilentEnabled
                onCheckedChanged: {
                    if (checked !== prayerManager.fridaySilentEnabled) {
                        prayerManager.setFridaySilentEnabled(checked)
                    }
                }
            }

            ComboBox {
                width: page.width
                enabled: prayerManager.fridaySilentEnabled
                label: qsTr("Starts before Friday prayer")
                property var beforeValues: [10, 15, 20, 30, 45, 60]
                currentIndex: {
                    var idx = beforeValues.indexOf(prayerManager.fridaySilentBeforeMinutes)
                    return idx >= 0 ? idx : 3
                }
                menu: ContextMenu {
                    MenuItem { text: formatDigits(qsTr("10 minutes before")) }
                    MenuItem { text: formatDigits(qsTr("15 minutes before")) }
                    MenuItem { text: formatDigits(qsTr("20 minutes before")) }
                    MenuItem { text: formatDigits(qsTr("30 minutes before")) }
                    MenuItem { text: formatDigits(qsTr("45 minutes before")) }
                    MenuItem { text: formatDigits(qsTr("60 minutes before")) }
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex < beforeValues.length) {
                        prayerManager.setFridaySilentBeforeMinutes(beforeValues[currentIndex])
                    }
                }
            }

            ComboBox {
                width: page.width
                enabled: prayerManager.fridaySilentEnabled
                label: qsTr("Duration after Friday prayer")
                property var afterValues: [15, 20, 30, 45, 60, 90]
                currentIndex: {
                    var idx = afterValues.indexOf(prayerManager.fridaySilentAfterMinutes)
                    return idx >= 0 ? idx : 2
                }
                menu: ContextMenu {
                    MenuItem { text: formatDigits(qsTr("15 minutes")) }
                    MenuItem { text: formatDigits(qsTr("20 minutes")) }
                    MenuItem { text: formatDigits(qsTr("30 minutes")) }
                    MenuItem { text: formatDigits(qsTr("45 minutes")) }
                    MenuItem { text: formatDigits(qsTr("60 minutes")) }
                    MenuItem { text: formatDigits(qsTr("90 minutes")) }
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex < afterValues.length) {
                        prayerManager.setFridaySilentAfterMinutes(afterValues[currentIndex])
                    }
                }
            }
        }
    }
}
