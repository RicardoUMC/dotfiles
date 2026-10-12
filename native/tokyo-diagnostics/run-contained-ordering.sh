#!/usr/bin/env bash
# run-contained-ordering.sh — bounded, fail-closed ordering driver for the
# disposable CPU-only compositor + Qt diagnostics harness pair.
#
# This driver runs the subsurface below/above ordering exercise. Each case
# launches `tokyo-wayland-compositor` and `tokyo-diagnostics-harness` together
# inside ONE private bwrap sandbox hosted in a transient user systemd unit
# (identity-based, never bare PIDs). It captures the compositor's TOKYO_FRAME
# evidence and the client's logs (WAYLAND_DEBUG included), checks socket and
# unit/process cleanup, and fails closed on missing artifacts or a violated
# no-device/no-inherited-display boundary. Output is staged at deterministic
# paths under a private runtime directory and echoed to stdout as the durable
# evidence record before that directory is removed.
#
# It MUST NOT be executed until a separate runtime authorization exists. This
# file is build/static only. It makes no visual-ordering claim from protocol
# success, clean exits, or framebuffer digests alone; see README.md.
#
# Usage:
#   run-contained-ordering.sh [--deadline-ms N] [--socket-prefix NAME]
#
#   --deadline-ms N       bounded CLIENT deadline, 100..60000 ms (default 8000).
#                         The compositor deadline is N plus an internal grace,
#                         clamped to 60000 ms; the systemd RuntimeMaxSec is the
#                         compositor deadline plus a further backstop grace.
#   --socket-prefix NAME  socket-name prefix; each case appends "-below"/"-above".
#                         Default: tokyo-ordering-<token>.

set -u

SELF_NAME="tokyo-diag-ordering"

# ---- bounded constants -----------------------------------------------------
readonly DEADLINE_MIN_MS=100
readonly DEADLINE_MAX_MS=60000
readonly DEFAULT_CLIENT_DEADLINE_MS=8000
readonly COMPOSITOR_GRACE_MS=8000
readonly BACKSTOP_GRACE_MS=5000
readonly MAX_SOCKET_BYTES=107
readonly CASE_SUFFIX_BYTES=6    # "-below" / "-above"
readonly RUNTIME_PREFIX="/tmp/tokyo-ordering-runtime."
readonly UNIT_PREFIX="tokyo-ordering-"
readonly TIMEOUT_KILL_AFTER="5s"

# ---- helpers ----------------------------------------------------------------
log() {
    printf '%s: %s\n' "$SELF_NAME" "$*" >&2
}

evidence() {
    printf '%s\n' "$*"
}

die() {
    printf '%s: error: %s\n' "$SELF_NAME" "$*" >&2
    exit 1
}

usage() {
    printf 'usage: %s [--deadline-ms N] [--socket-prefix NAME]\n' "$0" >&2
}

parse_deadline() {
    local value="$1" parsed
    case "$value" in
        ''|*[!0-9]*) return 1 ;;
    esac
    # Reject inputs long enough to overflow 64-bit shell arithmetic.
    [ "${#value}" -le 8 ] || return 1
    parsed=$((10#$value))
    if [ "$parsed" -ge "$DEADLINE_MIN_MS" ] && [ "$parsed" -le "$DEADLINE_MAX_MS" ]; then
        printf '%s\n' "$parsed"
        return 0
    fi
    return 1
}

validate_socket_prefix() {
    local name="$1"
    local max_prefix_bytes=$(( MAX_SOCKET_BYTES - CASE_SUFFIX_BYTES ))
    [ -n "$name" ] || return 1
    [ "${#name}" -le "$max_prefix_bytes" ] || return 1
    case "$name" in
        *[!A-Za-z0-9_-]*) return 1 ;;
    esac
    return 0
}

