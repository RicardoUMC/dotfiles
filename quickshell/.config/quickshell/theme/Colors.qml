pragma Singleton
import QtQuick

QtObject {
    // Tokyo City Terminal Dark — Base16
    // https://tinted-theming.github.io/tinted-gallery/#base16-tokyo-city-terminal-dark

    // Backgrounds
    readonly property color base00: "#171D23"  // Fondo principal
    readonly property color base01: "#1D252C"  // Fondo secundario
    readonly property color base02: "#28323A"  // Selección, highlights
    readonly property color base03: "#526270"  // Comentarios, texto deshabilitado

    // Foregrounds
    readonly property color base04: "#B7C5D3"  // Texto oscuro
    readonly property color base05: "#D8E2EC"  // Texto principal
    readonly property color base06: "#F6F6F8"  // Texto claro
    readonly property color base07: "#FBFBFD"  // Texto muy claro

    // Accent colors
    readonly property color base08: "#D95468"  // Rojo — errores
    readonly property color base09: "#FF9E64"  // Naranja
    readonly property color base0A: "#EBBF83"  // Amarillo
    readonly property color base0B: "#8BD49C"  // Verde — éxito
    readonly property color base0C: "#70E1E8"  // Cyan
    readonly property color base0D: "#539AFC"  // Azul — accent principal
    readonly property color base0E: "#B62D65"  // Magenta
    readonly property color base0F: "#DD9D82"  // Marrón/salmón

    // Aliases semánticos — usá estos en los componentes, no los base directamente
    readonly property color background:     base00
    readonly property color backgroundAlt:  base01
    readonly property color surface:        base02
    readonly property color muted:          base03
    readonly property color textDim:        base04
    readonly property color text:           base05
    readonly property color textBright:     base06
    readonly property color textWhite:      base07

    readonly property color red:     base08
    readonly property color orange:  base09
    readonly property color yellow:  base0A
    readonly property color green:   base0B
    readonly property color cyan:    base0C
    readonly property color blue:    base0D
    readonly property color magenta: base0E
    readonly property color brown:   base0F

    readonly property color accent: base0D  // Azul — color de acento global
}
