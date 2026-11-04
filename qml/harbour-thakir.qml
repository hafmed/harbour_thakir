import QtQuick 2.6
import Sailfish.Silica 1.0
import "pages"
import "cover"

ApplicationWindow {
    id: root
    initialPage: Component { MainPage {} }
    cover: Component { CoverPage {} }
    allowedOrientations: Orientation.All

    Timer {
        id: languageRefreshTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (pageStack.busy) {
                languageRefreshTimer.restart()
                return
            }

            var pageToRestore = ""
            if (pageStack.currentPage) {
                var objName = pageStack.currentPage.objectName
                if (objName === "settingsPage") {
                    pageToRestore = Qt.resolvedUrl("pages/SettingsPage.qml")
                } else if (objName === "locationSettingsPage") {
                    pageToRestore = Qt.resolvedUrl("pages/LocationSettingsPage.qml")
                } else if (objName === "alertSettingsPage") {
                    pageToRestore = Qt.resolvedUrl("pages/AlertSettingsPage.qml")
                } else if (objName === "silentModeSettingsPage") {
                    pageToRestore = Qt.resolvedUrl("pages/SilentModeSettingsPage.qml")
                } else if (objName === "timeAdjustmentsPage") {
                    pageToRestore = Qt.resolvedUrl("pages/TimeAdjustmentsPage.qml")
                } else if (objName === "aboutPage") {
                    pageToRestore = Qt.resolvedUrl("pages/AboutPage.qml")
                } else if (objName === "favoritesPage") {
                    pageToRestore = Qt.resolvedUrl("pages/FavoritesPage.qml")
                } else if (objName === "qiblaPage") {
                    pageToRestore = Qt.resolvedUrl("pages/QiblaPage.qml")
                } else if (objName === "citySearchPage") {
                    pageToRestore = Qt.resolvedUrl("pages/CitySearchPage.qml")
                } else if (objName === "cityMapPage") {
                    pageToRestore = Qt.resolvedUrl("pages/CityMapPage.qml")
                }
            }

            root.cover = Qt.createComponent(Qt.resolvedUrl("cover/CoverPage.qml"))

            pageStack.replaceAbove(null, Qt.resolvedUrl("pages/MainPage.qml"), {}, PageStackAction.Immediate)
            if (pageToRestore.length > 0) {
                pageStack.push(pageToRestore, {}, PageStackAction.Immediate)
            }
        }
    }

    Connections {
        target: prayerManager
        onAppLanguageChanged: {
            languageRefreshTimer.restart()
        }
    }

    Component.onCompleted: {
        if (prayerManager.hasCity) {
            // Refreshes today's/tomorrow's displayed times. Actual athan
            // playback is handled by a periodic --check-and-play run of
            // this same binary, triggered by a system-level timer (see
            // systemd/harbour-thakir-check.timer) - this call just
            // updates the GUI, it doesn't drive any scheduling itself.
            prayerManager.recalculateAndSchedule()
        }
    }
}
