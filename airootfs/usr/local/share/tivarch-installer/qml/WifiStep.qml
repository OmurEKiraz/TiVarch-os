import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: wifiStep

    Component.onCompleted: {
        backend.updateNetworkStatus()
        backend.scanWifi()
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: 820
        spacing: 24

        // Screen Title & Subtitle
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Text {
                text: "Connect to Network"
                color: "#ffffff"
                font.pixelSize: 34
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "An active internet connection is required to fetch base packages."
                color: "#7e889b"
                font.pixelSize: 16
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Live Network Status Card
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: 58
            radius: 10
            color: backend.netType === "Offline" ? "#1e1317" : "#0f231e"
            border.color: backend.netType === "Offline" ? "#e63946" : "#00f5d4"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16
                spacing: 14

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: backend.netType === "Offline" ? "#e63946" : "#00f5d4"
                }

                Text {
                    text: backend.netType === "Offline" 
                          ? "Offline — Connect to Wi-Fi or plug in Ethernet" 
                          : "Online: " + backend.netType + " (" + backend.netDetails + ")"
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }

                Button {
                    text: "Rescan"
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: 90
                    background: Rectangle {
                        color: "#18202c"
                        radius: 6
                        border.color: "#273347"
                    }
                    contentItem: Text {
                        text: "Rescan"
                        color: "#00f5d4"
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        backend.updateNetworkStatus()
                        backend.scanWifi()
                    }
                }
            }
        }

        // Wi-Fi Access Points List
        ListView {
            id: wifiView
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: 240
            spacing: 8
            clip: true
            model: backend.wifiList

            delegate: Rectangle {
                width: wifiView.width
                height: 52
                radius: 8
                color: wifiView.currentIndex === index ? "#162235" : "#11141c"
                border.color: wifiView.currentIndex === index ? "#00f5d4" : "#1c222e"
                border.width: wifiView.currentIndex === index ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12

                    Text {
                        text: modelData.ssid
                        color: "#ffffff"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: modelData.signal + "%  •  " + modelData.security
                        color: "#748096"
                        font.pixelSize: 14
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        wifiView.currentIndex = index
                        passField.forceActiveFocus()
                    }
                }
            }
        }

        // Selected Network Password & Connect Row with Show/Hide Toggle
        RowLayout {
            Layout.preferredWidth: parent.width
            spacing: 12
            visible: wifiView.currentIndex >= 0 && wifiView.count > 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: "#11141c"
                radius: 8
                border.color: passField.activeFocus ? "#00f5d4" : "#242c3d"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 8

                    TextField {
                        id: passField
                        Layout.fillWidth: true
                        placeholderText: "Enter Wi-Fi Password (leave empty if open)"
                        placeholderTextColor: "#4a5568"
                        echoMode: togglePassBtn.passwordVisible ? TextInput.Normal : TextInput.Password
                        color: "#ffffff"
                        font.pixelSize: 15
                        background: null
                    }

                    // Show / Hide Password Button
                    Button {
                        id: togglePassBtn
                        property bool passwordVisible: false
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 34
                        background: Rectangle {
                            color: togglePassBtn.down ? "#222c3c" : "#161b26"
                            radius: 6
                            border.color: togglePassBtn.passwordVisible ? "#00f5d4" : "#2d3748"
                            border.width: 1
                        }
                        contentItem: Text {
                            text: togglePassBtn.passwordVisible ? "Hide" : "Show"
                            color: togglePassBtn.passwordVisible ? "#00f5d4" : "#a0aec0"
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            passwordVisible = !passwordVisible
                        }
                    }
                }
            }

            Button {
                Layout.preferredHeight: 50
                Layout.preferredWidth: 140
                background: Rectangle {
                    color: "#162235"
                    radius: 8
                    border.color: "#00f5d4"
                }
                contentItem: Text {
                    text: "Connect"
                    color: "#00f5d4"
                    font.pixelSize: 15
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (wifiView.currentIndex >= 0) {
                        var targetSSID = backend.wifiList[wifiView.currentIndex].ssid
                        backend.connectWifi(targetSSID, passField.text)
                    }
                }
            }
        }

        // Bottom Action Row
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            spacing: 20

            Button {
                Layout.preferredWidth: 260
                Layout.preferredHeight: 52
                background: Rectangle {
                    radius: 26
                    color: "#00f5d4"
                }
                contentItem: Text {
                    text: "Continue"
                    color: "#07090e"
                    font.pixelSize: 17
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: navStack.push("LocaleStep.qml")
            }
        }
    }
}