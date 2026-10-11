# Tokyo.Diagnostics

Stage 2 is a standalone, opt-in Qt/QML diagnostics module. It is not loaded by
Quickshell and never discovers or attaches to Quickshell. `SubsurfaceProbe` can create
one bounded, synthetic-color Wayland child surface under the harness's own window.
It requests below-parent ordering by default; an explicit above-parent selector is
available only for comparison. Both variants use an empty input region. It does not implement blur,
screen capture, input routing, or live-shell integration. `BackgroundEffectProbe` is a
separate, disabled-by-default protocol probe: with explicit opt-in it binds the
installed `ext-background-effect-v1`, sets and clears one bounded region, and
commits each state. It reports protocol request/commit evidence only; it never
claims visual blur.

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
`tokyo-wayland-fixture-core`, the Qt-independent
`tokyo-wayland-protocol-server`, and the Qt-independent
`tokyo-wayland-compositor`, and `tokyo-wayland-cycle-probe`, plus the opt-in `BackgroundEffectProbe` protocol
path. The sentinel is a build/link-only shared-library
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
or other runtime side effect.

The compositor target (`tokyo-wayland-compositor`) is the first Qt-independent
unit with real request semantics: it creates exactly one validated private
socket, registers `wl_compositor`, `wl_shm` (via libwayland's built-in shm
implementation), `wl_subcompositor`, `wl_output`, and `xdg_wm_base`, and
handles enough requests for a Qt Wayland SHM client (surface create/commit, shm
pool/buffer, xdg surface/toplevel configure + ack, subsurface position and
below/above placement, frame callbacks, and buffer release). It composites each
committed toplevel scene into a bounded in-memory ARGB framebuffer and reduces
it to a bounded textual frame record (`TOKYO_FRAME`) carrying a 32-bit pixel
digest and the ordered subsurface stack. Each created subsurface receives a
bounded per-process creation index, included in `TOKYO_FRAME` entries alongside
the per-run resource ID. The driver selects the last frame containing a
subsurface stack (`sub:`), after placement has taken effect and before teardown.
A digest difference is CPU framebuffer evidence only; it is not a claim of visual
ordering on a real display. Ordering is claimed only when normalized stable
child-index stacks reverse between below and above. The event loop terminates on the bounded
`--deadline-ms` timer or when the last client disconnects, then destroys
clients, globals, and the display deterministically. It opens no DRM, udmabuf,
GPU device, or seat and never touches the active desktop or an inherited
`WAYLAND_DISPLAY`; it must not be run outside an authorized disposable
containment boundary. Synchronized-vs-desynchronized subsurface commit
deferral and popup positioning are intentionally not modeled; every commit is
applied immediately. None of these targets provides visual-ordering proof or
runtime containment on its own. The
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

The requested ordering defaults to below-parent. Background effect probing is
opt-in only (`TOKYO_DIAGNOSTICS_ENABLE_BACKGROUND_EFFECT=1` or
`--enable-background-effect-probe`) and must use the contained launcher:

```sh
native/tokyo-diagnostics/run-contained-background-effect.sh --deadline-ms 8000
```

The launcher preserves the no-DRM/udmabuf, cleared-environment, private-socket,
bounded-deadline, and identity-cleanup boundary. If the protocol global is absent,
the client fails closed. The disposable compositor advertises the protocol with
the blur capability bit for request sequencing only, accepts region set/clear requests, and logs their surface
commit sequencing; the fixture copies region rectangles before the client destroys
its wl_region. This is an ABI/request probe only: it does not provide GPU
blur, visual capture, or evidence that a real compositor applies an effect. Always leave
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

The build-only fixture proves scanner/protocol generation and public server
linkage. The protocol server has also completed one authorized server-only run
inside the contained launcher with a private `XDG_RUNTIME_DIR` and socket, an
external deadline, PID/socket identity checks, and post-exit cleanup. This does
not prove client protocol, compositor behavior, CPU composition, or visual
ordering; those remain outside this server-only exercise.

## Contained launcher scaffold

