# Tokyo.Diagnostics

Stage 2 is a standalone, opt-in Qt/QML diagnostics module. It is not loaded by
Quickshell and never discovers or attaches to Quickshell. `SubsurfaceProbe` can create
one bounded, synthetic-color Wayland child surface under the harness's own window.
It requests below-parent ordering by default; an explicit above-parent selector is
available only for comparison. Both variants use an empty input region. It does not implement blur,
screen capture, input routing, or live-shell integration.

## Dependencies

- CMake 3.21 or newer
- A C++17 compiler
- `pkg-config`, the `wayland-server` development metadata/headers, and
  `wayland-protocols` data
- `wayland-scanner` on `PATH` (used to generate the stable xdg-shell server API)
- Qt 6.2 or newer with development components: Core, Gui, Qml, Quick, and WaylandClient
- Matching QtWayland private development headers (`QtWaylandClientPrivate`)
- `qt_add_qml_module` from the Qt 6 CMake package

No packages are installed by this project. It does not write to Quickshell-managed
folders. Building the sentinel does not launch a compositor, client, diagnostics
harness, Wayland server, or runtime process, and does not access active desktop
sockets, `/dev/dri`, services, or coredump configuration.

## Configure and build

From the repository root:

```sh
cmake -S native/tokyo-diagnostics -B native/tokyo-diagnostics/build \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build native/tokyo-diagnostics/build
```

The build produces `tokyo-diagnostics-harness`, the `Tokyo.Diagnostics` QML
module target, `tokyo-wayland-server-api-sentinel`, and the Qt-independent
`tokyo-wayland-fixture-core`. The sentinel is a build/link-only shared-library
target outside the Qt/QML module. The fixture additionally proves that the
installed `wayland-scanner` and stable `xdg-shell` protocol data generate
server code and that the public libwayland server interfaces link. Both targets
are inert and must not be run: they create no socket, display, protocol globals,
or other runtime side effect. Neither target provides a server, compositor, CPU
composition, or runtime containment. The module URI is independent of
Quickshell's modules. QtWaylandClient private headers are used only in
`waylandsubsurfaceadapter.cpp`; this is an ABI risk and the module must be
rebuilt against the exact Qt build it runs with.

## Run the isolated harness

The harness is a separate process and can run without Quickshell:

```sh
QT_QPA_PLATFORM=offscreen \
  native/tokyo-diagnostics/build/tokyo-diagnostics-harness
```

The ordinary smoke command above keeps the probe disabled. The opt-in probe is
currently blocked: do not run it against the active desktop or any inherited
`WAYLAND_DISPLAY`. A future run requires the disposable-compositor gate described
below, with a private socket, private runtime/config/home, no `/dev/dri`, no host
Wayland sockets, `LimitCORE=0` or verified dump suppression, an explicit deadline,
and identity-based cleanup.

The requested ordering defaults to below-parent. Always leave
`TOKYO_DIAGNOSTICS_ENABLE_SUBSURFACE` unset for the disabled baseline; its value
must be affirmative (`1`, `true`, `yes`, or `on`) to enable the probe.

Teardown now explicitly destroys the `wl_subsurface` role before the child
`wl_surface`, then releases the Qt SHM buffer wrapper and clears all handles.
This prevents a stale subsurface role from surviving into a replacement parent
commit. Offline build/static checks passed; compositor behavior remains
unverified. Do not run the harness against a Wayland compositor until the gate
is independently validated.

For a bounded harness-only lifecycle exercise (below-parent by default), run:

```sh
QT_QPA_PLATFORM=offscreen \
  native/tokyo-diagnostics/build/tokyo-diagnostics-harness \
  --exercise-subsurface-lifecycle
```

This command enables the standalone probe, but the offscreen platform cannot
produce an active Wayland child; it must fail closed at the readiness gate and
exit nonzero. On a future disposable Wayland compositor only, the lifecycle mode
will wait for an initial active child, request one bounded geometry replacement,
wait for a replacement active child, explicitly disable it, and then quit after a
teardown grace period. A clean quit without the active surface/subsurface IDs and
matching `WAYLAND_DEBUG` destroy ordering is insufficient evidence. No compositor
runtime validation is currently claimed.

A future paired comparison must run only after the disposable gate is accepted:
run below-parent and above-parent as separate bounded processes on the same private
compositor, capture each result through an explicitly authorized capture path, and
retain the compositor log, `WAYLAND_DEBUG` trace, process identities, socket owner,
exit status, and liveness check. `--subsurface-order=above` and
`--subsurface-order=below` are equivalent selectors. A status string or clean
process exit is not compositor-visible proof; visual ordering requires paired
captures plus protocol and liveness evidence.

## Disposable-compositor gate

The installed Hyprland/Aquamarine combination is not yet a runnable isolated
backend for this probe: Hyprland requests mandatory headless plus optional DRM and
Wayland implementations, while Aquamarine still needs a render allocator unless
NULL is first. Do not expose host `/dev/dri`, inherit the active Wayland socket, or
nest into the live desktop. The next safe option is an independently launched
outer disposable compositor or a separately built software/null allocator. Until
one is available, the opt-in lifecycle and ordering probes remain blocked.

Upstream KWin v6.7.5 is not acceptable under the current no-device gate either.
Its `--virtual` path selects `VirtualBackend`, creates `Session::Type::Noop`, and
`VirtualBackend::initialize()` returns true with QPainter support. However,
`ApplicationWayland` calls `createGpuManager()` before backend selection;
`GpuManager` opens `/dev/udmabuf`, creates a udev DRM monitor, and scans render
devices. The virtual backend therefore does not establish the required no-device
boundary.

The build-only fixture now proves scanner/protocol generation and public server
linkage. It is a null protocol fixture: it does not provide a server, compositor,
CPU composition, or runtime containment, and therefore cannot prove visual
ordering. Task 11 remains incomplete and task 12 remains blocked.

## Import from another Qt/QML application

Link the `tokyo-diagnostics` CMake target (or its built library) and make the
module's generated QML import directory available to the application. The QML
import is:

```qml
import Tokyo.Diagnostics

DiagnosticBridge { id: bridge }
```

This scaffold deliberately does not define a deployment or installation path for
Quickshell. Any future integration requires a separate authorization and ABI review.