# ---- argument parsing --------------------------------------------------------
client_deadline_ms=$DEFAULT_CLIENT_DEADLINE_MS
socket_prefix=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --deadline-ms)
            [ "$#" -ge 2 ] || { usage; die "missing value for --deadline-ms"; }
            client_deadline_ms=$(parse_deadline "$2") \
                || { usage; die "invalid --deadline-ms (expected ${DEADLINE_MIN_MS}..${DEADLINE_MAX_MS})"; }
            shift 2
            ;;
        --deadline-ms=*)
            client_deadline_ms=$(parse_deadline "${1#--deadline-ms=}") \
                || { usage; die "invalid --deadline-ms (expected ${DEADLINE_MIN_MS}..${DEADLINE_MAX_MS})"; }
            shift
            ;;
        --socket-prefix)
            [ "$#" -ge 2 ] || { usage; die "missing value for --socket-prefix"; }
            socket_prefix="$2"
            shift 2
            ;;
        --socket-prefix=*)
            socket_prefix="${1#--socket-prefix=}"
            shift
            ;;
        *)
            usage
            die "unknown option: $1"
            ;;
    esac
done

# ---- preconditions (fail closed) --------------------------------------------
for tool in systemd-run bwrap timeout grep mkdir cat sed tail awk; do
    command -v "$tool" >/dev/null 2>&1 || die "required tool unavailable: $tool"
done

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) \
    || die "cannot resolve script directory"
build_dir="${script_dir}/build"
compositor_bin="${build_dir}/tokyo-wayland-compositor"
harness_bin="${build_dir}/tokyo-diagnostics-harness"
harness_lib="${build_dir}/libtokyo-diagnostics.so"
cycle_probe_bin="${build_dir}/tokyo-wayland-cycle-probe"

[ -f "$compositor_bin" ] && [ -x "$compositor_bin" ] \
    || die "missing or non-executable compositor artifact: $compositor_bin"
[ -f "$harness_bin" ] && [ -x "$harness_bin" ] \
    || die "missing or non-executable harness artifact: $harness_bin"
[ -f "$harness_lib" ] || die "missing harness library artifact: $harness_lib"
[ -f "$cycle_probe_bin" ] && [ -x "$cycle_probe_bin" ] \
    || die "missing or non-executable cycle probe artifact: $cycle_probe_bin"

# ---- private runtime directory (identity-based cleanup, never bare PIDs) -----
runtime_dir=""
cleanup() {
    if [ -n "$runtime_dir" ] && [ -d "$runtime_dir" ]; then
        case "$runtime_dir" in
            "${RUNTIME_PREFIX}"*)
                rm -rf -- "$runtime_dir"
                ;;
            *)
                log "refusing to remove unexpected runtime path: $runtime_dir"
                ;;
        esac
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

runtime_dir=$(mktemp -d "${RUNTIME_PREFIX}XXXXXXXXXX") \
    || die "failed to create the private runtime directory"
case "$runtime_dir" in
    "${RUNTIME_PREFIX}"*) : ;;
    *) die "refusing unsafe runtime path: $runtime_dir" ;;
esac
chmod 0700 "$runtime_dir"

token="${runtime_dir#"${RUNTIME_PREFIX}"}"
[ -n "$token" ] || die "runtime directory token is empty"
case "$token" in
    *[!A-Za-z0-9]*) die "unexpected runtime directory token: $token" ;;
esac

if [ -z "$socket_prefix" ]; then
    socket_prefix="tokyo-ordering-${token}"
fi
validate_socket_prefix "$socket_prefix" \
    || die "invalid --socket-prefix (use [A-Za-z0-9_-], at most $((MAX_SOCKET_BYTES - CASE_SUFFIX_BYTES)) bytes)"

