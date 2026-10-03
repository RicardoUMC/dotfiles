pragma Singleton
import QtQuick

// Shared motion vocabulary for the shell.
//
// Adapted from Caelestia's motion *principle* — animations are addressed by
// named intent (effects vs. spatial), never by per-call-site duration and
// easing literals — not by copying its code or its Material-3 curve table.
// The implementation is plain QML, driven by the existing `Theme.anim*`
// duration tokens plus one new global `Theme.animScale` knob.
//
// Two intents for now, deliberately kept minimal:
//   - Effects: short, non-overshooting. For state feedback on already-visible
//     content (opacity, color, small overlays).
//   - Spatial: longer, smooth deceleration. For geometry that moves or grows
//     (height/width/position), where a snappy curve reads as a snap.
//
// Timing defaults are inherited from `Theme`, so `anim.fast/normal/slow` keep
// answering for every call site that has not been migrated yet, and scale 1
// preserves the current timings exactly.
//
// Curves: `easing.bezierCurve` needs exact care on this Qt build.
//   - The list is read as control POINTS and must end at (1, 1). A bare
//     4-value CSS-style `cubic-bezier(x1, y1, x2, y2)` is rejected with
//     `QEasingCurve: Invalid bezier curve` and degrades SILENTLY to linear.
//   - Therefore every curve here is the 6-value form
//     [x1, y1, x2, y2, 1, 1].
//   - A declarative sub-property binding is accepted by qmllint but can be
//     dropped at runtime, so support is probed once against a real
//     `NumberAnimation` (`probe` below) instead of assumed. If the probe does
//     not confirm an applied curve, every intent falls back to a documented
//     built-in `Easing` type. This is what keeps the primitive portable across
//     Qt builds rather than quietly turning the shell's motion linear.
// Do not add `pragma ComponentBehavior: Bound` here: Qt 6.11 permits the
// singleton lookup across files but silently drops bound inline-component
// instances created by external Behavior call sites, making motion snap while
// qmllint still reports a clean result.
QtObject {
    id: root

    // True only once the probe has run and confirmed a curve actually applied.
    readonly property bool curveUsable: root.probeDone && root.probeApplied

    // Raw probe state; split so `curveUsable` never reports a provisional true.
    property bool probeDone: false
    property bool probeApplied: false

    // Tuning knob: 1.0 keeps the shell's current motion timing exactly.
    // Read from `Theme` so durations and scale stay hot-reloadable together.
    readonly property real durationScale: Theme.animScale

    // Effects intent: one fast step. Drives chip/panel state feedback.
    readonly property int effectsDuration: Math.max(1, Math.round(Theme.animFast * root.durationScale))

    // Spatial intent: the slowest family, for geometry that travels.
    readonly property int spatialDuration: Math.max(1, Math.round(Theme.animSlow * root.durationScale))

    // Curve control points, or empty when unsupported (the fallback types
    // below then take over, and an empty list keeps Qt from parsing a bad curve).
    readonly property var effectsCurve: root.curveUsable ? [0.31, 0.94, 0.34, 1.0, 1, 1] : []
    readonly property var spatialCurve: root.curveUsable ? [0.38, 1.0, 0.22, 1.0, 1, 1] : []

    // Fallback is `Easing.OutCubic`, the non-overshooting deceleration the shell
    // already uses for state transitions, so an unsupported host keeps the feel
    // it had before this primitive existed.
    readonly property int effectsEasing: root.curveUsable ? Easing.Bezier : Easing.OutCubic
    readonly property int spatialEasing: root.curveUsable ? Easing.Bezier : Easing.OutCubic

    // Call sites use these as drop-in animation types, and carry no timing of
    // their own:
    //   Behavior on opacity { Motion.Effects {} }
    //   Behavior on height  { Motion.Spatial {} }
    //   Behavior on color   { Motion.EffectsColor {} }

    // Short state feedback on a numeric property.
    component Effects : NumberAnimation {
        duration: Theme.animationsEnabled ? Motion.effectsDuration : 0
        easing.type: Motion.effectsEasing
        easing.bezierCurve: Motion.effectsCurve
    }

    // Same intent as Effects, for a color property (ColorAnimation is a
    // separate type; a NumberAnimation cannot interpolate colors).
    component EffectsColor : ColorAnimation {
        duration: Theme.animationsEnabled ? Motion.effectsDuration : 0
        easing.type: Motion.effectsEasing
        easing.bezierCurve: Motion.effectsCurve
    }

    // Smooth geometry change on a numeric property.
    component Spatial : NumberAnimation {
        duration: Theme.animationsEnabled ? Motion.spatialDuration : 0
        easing.type: Motion.spatialEasing
        easing.bezierCurve: Motion.spatialCurve
    }

    // One-shot capability probe. Declared as a real child object, not a
    // Component definition, so its onCompleted handler actually runs when the
    // singleton is first used — before any behavior animates, and never again.
    readonly property Item probe: Item {
        NumberAnimation {
            id: probeAnim
            duration: 1
        }

        Component.onCompleted: {
            // Assigned in the 6-value point form that this primitive ships.
            // The readback plus a shape check means a host that merely echoes
            // back whatever it was given still fails the probe.
            var controlPoints = [0.31, 0.94, 0.34, 1.0, 1, 1]
            probeAnim.easing.type = Easing.Bezier
            probeAnim.easing.bezierCurve = controlPoints

            var readBack = probeAnim.easing.bezierCurve
            root.probeApplied = readBack.length === controlPoints.length
                    && probeAnim.easing.valueForProgress(0.5) > 0.75
            root.probeDone = true
        }
    }
}
