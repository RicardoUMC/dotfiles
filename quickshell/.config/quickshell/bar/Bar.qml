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
    implicitHeight: 48

    // Sin márgenes en el PanelWindow — el efecto flotante lo da el padding interno
    margins {
        top: 0
        left: 0
        right: 0
    }

    // Fondo de la barra
    color: "transparent"

    Rectangle {
        // Márgenes internos para el efecto flotante
        anchors {
            fill: parent
            topMargin: 8
            leftMargin: 12
            rightMargin: 12
            bottomMargin: 0
        }
        radius: 10
        color: Qt.rgba(
            Colors.base01.r,
            Colors.base01.g,
            Colors.base01.b,
            0.33  // Ligera transparencia
        )

        // Borde sutil
        border {
            width: 1
            color: Qt.rgba(
                Colors.base03.r,
                Colors.base03.g,
                Colors.base03.b,
                0.33
            )
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 12
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
}