# ---- derived deadlines (client -> compositor -> systemd -> outer backstop) ----
compositor_deadline_ms=$(( client_deadline_ms + COMPOSITOR_GRACE_MS ))
[ "$compositor_deadline_ms" -le "$DEADLINE_MAX_MS" ] || compositor_deadline_ms=$DEADLINE_MAX_MS
runtime_max_ms=$(( compositor_deadline_ms + BACKSTOP_GRACE_MS ))
outer_timeout_ms=$(( runtime_max_ms + BACKSTOP_GRACE_MS ))
client_deadline_s=$(( (client_deadline_ms + 999) / 1000 ))
outer_timeout_s=$(( (outer_timeout_ms + 999) / 1000 ))
runtime_max_sec="${runtime_max_ms}ms"

log "runtime_dir=${runtime_dir} socket_prefix=${socket_prefix}"
log "client_deadline_ms=${client_deadline_ms} compositor_deadline_ms=${compositor_deadline_ms} runtime_max_ms=${runtime_max_ms} outer_timeout_ms=${outer_timeout_ms}"
log "compositor=${compositor_bin}"
log "harness=${harness_bin}"

# ---- orchestration script (runs INSIDE the sandbox, one case per invocation) -
orchestrator="${runtime_dir}/orchestrate.sh"
cat > "$orchestrator" <<'ORCHESTRATE'
#!/usr/bin/env bash
set -u

order="$1"
socket="$2"
case_dir="$3"
compositor_bin="$4"
harness_bin="$5"
cycle_probe_bin="$6"
compositor_deadline_ms="$7"
client_deadline_s="$8"

compositor_log="${case_dir}/compositor.log"
client_log="${case_dir}/client.log"
result_file="${case_dir}/result.txt"

mkdir -p "$case_dir" || { echo "orchestrate: mkdir failed: $case_dir" >&2; exit 1; }

# 0. Boundary preflight: fail closed if any host device node is visible inside
#    the sandbox. The launcher clears the environment and sets a private
#    WAYLAND_DISPLAY, so inherited display state cannot leak by construction;
#    this check records the no-device half of that boundary.
if [ -e /dev/dri ] || [ -e /dev/udmabuf ]; then
    printf 'ORDER=%s\nBOUNDARY=FAILED-device-node-visible\n' "$order" > "$result_file"
    exit 5
fi
printf 'ORDER=%s\nBOUNDARY=ok\n' "$order" > "$result_file"

# 1. Start the compositor in the background, logging to the case directory.
"$compositor_bin" --socket "$socket" --deadline-ms "$compositor_deadline_ms" \
    > "$compositor_log" 2>&1 &
compositor_pid=$!

# Negative cases intentionally exercise a protocol error. Both processes must
# exit nonzero: the client proves it observed the rejection, while the server
# proves the rejection was fail-closed rather than a clean accepted request.
if [ "$order" = "self" ] || [ "$order" = "cycle" ]; then
    WAYLAND_DISPLAY="$socket" timeout --signal=TERM --kill-after=5s "${client_deadline_s}s" \
        "$cycle_probe_bin" --case "$order" > "$client_log" 2>&1
    client_status=$?
    wait "$compositor_pid" 2>/dev/null
    compositor_status=$?
    printf 'CLIENT_EXIT=%s\nCOMPOSITOR_EXIT=%s\n' \
        "$client_status" "$compositor_status" >> "$result_file"
    if [ "$client_status" -eq 0 ] || [ "$compositor_status" -eq 0 ]; then
        printf 'RESULT=failed-negative-exit-assertion\n' >> "$result_file"
        exit 6
    fi
    if ! grep -q 'TOKYO_CYCLE_PROBE' "$client_log" 2>/dev/null \
        || ! grep -q 'reason=protocol-error' "$compositor_log" 2>/dev/null; then
        printf 'RESULT=failed-negative-protocol-evidence\n' >> "$result_file"
        exit 7
    fi
    printf 'RESULT=ok-negative-rejection\n' >> "$result_file"
    exit 0
fi

