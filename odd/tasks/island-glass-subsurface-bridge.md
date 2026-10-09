# Diagnostic subsurface bridge for island glass

## Goal
Build a standalone, opt-in diagnostic C++/Qt module that can later create a same-connection subsurface child below the Quickshell Bar, without replacing the production Bar or claiming that live backdrop blur is solved.

## Scope
- Work on `feat/global-surface-system` only; `main` remains unchanged.
- Stage 1 is build-only: establish a reproducible native module, QML type registration, dependency checks, and isolated harness boundary.
- No live shell integration, no compositor plugin, no screen capture, no fullscreen blur rule, no service/routing/focus/Escape/input/overlay changes.
- Native module imports lazily and must not prevent the normal shell from loading when absent.

## Tasks
1. [x] Create build-only CMake/module scaffold under `native/tokyo-diagnostics`.
2. [x] Add a minimal QML-facing bridge API with explicit capability/error state but no live surface mutation.
3. [x] Add an isolated ordering-probe harness boundary and dependency/build checks.
4. [x] Verify module loading in a separate process without changing the active shell.
5. [x] Review the build/ABI boundary before any subsurface or blur protocol code.
6. [x] Implement an isolated ordering-only subsurface probe behind a native capability gate.
7. [x] Verify child-surface creation and ordering requests; require paired below/above captures for visual ordering.
8. [x] Fix the unsafe subsurface teardown ordering exposed by the compositor crash.
9. [x] Harden harness opt-in and readiness-gated lifecycle evidence (offline-validated; compositor behavior remains unverified).
10. [x] Verify teardown statically/offscreen only; do not rerun against the active compositor.
11. Prepare a disposable compositor harness and verify process/socket containment before any runtime rerun.
   - [x] Add a build-only Wayland server API sentinel proving installed `wayland-server` headers and pkg-config metadata are consumable; runtime containment remains unverified.
   - [x] Add a Qt-independent, build-only public-libwayland fixture core target; it must not add Qt, QML, or runtime behavior.
   - [x] Compile protocol-code generation coverage for `wl_compositor`, `wl_shm`, `wl_subcompositor`, `xdg_wm_base`, and `wl_output`.
   - [x] Keep the fixture inert and unexecuted until a separate containment launcher exists.
   - [x] Document that a null protocol fixture cannot prove visual ordering without CPU composition.
   - [x] Add the Qt-independent Wayland server lifecycle sentinel as a build-only unit: one validated private socket, no globals, and bounded timer teardown.
     - [x] Require `--socket NAME`; bound optional `--deadline-ms` to 1..60000 and reject traversal/invalid names.
     - [x] Build/link only against public `wayland-server` APIs; preserve the existing sentinel and fixture-core targets.
     - [x] Do not run the executable or any compositor/client/service yet.
     - [ ] A later runtime may run only inside the already-tested bwrap namespace with private `XDG_RUNTIME_DIR`/socket, external deadline, PID/socket identity, and post-exit cleanup.
     - [x] Treat this as lifecycle/socket evidence only; it proves no client protocol or visual ordering.
12. [ ] Decide whether a bounded background-effect probe is justified; blocked until a separately validated containment path exists. Do not integrate production glass automatically.

## Stage 1 evidence
- CMake configure/build passed for the standalone module and harness.
- Qt6 `qmllint` passed for the harness; the offscreen harness started without diagnostics and was stopped by the bounded timeout (`124`), which is expected for this smoke test.
- `git diff --check` passed. The active Quickshell shell was not reloaded or otherwise touched.
- The scaffold intentionally reported `surfaceCreationSupported: false`; no production shell path is changed.

## Stage 2 ordering-only evidence
- `SubsurfaceProbe` is QML-facing, default-disabled, and creates a child only for the harness's own realized, visible/exposed `QWindow` after explicit opt-in. It now waits via lifecycle signals and bounded single-shot retries instead of probing during initial QML construction; runtime verification of that lifecycle fix remains incomplete.
- The private Qt adapter is isolated in `waylandsubsurfaceadapter.cpp`; it uses Qt 6.11 QtWayland private display/SHM plumbing plus the target window's native Wayland surface. ABI compatibility is therefore limited to the matching Qt build.
- The probe requests bounded local geometry, synthetic magenta content, selectable `wl_subsurface.place_below` (default) or `wl_subsurface.place_above` ordering, and an empty input region; disable, target destruction, adapter destruction, and process exit tear it down.
- Offscreen/non-Wayland behavior is fail-closed and reports no surface.
- Paired Wayland captures establish ordering: the magenta child is absent below the opaque parent and visible above it. Protocol logs confirm matching `place_below`/`place_above` requests with no errors.
- Process-level teardown after SIGTERM was clean, but the lifecycle exercise exposed an unsafe client teardown: `wl_surface#56.destroy()` was emitted without a preceding `wl_subsurface#46.destroy()`, immediately before a replacement child and parent commit. Do not treat that prior runtime result as validation of the hardened harness.
- Hyprland PID 2558826 then crashed at `CSubsurface::recheckDamageForSubsurfaces`/`CWindow::commitWindow` and restarted PID 2367047 in safe mode. The crash core, journal, and runtime timestamps correlate at 08:35:08 UTC.
- Treat the missing explicit `wl_subsurface_destroy` before child-surface destruction as the leading client defect. The adapter now destroys the subsurface role, then child surface, then SHM wrapper/handles, with idempotent pointer resets. Offline build/static checks passed; compositor behavior remains unverified. Suspend live compositor probes. No background blur is attached.
- Harness hardening is offline-validated: environment opt-in accepts only `1`, `true`, `yes`, or `on` case-insensitively; lifecycle timers begin only after observed active state; missing initial or replacement readiness fails explicitly and nonzero; initial/replacement/final-disable logs expose numeric native IDs. Runtime compositor behavior remains unverified.
- Task 10 is complete as an offline/static-only verification boundary. Task 11 begins with a build-only `wayland-server` API sentinel; it creates no socket, display, protocol globals, or runtime side effect, and does not establish disposable-compositor containment.
- Native logs retain the last-destroyed IDs and log role-before-surface destruction, but the `WAYLAND_DEBUG` trace remains authoritative. A clean quit without active-ID records and matching role-before-surface destroy ordering is insufficient evidence.

