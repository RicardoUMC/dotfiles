import QtQuick
import QtQuick.Layouts
import "../theme"

Item {
    property bool expanded: false

    implicitWidth:  Math.max(timeText.implicitWidth, dateText.implicitWidth) + 18
    implicitHeight: clockColumn.implicitHeight + 8

    function updateClock() {
        const now = new Date()
        const days   = ["Dom","Lun","Mar","Mié","Jue","Vie","Sáb"]
        const months = ["Ene","Feb","Mar","Abr","May","Jun","Jul","Ago","Sep","Oct","Nov","Dic"]
        const timeStr = `${String(now.getHours()).padStart(2,"0")}:${String(now.getMinutes()).padStart(2,"0")}`
        const dateStr = `${days[now.getDay()]} ${String(now.getDate()).padStart(2,"0")} ${months[now.getMonth()]}`
        timeText.text = timeStr
        dateText.text = dateStr
    }

    onExpandedChanged: updateClock()

    Column {
        id: clockColumn
        anchors.centerIn: parent
        spacing: 2

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            color: Colors.text
            font { family: Colors.uiFont; pixelSize: Theme.fontSizeBody }
        }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            visible: expanded
            color: Colors.textDim
            font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
        }
    }

    // Debug visual bounds overlay (development scaffolding)
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: Theme.radiusSm
        border {
            width: Theme.debugBorderWidth
            color: Theme.debugBorderColor
        }
        visible: Theme.debugVisualBounds
        z: 999
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updateClock()
    }
}
