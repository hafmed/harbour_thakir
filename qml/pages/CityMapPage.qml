import QtQuick 2.6
import Sailfish.Silica 1.0
import QtPositioning 5.3
import QtLocation 5.3

Page {
    id: page
    objectName: "cityMapPage"

    property var tappedCoordinate: QtPositioning.coordinate(0, 0)
    property bool hasTapped: false
    property bool resolving: false
    readonly property bool isOffline: !prayerManager.geocoder.isOnline

    Connections {
        target: prayerManager.geocoder
        onResultsReady: {
            resolving = false
            if (results.length === 0) {
                statusLabel.text = qsTr("No city found there. Try tapping more precisely on a city.")
                return
            }
            // Auto-pick the closest-sounding match rather than showing
            // another list - tapping a point is meant to be a quicker
            // path than the text search, not a second search step.
            var best = results[0]
            prayerManager.selectCity(best.name, best.country, best.latitude,
                                       best.longitude, best.timezone, best.countryCode)
            pageStack.pop(pageStack.find(function(p) { return p.objectName === "mainPage" }))
        }
        onSearchFailed: {
            resolving = false
            if (isOffline || error.indexOf("Network access is disabled") !== -1) {
                statusLabel.text = qsTr("Network access is disabled. Please connect to the internet to pick a city.")
            } else {
                statusLabel.text = qsTr("Could not identify that location: ") + error
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent

        PageHeader {
            id: header
            title: qsTr("Tap a city on the map")
        }

        Rectangle {
            id: offlineBanner
            visible: isOffline
            anchors.top: header.bottom
            width: parent.width
            height: visible ? (offlineLabel.paintedHeight + 2 * Theme.paddingMedium) : 0
            color: Qt.rgba(1.0, 0.2, 0.2, 0.15)
            border.color: "#cc3333"
            border.width: 1
            z: 10

            Label {
                id: offlineLabel
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.horizontalPageMargin
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: "#ff5555"
                text: qsTr("Network access is disabled. Please connect to the internet to use the map and pick a city.")
            }
        }

        Map {
            id: map
            anchors.top: offlineBanner.visible ? offlineBanner.bottom : header.bottom
            anchors.bottom: footer.top
            width: parent.width
            plugin: Plugin { name: "osm" }
            // Default view centered on Algeria (28°N, 2°E is roughly
            // its geographic centroid, accounting for its large
            // southern Saharan extent) at a zoom level that shows the
            // whole country - just the initial view, still fully
            // pannable/zoomable to anywhere in the world.
            center: QtPositioning.coordinate(28.0, 2.0)
            zoomLevel: 5
            Component.onCompleted: {
                map.center = QtPositioning.coordinate(28.0, 2.0);
                map.zoomLevel = 5.0;
            }

            MapQuickItem {
                visible: hasTapped
                coordinate: tappedCoordinate
                anchorPoint.x: pin.width / 2
                anchorPoint.y: pin.height
                sourceItem: Rectangle {
                    id: pin
                    width: Theme.iconSizeSmall
                    height: width
                    radius: width / 2
                    color: Theme.highlightColor
                    border.color: "white"
                    border.width: 2
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (isOffline) {
                        statusLabel.text = qsTr("Network access is disabled. Please connect to the internet to pick a city.")
                        return
                    }
                    tappedCoordinate = map.toCoordinate(Qt.point(mouse.x, mouse.y))
                    hasTapped = true
                    statusLabel.text = qsTr("Pinned - tap \u201cUse this location\u201d to confirm")
                }
            }
        }

        Column {
            id: footer
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: Theme.paddingSmall

            Label {
                id: statusLabel
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: isOffline ? "#ff5555" : Theme.secondaryColor
                text: isOffline
                      ? qsTr("Network access is disabled. Please connect to the internet to pick a city.")
                      : (hasTapped ? qsTr("Pinned - tap \u201cUse this location\u201d to confirm") : qsTr("Pan and zoom, then tap a city"))
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                enabled: !isOffline && hasTapped && !resolving
                text: isOffline ? qsTr("Network disabled") : (resolving ? qsTr("Looking up\u2026") : qsTr("Use this location"))
                onClicked: {
                    if (isOffline) {
                        statusLabel.text = qsTr("Network access is disabled. Please connect to the internet to pick a city.")
                        return
                    }
                    resolving = true
                    statusLabel.text = qsTr("Looking up city name\u2026")
                    prayerManager.geocoder.reverseSearch(tappedCoordinate.latitude, tappedCoordinate.longitude)
                }
            }
        }
    }
}
