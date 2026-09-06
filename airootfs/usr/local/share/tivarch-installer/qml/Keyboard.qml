import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    height: 280
    color: "#161922"
    border.color: "#282c37"
    border.width: 1
    radius: 12

    property var targetField: null

    readonly property var rows: [
        ["1","2","3","4","5","6","7","8","9","0"],
        ["q","w","e","r","t","y","u","i","o","p"],
        ["a","s","d","f","g","h","j","k","l"],
        ["z","x","c","v","b","n","m"]
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Repeater {
            model: root.rows
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Repeater {
                    model: modelData
                    Button {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 52
                        text: modelData

                        contentItem: Text {
                            text: parent.text
                            color: "#ffffff"
                            font.pixelSize: 22
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.down ? "#3a4052" : (parent.hovered ? "#2b3040" : "#1e222d")
                            radius: 8
                            border.color: "#3e445b"
                        }
                        onClicked: {
                            if (root.targetField) root.targetField.text += text
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Button {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 52
                text: "Space"
                contentItem: Text { text: "Space"; color: "#fff"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.down ? "#3a4052" : "#1e222d"; radius: 8; border.color: "#3e445b" }
                onClicked: if (root.targetField) root.targetField.text += " "
            }

            Button {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 52
                text: "Backspace"
                contentItem: Text { text: "⌫"; color: "#ff6b6b"; font.pixelSize: 22; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.down ? "#3a4052" : "#1e222d"; radius: 8; border.color: "#3e445b" }
                onClicked: {
                    if (root.targetField && root.targetField.text.length > 0) {
                        root.targetField.text = root.targetField.text.slice(0, -1)
                    }
                }
            }
        }
    }
}