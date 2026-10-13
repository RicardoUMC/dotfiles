# Configurable Bar

**Status:** Configuration-only foundation implemented; rendering remains planned.
**Related current spec:** [Bar](bar.md)

This specification defines the future bar model and the implemented configuration foundation. The live shell still renders a top-anchored bar with left, center, and right islands, and the center dashboard remains embedded in that bar. The foundation normalizes and resolves declarative configuration but intentionally does not apply future placement or rendering choices.

## Design goals

- Let each monitor choose its bar position and visibility policy.
- Preserve the current wrapped-silhouette ornamentation as a first-class style.
- Offer a continuous bar style without forcing the current island geometry into it.
- Allow the center dashboard to be embedded in the bar or detached as an independent surface.
- Keep monitor seams usable for moving the pointer between adjacent outputs.

## Configuration model

Global configuration provides defaults. A monitor-specific configuration overrides only the values it declares. Runtime visibility and hover state belong to each monitor's `Bar` instance; they are never one global session-wide bar state.

Approved single-file schema:

```json
{
  "bar": {
    "screens": "all",
    "style": "silhouette",
    "defaults": {
      "position": "top",
      "visibility": "always",
      "style": "islands",
      "revealPolicy": "external-edges"
    }
  },
  "dashboard": { "attachment": "embedded" },
  "monitors": {
    "DP-1": {
      "bar": { "position": "bottom" },
      "dashboard": { "attachment": "detached" }
    }
  }
}
```

Legacy `bar.screens` and `bar.style` remain compatible with the current shell. Future defaults live under `bar.defaults`; `dashboard.attachment` is global, while `monitors.<ShellScreen.name>.bar` and `.dashboard` are sparse exact-name overrides. Unknown monitor names are inert, and monitor indexes or ordering are never used.

The normalized snapshot validates each enum and safely falls back to `top`, `always`, `islands`, `external-edges`, or `embedded` as appropriate. A successful reload replaces the normalized snapshot, so removed overrides inherit global defaults again. Malformed JSON preserves the last good snapshot. Hot reload uses the existing `Theme` `FileView` watcher and debounce.

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

The configuration foundation is implemented, but its future values are declarative only. Current behavior remains the baseline:

- `Bar.qml` is top-anchored and full-width.
- It is instantiated once per enabled screen.
- It renders left, center, and right islands.
- The center island expands in place into `CenterDashboard.qml`.
- Legacy `Theme.barStyle` still selects the existing silhouette/plain bar treatment.
- The future `style` value is normalized and resolved per screen, but is intentionally inert; `islands` preserves the current behavior by default.

This session does **not** implement placement, orientation, edge reveal, continuous rendering, disabled surface creation, detached dashboard rendering, or dynamic colors. The current top/always/islands/embedded defaults preserve behavior.

## Remaining implementation scope

- Applying resolved position and orientation to `Bar.qml`.
- Implementing edge reveal using only external edges.
- Rendering the `continuous` style and suppressing surface creation for `disabled`.
- Supporting a detached dashboard surface.
- Defining dynamic color behavior separately; this foundation does not implement it.
- Defining a compositor-specific cursor API or requiring a particular external auto-hide helper.
