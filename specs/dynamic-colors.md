# Dynamic Wallpaper Colors

**Status:** Planned — design captured, implementation not started.

This specification defines a future color system that can derive semantic colors from the selected wallpaper while preserving an explicit user-controlled fallback. It does not change the current static `Colors.qml` palette.

## Configuration model

Conceptual configuration:

```json
{
  "theme": {
    "colorMode": "dynamic",
    "fallbackPalette": "tokyo-city"
  }
}
```

| `colorMode` | Meaning |
|---|---|
| `fixed` | Use the selected fallback palette for the whole session. |
| `dynamic` | Derive one semantic palette from the selected wallpaper for the whole session. |
| `accent-only` | Keep the fallback's surfaces and text roles, but derive the accent roles from the wallpaper. |

The active palette is global for the session. It is not calculated independently for each monitor, even when monitors display different wallpaper images.

## Fallback policy

The user chooses `fallbackPalette`. Tokyo City is an available fallback, not a mandatory one. If wallpaper extraction fails, returns unusable colors, or dynamic mode is unavailable, the shell must use the selected fallback rather than inventing a replacement or leaving roles undefined.

A fallback must provide a complete readable palette, including at least:

- background and elevated surfaces;
- primary and secondary text;
- accent;
- success, warning, and danger states;
- readable contrast for controls, overlays, and notifications.

Future custom palettes may be user-defined, but they must still satisfy the same semantic-role and contrast contract.

## Separation of responsibilities

The future implementation should keep these stages separate:

1. **Extraction** obtains candidate colors from the selected wallpaper.
2. **Transformation** converts candidates into semantic roles and validates contrast.
3. **Selection** chooses dynamic or fallback output according to `colorMode` and extraction state.
4. **Consumption** exposes the active roles through the color-token layer used by components.

Dynamic colors affect semantic color roles only. Structural values remain independent and continue to belong to `Theme.qml`, including spacing, radii, geometry, opacity, and animation timing.

## Design constraints

- The Tokyo City palette remains the current default until this design is implemented.
- Components must consume semantic roles rather than read extracted colors directly.
- A palette transition must not leave a partially updated frame where foreground and background roles come from different palettes.
- Fallback selection must be visible and configurable by the user.
- A failed extraction must be observable during verification without making the shell unusable.
- The active palette remains global even in an N-monitor session.

## Interaction with existing design

Dynamic colors must preserve the existing visual grammar:

- island and dashboard surfaces retain their structural geometry;
- danger actions remain visually distinct from ordinary service states;
- the special workspace cyan reservation remains a deliberate semantic decision unless explicitly revised;
- typography and font-family tokens remain unchanged;
- dynamic color support must not silently alter bar position, visibility, dashboard attachment, or overlay-layer policy.

## Out of scope

- Choosing a specific extraction library or algorithm.
- Implementing wallpaper observation or palette caching.
- Defining per-monitor palettes.
- Replacing the current Tokyo City palette before an explicit implementation task.
