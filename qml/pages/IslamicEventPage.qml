import QtQuick 2.6
import Sailfish.Silica 1.0

Page {
    id: page
    objectName: "islamicEventPage"

    property string eventTitle: ""
    property string eventBanner: ""
    property string eventContent: ""
    readonly property bool isRtl: Qt.application.layoutDirection === Qt.RightToLeft || prayerManager.isArabicLanguage

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentCol.height + Theme.paddingLarge * 2

        VerticalScrollDecorator {}

        Column {
            id: contentCol
            width: parent.width - 2 * Theme.horizontalPageMargin
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.paddingMedium

            PageHeader {
                title: isRtl ? "حدث اليوم" : qsTr("Today's Event")
            }

            Rectangle {
                width: parent.width
                height: bannerCol.implicitHeight + Theme.paddingMedium * 2
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                border.color: Theme.rgba("#e0a93b", 0.6)
                border.width: 1

                Column {
                    id: bannerCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Theme.paddingMedium
                    }
                    spacing: Theme.paddingSmall / 2

                    Label {
                        width: parent.width
                        text: eventTitle
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        color: "#e0a93b"
                        wrapMode: Text.Wrap
                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                    }

                    Label {
                        width: parent.width
                        text: eventBanner
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.highlightColor
                        wrapMode: Text.Wrap
                        visible: eventBanner.length > 0 && eventBanner !== eventTitle
                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                    }

                    Label {
                        width: parent.width
                        text: prayerManager.hijriDate ? (prayerManager.hijriDate + (isRtl ? " هـ" : " H.Y")) : ""
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: Theme.secondaryColor
                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingSmall
            }

            Label {
                width: parent.width
                text: eventContent
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primaryColor
                wrapMode: Text.Wrap
                lineHeight: 1.25
                horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
            }
        }
    }
}