`run-contained-server.sh` is a fail-closed launcher for bounded server-only
runtime checks. It launches exactly one command inside a transient user systemd
unit whose ExecStart is an unprivileged bwrap sandbox. It makes no visual,
compositor, or client-ordering claim. The authorized protocol-server exercise
used this launcher once; future compositor/client runs require a separate
runtime gate.

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
- [x] A repeatable `--ro-bind PATH` option binds an additional absolute-path
  regular file read-only at its own path inside the sandbox (for a small
  allowlisted set of build artifacts). Relative, missing, directory, special,
  or unreadable paths fail closed. The server-only default behavior is
  unchanged: the command after `--` is still required and passed verbatim.
- [x] Static syntax verification only: `bash -n` and `git diff --check` pass.
- [x] Authorized protocol-server-only runtime completed once through the
  launcher.
- [x] The contained compositor/client ordering exercise and protocol-negative
  regression cases completed through the separately validated runtime gate.

The server-only exercise proves private-socket containment, bounded liveness,
identity cleanup, and absence of inherited active-desktop/device exposure for
that process. The ordering driver additionally proves contained protocol
handling, fail-closed exit status, and CPU framebuffer ordering evidence. It
still proves nothing about live Hyprland rendering, blur, or GPU behavior. It proves nothing about compositor behavior, client protocol, or
visual ordering. The `NoNewPrivileges=yes` plus unprivileged `--unshare-user`
combination and full resource-limit enforcement were observed for this run.

## Ordering driver and negative regression checks

`run-contained-ordering.sh` is the bounded, fail-closed driver for the paired
compositor/client subsurface-ordering exercise and the protocol-level negative
regressions. The current verification ran it through the existing bwrap and
transient systemd boundary: both positive cases passed, and the self-parent and
ancestor-cycle cases each observed nonzero client and compositor exits. This is
contained protocol/CPU-frame evidence only; blur and live-shell integration
remain out of scope.

Usage:

```sh
native/tokyo-diagnostics/run-contained-ordering.sh [--deadline-ms N] [--socket-prefix NAME]
```

- `--deadline-ms N` — bounded CLIENT deadline in ms (default `8000`, range
  `100..60000`). The compositor deadline is `N + 8000` clamped to `60000`; the
  transient unit `RuntimeMaxSec` is the compositor deadline plus a `5000` ms
  backstop, and an outer `timeout` is that value plus another `5000` ms.
- `--socket-prefix NAME` — validated `[A-Za-z0-9_-]` prefix of at most 101
  bytes; cases append `-below`, `-above`, `-self`, and `-cycle`. Default:
  `tokyo-ordering-<token>`.

Behavior, per case (all four cases use their own private sandbox/unit):

1. One `bwrap --unshare-all --clearenv` sandbox ro-binds `/usr`, the three
   allowlisted build artifacts (compositor binary, harness binary, and
   `libtokyo-diagnostics.so` at their absolute paths), and the private runtime
   directory (rw at `/run/tokyo-runtime`). `/dev` is a private device set, so
   `/dev/dri` and `/dev/udmabuf` are absent; `--clearenv` plus an explicit
   private `WAYLAND_DISPLAY` remove inherited display state.
2. A generated orchestration script inside the sandbox starts the compositor
   (`--socket <case-socket> --deadline-ms <compositor deadline>`) in the
   background, waits (bounded) for `TOKYO_WAYLAND_COMPOSITOR_READY`, then runs
   either the positive harness under `QT_QPA_PLATFORM=wayland`,
   `TOKYO_DIAGNOSTICS_ENABLE_SUBSURFACE=1`,
   `TOKYO_DIAGNOSTICS_SUBSURFACE_ORDER=<order>`, `WAYLAND_DEBUG=1`, and
   `--enable-subsurface-probe --subsurface-order=<order>`, bounded by
   `timeout --signal=TERM --kill-after=5s` (a process-group bound, never a bare
   PID). For `self` and `cycle`, it instead runs the installed-libwayland
   `tokyo-wayland-cycle-probe`; the probe expects a protocol error and exits
   nonzero, while the compositor also exits nonzero with `reason=protocol-error`.
3. It waits for the compositor to terminate on client disconnect or protocol
   rejection, then writes
   deterministic evidence under the private runtime directory:
   `<case>/compositor.log`, `<case>/client.log`, `<case>/frames.txt`,
   `<case>/compositor-exit.txt`, and `<case>/result.txt`.

