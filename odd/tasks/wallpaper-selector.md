# Wallpaper selector

## Goal
Add a Caelestia-inspired local wallpaper catalog and selector to the Quickshell shell, backed by `swww`, while preserving the existing global overlay and N-monitor rules.

## Decisions
- Backend: `swww` compatibility, resolved by Arch's helper to the maintained `awww` package.
- Initial image: no image copied; selector must work with an empty catalog.
- Adaptation: use a shell-owned QML singleton service, a dedicated Top-layer selector overlay, and an explicit Hyprland keybind/IPC entry point. Do not copy Caelestia code.
- Scope: local image catalog, thumbnails, current wallpaper persistence, random selection, and applying to all connected outputs. Per-monitor independent wallpaper assignment is deferred.

## Tasks
1. Define wallpaper service contract and storage/configuration surface.
2. Implement the service and `swww` integration with empty-catalog/error handling.
3. Implement the selector overlay and wire global overlay/keybind/IPC routing.
4. Verify Qt 6 lint, shell reload, and focused runtime behavior; update docs.

## Non-goals
- Remote wallpaper providers or downloads.
- Dynamic color extraction/theme regeneration.
- Per-monitor wallpaper profiles.
- Copying or vendoring Caelestia implementation.

## Evidence
- Caelestia reference: `/home/unseen/src/reference/Caelestia/services/Wallpapers.qml`, `modules/launcher/WallpaperList.qml`, `modules/nexus/pages/wallandstyle/WallpaperSelect.qml`.
- Existing overlay contract: `specs/overlay-manager.md`.
- Existing launcher and coordinator: `quickshell/.config/quickshell/launcher/LauncherCentered.qml`, `shell.qml`.

## UX/UI direction

The current first slice is functionally correct but leaves a large empty panel when the catalog has one image. The redesign takes Caelestia's centered wallpaper carousel, enlarged current item, image-first hierarchy, and wheel navigation as principles only. Tokyo City adaptation: restrained blue selection seam, dark translucent panel, explicit Apply/Random actions, keyboard hints, no hover-to-open behavior, and no copied Caelestia code.

## Progress
- [x] Define service contract and storage/configuration surface.
- [x] Implement service and `swww` integration.
- [x] Implement selector overlay and routing (fullscreen overlay carousel; no dashboard tab).
- [ ] Verify and document (Qt 6 lint and reload pass; live backend installed by user; persistence restoration verified with hard reload and `awww query`; native review blocked by provider usage limit).
- [x] Redesign selector UX/UI with centered preview carousel.
- [x] Add sober test wallpaper collection (night, nature, architecture, abstract).
- [x] Replace dashboard-tab experiment with fullscreen wallpaper overlay carousel.
- [x] Increase carousel image presence and make navigation cyclic.
- [x] Add shared Motion animations and reduce selector copy to essential actions.
- [x] Make motion globally configurable with per-part overrides and configurable wallpaper application transitions.
- [x] Add real wallpaper preview transactions: preview on carousel navigation, restore on cancel, persist only on Apply.
- [x] Restore persisted wallpaper on shell startup and verify after hard shell restart.
- [x] Animate overlay carousel image swaps without changing real wallpaper preview behavior. Uses a two-layer crossfade governed by `wallpaper.carousel`; rapid reversal cancels the pending layer safely.
- [x] Add perspective depth tiers to the overlay carousel so cards shrink, fade, and spread non-linearly as they move away from center. The seven-card model uses three progressively smaller side tiers with non-linear spacing.
- [x] Bind carousel cards to wallpaper identities so focus changes animate cards through the depth tiers instead of swapping content inside fixed slots. Each delegate now follows a wallpaper index and computes a cyclic relative offset; depth tiers are clamped for hidden distant cards.

## Delivery Evidence
- Work-unit commit: `84e6a29` (`feat(quickshell): add wallpaper selector preview workflow`)
