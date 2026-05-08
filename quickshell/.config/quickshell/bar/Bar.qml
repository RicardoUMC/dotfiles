import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    // Anclaje — arriba, izquierda a derecha
    anchors {
        top: true
        left: true
        right: true
    }

    // Reserva espacio en el compositor — las ventanas no se enciman
    exclusionMode: ExclusionMode.Auto

    // Zona total reservada arriba (barra + margen flotante)
    implicitHeight: 37

    // Sin márgenes en el PanelWindow — el efecto flotante lo da el padding interno
    margins {
        top: 0
        left: 0
        right: 0
    }

    // Fondo de la barra
    color: "transparent"

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 12
            topMargin: 10
            bottomMargin: 0
        }
        spacing: 0

        // --- IZQUIERDA: Workspaces ---
        Workspaces {
            Layout.alignment: Qt.AlignVCenter
        }
        // --- DERECHA: Stats + Reloj ---
        Item { Layout.fillWidth: true }

        SystemStats {
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
