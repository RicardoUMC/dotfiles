# Configurable Bar

**Status:** Planned — design captured, implementation not started.
**Related current spec:** [Bar](bar.md)

This specification defines the future bar model. It does not change the current implementation: the live shell still renders a top-anchored bar with left, center, and right islands, and the center dashboard remains embedded in that bar.

## Design goals

- Let each monitor choose its bar position and visibility policy.
- Preserve the current wrapped-silhouette ornamentation as a first-class style.
- Offer a continuous bar style without forcing the current island geometry into it.
- Allow the center dashboard to be embedded in the bar or detached as an independent surface.
- Keep monitor seams usable for moving the pointer between adjacent outputs.

## Configuration model

Global configuration provides defaults. A monitor-specific configuration overrides only the values it declares. Runtime visibility and hover state belong to each monitor's `Bar` instance; they are never one global session-wide bar state.

Conceptual shape:

```json
{
  "bar": {
    "position": "top",
    "visibility": "always",
    "style": "islands",
    "revealPolicy": "external-edges"
  },
  "dashboard": {
    "attachment": "embedded"
  }
}
```

Monitor overrides follow the existing name-based monitor identity rule. They must not use monitor indexes or assume a stable ordering.

## Position

| Value | Meaning |
|---|---|
| `top` | Horizontal bar anchored to the top edge. |
| `bottom` | Horizontal bar anchored to the bottom edge. |
| `left` | Vertical bar anchored to the left edge. |
| `right` | Vertical bar anchored to the right edge. |

Changing position changes layout orientation, anchors, reserved edge, hit regions, and ornament placement together. It is not a visual rotation of the current top-bar surface.

## Visibility

| Value | Meaning |
|---|---|
| `always` | The bar remains visible and reserves its configured edge space. |
| `edge-reveal` | The bar is hidden or reduced to a reveal strip and appears when the pointer reaches its eligible edge. |
| `disabled` | No bar surface is created for that monitor. |

`edge-reveal` is evaluated independently for every monitor. A monitor becoming revealed must not reveal bars on other monitors.

### Reveal boundary rule

Reveal strips may be placed only on an external edge of the output layout. A shared seam between adjacent monitors is not a generic layer-shell edge and must remain free for pointer traversal. The implementation must derive eligible edges from the actual `ShellScreen` geometries (`x`, `y`, `width`, and `height`) rather than from monitor order or count.

If a monitor has no eligible external edge for the selected position, the bar remains usable through an explicit shortcut or IPC action; the implementation must not create a seam-capturing hot zone as a fallback.

## Visual styles

| Value | Meaning |
|---|---|
| `islands` | Separate left/right (and any future attached center) surfaces using the wrapped silhouette, curves, gaps, masks, and ornamental transitions. |
| `continuous` | A continuous bar surface spanning the configured bar axis. It may use a different background and transition grammar. |

The existing curves, wraps, notch corners, and ornamental tokens remain the canonical `islands` style. Selecting `continuous` may reinterpret or omit those details, but implementing it must not remove or alter the current island style.

## Dashboard attachment

| Value | Meaning |
|---|---|
| `embedded` | The dashboard is visually and interactively attached to the bar. It may expand from an island or another bar region without becoming a separate conceptual owner. |
| `detached` | The dashboard is an independent screen-pinned surface that can be positioned and managed separately from the bar. |

Attachment is independent from bar position, visibility, and style. All combinations are valid in the design, including an embedded dashboard in island mode and a detached dashboard in continuous mode.

The dashboard must be separated as a component boundary before implementation, even when `embedded` is the default. This prevents future bar placement or visibility changes from coupling dashboard state to bar geometry.

## Monitor and layer-shell constraints

- Create at most one bar view per enabled monitor, bound explicitly to that `ShellScreen`.
- Keep per-monitor reveal, reservation, and dashboard attachment state separate.
- When visible, reserve only the configured edge and the bar's actual occupied size.
- When hidden, remove the normal reservation while retaining only the minimal reveal mechanism required by the selected policy.
- Interactive bar and dashboard surfaces remain `Top`; transient notification and OSD surfaces remain `Overlay`.
- No reveal behavior may depend on a compositor-selected output or an unpinned `PanelWindow`.

## Compatibility with the current shell

The current implementation remains the baseline until this design is implemented:

- `Bar.qml` is top-anchored and full-width.
- It is instantiated once per enabled screen.
- It renders left, center, and right islands.
- The center island expands in place into `CenterDashboard.qml`.
- `Theme.barStyle` currently selects the existing silhouette/plain bar treatment; it is not yet the future `islands`/`continuous` mode described here.

## Out of scope

- Implementing the new configuration keys.
- Refactoring `Bar.qml` or `CenterDashboard.qml`.
- Choosing final default values for every future token.
- Defining a compositor-specific cursor API or requiring a particular external auto-hide helper.
