import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property string selectedTarget: ""
    signal startInstall(string target)

    Component.onCompleted: backend.scanDisks()

    Connections {
        target: backend
        function onDisksChanged() {
            if (backend.disks.length > 0 && root.selectedTarget === "") {
                diskList.currentIndex = 0
                root.selectedTarget = backend.disks[0].device
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: 860
        spacing: 28

        // Header section
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Text {
                text: "Select Destination Storage"
                color: "#ffffff"
                font.pixelSize: 38
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Choose the internal drive where TiVarch will be installed."
                color: "#7e889b"
                font.pixelSize: 18
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Storage Cards List
        ListView {
            id: diskList
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: 280
            spacing: 14
            clip: true
            model: backend.disks

            delegate: Item {
                width: diskList.width
                height: 80

                readonly property bool isSelected: diskList.currentIndex === index

                Rectangle {
                    id: cardBg
                    anchors.fill: parent
                    radius: 12
                    color: isSelected ? "#141d2b" : "#0f1219"
                    border.color: isSelected ? "#00f5d4" : "#1a202c"
                    border.width: isSelected ? 2 : 1
                    scale: isSelected ? 1.02 : 1.0

                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        spacing: 20

                        // Drive Icon Indicator
                        Rectangle {
                            width: 42
                            height: 42
                            radius: 8
                            color: isSelected ? "#1b333a" : "#171c26"

                            Text {
                                anchors.centerIn: parent
                                text: "SSD"
                                color: isSelected ? "#00f5d4" : "#555f73"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                        }

                        ColumnLayout {
                            spacing: 3
                            Text {
                                text: modelData.device
                                color: "#ffffff"
                                font.pixelSize: 19
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: modelData.model
                                color: "#748096"
                                font.pixelSize: 14
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Capacity Pill
                        Rectangle {
                            height: 32
                            width: capacityText.implicitWidth + 24
                            radius: 16
                            color: isSelected ? "#09332e" : "#171a22"

                            Text {
                                id: capacityText
                                anchors.centerIn: parent
                                text: modelData.size
                                color: isSelected ? "#00f5d4" : "#a0aec0"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            diskList.currentIndex = index
                            root.selectedTarget = modelData.device
                        }
                    }
                }
            }
        }

        // Action CTA & Warning
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            Button {
                id: installBtn
                Layout.preferredWidth: 340
                Layout.preferredHeight: 60
                Layout.alignment: Qt.AlignHCenter
                // ONLY enable the button if a real /dev/ disk is selected
                enabled: diskList.currentIndex >= 0 && root.selectedTarget.startsWith("/dev/")

                background: Rectangle {
                    radius: 30
                    color: parent.enabled ? (parent.down ? "#00c4aa" : "#00f5d4") : "#161b24"
                }

                contentItem: Text {
                    text: "Erase & Install TiVarch"
                    color: parent.enabled ? "#07090e" : "#444c5c"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (root.selectedTarget && root.selectedTarget.startsWith("/dev/")) {
                        root.startInstall(root.selectedTarget)
                    }
                }
            }

            Text {
                text: "All existing partitions on the selected disk will be formatted."
                color: "#e63946"
                font.pixelSize: 14
                opacity: 0.85
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}