## Architecture constraints
- Use an independent QML URI (`Tokyo.Diagnostics`), never Quickshell internal plugin symbols.
- Keep the bridge passive until a later authorized ordering probe.
- Prefer public Qt APIs; isolate unavoidable QtWayland private APIs behind one native adapter.
- A future bridge consumes parent-local geometry from its owning Bar; it does not own placement, input, routing, focus, overlays, services, or monitor selection.
- Keep production translucent island fallback authoritative and all prototype selectors disabled by default.

## Disposable compositor gate
- Containment is fail-closed. Verified local help/static evidence requires bwrap 0.13.0 with mandatory `--unshare-all`, `--unshare-user`, `--unshare-ipc`, `--unshare-pid`, `--unshare-net`, `--unshare-cgroup`, `--clearenv`, private mounts, `--new-session`, `--die-with-parent`, and `--json-status-fd`; never use `*-try` flags because they continue without isolation. `systemd-run` offers `--property`, `--wait`, `--collect`, and documented resource properties, but effective user-manager enforcement and coredump suppression under this host's systemd-coredump pipe remain unverified. The actual containment launcher and runtime remain blocked pending authoritative verification of core suppression, identity cleanup, and post-client liveness.
- A harmless namespace preflight using exactly `--unshare-all`, private `/run` and `/tmp`, a `/dev` tmpfs, a read-only `/usr` bind, explicit `/bin`/`/lib`/`/lib64` symlinks, `--clearenv`, `--new-session`, and `--die-with-parent` exited 0 while checking that no inherited display, socket, or device paths were visible. This proves only namespace path visibility; it does not prove coredump suppression, systemd limits, actual fixture correctness, or post-client liveness. Task 11 remains incomplete and task 12 remains blocked.
- The installed Hyprland 0.56.2 source hardcodes Aquamarine implementations in this order: mandatory headless, optional DRM, then Wayland fallback; there is no confirmed CLI backend selector.
- Aquamarine's headless backend itself does not open a device, but its backend startup requires a render allocator unless the first implementation is the NULL backend. Hyprland does not request NULL, so a no-device namespace is expected to fail closed rather than provide a runnable compositor.
- Do not expose `/dev/dri`, inherit the active `WAYLAND_DISPLAY`, or nest into the live desktop. A viable runtime gate therefore needs either an independently launched disposable outer Wayland compositor or a separately built test compositor that supplies an isolated software/null allocator; neither is installed or authorized yet.
- Until that gate exists, runtime validation is blocked. The only accepted evidence remains private-socket ownership, no hardware/active-socket access, bounded process lifetime, child/replacement IDs, role-before-surface `WAYLAND_DEBUG` destroys, and compositor liveness after harness exit.
- Upstream KWin v6.7.5 is not acceptable under the current no-device gate: `--virtual` selects `VirtualBackend`, creates `Session::Type::Noop`, and `VirtualBackend::initialize()` returns true with QPainter support, but `ApplicationWayland` calls `createGpuManager()` before backend selection. `GpuManager` opens `/dev/udmabuf`, creates a udev DRM monitor, and scans render devices, so the virtual backend does not provide the required no-device boundary.
- The Qt-independent build-only fixture now proves scanner/protocol generation and public server linkage. It remains inert and unexecuted: it provides no server, compositor, CPU composition, or runtime containment, so it cannot prove visual ordering. Task 11 remains incomplete, and task 12 remains blocked.

## Acceptance criteria
- Native scaffold builds reproducibly against the installed Qt/CMake toolchain or reports an exact dependency blocker.
- QML type registration/import is isolated from the production shell and has no runtime side effects.
- The module reports capability/build identity without creating a Wayland surface unless the standalone harness opt-in is explicitly enabled.
- The ordering-only stage does not attach background blur, use screen capture, or access Quickshell internals.
- No active shell reload, compositor, service, or input behavior is changed.
- Native review and evidence are complete before progressing to surface creation.
- The above-parent selector is comparison-only and is not a production recommendation.
