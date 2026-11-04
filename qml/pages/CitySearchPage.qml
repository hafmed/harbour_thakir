import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "citySearchPage"

    ListModel { id: resultsModel }

    Connections {
        target: prayerManager.geocoder
        onResultsReady: {
            resultsModel.clear()
            for (var i = 0; i < results.length; i++) {
                resultsModel.append(results[i])
            }
            if (results.length === 0) {
                busyLabel.text = qsTr("No matches. Try a different spelling.")
            } else {
                busyLabel.text = ""
            }
        }
        onSearchFailed: {
            if (!prayerManager.geocoder.isOnline || error.indexOf("Network access is disabled") !== -1) {
                busyLabel.text = qsTr("Network access is disabled. Please connect to the internet to search.")
                busyLabel.color = "#ff5555"
            } else {
                busyLabel.text = qsTr("Search failed: ") + error
                busyLabel.color = Theme.secondaryColor
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent

        PullDownMenu {
            MenuItem {
                text: qsTr("Pick on map instead")
                onClicked: pageStack.push(Qt.resolvedUrl("CityMapPage.qml"))
            }
        }

        PageHeader { id: header; title: qsTr("Find a city") }

        Rectangle {
            id: offlineBanner
            visible: !prayerManager.geocoder.isOnline
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
                text: qsTr("Network access is disabled. Please connect to the internet to search for a city.")
            }
        }

        SearchField {
            id: searchField
            anchors.top: offlineBanner.visible ? offlineBanner.bottom : header.bottom
            width: parent.width
            placeholderText: qsTr("Any city in the world")
            onTextChanged: {
                if (text.length >= 2) {
                    if (!prayerManager.geocoder.isOnline) {
                        busyLabel.text = qsTr("Network access is disabled. Please connect to the internet to search.")
                        busyLabel.color = "#ff5555"
                    } else {
                        busyLabel.text = qsTr("Searching\u2026")
                        busyLabel.color = Theme.secondaryColor
                        prayerManager.geocoder.search(text)
                    }
                } else {
                    resultsModel.clear()
                    busyLabel.text = ""
                    busyLabel.color = Theme.secondaryColor
                }
            }
            EnterKey.iconSource: "image://theme/icon-m-enter-search"
        }

        Label {
            id: busyLabel
            anchors.top: searchField.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 2 * Theme.horizontalPageMargin
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.secondaryColor
        }

        SilicaListView {
            anchors.top: busyLabel.bottom
            anchors.bottom: parent.bottom
            width: parent.width
            model: resultsModel
            delegate: ListItem {
                contentHeight: Theme.itemSizeMedium
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.horizontalPageMargin
                    Label {
                        text: name + (admin1 ? (", " + admin1) : "")
                        color: Theme.primaryColor
                    }
                    Label {
                        text: country + "  \u00b7  " + timezone
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }
                }
                onClicked: {
                    prayerManager.selectCity(name, country, latitude, longitude, timezone, countryCode)
                    pageStack.pop()
                }
            }
            VerticalScrollDecorator {}
        }
    }
}
