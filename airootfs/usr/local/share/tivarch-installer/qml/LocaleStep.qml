import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 28
    Layout.fillWidth: true

    property string selectedKeymap: "us"
    property string selectedTimezone: backend.detectedTimezone

    signal nextStep()

    Text {
        text: "Region & Localization"
        color: "#ffffff"
        font.pixelSize: 36
        font.bold: true
        Layout.alignment: Qt.AlignHCenter
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 40

        ColumnLayout {
            spacing: 10
            Text { text: "Keyboard Layout"; color: "#8e9aaf"; font.pixelSize: 18 }
            ComboBox {
                id: keymapBox
                Layout.preferredWidth: 320
                Layout.preferredHeight: 52
                model: backend.keymaps
                onActivated: {
                    root.selectedKeymap = currentText
                    backend.setKeymap(currentText)
                }
            }
        }

        ColumnLayout {
            spacing: 10
            Text { text: "Timezone"; color: "#8e9aaf"; font.pixelSize: 18 }
            ComboBox {
                id: tzBox
                Layout.preferredWidth: 320
                Layout.preferredHeight: 52
                model: backend.timezones
                Component.onCompleted: {
                    var idx = indexOfValue(backend.detectedTimezone)
                    if (idx !== -1) currentIndex = idx
                }
                onActivated: {
                    root.selectedTimezone = currentText
                    backend.applyTimezoneAndSync(currentText)
                }
            }
        }
    }

    Button {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: 52
        Layout.preferredWidth: 220
        background: Rectangle { color: "#00f5d4"; radius: 26 }
        contentItem: Text { text: "Proceed"; color: "#07090e"; font.pixelSize: 17; font.weight: Font.Bold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        onClicked: {
            root.selectedKeymap = keymapBox.currentText
            root.selectedTimezone = tzBox.currentText
            backend.applyTimezoneAndSync(root.selectedTimezone)
            root.nextStep()
        }
    }
}