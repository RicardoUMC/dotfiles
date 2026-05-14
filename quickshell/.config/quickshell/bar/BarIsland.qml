import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../theme"

Item {
    id: root

    property real bgOpacity:     Theme.islandBgOpacity
    property real borderOpacity: Theme.islandBorderOpacity
    property real blurRadius:    Theme.islandBlur

    property int spacing: Theme.spacingSm

    // Children placed here are laid out in a row inside the island
    default property alias contentData: innerRow.data

    implicitWidth:  innerRow.implicitWidth  + Theme.islandPaddingH * 2
    implicitHeight: Math.max(innerRow.implicitHeight, 26) + Theme.islandPaddingV * 2

    // Background — rendered first, blurred via MultiEffect
    Rectangle {
        id: bgSource
        anchors.fill: parent
        radius: Theme.radiusPill
        color: Qt.rgba(Colors.base01.r, Colors.base01.g, Colors.base01.b, root.bgOpacity)
        visible: false
    }

    MultiEffect {
        source: bgSource
        anchors.fill: bgSource
        blurEnabled: root.blurRadius > 0
        blur: Math.min(root.blurRadius / 64, 1.0)
        blurMax: 32
    }

    // Crisp border ring on top
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: "transparent"
        border {
            width: 1
            color: Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, root.borderOpacity)
        }
    }

    RowLayout {
        id: innerRow
        anchors {
            fill: parent
            leftMargin:   Theme.islandPaddingH
            rightMargin:  Theme.islandPaddingH
            topMargin:    Theme.islandPaddingV
            bottomMargin: Theme.islandPaddingV
        }
        spacing: root.spacing
    }
}