Exact evidence emitted on stdout (the durable record; the runtime directory is
removed on exit):

- `CASE below|above|self|cycle`, `STATUS: ok|failed (exit N)`, `CLEANUP: ok|failed`.
- `RESULT`-prefixed `<case>/result.txt` (`ORDER`, `BOUNDARY`, `CLIENT_EXIT`,
  `COMPOSITOR_EXIT`, `RESULT`).
- `COMPOSITOR`-prefixed full `compositor.log` (READY line, `TOKYO_FRAME` lines,
  `TOKYO_STATE` role/place lines, `TOKYO_WAYLAND_COMPOSITOR_EXIT`). Stack entries
  retain resource IDs and include stable `child=<creation-index>` values.
- `CLIENT`-prefixed full `client.log` (`WAYLAND_DEBUG` trace plus the
  `[subsurface-native] active child pair ... ordering=...` line, or the strict
  fallback described below).
- `ORDERING DISTINGUISHABILITY` with the last child-bearing `TOKYO_FRAME` line
  per case (the last line containing `sub:`), its `digest=0x...`, normalized
  child-index stack, and separate CPU-digest and ordering verdicts. Both selected
  frames are required before either comparison is made. The digest verdict says
  only that CPU framebuffers differ; the ordering verdict requires two normalized
  stable child-index stacks in reverse order.

Fail-closed conditions (any one fails the driver with a nonzero exit): missing
or non-executable build artifacts; a visible `/dev/dri` or `/dev/udmabuf` node
inside the sandbox; the compositor never reaching READY; the client log missing
both the explicit `active child pair` line and the strict protocol fallback; no
`TOKYO_FRAME`; either case lacking a last child-bearing frame; or the compositor
exit reason not being `client-disconnect` for positive cases; negative cases
require both child statuses to be nonzero, a `TOKYO_CYCLE_PROBE` record, and
`reason=protocol-error`. The fallback requires at least two
`wl_subcompositor.get_subsurface` requests and at least two
`wl_subsurface.place_above`/`place_below` requests in `WAYLAND_DEBUG`. Cleanup
requires the private socket file
to be removed and the transient unit to be collected (checked by unit name,
never a bare PID); the private runtime directory is removed on exit.

The transient unit carries `LimitCORE=1`, `MemoryMax=256M`, `TasksMax=32`,
`LimitNOFILE=256`, `LimitAS=512M`, `RuntimeMaxSec`, `KillMode=control-group`,
and `NoNewPrivileges=yes`. These limits are static, bounded guesses sized for a
single Qt Quick window plus the compositor; the verifier must confirm they are
sufficient yet still enforced.

Limitations:

- The compositor guard rejects self-parenting and any ancestor cycle before
  assigning the subsurface role. The cycle probe independently verifies both
  guards through the installed Wayland client/server APIs; it does not prove
  behavior of other compositors.
- The contained run is regression evidence for protocol handling, process exit
  status, cleanup, and CPU framebuffer ordering. It does not prove visual
  ordering on a real display, live Hyprland rendering, blur, `BackgroundEffect`,
  or GPU behavior.
- A framebuffer digest difference is CPU framebuffer distinguishability only,
  not visual ordering on a real display, and not proof from a clean exit alone.
  The compositor's bounded per-process child-creation index is the stable
  cross-case identity. The driver ignores per-run resource IDs and placement
  labels when normalizing stack order, and claims ordering only when the two
  stable child-index sequences reverse.
- The compositor advertises `wl_compositor`, `wl_shm`, `wl_subcompositor`,
  `wl_output`, and `xdg_wm_base` but no `wl_seat`; the ordering probe needs no
  input, but the verifier must confirm the Qt Wayland client still maps and
  exposes the window without a seat.
- The sandbox binds no `/etc/fonts`, so fontconfig/text rendering may be
  degraded inside the sandbox; subsurface evidence uses solid-color SHM fills
  and is unaffected.
- `MemoryMax`/`LimitAS` are the first static guesses for a Qt client and may
  need adjustment at runtime if the unit is OOM-killed.

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
