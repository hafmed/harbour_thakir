import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: dialog
    property string title: qsTr("Save as favorite")
    property alias name: nameField.text

    canAccept: nameField.text.trim().length > 0

    Column {
        width: parent.width

        DialogHeader {
            title: dialog.title
        }

        TextField {
            id: nameField
            width: parent.width
            label: qsTr("Favorite name")
            placeholderText: qsTr("e.g. Home, Work, Travel")
            focus: true
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.enabled: text.trim().length > 0
            EnterKey.onClicked: dialog.accept()
        }
    }
}
