#!/usr/bin/env bash
# Bounded opt-in BackgroundEffect protocol probe. The outer path reuses the
# established fail-closed bwrap/systemd containment launcher; the inner path
# starts only the disposable CPU compositor and one harness client.
set -u
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
script_path="$self/$(basename -- "$0")"
compositor="$self/build/tokyo-wayland-compositor"
harness="$self/build/tokyo-diagnostics-harness"
launcher="$self/run-contained-server.sh"

die() { printf 'tokyo-background-effect: error: %s\n' "$*" >&2; exit 1; }

if [ "${1-}" = --contained ]; then
    shift
    [ "${1-}" = --compositor ] && shift || die "missing contained compositor"
    compositor_path=${1-}; shift
    [ "${1-}" = --harness ] && shift || die "missing contained harness"
    harness_path=${1-}; shift
    [ -x "$compositor_path" ] && [ -x "$harness_path" ] || die "contained artifacts unavailable"
    [ ! -e /dev/dri ] && [ ! -e /dev/udmabuf ] || die "device boundary failed"
    log=/run/tokyo-runtime/background-effect-compositor.log
    client_log=/run/tokyo-runtime/background-effect-client.log
    : >"$log"
    trap 'rm -f -- "$log" "$client_log"' EXIT
    "$compositor_path" --socket "$WAYLAND_DISPLAY" --deadline-ms 5000 >"$log" 2>&1 &
    compositor_pid=$!
    for _ in $(seq 1 100); do
        grep -q '^TOKYO_WAYLAND_COMPOSITOR_READY' "$log" && break
        kill -0 "$compositor_pid" 2>/dev/null || die "compositor exited before readiness"
        sleep 0.05
    done
    grep -q '^TOKYO_WAYLAND_COMPOSITOR_READY' "$log" || die "compositor readiness deadline"
    set +e
    WAYLAND_DEBUG=1 QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software \
        TOKYO_DIAGNOSTICS_ENABLE_BACKGROUND_EFFECT=1 \
        timeout --signal=TERM --kill-after=2s 3s \
        "$harness_path" --enable-background-effect-probe --enable-subsurface-probe >"$client_log" 2>&1
    client_status=$?
    wait "$compositor_pid"; compositor_status=$?
    set -e
    printf 'TOKYO_BACKGROUND_EFFECT_CLIENT_EXIT=%s\nTOKYO_BACKGROUND_EFFECT_COMPOSITOR_EXIT=%s\n' \
        "$client_status" "$compositor_status"
    cat "$log"
    cat "$client_log"
    grep -q 'TOKYO_BACKGROUND_EFFECT event=set-region' "$log" || die "set-region evidence missing"
    grep -q 'TOKYO_BACKGROUND_EFFECT event=commit.*region=' "$log" || die "set commit evidence missing"
    grep -q 'TOKYO_BACKGROUND_EFFECT event=commit.*region=none' "$log" || die "clear commit evidence missing"
    [ "$client_status" -eq 124 ] || die "harness did not stop at bounded deadline ($client_status)"
    [ "$compositor_status" -eq 0 ] || die "compositor failed ($compositor_status)"
    exit 0
fi

deadline=8000
if [ "${1-}" = --deadline-ms ]; then
    [ "$#" -ge 2 ] || die "missing deadline"
    deadline=$2
    shift 2
fi
case "$deadline" in ''|*[!0-9]*) die "invalid deadline" ;; esac
[ "$deadline" -ge 100 ] && [ "$deadline" -le 60000 ] || die "deadline must be 100..60000 ms"
[ "$#" -eq 0 ] || die "unexpected arguments"
[ -x "$compositor" ] && [ -x "$harness" ] || die "build artifacts missing"
for tool in bwrap systemd-run timeout mktemp; do
    command -v "$tool" >/dev/null 2>&1 || die "required tool unavailable: $tool"
done
runtime_dir=$(mktemp -d /tmp/tokyo-background-runtime.XXXXXXXXXX) || die "runtime directory creation failed"
case "$runtime_dir" in /tmp/tokyo-background-runtime.*) ;; *) die "unsafe runtime directory" ;; esac
chmod 0700 "$runtime_dir"
token=${runtime_dir##*.}
unit="tokyo-background-${token}"
cleanup() { [ -d "$runtime_dir" ] && rm -rf -- "$runtime_dir"; }
trap cleanup EXIT INT TERM HUP
runtime_ms=$((deadline + 5000))
timeout_ms=$((runtime_ms + 5000))
timeout_s=$(( (timeout_ms + 999) / 1000 ))
compositor_deadline=$((deadline + 2000))
[ "$compositor_deadline" -le 60000 ] || compositor_deadline=60000
bwrap_args=(
    bwrap --unshare-all --clearenv --new-session --die-with-parent
    --ro-bind /usr /usr --symlink usr/bin /bin --symlink usr/lib /lib --symlink usr/lib /lib64
    --proc /proc --dev /dev --tmpfs /tmp --tmpfs /run
    --dir /run/tokyo-runtime --bind "$runtime_dir" /run/tokyo-runtime --dir /home/tokyo
    --ro-bind "$compositor" "$compositor" --ro-bind "$harness" "$harness"
    --ro-bind "$self/build/libtokyo-diagnostics.so" "$self/build/libtokyo-diagnostics.so"
    --ro-bind "$script_path" "$script_path"
    --setenv PATH /usr/bin:/bin --setenv HOME /home/tokyo
    --setenv XDG_RUNTIME_DIR /run/tokyo-runtime --setenv WAYLAND_DISPLAY "tokyo-$token"
    --chdir /run/tokyo-runtime --
    "$script_path" --contained --compositor "$compositor" --harness "$harness"
)
echo "tokyo-background-effect: unit=$unit deadline_ms=$deadline runtime_dir=$runtime_dir" >&2
timeout --signal=TERM --kill-after=5s "${timeout_s}s" \
    systemd-run --user --wait --pipe --collect --unit="$unit" \
    --property=LimitCORE=1 --property=MemoryMax=256M --property=TasksMax=32 \
    --property=LimitNOFILE=256 --property=LimitAS=512M \
    --property=RuntimeMaxSec="${runtime_ms}ms" --property=KillMode=control-group \
    --property=NoNewPrivileges=yes -- "${bwrap_args[@]}"
