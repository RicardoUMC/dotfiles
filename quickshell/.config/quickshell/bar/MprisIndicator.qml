import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../theme"

Item {
    id: root

    signal clicked()

    readonly property var player: {
        const players = Mpris.players.values
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    readonly property bool active: root.player !== null
        && (root.player.trackTitle !== "" || root.player.trackArtist !== "")

    visible: root.active
    implicitWidth: root.active ? chipRow.implicitWidth + 16 : 0
    implicitHeight: 26

    Behavior on implicitWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, 0.33)
        border {
            width: 1
            color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.3)
        }
    }

    RowLayout {
        id: chipRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.player?.playbackState === MprisPlaybackState.Playing ? "󰎆" : "󰎇"
            color: Colors.accent
            font { family: Colors.monoFont; pixelSize: 11 }
        }

        Text {
            text: {
                if (!root.player) return ""
                const title = root.player.trackTitle ?? ""
                return title.length > 28 ? title.slice(0, 28) + "…" : title
            }
            color: Colors.textDim
            font { family: Colors.uiFont; pixelSize: 11 }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
