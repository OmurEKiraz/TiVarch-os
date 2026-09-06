import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: appWindow
    visible: true
    width: 1920
    height: 1080
    visibility: Window.FullScreen
    color: "#0a0c12"

    // Global Installer Data Store
    QtObject {
        id: session
        property string targetDisk: ""
        property string timezone: "UTC"
        property string keymap: "us"
        property string hostname: "tivarch-tv"
        property string username: "tivuser"
        property string password: ""
    }

    StackView {
        id: navStack
        anchors.fill: parent
        initialItem: "WifiStep.qml"
    }

    Connections {
        target: backend
        function onProgressChanged(val, msg) {
            if (navStack.currentItem && navStack.currentItem.objectName === "installView") {
                navStack.currentItem.progress = val
                navStack.currentItem.status = msg
            }
        }
        function onInstallFinished(success, msg) {
            if (navStack.currentItem && navStack.currentItem.objectName === "installView") {
                navStack.currentItem.isDone = true
                navStack.currentItem.status = msg
            }
        }
    }
}