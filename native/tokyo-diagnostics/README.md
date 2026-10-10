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
module target, `tokyo-wayland-server-api-sentinel`,
`tokyo-wayland-server-lifecycle`, the Qt-independent
`tokyo-wayland-fixture-core`, and the Qt-independent
`tokyo-wayland-protocol-server`. The sentinel is a build/link-only shared-library
target outside the Qt/QML module. The lifecycle target is a Qt-independent
C++17 executable that creates exactly one validated private socket, advertises
no protocol globals, and tears down through a bounded timer; it is build-only
for now and must not be run. The protocol server target is the next
Qt-independent C++17 unit: it creates exactly one validated private socket and
registers the five required globals (`wl_compositor`, `wl_shm`,
`wl_subcompositor`, `wl_output`, and `xdg_wm_base` via the generated
xdg-shell server API) with no request handlers; it is build-only for now and
must not be run. The fixture additionally proves that the installed
`wayland-scanner` and stable `xdg-shell` protocol data generate server code and
that the public libwayland server interfaces link. The API sentinel and fixture
are inert and must not be run: they create no socket, display, protocol globals,
or other runtime side effect. None of these targets provides a compositor,
client protocol, CPU composition, visual ordering, or runtime containment. The
module URI is independent of Quickshell's modules.
QtWaylandClient private headers are used only in `waylandsubsurfaceadapter.cpp`;
this is an ABI risk and the module must be rebuilt against the exact Qt build it
runs with.

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
Wayland sockets, verified dump suppression (`LimitCORE=1` is the fail-closed
candidate on this host's pipe-mode `core_pattern`; `LimitCORE=0` alone is
insufficient), an explicit deadline,
and identity-based cleanup (pidfd or unique systemd unit/cgroup identity, never
bare PIDs).

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

Containment is fail-closed. Verified local help/static evidence requires bwrap
0.13.0 with mandatory `--unshare-all`, `--unshare-user`, `--unshare-ipc`,
`--unshare-pid`, `--unshare-net`, `--unshare-cgroup`, `--clearenv`, private
mounts, `--new-session`, `--die-with-parent`, and `--json-status-fd`; never use
`*-try` flags because they continue without isolation. `systemd-run` offers
`--property`, `--wait`, `--collect`, and documented resource properties;
effective user-manager enforcement of those properties is now verified against
the unit's cgroup files and `/proc/<pid>/limits` (see the transient-unit
resource-limit evidence below), never assumed from the unit spec alone.

This host uses the classic kernel `core_pattern` pipe to
`/usr/lib/systemd/systemd-coredump`
(`|/usr/lib/systemd/systemd-coredump %P %u %g %s %t %c %h %d %F %I`). Under
pipe mode, `LimitCORE=0` is NOT accepted as proven coredump suppression: the
kernel still spawns the pipe helper, and `%c` is passed only as context (the core
soft-limit value), not as a gate that prevents helper dispatch.

Fail-closed A/B/C proof, verified against this host's classic systemd-coredump
pipe using a harmless dedicated crash helper (never the real harness or
compositor):
- A (control): `LimitCORE=infinity` produced a stored 52.4 KiB `bash` core and
  handler dispatch.
- B (test): `LimitCORE=0` produced no stored file, but systemd-coredump still ran
  and logged resource-limit suppression — a missing core file is therefore not
  suppression proof by itself.
- C (contrast): `LimitCORE=1` prevented handler dispatch and the kernel logged an
  RLIMIT_CORE abort, so `0` and `1` are distinct behaviors.