# 2. Bounded readiness wait on the compositor's READY line.
ready=0
attempt=0
while [ "$attempt" -lt 100 ]; do
    if grep -q '^TOKYO_WAYLAND_COMPOSITOR_READY' "$compositor_log" 2>/dev/null; then
        ready=1
        break
    fi
    if ! kill -0 "$compositor_pid" 2>/dev/null; then
        break
    fi
    sleep 0.05
    attempt=$((attempt + 1))
done

if [ "$ready" -ne 1 ]; then
    printf 'RESULT=failed-compositor-not-ready\n' >> "$result_file"
    wait "$compositor_pid" 2>/dev/null || true
    exit 1
fi

# 3. Run the client under a bounded process-group timeout (not a bare PID).
WAYLAND_DEBUG=1 \
QT_QPA_PLATFORM=wayland \
QT_QUICK_BACKEND=software \
TOKYO_DIAGNOSTICS_ENABLE_SUBSURFACE=1 \
TOKYO_DIAGNOSTICS_SUBSURFACE_ORDER="$order" \
timeout --signal=TERM --kill-after=5s "${client_deadline_s}s" \
    "$harness_bin" --enable-subsurface-probe --exercise-subsurface-lifecycle \
        --subsurface-order="$order" \
    > "$client_log" 2>&1
client_status=$?

# 4. The compositor terminates on client disconnect (or its own deadline).
wait "$compositor_pid" 2>/dev/null
compositor_status=$?

printf 'CLIENT_EXIT=%s\nCOMPOSITOR_EXIT=%s\n' \
    "$client_status" "$compositor_status" >> "$result_file"

if [ "$client_status" -ne 0 ] || [ "$compositor_status" -ne 0 ]; then
    printf 'RESULT=failed-child-exit\n' >> "$result_file"
    exit 5
fi

grep '^TOKYO_FRAME ' "$compositor_log" > "${case_dir}/frames.txt" 2>/dev/null || true
grep '^TOKYO_WAYLAND_COMPOSITOR_EXIT ' "$compositor_log" > "${case_dir}/compositor-exit.txt" 2>/dev/null || true

# 5. Fail closed unless all three evidence conditions hold. The explicit
#    diagnostic line is preferred, but WAYLAND_DEBUG is an acceptable strict
#    fallback when it proves both child creation and both placement requests.
explicit_pair=0
if grep -qF 'active child pair' "$client_log" 2>/dev/null; then
    explicit_pair=1
fi
get_subsurface_count=$(grep -Ec 'wl_subcompositor[^[:space:]]*\.get_subsurface\([^)]*wl_surface[^0-9]*[0-9]+' "$client_log" 2>/dev/null || true)
place_count=$(grep -Ec 'wl_subsurface[^[:space:]]*\.(place_above|place_below)\([^)]*wl_surface[^0-9]*[0-9]+' "$client_log" 2>/dev/null || true)
if [ "$explicit_pair" -ne 1 ] && {
    [ "${get_subsurface_count:-0}" -lt 2 ] || [ "${place_count:-0}" -lt 2 ];
}; then
    printf 'RESULT=failed-client-ordering-evidence-missing\n' >> "$result_file"
    exit 2
fi
if [ ! -s "${case_dir}/frames.txt" ]; then
    printf 'RESULT=failed-no-tokyo-frame\n' >> "$result_file"
    exit 3
fi
if ! grep -q 'reason=client-disconnect' "${case_dir}/compositor-exit.txt" 2>/dev/null; then
    printf 'RESULT=failed-compositor-exit-not-client-disconnect\n' >> "$result_file"
    exit 4
fi

printf 'RESULT=ok\n' >> "$result_file"
exit 0
ORCHESTRATE
chmod 0700 "$orchestrator"

