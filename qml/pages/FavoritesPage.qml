import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "favoritesPage"

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: prayerManager.favorites

        PullDownMenu {
            MenuItem {
                text: qsTr("Save current settings as favorite")
                enabled: prayerManager.hasCity
                onClicked: {
                    var dialog = pageStack.push(Qt.resolvedUrl("SaveFavoriteDialog.qml"), {
                        title: qsTr("Save as favorite"),
                        name: prayerManager.cityName
                    })
                    dialog.accepted.connect(function() {
                        prayerManager.saveCurrentAsFavorite(dialog.name)
                    })
                }
            }
        }

        header: PageHeader {
            title: qsTr("Favorites")
        }

        ViewPlaceholder {
            enabled: listView.count === 0
            text: qsTr("No favorites saved yet")
            hintText: prayerManager.hasCity
                      ? qsTr("Pull down to save your current city and settings as a favorite")
                      : qsTr("First select a city, then pull down to save it as a favorite")
        }

        delegate: ListItem {
            id: listItem
            contentHeight: Theme.itemSizeMedium

            function openRenameDialog() {
                var dialog = pageStack.push(Qt.resolvedUrl("SaveFavoriteDialog.qml"), {
                    title: qsTr("Rename favorite"),
                    name: modelData.name
                })
                dialog.accepted.connect(function() {
                    prayerManager.renameFavorite(modelData.id, dialog.name)
                })
            }

            Item {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                }
                height: contentCol.height

                Image {
                    id: favIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    source: "image://theme/icon-m-favorite"
                    visible: modelData.isActive
                }

                Column {
                    id: contentCol
                    anchors {
                        left: favIcon.visible ? favIcon.right : parent.left
                        leftMargin: favIcon.visible ? Theme.paddingMedium : 0
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    Label {
                        width: parent.width
                        text: modelData.name
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeMedium
                        color: modelData.isActive ? Theme.highlightColor : Theme.primaryColor
                    }

                    Label {
                        width: parent.width
                        text: modelData.cityName + (modelData.countryName ? (", " + modelData.countryName) : "")
                              + " • " + prayerManager.methodName(modelData.method)
                              + " • " + prayerManager.madhabName(modelData.madhab)
                        truncationMode: TruncationMode.Fade
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                    }
                }
            }

            onClicked: {
                prayerManager.applyFavorite(modelData.id)
                pageStack.pop(pageStack.find(function(p) { return p.objectName === "mainPage" }))
            }

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Set as active")
                    visible: !modelData.isActive
                    onClicked: prayerManager.applyFavorite(modelData.id)
                }

                MenuItem {
                    text: qsTr("Update with current settings")
                    onClicked: prayerManager.updateFavorite(modelData.id)
                }

                MenuItem {
                    text: qsTr("Rename")
                    onClicked: listItem.openRenameDialog()
                }

                MenuItem {
                    text: qsTr("Delete")
                    onClicked: listItem.remorseDelete(function() {
                        prayerManager.deleteFavorite(modelData.id)
                    })
                }
            }
        }
    }
}
