import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property int progressValue: 0
    property string statusText: "Initializing hardware environment..."
    property bool isFinished: false

    ColumnLayout {
        anchors.centerIn: parent
        width: 800
        spacing: 36

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            Text {
                text: root.isFinished ? "Ready for Use" : "Installing System"
                color: "#ffffff"
                font.pixelSize: 36
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: root.isFinished ? "TiVarch has been deployed to the internal drive." : "Writing rootfs image and setting up bootloader..."
                color: "#7e889b"
                font.pixelSize: 18
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Clean Custom Progress Bar
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: 12
            radius: 6
            color: "#141824"

            Rectangle {
                height: parent.height
                radius: 6
                width: Math.max(12, parent.width * (root.progressValue / 100))
                color: "#00f5d4"
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }

        // Live Log/Status Message
        Text {
            text: root.statusText
            color: "#00f5d4"
            font.pixelSize: 16
            font.family: "Monospace"
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.9
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 280
            Layout.preferredHeight: 58
            visible: root.isFinished

            background: Rectangle {
                radius: 29
                color: "#3a86ff"
            }

            contentItem: Text {
                text: "Reboot System"
                color: "#ffffff"
                font.pixelSize: 18
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: backend.rebootSystem()
        }
    }
}