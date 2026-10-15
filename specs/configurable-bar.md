# Configurable Bar

**Status:** Configuration foundation, `disabled` visibility filtering, top/bottom baseline positioning, left/right physical placement, endpoint order/content policies, and the integrated service divider are implemented. Left reuses the horizontal top island source and applies a 90-degree counter-clockwise rotation to visible notch masks, decorative wraps, and bounded native blur Regions; content remains upright and stacked vertically, with left-side overlay offsets following the vertical bar geometry. The service divider supports inward-facing `arc`, legacy `hairline`, and `none` modes. Edge reveal, continuous style, and detached dashboard rendering remain inert. Manual pointer-level dashboard/input verification is still pending; this document does not claim native review approval.
**Related current spec:** [Bar](bar.md)

This specification defines the configurable bar model and its current implementation boundary. Each `Bar` resolves its position through `Theme.effectiveBarConfig(screenName)`, so exact-name monitor overrides can place the existing island bar at the top, bottom, left, or right edge. The top position remains the baseline behavior.

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
      "revealPolicy": "external-edges",
      "order": ["workspaces", "services"],
      "content": {
        "workspaceMode": "numbers",
        "appMode": "active-icon",
        "clockMode": "auto"
      },
      "divider": "arc",
      "motion": "calm"
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

Legacy `bar.screens` and `bar.style` remain compatible with the current shell. Future defaults live under `bar.defaults`; `dashboard.attachment` is global, while `monitors.<ShellScreen.name>.bar` and `.dashboard` are sparse exact-name overrides. Unknown monitor names are inert, and monitor indexes or ordering are never used. Selection uses exact `ShellScreen.name` identity and is N-monitor generic.

The normalized snapshot validates each enum and safely falls back to `top`, `always`, `islands`, `external-edges`, `embedded`, `workspaces -> services`, numeric workspace indicators, the active application icon, automatic clock orientation, `arc`, or `calm` as appropriate. A successful reload replaces the normalized snapshot, so removed overrides inherit global defaults again. Malformed JSON preserves the last good snapshot. Hot reload uses the existing `Theme` `FileView` watcher and debounce.

## Position

| Value | Meaning |
|---|---|
| `top` | Horizontal bar anchored to the top edge. |
| `bottom` | Horizontal bar anchored to the bottom edge. |
| `left` | Vertical bar anchored to the left edge. |
| `right` | Vertical bar anchored to the right edge. |

Changing position changes layout orientation, anchors, reserved edge, hit regions, and ornament placement together. Top/bottom remain horizontal baseline placements; bottom mirrors the top visible masks and wraps around a centered vertical transform, including edge-aware native-blur geometry and the bottom-center `CenterPanel` cutout. Left is implemented by reusing one canonical horizontal top-island source, centering it before a 90-degree counter-clockwise rotation with `(u,v) -> (v,W-u)`, and consuming that same body/cap/wrap geometry for debug and production masks; content remains upright and stacked vertically, with the logical endpoint order resolved independently from the center/dashboard island. The left-only lateral geometry roles are swapped so each content island preserves the opposite top-bar endpoint silhouette, while physical-right caps use outward-facing handedness at the workspace upper endpoint and services lower endpoint. Endpoint caps and inward wraps use one complementary scalar contract across the visible rotated source and native blur. Right uses the corrected mirrored vertical frame; masks, wraps, input regions, native-blur geometry, and `exclusiveZone` follow the selected edge. Vertical owner surfaces span the output width for in-surface control-center overlays, while `exclusiveZone` remains the collapsed content width.

## Endpoint order and content policy

`bar.defaults.order` and a sparse monitor override choose which reusable endpoint occupies the logical start and end slots. The center/dashboard island remains fixed between them. Valid orders are `[`"workspaces"`, `"services"`]` and `[`"services"`, `"workspaces"`]`; malformed or duplicate lists fall back to the former.

`bar.defaults.content` controls the reusable endpoint presentation:

- `workspaceMode`: `numbers`, `bullets`, or `active-only`.
- `appMode`: `hidden`, `active-icon`, `all-icons`, or `vertical-labels`.
- `clockMode`: `auto`, `horizontal`, `vertical`, or `hidden`.

