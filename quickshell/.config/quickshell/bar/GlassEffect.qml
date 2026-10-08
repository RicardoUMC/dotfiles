import QtQuick
import Quickshell

// Bounded blur-region geometry for one visual surface. This is deliberately a
// Region, not an input mask or fullscreen catcher. The owning PanelWindow
// applies it through BackgroundEffect.blurRegion when glass/nativeBlur is on;
// unsupported compositor/API behavior is handled natively as a warning/no-op.
Region {
    // Kept as a named component so the visible region can be reused without
    // changing the surface's geometry or input ownership.
}
