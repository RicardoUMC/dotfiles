// Tokyo City Terminal Dark — Base16
// Kept in sync with quickshell/theme/Colors.qml
// Note: not a pragma Singleton — SDDM QML engine does not support singleton registration.
// Import this file directly where needed.
import QtQuick 2.15

QtObject {
    readonly property color base00: "#171D23"
    readonly property color base01: "#1D252C"
    readonly property color base02: "#28323A"
    readonly property color base03: "#526270"
    readonly property color base04: "#B7C5D3"
    readonly property color base05: "#D8E2EC"
    readonly property color base06: "#F6F6F8"
    readonly property color base07: "#FBFBFD"
    readonly property color base08: "#D95468"
    readonly property color base09: "#FF9E64"
    readonly property color base0A: "#EBBF83"
    readonly property color base0B: "#8BD49C"
    readonly property color base0C: "#70E1E8"
    readonly property color base0D: "#539AFC"
    readonly property color base0E: "#B62D65"
    readonly property color base0F: "#DD9D82"

    readonly property color background:    base00
    readonly property color backgroundAlt: base01
    readonly property color surface:       base02
    readonly property color muted:         base03
    readonly property color textDim:       base04
    readonly property color text:          base05
    readonly property color textBright:    base06

    readonly property color red:     base08
    readonly property color orange:  base09
    readonly property color yellow:  base0A
    readonly property color green:   base0B
    readonly property color cyan:    base0C
    readonly property color blue:    base0D
    readonly property color magenta: base0E

    readonly property color accent: base0D

    readonly property string monoFont: "VictorMono Nerd Font"
    readonly property string sansFont: "Noto Sans"
}
