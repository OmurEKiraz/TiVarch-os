import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    objectName: "installView"
    property int progress: 0
    property string status: "Preparing storage..."
    property bool isDone: false

    ColumnLayout {
        anchors.centerIn: parent
        width: 800
        spacing: 24

        // Title
        Text {
            text: isDone ? "Setup Complete" : "Installing TiVarch OS"
            color: "#ffffff"
            font.pixelSize: 36
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        // Persistent Warning Badge (Only during installation)
        Rectangle {
            visible: !isDone
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 40
            Layout.preferredWidth: warningRow.implicitWidth + 32
            radius: 20
            color: "#26EF4444"
            border.color: "#EF4444"
            border.width: 1

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !isDone
                NumberAnimation { from: 1.0; to: 0.5; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.5; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }

            RowLayout {
                id: warningRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "⚠️"
                    font.pixelSize: 15
                }

                Text {
                    text: "Do not power off or unplug the system during installation"
                    color: "#FCA5A5"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }

        // Animated Spinner (Only during installation)
        Item {
            visible: !isDone
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48

            Rectangle {
                id: spinner
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.color: "#161b26"
                border.width: 4

                // Spinning arc highlight
                Rectangle {
                    width: parent.width
                    height: parent.height
                    radius: width / 2
                    color: "transparent"
                    border.color: "#00f5d4"
                    border.width: 4
                    clip: true

                    // Masks half of the circle to create the arc
                    Rectangle {
                        width: parent.width
                        height: parent.height / 2
                        color: "#0c1017" // Match background to cut arc
                    }
                }

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: !isDone
                }
            }
        }

        // Progress Bar
        Rectangle {
            Layout.fillWidth: true
            height: 12
            radius: 6
            color: "#161b26"

            Rectangle {
                height: parent.height
                radius: 6
                width: Math.max(parent.height, parent.width * (progress / 100))
                color: "#00f5d4"
                Behavior on width { NumberAnimation { duration: 250 } }
            }
        }

        // Status Line + Percentage
        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: status
                color: "#00f5d4"
                font.pixelSize: 15
                font.family: "Monospace"
                elide: Text.ElideRight
            }

            Text {
                text: progress + "%"
                color: "#ffffff"
                font.pixelSize: 15
                font.bold: true
            }
        }

        // Reboot Button (Appears only when done)
        Button {
            visible: isDone
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 240
            Layout.preferredHeight: 52
            background: Rectangle { 
                color: parent.down ? "#2b6cb0" : "#3a86ff" 
                radius: 26 
            }
            contentItem: Text {
                text: "Reboot System"
                color: "#ffffff"
                font.pixelSize: 17
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: backend.reboot()
        }
    }
}