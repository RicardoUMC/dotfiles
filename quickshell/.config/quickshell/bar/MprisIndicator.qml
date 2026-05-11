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
        NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, Theme.opacityOverlay)
        border {
            width: 1
            color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, Theme.opacityBorder)
        }
    }

    RowLayout {
        id: chipRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.player?.playbackState === MprisPlaybackState.Playing ? "󰎆" : "󰎇"
            color: Colors.accent
            font { family: Colors.monoFont; pixelSize: Theme.fontSizeLabel }
        }

        Text {
            text: {
                if (!root.player) return ""
                const title = root.player.trackTitle ?? ""
                return title.length > 28 ? title.slice(0, 28) + "…" : title
            }
            color: Colors.textDim
            font { family: Colors.uiFont; pixelSize: Theme.fontSizeLabel }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