# ---- per-case sandbox + unit -------------------------------------------------
run_case() {
    local order="$1" socket="$2" case_dir="$3" unit_name="$4"

    log "case=${order} unit=${unit_name} socket=${socket} case_dir=${case_dir}"

    local bwrap_args=(
        bwrap
        --unshare-all
        --clearenv
        --new-session
        --die-with-parent
        --ro-bind /usr /usr
        --symlink usr/bin /bin
        --symlink usr/lib /lib
        --symlink usr/lib /lib64
        --proc /proc
        --dev /dev
        --tmpfs /tmp
        --tmpfs /run
        --dir /run/tokyo-runtime
        --bind "$runtime_dir" /run/tokyo-runtime
        --dir /home/tokyo
        --ro-bind "$compositor_bin" "$compositor_bin"
        --ro-bind "$harness_bin" "$harness_bin"
        --ro-bind "$harness_lib" "$harness_lib"
        --ro-bind "$cycle_probe_bin" "$cycle_probe_bin"
        --setenv PATH /usr/bin:/bin
        --setenv HOME /home/tokyo
        --setenv XDG_RUNTIME_DIR /run/tokyo-runtime
        --setenv WAYLAND_DISPLAY "$socket"
        --chdir /run/tokyo-runtime
        --
        /usr/bin/bash /run/tokyo-runtime/orchestrate.sh \
            "$order" "$socket" "/run/tokyo-runtime/${order}" \
            "$compositor_bin" "$harness_bin" "$cycle_probe_bin" \
            "$compositor_deadline_ms" "$client_deadline_s"
    )

    local systemd_run_args=(
        systemd-run
        --user
        --wait
        --collect
        "--unit=${unit_name}"
        --property=LimitCORE=1
        --property=MemoryMax=512M
        --property=TasksMax=16
        --property=LimitNOFILE=128
        --property=LimitAS=4096M
        "--property=RuntimeMaxSec=${runtime_max_sec}"
        --property=KillMode=control-group
        --property=NoNewPrivileges=yes
        --
    )

    timeout --signal=TERM --kill-after="$TIMEOUT_KILL_AFTER" "${outer_timeout_s}s" \
        "${systemd_run_args[@]}" "${bwrap_args[@]}"
    return $?
}

# ---- cleanup + evidence reporting --------------------------------------------
check_cleanup() {
    local order="$1" socket="$2" unit_name="$3"
    local failures=0

    if [ -e "$runtime_dir/${socket}" ]; then
        log "cleanup: socket still present (${order}): $runtime_dir/${socket}"
        failures=$((failures + 1))
    else
        log "cleanup: socket removed (${order})"
    fi

    if systemctl --user --quiet is-active "$unit_name" 2>/dev/null; then
        log "cleanup: unit still active (${order}): $unit_name"
        failures=$((failures + 1))
    else
        log "cleanup: unit collected (${order})"
    fi

    [ "$failures" -eq 0 ]
}

report_case() {
    local order="$1" case_dir="$2" case_status="$3" cleanup_status="$4"

    evidence "===== CASE ${order} ====="
    if [ "$case_status" -eq 0 ]; then
        evidence "STATUS: ok"
    else
        evidence "STATUS: failed (exit ${case_status})"
    fi
    if [ "$cleanup_status" -eq 0 ]; then
        evidence "CLEANUP: ok (socket removed, unit collected)"
    else
        evidence "CLEANUP: failed (socket or unit still present)"
    fi

    if [ -f "${case_dir}/result.txt" ]; then
        evidence "---- result ----"
        cat "${case_dir}/result.txt" | sed 's/^/RESULT /'
    fi
    if [ -f "${case_dir}/compositor.log" ]; then
        evidence "---- compositor.log ----"
        cat "${case_dir}/compositor.log" | sed 's/^/COMPOSITOR /'
    fi
    if [ -f "${case_dir}/client.log" ]; then
        evidence "---- client.log ----"
        cat "${case_dir}/client.log" | sed 's/^/CLIENT /'
    fi
    evidence "====================="
}

