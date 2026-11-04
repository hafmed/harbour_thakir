import QtQuick 2.6
import Sailfish.Silica 1.0

Dialog {
    id: dialog
    objectName: "textModeDisclaimerDialog"

    readonly property bool isRtl: prayerManager.isArabicLanguage
    property bool isConfirmed: quranManager.isTextModeDisclaimerConfirmed(prayerManager.appVersion)

    signal switchToMushafRequested()

    canAccept: true

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentCol.height + Theme.paddingLarge

        Column {
            id: contentCol
            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: isRtl ? "تنبيه نمط النص والتجويد" : qsTr("Text & Tajweed Notice")
                acceptText: isRtl ? "متابعة" : qsTr("Continue")
                cancelText: isRtl ? "إغلاق" : qsTr("Close")
            }

            // Warning Notice Box
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                radius: 12
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)
                border.color: Theme.rgba(Theme.highlightColor, 0.3)
                border.width: 1
                height: warningCol.height + 2 * Theme.paddingMedium

                Column {
                    id: warningCol
                    anchors.centerIn: parent
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.paddingSmall

                        HighlightImage {
                            source: "image://theme/icon-m-about"
                            width: Theme.iconSizeMedium
                            height: Theme.iconSizeMedium
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.highlightColor
                        }

                        Label {
                            text: isRtl ? "تنبيه هام حول النص القرآني" : qsTr("Important Notice: Quran Text")
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            color: Theme.highlightColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Label {
                        width: parent.width
                        text: isRtl
                              ? "يُخلي مطوّر التطبيق مسؤوليته الكاملة عن أي أخطاء أو تشوهات غير مقصودة قد تطرأ على الرسم الإملائي العثماني أو تموضع علامات الضبط والهمزات والمدود الناتجة عن المعالجة والعرض الآلي للنص القرآني في النمط النصي أو نمط التجويد، وذلك نظراً للمحدودية التقنية لخطوط النظام ومحركات تصيير النصوص."
                              : qsTr("The application developer assumes no responsibility for the automatically generated rendering, diacritics, or typography of the Holy Quran in Text or Tajweed mode, due to technical limitations of system fonts and layout engines.")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                    }
                }
            }

            // Recommendation to use Mushaf Pages Box
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                radius: 12
                color: Theme.rgba(Theme.primaryColor, 0.05)
                border.color: Theme.rgba(Theme.primaryColor, 0.15)
                border.width: 1
                height: recCol.height + 2 * Theme.paddingMedium

                Column {
                    id: recCol
                    anchors.centerIn: parent
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width
                        text: isRtl
                              ? "✨ إن الرسم الدقيق والمضبوط والمعتمد للقرآن الكريم متوفر بالكامل وبأعلى موثوقية في نمط «صفحات المصحف» المصورة."
                              : qsTr("✨ An accurate, verified, and pristine rendering of the Holy Quran is available in 'Pages of the Mushaf' mode.")
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Theme.highlightColor
                        wrapMode: Text.Wrap
                        horizontalAlignment: isRtl ? Text.AlignRight : Text.AlignLeft
                    }

                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        preferredWidth: parent.width
                        text: isRtl ? "📖 الانتقال إلى صفحات المصحف" : qsTr("📖 Switch to Mushaf Pages")
                        onClicked: {
                            if (confirmSwitch.checked) {
                                quranManager.confirmTextModeDisclaimer(prayerManager.appVersion)
                            } else {
                                quranManager.recordTextModeDisclaimerShown()
                            }
                            quranManager.viewMode = 1
                            dialog.switchToMushafRequested()
                            dialog.reject()
                        }
                    }
                }
            }

            // Acknowledgment Checkbox / Switch
            TextSwitch {
                id: confirmSwitch
                width: parent.width
                text: isRtl ? "أقرّ بعلمي وفهمي لهذا التنبيه" : qsTr("I acknowledge and confirm awareness of this notice")
                description: isRtl
                             ? (confirmSwitch.checked ? "تم التأكيد: سيظهر هذا التنبيه مرة واحدة شهرياً فقط" : "ضع علامة هنا للتأكيد (سيظهر شهرياً بدلاً من يومياً)")
                             : (confirmSwitch.checked ? qsTr("Confirmed: notice will appear once a month") : qsTr("Check to confirm awareness (will appear monthly instead of daily)"))
                checked: isConfirmed
            }
        }
    }

    onAccepted: {
        if (confirmSwitch.checked) {
            quranManager.confirmTextModeDisclaimer(prayerManager.appVersion)
        } else {
            quranManager.recordTextModeDisclaimerShown()
        }
    }

    onRejected: {
        if (confirmSwitch.checked) {
            quranManager.confirmTextModeDisclaimer(prayerManager.appVersion)
        } else {
            quranManager.recordTextModeDisclaimerShown()
        }
    }
}