Side bars keep content upright. Their default app presentation is the active application's icon, avoiding unbounded labels; vertical labels remain an explicit opt-in. The clock's `auto` mode turns vertical on for left/right placement.

## Service divider

`bar.defaults.divider` is independent from placement and endpoint order. The default `arc` mode draws a passive, inward-facing curve whose axis follows the selected edge: top/bottom use a vertical curve and left/right use a horizontal curve. `hairline` keeps a straight separator, and `none` removes both the stroke and its semantic gap. `Theme.islandSeparatorWidth` controls stroke width and `Theme.islandSemanticGap` controls the surrounding space. The divider never owns input or routing.

## Motion policy

`bar.defaults.motion` controls the transitions introduced by the configurable bar contract. `calm` is the default and uses the shared `Motion.Effects` intent for state/color feedback and `Motion.Spatial` for endpoint geometry. `reduced` disables those bar-local behaviors without changing layout, routing, or the global wallpaper/panel animation policy. `expressive` currently uses the same shared intents as `calm` until a richer motion vocabulary is introduced.

## Visibility

| Value | Meaning |
|---|---|
| `always` | The bar remains visible and reserves its configured edge space. |
| `edge-reveal` | The bar is hidden or reduced to a reveal strip and appears when the pointer reaches its eligible edge. |
| `disabled` | No `Bar` instance is created for that monitor; its currently Bar-owned surfaces are removed with the instance. |

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
- When visible, reserve only the configured edge and the bar's actual occupied size; a vertical owner surface may span the full output width for screen-pinned in-surface overlays while its `exclusiveZone` remains narrow.
- When hidden, remove the normal reservation while retaining only the minimal reveal mechanism required by the selected policy.
- Interactive bar and dashboard surfaces remain `Top`; transient notification and OSD surfaces remain `Overlay`.
- No reveal behavior may depend on a compositor-selected output or an unpinned `PanelWindow`.

## Compatibility with the current shell

The current implementation applies the normalized `disabled` visibility filter and the resolved physical position. `Bar.qml` remains one instance per enabled screen, renders left/center/right islands, and expands the center island in place into `CenterDashboard.qml`. Top and bottom remain the baseline physical placements; bottom mirrors top around a centered vertical transform, with edge-aware native blur and a bottom-center `CenterPanel` cutout. Left physical placement is implemented by reusing the horizontal top island source and applying a 90-degree counter-clockwise rotation to visible notch masks, decorative wraps, and bounded native blur Regions; content remains upright and stacked vertically, with left-side overlay offsets. Right uses the corrected mirrored vertical frame. Vertical owner surfaces span the full output width so the in-surface `RightControlCenter` body/backdrop is not clipped; `exclusiveZone` still reserves only the collapsed content dimension on the selected edge, and the input union follows the rendered geometry. `edge-reveal` remains always-visible behavior. Continuous style, detached dashboard rendering, and dynamic colors remain inert. Explicit `disabled` may legitimately produce zero Bars and is not undone by the legacy selector fallback.

## Remaining implementation scope

- Implementing edge reveal using only external edges.
- Rendering the `continuous` style.
- Supporting a detached dashboard surface; independent surfaces remain future work.
- Defining dynamic color behavior separately; this foundation does not implement it.
- Defining a compositor-specific cursor API or requiring a particular external auto-hide helper.

## Bar lifecycle and overlay reconciliation

Legacy `bar.screens` name selection runs first. An empty legacy name match falls back to all connected screens so an unplugged or mistyped name does not remove every candidate. The normalized per-monitor visibility policy then filters those candidates. Therefore an explicit `visibility: "disabled"` can legitimately leave zero `Bar` instances; that result is not revived by the legacy fallback.

When a monitor stops producing a `Bar`, its currently active or pending Bar-owned overlay is cleared by screen identity, including pending opens waiting on the shared anti-serial-conflict timer. Standalone launcher and wallpaper surfaces are not cleared by Bar reconciliation. This is the approved transitional contract: disabling a monitor removes its `Bar` and currently Bar-owned surfaces; detached dashboards and other independent surfaces are future work.