`LimitCORE=1` is the preferred fail-closed candidate for a future disposable
unit. Effective user-manager resource-limit enforcement is now verified against
transient user units: with `LimitCORE=1`, `MemoryMax=32M` was observed at cgroup
`memory.max=33554432`, `TasksMax=8` at `pids.max=8`, and `LimitNOFILE=64` plus
`LimitAS=128M` in `/proc/self/limits`; `RuntimeMaxSec=2s` terminated a 10s sleep
with systemd result `timeout`; and `KillMode=control-group` killed both recorded
main and child PIDs and removed the unit cgroup. The first observation had a
systemd `${cg}` quoting artifact, so the corrected rerun supplied the cgroup
evidence. One stopped `tokyo-limit-kill.service` remains inactive/dead as
evidence; no cores or unexpected artifacts were created. Actual fixture-unit validation, client protocol, and post-client liveness
remain pending; the contained launcher scaffold now exists but is unexecuted
(static `bash -n` and `git diff --check` only). Task 11 remains incomplete and
task 12 remains blocked. The A2 control core was intentionally
retained as evidence at its exact path
`/var/lib/systemd/coredump/core.bash.1000.7b558ccb1abe483298c6fbe74d92e575.1809959.1791575686000000.zst`;
the user chose retention because `coredumpctl` has no `delete` verb and the
core's root ownership blocked direct removal. Cleanup must key on pidfd or the
unique systemd unit/cgroup identity, never a bare PID that may be recycled. The
contained launcher scaffold now exists but is unexecuted (static `bash -n` and
`git diff --check` only); runtime remains blocked pending authoritative
verification of core suppression, identity cleanup, and post-client liveness. A harmless namespace preflight using
exactly `--unshare-all`, private `/run` and `/tmp`, a `/dev` tmpfs, a
read-only `/usr` bind, explicit `/bin`/`/lib`/`/lib64` symlinks, `--clearenv`,
`--new-session`, and `--die-with-parent` exited 0 while checking that no
inherited display, socket, or device paths were visible. This proves only
namespace path visibility; it does not prove coredump suppression, systemd
limits, actual fixture correctness, or post-client liveness. Task 11 remains
incomplete and task 12 remains blocked.

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
linkage. The lifecycle sentinel is the next bounded safe unit: its later runtime
may run only inside the already-tested bwrap namespace, with a private
`XDG_RUNTIME_DIR` and socket, an external deadline, PID/socket identity checks,
and post-exit cleanup. Do not run it yet. It still proves no client protocol,
compositor behavior, CPU composition, or visual ordering. Task 11 remains
incomplete and task 12 remains blocked.

## Contained launcher scaffold

`run-contained-server.sh` is a fail-closed launcher scaffold for the lifecycle
sentinel's future runtime. It is a static, syntax-verified artifact only and
must not be executed until a separate runtime authorization. It launches
exactly one command inside a transient user systemd unit whose ExecStart is an
unprivileged bwrap sandbox. It makes no visual, protocol, compositor, or
runtime claim, and its only intended first command is the build-only
`tokyo-wayland-server-lifecycle` sentinel.

Boundary and checklist (scaffold only, static syntax verification first):

- [x] Fail-closed argument surface: a command is required after `--`;
  `--deadline-ms` is bounded to 100..60000 and `--socket` is restricted to
  `[A-Za-z0-9_-]` of at most 107 bytes; defaults are deterministic and unique
  per invocation (`tokyo-<token>` socket and a per-run `mktemp` token).
- [x] Private 0700 runtime directory under a strict `/tmp/tokyo-diag-runtime.*`
  prefix, an EXIT/INT/TERM/HUP trap, and cleanup that removes only that exact
  directory; any unexpected path is refused.
- [x] Unique transient `systemd-run --user --wait --collect --unit=...` identity
  with `LimitCORE=1`, `MemoryMax=32M`, `TasksMax=8`, `LimitNOFILE=64`,
  `LimitAS=128M`, `RuntimeMaxSec` derived from the deadline,
  `KillMode=control-group`, and `NoNewPrivileges=yes`; an external `timeout`
  deadline is the same window plus a short grace. Cleanup keys on the unit
  identity, never a bare PID (no pkill).
- [x] bwrap uses mandatory `--unshare-all` (never a `*-try` flag),
  `--clearenv`, read-only `/usr`, explicit `/bin`/`/lib`/`/lib64` symlinks,
  private `/proc`, `/dev`, `/tmp`, and `/run`, `--die-with-parent`, and
  `--new-session`; only the fresh runtime directory is bound (at
  `/run/tokyo-runtime`), and the command's own executable file is bound
  read-only at its original absolute path. Env is `HOME=/home/tokyo`,
  `XDG_RUNTIME_DIR=/run/tokyo-runtime`, and an explicit `WAYLAND_DISPLAY`
  socket name; no host runtime, display, X11, session-bus, DRM, or udmabuf
  state is exposed.
- [x] The command after `--` is passed verbatim and never reinterpreted; the
  launcher logs the unit name, runtime directory identity, socket name, and
  deadline without secrets, and fails closed when `bwrap`, `systemd-run`, or
  `timeout` is missing or any precondition fails.
- [x] Static syntax verification only: `bash -n` and `git diff --check` pass.
- [ ] Runtime execution is not yet authorized; do not run the script, a
  compositor, a client, a harness, or a service. Task 11 remains incomplete and
  task 12 remains blocked.

The scaffold proves nothing about compositor behavior, client protocol, visual
ordering, or liveness until a separately authorized runtime exercise. The
`NoNewPrivileges=yes` plus unprivileged `--unshare-user` combination and the
full resource-limit enforcement are unverified together at runtime and remain
pending that authorization.

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
