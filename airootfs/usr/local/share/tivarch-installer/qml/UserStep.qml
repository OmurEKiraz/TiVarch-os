import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: userStep

    ColumnLayout {
        anchors.centerIn: parent
        width: 680
        spacing: 22

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Text {
                text: "Device & User Account"
                color: "#ffffff"
                font.pixelSize: 34
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Set up the local network name and primary login credentials."
                color: "#7e889b"
                font.pixelSize: 16
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Computer Hostname
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Computer Name (Hostname)"
                color: "#a0aec0"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            TextField {
                id: hostInput
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                text: session.hostname
                color: "#ffffff"
                font.pixelSize: 15
                background: Rectangle {
                    color: "#11141c"
                    radius: 8
                    border.color: hostInput.activeFocus ? "#00f5d4" : "#242c3d"
                }
            }
        }

        // Username
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Username"
                color: "#a0aec0"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            TextField {
                id: userInput
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                text: session.username
                color: "#ffffff"
                font.pixelSize: 15
                background: Rectangle {
                    color: "#11141c"
                    radius: 8
                    border.color: userInput.activeFocus ? "#00f5d4" : "#242c3d"
                }
            }
        }

        // Password & Confirm
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "Password"
                    color: "#a0aec0"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                TextField {
                    id: passInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    echoMode: TextInput.Password
                    color: "#ffffff"
                    font.pixelSize: 15
                    background: Rectangle {
                        color: "#11141c"
                        radius: 8
                        border.color: passInput.activeFocus ? "#00f5d4" : "#242c3d"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "Confirm Password"
                    color: "#a0aec0"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                TextField {
                    id: confirmInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    echoMode: TextInput.Password
                    color: "#ffffff"
                    font.pixelSize: 15
                    background: Rectangle {
                        color: "#11141c"
                        radius: 8
                        border.color: confirmInput.activeFocus ? "#00f5d4" : "#242c3d"
                    }
                }
            }
        }

        // Password mismatch notice
        Text {
            visible: passInput.text !== confirmInput.text && confirmInput.text.length > 0
            text: "Passwords do not match."
            color: "#e63946"
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter
        }

        // Navigation Action Buttons
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
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
                enabled: (passInput.text === confirmInput.text) && (userInput.text.trim().length > 0)
                background: Rectangle {
                    radius: 25
                    color: parent.enabled ? "#00f5d4" : "#1e2433"
                }
                contentItem: Text {
                    text: "Choose Disk"
                    color: parent.enabled ? "#07090e" : "#555"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    session.hostname = hostInput.text.trim() || "tivarch-tv"
                    session.username = userInput.text.trim().toLowerCase() || "tivuser"
                    session.password = passInput.text
                    navStack.push("DiskStep.qml")
                }
            }
        }
    }
}