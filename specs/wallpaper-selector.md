# Wallpaper selector

## Status
Implemented (first slice)

## Behavior

- `WallpaperService` indexes image files recursively under `~/Pictures/Wallpapers`.
- Supported formats are JPG, JPEG, PNG, WebP, AVIF, BMP, and GIF.
- `WallpaperSelector` is a fullscreen `Top` overlay, preserving the shell's overlay exclusivity and focused-monitor screen pinning.
- `Super+Shift+W` and `quickshell ipc call wallpaper toggle` open the selector.
- Selecting an image applies it to all outputs through the `awww`/swww-compatible backend (`awww img --transition-type fade`) and stores the selected path through `Quickshell.statePath("wallpaper/path.txt")`.
- On shell startup, the persisted path is restored after the catalog scan and reapplied through the backend.
- The overlay shows a large horizontal cyclic carousel; Left/Right and mouse wheel wrap from last to first and first to last, Enter applies, and Escape closes. The UI intentionally avoids showing explicit keyboard/mouse instructions.
- The selector uses the shared `Motion` vocabulary for card movement, selection styling, and control feedback; visible copy is limited to the title, count, Random action, and Apply action.
- Animation policy is user-configurable through `config.json`: `anim.enabled: false` disables shared motion globally, while `anim.overrides` can selectively disable `wallpaper.carousel`, `wallpaper.selection`, `wallpaper.controls`, `wallpaper.apply`, or `wallpaper.overlay`.
- Wallpaper application keeps `fade` by default and supports `none`, `simple`, `fade`, `left`, `right`, `top`, `bottom`, `wipe`, `wave`, `grow`, `center`, `any`, `outer`, and `random` through `wallpaper.transition`, with duration/fps/step controls.
- Opening the selector starts a preview transaction. Carousel navigation previews the selected wallpaper on the real desktop through `awww`; `Apply` commits the path and persistence, while Escape, outside click, toggle-close, or another overlay restores the wallpaper that was active when the selector opened.
- The initial local image is `~/Pictures/Wallpapers/tokyo-night-anime-wallpapers.jpg`.
- A sober test collection is available under `~/Pictures/Wallpapers/{night,nature,architecture,abstract}/`; source URLs are recorded in `~/Pictures/Wallpapers/README.md`.

## Prerequisite

Install and enable the Arch package selected by `yay -S swww` (currently resolved as `awww`, the maintained swww-compatible replacement). The shell keeps the catalog usable when the backend is unavailable and reports an error through the selector instead of crashing.

## Deferred

Per-monitor profiles, remote providers, dynamic color extraction, and image file browsing/import from the UI remain out of scope for this slice.
