import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property var colors

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 2

        Text {
            id: timeText
            Layout.alignment: Qt.AlignRight
            font.family: root.colors.monoFont
            font.pixelSize: 52
            font.bold: true
            color: root.colors.text

            function update() { text = Qt.formatTime(new Date(), "HH:mm") }
            Component.onCompleted: update()
        }

        Text {
            id: dateText
            Layout.alignment: Qt.AlignRight
            font.family: root.colors.monoFont
            font.pixelSize: 13
            color: root.colors.muted

            function update() {
                const d = new Date()
                const days   = ["domingo","lunes","martes","miércoles","jueves","viernes","sábado"]
                const months = ["enero","febrero","marzo","abril","mayo","junio",
                                "julio","agosto","septiembre","octubre","noviembre","diciembre"]
                text = days[d.getDay()] + ", " + d.getDate() + " de " + months[d.getMonth()] + " de " + d.getFullYear()
            }
            Component.onCompleted: update()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: { timeText.update(); dateText.update() }
    }
}