# ---- main: two bounded cases -------------------------------------------------
overall_status=0
for order in below above self cycle; do
    socket="${socket_prefix}-${order}"
    case_dir="${runtime_dir}/${order}"
    unit_name="${UNIT_PREFIX}${token}-${order}.service"

    run_case "$order" "$socket" "$case_dir" "$unit_name"
    case_status=$?

    check_cleanup "$order" "$socket" "$unit_name"
    cleanup_status=$?

    report_case "$order" "$case_dir" "$case_status" "$cleanup_status"

    [ "$case_status" -eq 0 ] || overall_status=1
    [ "$cleanup_status" -eq 0 ] || overall_status=1
done

# ---- cross-case ordering distinguishability ----------------------------------
below_frames="${runtime_dir}/below/frames.txt"
above_frames="${runtime_dir}/above/frames.txt"

# Select the last child-bearing frame: earlier frames can capture the
# pre-placement stack, while the final such frame is the ordering evidence
# immediately before teardown.
below_child_frame=$(grep -F 'sub:' "$below_frames" 2>/dev/null | tail -n 1 || true)
above_child_frame=$(grep -F 'sub:' "$above_frames" 2>/dev/null | tail -n 1 || true)
below_digest=$(printf '%s\n' "$below_child_frame" | sed -n 's/.*digest=\([^ ]*\).*/\1/p')
above_digest=$(printf '%s\n' "$above_child_frame" | sed -n 's/.*digest=\([^ ]*\).*/\1/p')

normalize_stack() {
    printf '%s\n' "$1" \
        | sed -n 's/.* order=\([^ ]*\) digest=.*/\1/p' \
        | tr '>' '\n' \
        | sed -n 's/.*:child=\([0-9][0-9]*\)@.*/\1/p' \
        | awk 'BEGIN { first=1 } { if (!first) printf ","; printf "%s", $0; first=0 }'
}

reverse_stack() {
    printf '%s\n' "$1" | awk -F, '{ for (i = NF; i >= 1; --i) { if (i < NF) printf ","; printf "%s", $i } }'
}

below_stack=$(normalize_stack "$below_child_frame")
above_stack=$(normalize_stack "$above_child_frame")
expected_above_stack=$(reverse_stack "$below_stack")

# A digest difference is deliberately limited to CPU framebuffer
# distinguishability. It is not ordering evidence. Ordering is claimed only
# when both normalized stable child-index stacks contain two children and
# reverse between the below and above cases.
evidence "===== ORDERING DISTINGUISHABILITY ====="
evidence "below_last_child_frame: ${below_child_frame:-missing}"
evidence "above_last_child_frame: ${above_child_frame:-missing}"
evidence "below_digest: ${below_digest:-missing}"
evidence "above_digest: ${above_digest:-missing}"
evidence "below_normalized_stack: ${below_stack:-missing}"
evidence "above_normalized_stack: ${above_stack:-missing}"

if [ -n "$below_digest" ] && [ -n "$above_digest" ] \
    && [ "$below_digest" != "$above_digest" ]; then
    evidence "DIGEST VERDICT: CPU framebuffer distinguishable (digests differ)"
else
    evidence "DIGEST VERDICT: NOT CPU framebuffer distinguishable (missing or identical digests)"
    overall_status=1
fi

below_child_count=$(printf '%s\n' "$below_stack" | awk -F, '{ print (NF == 1 && $1 == "") ? 0 : NF }')
above_child_count=$(printf '%s\n' "$above_stack" | awk -F, '{ print (NF == 1 && $1 == "") ? 0 : NF }')
if [ "$below_child_count" -eq 2 ] && [ "$above_child_count" -eq 2 ] \
    && [ "$above_stack" = "$expected_above_stack" ] \
    && [ "$below_stack" != "$above_stack" ]; then
    evidence "ORDERING VERDICT: proven (normalized stable child indices reverse)"
else
    evidence "ORDERING VERDICT: NOT proven (normalized stable child indices did not reverse)"
    overall_status=1
fi

exit "$overall_status"
