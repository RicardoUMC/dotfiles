import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property var colors
    property bool failed: false

    signal accepted(string password)

    implicitWidth: 280
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            height: 42
            radius: 8
            color: root.colors.surface
            border.width: 1
            border.color: input.activeFocus
                ? Qt.rgba(root.colors.accent.r, root.colors.accent.g, root.colors.accent.b, 0.7)
                : root.failed
                    ? Qt.rgba(root.colors.red.r, root.colors.red.g, root.colors.red.b, 0.5)
                    : Qt.rgba(root.colors.muted.r, root.colors.muted.g, root.colors.muted.b, 0.3)

            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 8

                Text {
                    text: root.failed ? "󰌾" : "󰍁"
                    font.family: root.colors.monoFont
                    font.pixelSize: 16
                    color: root.failed ? root.colors.red : root.colors.muted
                }

                TextInput {
                    id: input
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: root.colors.text
                    font.family: root.colors.uiFont
                    font.pixelSize: 14
                    selectionColor: Qt.rgba(root.colors.accent.r, root.colors.accent.g, root.colors.accent.b, 0.3)
                    focus: true
                    clip: true

                    Keys.onReturnPressed: root.accepted(input.text)
                    Keys.onEnterPressed:  root.accepted(input.text)
                    onTextChanged: root.failed = false

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Contraseña"
                        color: root.colors.muted
                        font.family: root.colors.uiFont
                        font.pixelSize: 14
                        opacity: 0.5
                        visible: input.text.length === 0
                    }
                }

                Text {
                    text: "󰅖"
                    font.family: root.colors.monoFont
                    font.pixelSize: 14
                    color: root.colors.muted
                    opacity: 0.6
                    visible: input.text.length > 0

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: input.text = ""
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Contraseña incorrecta"
            color: root.colors.red
            font.family: root.colors.uiFont
            font.pixelSize: 12
            opacity: root.failed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 42
            radius: 8
            color: loginArea.containsMouse
                ? Qt.rgba(root.colors.accent.r, root.colors.accent.g, root.colors.accent.b, 0.25)
                : Qt.rgba(root.colors.accent.r, root.colors.accent.g, root.colors.accent.b, 0.15)
            border.width: 1
            border.color: Qt.rgba(root.colors.accent.r, root.colors.accent.g, root.colors.accent.b, 0.5)

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "Iniciar sesión"
                font.family: root.colors.uiFont
                font.pixelSize: 14
                font.weight: Font.Medium
                color: root.colors.accent
            }

            MouseArea {
                id: loginArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.accepted(input.text)
            }
        }
    }

    function clear() { input.text = "" }
    function focusInput() { input.forceActiveFocus() }
}
