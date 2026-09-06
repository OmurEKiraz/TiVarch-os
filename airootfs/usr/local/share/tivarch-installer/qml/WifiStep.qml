import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 24
    Layout.fillWidth: true

    signal nextStep()

    Component.onCompleted: {
        backend.updateNetworkStatus()
        backend.scanWifi()
    }

    Text {
        text: "Network Connection"
        color: "#ffffff"
        font.pixelSize: 36
        font.bold: true
        Layout.alignment: Qt.AlignHCenter
    }

    // Status Banner (Detects Ethernet vs Wi-Fi)
    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 800
        Layout.preferredHeight: 60
        radius: 10
        color: backend.netType === "Offline" ? "#2a151b" : "#0d2621"
        border.color: backend.netType === "Offline" ? "#e63946" : "#00f5d4"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Rectangle {
                width: 12; height: 12; radius: 6
                color: backend.netType === "Offline" ? "#e63946" : "#00f5d4"
            }

            Text {
                text: "Network Status: " + backend.netType + " (" + backend.netDetails + ")"
                color: "#ffffff"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            Button {
                text: "Refresh"
                Layout.preferredHeight: 36
                background: Rectangle { color: "#161b24"; radius: 6 }
                contentItem: Text { text: "Refresh"; color: "#00f5d4"; font.weight: Font.Bold }
                onClicked: {
                    backend.updateNetworkStatus()
                    backend.scanWifi()
                }
            }
        }
    }

    ListView {
        id: wifiList
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 800
        Layout.preferredHeight: 220
        spacing: 8
        clip: true
        model: backend.wifiList

        delegate: Rectangle {
            width: wifiList.width
            height: 52
            radius: 8
            color: wifiList.currentIndex === index ? "#1a2333" : "#10141d"
            border.color: wifiList.currentIndex === index ? "#00f5d4" : "#1c2331"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 14

                Text { text: modelData.ssid; color: "#ffffff"; font.pixelSize: 16; Layout.fillWidth: true }
                Text { text: modelData.signal + "% • " + modelData.security; color: "#718096"; font.pixelSize: 14 }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: wifiList.currentIndex = index
            }
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 14
        visible: wifiList.currentIndex >= 0

        TextField {
            id: passInput
            Layout.preferredWidth: 380
            Layout.preferredHeight: 48
            placeholderText: "Wi-Fi Password"
            echoMode: TextInput.Password
            color: "#ffffff"
            background: Rectangle { color: "#151924"; radius: 8; border.color: "#293247" }
        }

        Button {
            Layout.preferredHeight: 48
            Layout.preferredWidth: 140
            text: "Connect"
            background: Rectangle { color: "#00f5d4"; radius: 8 }
            contentItem: Text { text: "Connect"; color: "#07090e"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            onClicked: {
                var selected = wifiList.model[wifiList.currentIndex]
                backend.connectWifi(selected.ssid, passInput.text)
            }
        }
    }

    Button {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: 52
        Layout.preferredWidth: 220
        background: Rectangle { color: "#3a86ff"; radius: 26 }
        contentItem: Text { text: "Proceed"; color: "#ffffff"; font.pixelSize: 17; font.weight: Font.Bold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        onClicked: root.nextStep()
    }
}