import QtQuick 2.6
import Sailfish.Silica 1.0
import QtMultimedia 5.0

Page {
    id: page
    objectName: "alertSettingsPage"

    property var soundsModel: prayerManager.availableSounds()
    property var prayersWithSound: ["fajr", "dhuhr", "asr", "maghrib", "isha"]

    function indexForPrayer(prayer) {
        var current = prayerManager.athanSound(prayer)
        for (var i = 0; i < soundsModel.length; i++) {
            if (soundsModel[i].path === current) return i
        }
        return -1
    }

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
        onSoundsChanged: soundsModel = prayerManager.availableSounds()
    }

    Audio {
        id: previewPlayer
        onPlaybackStateChanged: {
            if (playbackState === Audio.PlayingState) {
                stopAthkarPreview()
            }
        }
    }

    function formatAudioSource(p) {
        if (!p) return ""
        if (p.indexOf("://") !== -1) return p
        if (p.charAt(0) === "/") return "file://" + p
        return "file:///" + p
    }

    property var athkarPlaylist: []
    property int athkarIndex: 0
    property bool isPlayingAthkar: false
    property string activeAthkarType: ""

    Audio {
        id: athkarPlayer
        onPlaybackStateChanged: {
            if (playbackState === Audio.StoppedState && status !== Audio.EndOfMedia) {
                isPlayingAthkar = false
                activeAthkarType = ""
            }
        }
        onStatusChanged: {
            if (status === Audio.EndOfMedia) {
                athkarIndex++
                if (athkarIndex < athkarPlaylist.length) {
                    var p = athkarPlaylist[athkarIndex]
                    source = formatAudioSource(p)
                    play()
                } else {
                    isPlayingAthkar = false
                    activeAthkarType = ""
                }
            } else if (status === Audio.Error || status === Audio.InvalidMedia) {
                console.log("athkarPlayer error status: " + status + " error: " + errorString)
                isPlayingAthkar = false
                activeAthkarType = ""
            }
        }
    }

    function startAthkarPreview(type, paths) {
        if (previewPlayer.playbackState === Audio.PlayingState) {
            previewPlayer.stop()
        }
        athkarPlayer.stop()
        athkarPlaylist = paths || []
        athkarIndex = 0
        if (athkarPlaylist.length > 0) {
            activeAthkarType = type
            isPlayingAthkar = true
            var p = athkarPlaylist[0]
            athkarPlayer.source = formatAudioSource(p)
            athkarPlayer.play()
        }
    }

    function stopAthkarPreview() {
        athkarPlayer.stop()
        isPlayingAthkar = false
        activeAthkarType = ""
        athkarPlaylist = []
        athkarIndex = 0
    }

    Component.onDestruction: {
        stopAthkarPreview()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: page.width

            PageHeader { title: qsTr("Alert Settings") }

            SectionHeader { text: qsTr("Athan activation") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Enable or disable athan playback and reminders for each prayer.")
            }

            Repeater {
                model: ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]
                delegate: TextSwitch {
                    width: page.width
                    text: modelData === "sunrise" ? qsTr("Sunrise (beep alert)") : prayerDisplayName(modelData)
                    checked: prayerManager.prayerEnabled(modelData)
                    onClicked: {
                        prayerManager.setPrayerEnabled(modelData, checked)
                    }
                }
            }

            SectionHeader { text: qsTr("Athan sounds") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                visible: soundsModel.length === 0
                text: qsTr("No sound files found under /usr/share/harbour-thakir/sounds/. Add .ogg files there and reinstall to choose between them here.")
            }

            Repeater {
                model: soundsModel.length > 0 ? prayersWithSound : []
                delegate: Row {
                    width: page.width
                    spacing: Theme.paddingSmall

                    ComboBox {
                        id: soundCombo
                        width: parent.width - previewButton.width - Theme.paddingSmall
                        label: prayerDisplayName(modelData)
                        currentIndex: indexForPrayer(modelData)
                        menu: ContextMenu {
                            Repeater {
                                model: soundsModel
                                MenuItem { text: modelData.name }
                            }
                        }
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < soundsModel.length) {
                                prayerManager.setAthanSound(modelData, soundsModel[currentIndex].path)
                            }
                        }
                    }

                    IconButton {
                        id: previewButton
                        anchors.bottom: soundCombo.bottom
                        anchors.bottomMargin: Theme.paddingMedium
                        icon.source: "image://theme/icon-m-play"
                        onClicked: {
                            if (soundCombo.currentIndex >= 0) {
                                previewPlayer.source = soundsModel[soundCombo.currentIndex].path
                                previewPlayer.play()
                            }
                        }
                    }
                }
            }

            SectionHeader { text: qsTr("Pre-alert") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Play a short beep some minutes before each prayer, as a heads up.")
            }

            Repeater {
                model: ["fajr", "dhuhr", "asr", "maghrib", "isha"]
                delegate: ComboBox {
                    width: page.width
                    label: prayerDisplayName(modelData)
                    property var minuteValues: [0, 5, 10, 15, 20, 30]
                    currentIndex: {
                        var m = prayerManager.preAlertMinutes(modelData)
                        var idx = minuteValues.indexOf(m)
                        return idx >= 0 ? idx : 2
                    }
                    menu: ContextMenu {
                        MenuItem { text: qsTr("Off") }
                        MenuItem { text: formatDigits(qsTr("5 minutes before")) }
                        MenuItem { text: formatDigits(qsTr("10 minutes before")) }
                        MenuItem { text: formatDigits(qsTr("15 minutes before")) }
                        MenuItem { text: formatDigits(qsTr("20 minutes before")) }
                        MenuItem { text: formatDigits(qsTr("30 minutes before")) }
                    }
                    onCurrentIndexChanged: {
                        if (currentIndex >= 0 && currentIndex < minuteValues.length) {
                            prayerManager.setPreAlertMinutes(modelData, minuteValues[currentIndex])
                        }
                    }
                }
            }

            SectionHeader { text: qsTr("Morning and evening Athkar") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Listen to Athkar audio clips before Chourouq and Maghreb.")
            }

            Row {
                width: page.width

                TextSwitch {
                    id: morningAthkarSwitch
                    width: parent.width - previewMorningBtn.width - Theme.paddingSmall
                    text: qsTr("Listening to morning Athkar")
                    checked: prayerManager.morningAthkarEnabled
                    onClicked: {
                        prayerManager.morningAthkarEnabled = checked
                    }
                }

                IconButton {
                    id: previewMorningBtn
                    anchors.verticalCenter: morningAthkarSwitch.verticalCenter
                    icon.source: (isPlayingAthkar && activeAthkarType === "morning")
                                 ? "image://theme/icon-m-pause"
                                 : "image://theme/icon-m-play"
                    onClicked: {
                        if (isPlayingAthkar && activeAthkarType === "morning") {
                            stopAthkarPreview()
                        } else {
                            startAthkarPreview("morning", prayerManager.morningAthkarAudioPaths())
                        }
                    }
                }
            }

            Slider {
                visible: morningAthkarSwitch.checked
                width: page.width
                minimumValue: 1
                maximumValue: 60
                stepSize: 1
                value: prayerManager.morningAthkarMinutes
                label: qsTr("Before Chourouq by %1 min").arg(formatDigits(Math.round(value)))
                onValueChanged: prayerManager.morningAthkarMinutes = Math.round(value)
            }

            Row {
                width: page.width

                TextSwitch {
                    id: eveningAthkarSwitch
                    width: parent.width - previewEveningBtn.width - Theme.paddingSmall
                    text: qsTr("Listening to evening Athkar")
                    checked: prayerManager.eveningAthkarEnabled
                    onClicked: {
                        prayerManager.eveningAthkarEnabled = checked
                    }
                }

                IconButton {
                    id: previewEveningBtn
                    anchors.verticalCenter: eveningAthkarSwitch.verticalCenter
                    icon.source: (isPlayingAthkar && activeAthkarType === "evening")
                                 ? "image://theme/icon-m-pause"
                                 : "image://theme/icon-m-play"
                    onClicked: {
                        if (isPlayingAthkar && activeAthkarType === "evening") {
                            stopAthkarPreview()
                        } else {
                            startAthkarPreview("evening", prayerManager.eveningAthkarAudioPaths())
                        }
                    }
                }
            }

            Slider {
                visible: eveningAthkarSwitch.checked
                width: page.width
                minimumValue: 1
                maximumValue: 60
                stepSize: 1
                value: prayerManager.eveningAthkarMinutes
                label: qsTr("Before Maghreb by %1 min").arg(formatDigits(Math.round(value)))
                onValueChanged: prayerManager.eveningAthkarMinutes = Math.round(value)
            }

            SectionHeader { text: qsTr("Respect phone's Silent mode") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("When on, the athan and pre-alert beep are skipped (not forced) while the phone is already in Silent mode - whether you set that yourself or this app's own “Silent mode during prayer” feature is currently holding it.")
            }

            TextSwitch {
                width: page.width
                text: qsTr("Respect Silent mode")
                checked: prayerManager.respectSilentMode()
                onCheckedChanged: prayerManager.setRespectSilentMode(checked)
            }

            SectionHeader { text: qsTr("Power button") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("When on, pressing the phone’s hardware power button while the athan is playing will immediately silence and stop it.")
            }

            TextSwitch {
                width: page.width
                text: qsTr("Stop athan with power button")
                checked: prayerManager.stopWithPowerButton
                onCheckedChanged: prayerManager.stopWithPowerButton = checked
            }

            SectionHeader { text: qsTr("Volume buttons") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("When on, pressing the volume up or volume down button while the athan is playing will immediately silence and stop it without changing the phone’s volume.")
            }

            TextSwitch {
                width: page.width
                text: qsTr("Stop athan with volume buttons")
                checked: prayerManager.stopWithVolumeButtons
                onCheckedChanged: prayerManager.stopWithVolumeButtons = checked
            }

            SectionHeader { text: qsTr("Turn phone upside down") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("When on, turning the phone upside down or face down while the athan is playing will immediately silence and stop it.")
            }

            TextSwitch {
                width: page.width
                text: qsTr("Stop athan by turning phone upside down")
                checked: prayerManager.stopWithFlipOver
                onCheckedChanged: prayerManager.stopWithFlipOver = checked
            }

            SectionHeader { text: qsTr("Athan notification") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("When on, displays a system notification with a Stop button when the athan is playing, allowing you to silence the athan from the notification banner or lock screen.")
            }

            TextSwitch {
                width: page.width
                text: qsTr("Show notification with Stop button")
                checked: prayerManager.showNotification
                onCheckedChanged: prayerManager.showNotification = checked
            }

            SectionHeader { text: qsTr("Screen") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("When turned off, the phone screen remains completely off during athan or athkar playback to conserve battery and avoid turning the display on.")
            }

            TextSwitch {
                width: page.width
                text: qsTr("Turn on screen during playback")
                checked: prayerManager.turnOnScreen
                onCheckedChanged: prayerManager.turnOnScreen = checked
            }

            SectionHeader { text: qsTr("Events View") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("When on, displays a status notification with the next prayer, remaining time, and prayer times on the Events View screen (left of the home/lock screen).")
            }

            TextSwitch {
                width: page.width
                text: qsTr("Show next prayer in Events View")
                checked: prayerManager.showInEventsView
                onCheckedChanged: prayerManager.showInEventsView = checked
            }

            SectionHeader { text: qsTr("About the background playback") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryColor
                text: qsTr("Athan playback runs via a periodic system timer (every minute, using WakeSystem to wake the device from suspend) that checks these settings directly - it doesn't need this app's window to stay open. It needs a one-time enable step after installing; see the project README.")
            }
        }
    }
}
