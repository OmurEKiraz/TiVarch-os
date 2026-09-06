import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal nextStep(string hostname, string username, string password, bool makeRoot)

    property bool isRootChecked: true

    ColumnLayout {
        anchors.centerIn: parent
        width: 720
        spacing: 24

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Text {
                text: "System Identity & User"
                color: "#ffffff"
                font.pixelSize: 34
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Configure the machine hostname and administrative credentials."
                color: "#7e889b"
                font.pixelSize: 16
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Hostname Field
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Text { text: "Computer Name (Hostname)"; color: "#a0aec0"; font.pixelSize: 15; font.weight: Font.DemiBold }
            TextField {
                id: hostnameInput
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                text: "tivarch-livingroom"
                color: "#ffffff"
                font.pixelSize: 16
                background: Rectangle { color: "#141824"; radius: 8; border.color: "#283149" }
            }
        }

        // Privilege Option Switcher
        RowLayout {
            spacing: 20
            Layout.alignment: Qt.AlignHCenter

            Button {
                text: "Root Account Setup"
                Layout.preferredWidth: 200
                Layout.preferredHeight: 44
                background: Rectangle {
                    color: root.isRootChecked ? "#00f5d4" : "#141824"
                    radius: 8
                }
                contentItem: Text {
                    text: parent.text
                    color: root.isRootChecked ? "#07090e" : "#a0aec0"
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.isRootChecked = true
            }

            Button {
                text: "Standard User (Sudoer)"
                Layout.preferredWidth: 200
                Layout.preferredHeight: 44
                background: Rectangle {
                    color: !root.isRootChecked ? "#00f5d4" : "#141824"
                    radius: 8
                }
                contentItem: Text {
                    text: parent.text
                    color: !root.isRootChecked ? "#07090e" : "#a0aec0"
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.isRootChecked = false
            }
        }

        // Username Field (Visible only if not configuring pure root)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: !root.isRootChecked

            Text { text: "Username"; color: "#a0aec0"; font.pixelSize: 15; font.weight: Font.DemiBold }
            TextField {
                id: usernameInput
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                placeholderText: "e.g. tivuser"
                text: "tivuser"
                color: "#ffffff"
                font.pixelSize: 16
                background: Rectangle { color: "#141824"; radius: 8; border.color: "#283149" }
            }
        }

        // Password Field
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Text { text: root.isRootChecked ? "Root Password (leave blank for passwordless)" : "User Password (leave blank for passwordless)"; color: "#a0aec0"; font.pixelSize: 15 }
            TextField {
                id: passwordInput
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                placeholderText: "Password (Optional)"
                echoMode: TextInput.Password
                color: "#ffffff"
                font.pixelSize: 16
                background: Rectangle { color: "#141824"; radius: 8; border.color: "#283149" }
            }
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 260
            Layout.preferredHeight: 54
            Layout.topMargin: 12

            background: Rectangle {
                radius: 27
                color: "#00f5d4"
            }

            contentItem: Text {
                text: "Confirm & Proceed"
                color: "#07090e"
                font.pixelSize: 17
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                var user = root.isRootChecked ? "root" : usernameInput.text
                root.nextStep(hostnameInput.text, user, passwordInput.text, root.isRootChecked)
            }
        }
    }
}