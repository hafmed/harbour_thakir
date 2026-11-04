import QtQuick 2.6
import Sailfish.Silica 1.0

ApplicationWindow {
    id: appWindow
    initialPage: Component {
        Page {
            id: page
            allowedOrientations: Orientation.All

            focus: true
            Component.onCompleted: page.forceActiveFocus()
            Keys.onVolumeUpPressed: {
                if (typeof stopWithVolumeButtons === "undefined" || stopWithVolumeButtons) {
                    event.accepted = true
                    playback.stop()
                    Qt.quit()
                }
            }
            Keys.onVolumeDownPressed: {
                if (typeof stopWithVolumeButtons === "undefined" || stopWithVolumeButtons) {
                    event.accepted = true
                    playback.stop()
                    Qt.quit()
                }
            }

            onStatusChanged: {
                if (status === PageStatus.Deactivating) {
                    playback.stop()
                }
            }

            function prayerDisplayName(prayerKey) {
                if (prayerKey === "morning_athkar") return qsTr("Morning Athkar")
                if (prayerKey === "evening_athkar") return qsTr("Evening Athkar")
                if (prayerKey === "dhuhr" && (new Date()).getDay() === 5) {
                    return qsTr("Friday prayer")
                }
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

            SilicaFlickable {
                anchors.fill: parent

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    spacing: Theme.paddingLarge

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: (playback.prayer === "morning_athkar" || playback.prayer === "evening_athkar")
                              ? qsTr("Athkar")
                              : qsTr("Athan")
                        font.pixelSize: Theme.fontSizeExtraLarge
                        color: Theme.highlightColor
                    }

                    Label {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: prayerDisplayName(playback.prayer)
                        font.pixelSize: Theme.fontSizeLarge
                    }

                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Stop")
                        onClicked: {
                            playback.stop()
                            Qt.quit()
                        }
                    }
                }
            }
        }
    }
}
