import QtQuick
import QtQuick.Effects

// Stage-1 synthetic island material prototype. The texture below is wholly
// client-owned and controlled; it is not a live desktop backdrop or capture.
// This component is visual-only: it owns no input, focus, routing, or overlay.
Item {
    id: root

    // The next task may set this true for one explicitly selected island. It is
    // deliberately false here so an instance is safe and inert when disabled.
    property bool active: false
    property Item maskItem: null

    readonly property bool syntheticTexture: true

    visible: active && maskItem !== null
    focus: false

    Item {
        id: controlledTexture
        anchors.fill: parent
        visible: false
        clip: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#38506b" }
                GradientStop { position: 0.5; color: "#243342" }
                GradientStop { position: 1.0; color: "#17212b" }
            }
        }

        Rectangle {
            id: animatedHighlight
            x: -width
            width: Math.max(48, parent.width * 0.32)
            height: parent.height * 1.8
            y: -parent.height * 0.4
            rotation: 18
            color: "#8ec5ff"
            opacity: 0.07

            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation {
                    from: -animatedHighlight.width
                    to: controlledTexture.width
                    duration: 4200
                    easing.type: Easing.InOutSine
                }
                PauseAnimation { duration: 900 }
            }
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: controlledTexture
        visible: root.visible
        maskEnabled: root.visible
        maskSource: root.maskItem
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        blurEnabled: root.visible
        blur: 0.12
        blurMax: 4
    }
}
