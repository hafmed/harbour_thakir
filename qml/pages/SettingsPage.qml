import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "settingsPage"

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height

        Column {
            id: column
            width: page.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: qsTr("Settings")
            }

            ListModel {
                id: settingsMenuModel

                ListElement {
                    title: QT_TR_NOOP("Location Settings")
                    iconSource: "image://theme/icon-m-location"
                    fallbackIcon: "../icons/ic_location.svg"
                    pageUrl: "LocationSettingsPage.qml"
                }
                ListElement {
                    title: QT_TR_NOOP("Alert Settings")
                    iconSource: "image://theme/icon-m-speaker"
                    fallbackIcon: "../icons/ic_alert.svg"
                    pageUrl: "AlertSettingsPage.qml"
                }
                ListElement {
                    title: QT_TR_NOOP("Silent Mode Settings")
                    iconSource: "image://theme/icon-m-silent"
                    fallbackIcon: "../icons/ic_silent.svg"
                    pageUrl: "SilentModeSettingsPage.qml"
                }
                ListElement {
                    title: QT_TR_NOOP("Time Adjustments")
                    iconSource: "image://theme/icon-m-time"
                    fallbackIcon: "../icons/ic_time.svg"
                    pageUrl: "TimeAdjustmentsPage.qml"
                }
                ListElement {
                    title: QT_TR_NOOP("Appearance & Background")
                    iconSource: "image://theme/icon-m-image"
                    fallbackIcon: ""
                    pageUrl: "AppearancePage.qml"
                }
                ListElement {
                    title: QT_TR_NOOP("About")
                    iconSource: "image://theme/icon-m-about"
                    fallbackIcon: "../icons/ic_about.svg"
                    pageUrl: "AboutPage.qml"
                }
            }

            Repeater {
                model: settingsMenuModel

                delegate: BackgroundItem {
                    id: menuItem
                    width: parent.width
                    height: Theme.itemSizeMedium

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.rightMargin: Theme.horizontalPageMargin
                        spacing: Theme.paddingLarge
                        layoutDirection: prayerManager.isArabicLanguage ? Qt.RightToLeft : Qt.LeftToRight

                        HighlightImage {
                            id: menuIcon
                            anchors.verticalCenter: parent.verticalCenter
                            source: model.iconSource
                            highlighted: menuItem.highlighted
                            color: menuItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                            onStatusChanged: {
                                if (status === Image.Error && model.fallbackIcon) {
                                    source = model.fallbackIcon
                                }
                            }
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (prayerManager.isArabicLanguage && model.title === "Appearance & Background")
                                  ? "المظهر والخلفية"
                                  : qsTr(model.title)
                            color: menuItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                            font.pixelSize: Theme.fontSizeMedium
                        }
                    }

                    onClicked: {
                        pageStack.push(Qt.resolvedUrl(model.pageUrl))
                    }
                }
            }
        }
    }
}
