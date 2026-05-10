import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property var colors

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2

        Text {
            id: timeText
            Layout.alignment: Qt.AlignHCenter
            font.family: root.colors.monoFont
            font.pixelSize: 52
            font.bold: true
            color: root.colors.text

            function update() { text = Qt.formatTime(new Date(), "HH:mm") }
            Component.onCompleted: update()
        }

        Text {
            id: dateText
            Layout.alignment: Qt.AlignHCenter
            font.family: root.colors.monoFont
            font.pixelSize: 13
            color: root.colors.muted

            function update() {
                text = Qt.formatDate(new Date(), "dddd, d 'de' MMMM 'de' yyyy")
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
