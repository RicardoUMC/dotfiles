import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    implicitWidth: timeText.implicitWidth + 18
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacityOverlay)
        border {
            width: 1
            color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
        }
    }

    Text {
        id: timeText
        anchors.centerIn: parent
        color: Colors.text
        font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                const now = new Date()
                const days   = ["Dom","Lun","Mar","Mié","Jue","Vie","Sáb"]
                const months = ["Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"]
                timeText.text = `${days[now.getDay()]} ${String(now.getDate()).padStart(2,"0")} ${months[now.getMonth()]}  ${String(now.getHours()).padStart(2,"0")}:${String(now.getMinutes()).padStart(2,"0")}`
            }
        }
    }
}
