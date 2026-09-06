import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: localeStep

    ColumnLayout {
        anchors.centerIn: parent
        width: 760
        spacing: 32

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Text {
                text: "Region & Localization"
                color: "#ffffff"
                font.pixelSize: 34
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Select your input keyboard layout and primary timezone."
                color: "#7e889b"
                font.pixelSize: 16
                Layout.alignment: Qt.AlignHCenter
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 36

            // Keyboard Layout Selection
            ColumnLayout {
                spacing: 8

                Text {
                    text: "Keyboard Layout"
                    color: "#a0aec0"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                ComboBox {
                    id: keymapCombo
                    Layout.preferredWidth: 320
                    Layout.preferredHeight: 52
                    model: backend.keymaps
                    currentIndex: backend.keymaps.indexOf(session.keymap) >= 0 
                                  ? backend.keymaps.indexOf(session.keymap) 
                                  : 0

                    background: Rectangle {
                        color: "#11141c"
                        radius: 8
                        border.color: keymapCombo.activeFocus ? "#00f5d4" : "#242c3d"
                    }

                    contentItem: Text {
                        leftPadding: 16
                        text: keymapCombo.currentText
                        color: "#ffffff"
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter
                    }

                    onActivated: {
                        session.keymap = currentText
                        backend.setKeymap(currentText)
                    }
                }
            }

            // Timezone Selection
            ColumnLayout {
                spacing: 8

                Text {
                    text: "System Timezone"
                    color: "#a0aec0"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                ComboBox {
                    id: timezoneCombo
                    Layout.preferredWidth: 320
                    Layout.preferredHeight: 52
                    model: backend.timezones
                    currentIndex: backend.timezones.indexOf(session.timezone) >= 0 
                                  ? backend.timezones.indexOf(session.timezone) 
                                  : 0

                    background: Rectangle {
                        color: "#11141c"
                        radius: 8
                        border.color: timezoneCombo.activeFocus ? "#00f5d4" : "#242c3d"
                    }

                    contentItem: Text {
                        leftPadding: 16
                        text: timezoneCombo.currentText
                        color: "#ffffff"
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter
                    }

                    onActivated: session.timezone = currentText
                }
            }
        }

        // Navigation Controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            spacing: 16

            Button {
                Layout.preferredWidth: 160
                Layout.preferredHeight: 50
                background: Rectangle {
                    radius: 25
                    color: "#161b24"
                    border.color: "#283345"
                }
                contentItem: Text {
                    text: "Back"
                    color: "#a0aec0"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: navStack.pop()
            }

            Button {
                Layout.preferredWidth: 220
                Layout.preferredHeight: 50
                background: Rectangle {
                    radius: 25
                    color: "#00f5d4"
                }
                contentItem: Text {
                    text: "Next"
                    color: "#07090e"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    session.keymap = keymapCombo.currentText
                    session.timezone = timezoneCombo.currentText
                    navStack.push("UserStep.qml")
                }
            }
        }
    }
}