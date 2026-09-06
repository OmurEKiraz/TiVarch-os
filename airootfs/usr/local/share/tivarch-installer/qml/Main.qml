import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    visible: true
    width: 1920
    height: 1080
    visibility: Window.FullScreen
    color: "#08090d"

    property string finalTarget: ""
    property string finalTimezone: "UTC"
    property string finalKeymap: "us"
    property string finalHostname: "tivarch"
    property string finalUsername: "root"
    property string finalPassword: ""
    property bool finalIsRoot: true
    property int currentStep: 0

    // Shortcut: Ctrl+Alt+T for emergency debug terminal
    Shortcut {
        sequences: ["Ctrl+Alt+T", "Ctrl+Alt+t"]
        onActivated: backend.openDebugTerminal()
    }

    Item {
        id: stage
        anchors.centerIn: parent
        width: 1200
        height: 840

        // Step Dots (5 steps total now)
        Row {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 40
            spacing: 8

            Repeater {
                model: 5
                Rectangle {
                    width: index === window.currentStep ? 30 : 8
                    height: 6
                    radius: 3
                    color: index === window.currentStep ? "#00f5d4" : "#1f2430"
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }
        }

        Item {
            anchors.fill: parent
            anchors.topMargin: 90

            // 0: Network
            WifiStep {
                anchors.fill: parent
                visible: window.currentStep === 0
                onNextStep: window.currentStep = 1
            }

            // 1: Locale & Timezone
            LocaleStep {
                anchors.fill: parent
                visible: window.currentStep === 1
                onNextStep: {
                    window.finalKeymap = selectedKeymap
                    window.finalTimezone = selectedTimezone
                    window.currentStep = 2
                }
            }

            // 2: User Configuration
            UserStep {
                anchors.fill: parent
                visible: window.currentStep === 2
                onNextStep: function(host, user, pass, isRoot) {
                    window.finalHostname = host
                    window.finalUsername = user
                    window.finalPassword = pass
                    window.finalIsRoot = isRoot
                    window.currentStep = 3
                }
            }

            // 3: Storage Selection
            DiskStep {
                anchors.fill: parent
                visible: window.currentStep === 3
                onStartInstall: function(target) {
                    window.finalTarget = target
                    window.currentStep = 4
                    backend.startInstall(
                        window.finalTarget,
                        window.finalTimezone,
                        window.finalKeymap,
                        window.finalHostname,
                        window.finalUsername,
                        window.finalPassword,
                        window.finalIsRoot
                    )
                }
            }

            // 4: Progress & Deploy
            InstallStep {
                id: installStepView
                anchors.fill: parent
                visible: window.currentStep === 4
            }
        }
    }

    Connections {
        target: backend
        function onInstallProgressChanged(percent, desc) {
            installStepView.progressValue = percent
            installStepView.statusText = desc
        }
        function onInstallFinishedChanged(success, msg) {
            installStepView.isFinished = success
            installStepView.statusText = msg
        }
    }
}