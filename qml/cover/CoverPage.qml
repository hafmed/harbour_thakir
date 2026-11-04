import QtQuick 2.6
import Sailfish.Silica 1.0

CoverBackground {
    id: coverRoot

    property string prayerTitle: ""
    property string prayerTimeStr: ""
    property string remainingText: ""
    property bool inPreAlert: false
    property bool isTomorrow: false

    function updateCover() {
        prayerManager.checkNextPrayer()

        if (!prayerManager.hasCity) {
            prayerTitle = ""
            prayerTimeStr = ""
            remainingText = ""
            inPreAlert = false
            isTomorrow = false
            return
        }

        var _lang = prayerManager.appLanguage
        var _num = prayerManager.useHindiNumerals
        var nextName = prayerManager.nextPrayerName
        isTomorrow = prayerManager.isNextPrayerTomorrow

        var d = new Date()
        if (isTomorrow) {
            d.setDate(d.getDate() + 1)
        }
        var isFriday = (nextName === "dhuhr" && d.getDay() === 5)

        prayerTitle = prayerManager.localizedPrayerName(nextName, isFriday, isTomorrow)
        prayerTimeStr = prayerManager.formatDigits(prayerManager.nextPrayerTime)
        remainingText = prayerManager.nextPrayerCountdown() ? prayerManager.localizedRemainingTime() : ""
        inPreAlert = prayerManager.isPreAlertWindow()
    }

    Timer {
        id: coverTimer
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updateCover()
    }

    onStatusChanged: {
        if (status === Cover.Active) {
            updateCover()
        }
    }

    Connections {
        target: prayerManager
        onTimesChanged: updateCover()
        onAppLanguageChanged: updateCover()
        onUseHindiNumeralsChanged: updateCover()
        onCityChanged: updateCover()
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingMedium
        spacing: Theme.paddingSmall

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: prayerManager.hasCity ? prayerManager.cityName : (prayerManager.appLanguage, qsTr("Athan"))
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
            truncationMode: TruncationMode.Fade
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: prayerTitle
            color: Theme.highlightColor
            font.pixelSize: isTomorrow ? Theme.fontSizeMedium : Theme.fontSizeLarge
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontSizeSmall
            truncationMode: TruncationMode.Fade
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: prayerTimeStr
            font.pixelSize: Theme.fontSizeExtraLarge
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontSizeMedium
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: remainingText
            font.pixelSize: Theme.fontSizeSmall
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: Theme.fontSizeExtraSmall
            truncationMode: TruncationMode.Fade
            color: inPreAlert ? "#f44336" : Theme.highlightColor
        }
    }
}
