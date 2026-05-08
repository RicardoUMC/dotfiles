import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"

FloatingWindow {
    id: root
    title: "qs-launcher-centered"
    color: "transparent"

    property string mode: "search"       // "search" | "navigate"
    property string filterText: ""
    property int selectedRow: 0          // índice dentro de filteredModel

    visible: false

    function toggleOpen() {
        if (visible) {
            visible = false
        } else {
            mode = "search"
            filterText = ""
            selectedRow = 0
            visible = true
        }
    }

    onVisibleChanged: {
        if (visible) keyHandler.forceActiveFocus()
    }

    // ── Modelo filtrado ───────────────────────────────────────────────
    // Copia solo las entradas que coinciden con filterText.
    // selectedRow es un índice REAL dentro de este modelo — sin conversión.
    ListModel {
        id: filteredModel
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { rebuildModel() }
    }

    // Reconstruye filteredModel cuando cambia el texto o al abrir
    onFilterTextChanged: rebuildModel()
    Component.onCompleted: rebuildModel()

    function rebuildModel() {
        filteredModel.clear()
        const filter = root.filterText.toLowerCase()
        const apps = DesktopEntries.applications.values
        if (!apps) return
        for (let i = 0; i < apps.length; i++) {
            const entry = apps[i]
            if (!entry) continue
            if (filter === "" || entry.name.toLowerCase().includes(filter)) {
                filteredModel.append({ "name": entry.name, "comment": entry.comment ?? "", "entryIndex": i })
            }
        }
        if (root.selectedRow >= filteredModel.count) {
            root.selectedRow = 0
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, 0.96)
        border {
            width: 1
            color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.4)
        }

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 10

            // ── Buscador ─────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 38
                radius: 8
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.8)
                border {
                    width: 1
                    color: root.mode === "search"
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.6)
                        : Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.3)
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 8

                    Text {
                        text: root.mode === "search" ? "" : ""
                        color: root.mode === "search" ? Colors.accent : Colors.muted
                        font { family: "CaskaydiaMono Nerd Font"; pixelSize: 14 }
                    }

                    Item {
                        Layout.fillWidth: true
                        height: 24

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.filterText.length > 0
                                ? root.filterText
                                : (root.mode === "search" ? "Buscar apps..." : "Pulsa 'i' para buscar")
                            color: root.filterText.length > 0 ? Colors.text : Colors.muted
                            font { family: "CaskaydiaMono Nerd Font"; pixelSize: 13 }
                            opacity: root.filterText.length > 0 ? 1.0 : 0.5
                        }
                    }
                }
            }

            // ── Lista de apps ────────────────────────────────────
            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: filteredModel
                currentIndex: root.selectedRow

                delegate: Rectangle {
                    id: delegateItem
                    required property string name
                    required property string comment
                    required property int entryIndex
                    required property int index

                    readonly property bool isSelected: root.selectedRow === index

                    width: appList.width
                    height: 40
                    radius: 6
                    color: isSelected
                        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.2)
                        : mouseArea.containsMouse
                            ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.08)
                            : "transparent"
                    border {
                        width: isSelected ? 1 : 0
                        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.4)
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 10

                        Text {
                            text: delegateItem.name
                            color: delegateItem.isSelected ? Colors.text : Colors.textDim
                            font {
                                family: "CaskaydiaMono Nerd Font"
                                pixelSize: 13
                                bold: delegateItem.isSelected
                            }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: delegateItem.comment
                            color: Colors.muted
                            font { family: "CaskaydiaMono Nerd Font"; pixelSize: 11 }
                            elide: Text.ElideRight
                            Layout.maximumWidth: 180
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: launchAt(delegateItem.entryIndex)
                        onEntered: root.selectedRow = delegateItem.index
                    }
                }
            }

            // ── Hint ─────────────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.mode === "search"
                    ? "↵ abrir · ↑↓ mover · Esc navegar"
                    : "↵ abrir · j/k ↑↓ mover · Esc cerrar"
                color: Colors.muted
                font { family: "CaskaydiaMono Nerd Font"; pixelSize: 10 }
                opacity: 0.5
            }
        }

        // ── Manejador de teclado ──────────────────────────────────────
        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                const key = event.key

                if (root.mode === "search") {
                    if (key === Qt.Key_Escape) {
                        root.mode = "navigate"
                        event.accepted = true

                    } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                        launchSelected()
                        event.accepted = true

                    } else if (key === Qt.Key_Down) {
                        moveSelection(1)
                        event.accepted = true

                    } else if (key === Qt.Key_Up) {
                        moveSelection(-1)
                        event.accepted = true

                    } else if (key === Qt.Key_Backspace) {
                        root.filterText = root.filterText.slice(0, -1)
                        event.accepted = true

                    } else if (event.text && event.text.length > 0 && !event.modifiers) {
                        root.filterText += event.text
                        event.accepted = true
                    }

                } else { // navigate
                    if (key === Qt.Key_Escape) {
                        root.visible = false
                        event.accepted = true

                    } else if (key === Qt.Key_J || key === Qt.Key_Down) {
                        moveSelection(1)
                        event.accepted = true

                    } else if (key === Qt.Key_K || key === Qt.Key_Up) {
                        moveSelection(-1)
                        event.accepted = true

                    } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                        launchSelected()
                        event.accepted = true

                    } else if (key === Qt.Key_I) {
                        root.mode = "search"
                        event.accepted = true
                    }
                }
            }

            function launchSelected() {
                if (filteredModel.count === 0) return
                const row = filteredModel.get(root.selectedRow)
                if (!row) return
                launchAt(row.entryIndex)
            }

            function moveSelection(delta) {
                const count = filteredModel.count
                if (count === 0) return
                root.selectedRow = (root.selectedRow + delta + count) % count
                appList.positionViewAtIndex(root.selectedRow, ListView.Contain)
            }
        }
    }

    // Lanza una entrada por su índice en DesktopEntries.applications
    function launchAt(idx) {
        const entry = DesktopEntries.applications.values[idx]
        if (entry) {
            entry.execute()
            root.visible = false
        }
    }
}
