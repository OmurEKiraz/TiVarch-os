import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: diskStep
    Component.onCompleted: backend.scanDisks()

    ColumnLayout {
        anchors.centerIn: parent
        width: 820
        spacing: 24

        Text {
            text: "Select Installation Drive"
            color: "#ffffff"
            font.pixelSize: 34
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        ListView {
            id: diskView
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: 300
            spacing: 12
            clip: true
            model: backend.disks

            delegate: Rectangle {
                width: diskView.width
                height: 72
                radius: 10
                color: diskView.currentIndex === index ? "#162235" : "#11141c"
                border.color: diskView.currentIndex === index ? "#00f5d4" : "#1e2433"
                border.width: diskView.currentIndex === index ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    Text {
                        text: modelData.device
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Text {
                        text: modelData.model
                        color: "#748096"
                        font.pixelSize: 15
                        Layout.fillWidth: true
                    }
                    Text {
                        text: modelData.size
                        color: "#00f5d4"
                        font.pixelSize: 16
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: diskView.currentIndex = index
                }
            }
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 300
            Layout.preferredHeight: 54
            enabled: backend.disks.length > 0 && diskView.currentIndex >= 0

            background: Rectangle {
                radius: 27
                color: parent.enabled ? "#00f5d4" : "#1e2433"
            }
            contentItem: Text {
                text: "Erase & Deploy TiVarch"
                color: parent.enabled ? "#07090e" : "#555"
                font.pixelSize: 17
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                var selected = backend.disks[diskView.currentIndex]
                session.targetDisk = selected.device
                backend.startInstallation(
                    session.targetDisk,
                    session.timezone,
                    session.keymap,
                    session.hostname,
                    session.username,
                    session.password
                )
                navStack.push("InstallStep.qml")
            }
        }
    }
}