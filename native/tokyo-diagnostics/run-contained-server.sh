#!/usr/bin/env bash
# run-contained-server.sh — fail-closed launcher scaffold for a disposable,
# contained Wayland server lifecycle exercise.
#
# This scaffold runs exactly one command inside a transient user systemd unit
# whose ExecStart is an unprivileged bwrap sandbox. It is currently intended
# only for the build-only `tokyo-wayland-server-lifecycle` sentinel (see
# README.md). It makes no visual, protocol, compositor, or runtime claim, and
# it MUST NOT be executed until a separate runtime authorization exists.
#
# Usage:
#   run-contained-server.sh [--deadline-ms N] [--socket NAME]
#                           [--ro-bind PATH] -- COMMAND [ARG...]
#
#   --deadline-ms N   bounded deadline, 100..60000 ms (default 10000)
#   --socket NAME     abstract socket name, [A-Za-z0-9_-], <= 107 bytes
#                     (default: deterministic unique name per invocation)
#   --ro-bind PATH    additional absolute-path regular file bound read-only at
#                     its own path inside the sandbox (repeatable). Use only
#                     for a small allowlisted set of build artifacts.
#   --                separates launcher options from the command (required)
#
# The command must be an absolute path to an executable file. It is passed
# verbatim after `--` and is never reinterpreted. The command's own stdout and
# stderr go to the transient unit's journal; launcher diagnostics go to stderr.

set -u

SELF_NAME="tokyo-diag-launcher"

# ---- bounded constants -----------------------------------------------------
readonly DEADLINE_MIN_MS=100
readonly DEADLINE_MAX_MS=60000
readonly DEFAULT_DEADLINE_MS=10000
readonly MAX_SOCKET_BYTES=107
readonly RUNTIME_PREFIX="/tmp/tokyo-diag-runtime."
readonly UNIT_PREFIX="tokyo-contained-"
# Extra headroom above the systemd RuntimeMaxSec so the external `timeout`
# backstop only fires when systemd's own deadline failed to terminate the unit.
readonly GRACE_MS=5000
readonly TIMEOUT_KILL_AFTER="5s"

# ---- helpers ----------------------------------------------------------------
log() {
    printf '%s: %s\n' "$SELF_NAME" "$*" >&2
}

die() {
    printf '%s: error: %s\n' "$SELF_NAME" "$*" >&2
    exit 1
}

usage() {
    printf 'usage: %s [--deadline-ms N] [--socket NAME] [--ro-bind PATH] -- COMMAND [ARG...]\n' \
        "$0" >&2
}

# parse_deadline VALUE -> prints the validated decimal millisecond value on
# stdout; returns nonzero on any invalid input (non-digit, out of range, or an
# unreasonably long digit string that could overflow shell arithmetic).
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

# validate_socket_name NAME -> 0 when NAME is non-empty, uses only
# [A-Za-z0-9_-], and is at most MAX_SOCKET_BYTES bytes (ASCII here, so a
# character count equals a byte count for every accepted character).
validate_socket_name() {
    local name="$1"
    [ -n "$name" ] || return 1
    [ "${#name}" -le "$MAX_SOCKET_BYTES" ] || return 1
    case "$name" in
        *[!A-Za-z0-9_-]*) return 1 ;;
    esac
    return 0
}

# ---- argument parsing --------------------------------------------------------
deadline_ms=$DEFAULT_DEADLINE_MS
socket_name=""
socket_provided=0
separator_seen=0
ro_bind_paths=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --)
            separator_seen=1
            shift
            break
            ;;
        --deadline-ms)
            [ "$#" -ge 2 ] || { usage; die "missing value for --deadline-ms"; }
            deadline_ms=$(parse_deadline "$2") \
                || { usage; die "invalid --deadline-ms (expected ${DEADLINE_MIN_MS}..${DEADLINE_MAX_MS})"; }
            shift 2
            ;;
        --deadline-ms=*)
            deadline_ms=$(parse_deadline "${1#--deadline-ms=}") \
                || { usage; die "invalid --deadline-ms (expected ${DEADLINE_MIN_MS}..${DEADLINE_MAX_MS})"; }
            shift
            ;;
        --socket)
            [ "$#" -ge 2 ] || { usage; die "missing value for --socket"; }
            socket_name="$2"
            socket_provided=1
            shift 2
            ;;
        --socket=*)
            socket_name="${1#--socket=}"
            socket_provided=1
            shift
            ;;
        --ro-bind)
            [ "$#" -ge 2 ] || { usage; die "missing value for --ro-bind"; }
            ro_bind_paths+=("$2")
            shift 2
            ;;
        --ro-bind=*)
            ro_bind_paths+=("${1#--ro-bind=}")
            shift
            ;;
        -*)
            usage
            die "unknown option: $1 (the command must follow --)"
            ;;
        *)
            usage
            die "unexpected argument before --: $1"
            ;;
    esac
done

[ "$separator_seen" -eq 1 ] \
    || { usage; die "missing -- separator; the command must follow --"; }
[ "$#" -ge 1 ] || { usage; die "missing command after --"; }

command_path="$1"
shift
command_args=("$@")

# ---- preconditions (fail closed) --------------------------------------------
for tool in systemd-run bwrap timeout; do
    command -v "$tool" >/dev/null 2>&1 || die "required tool unavailable: $tool"
done

case "$command_path" in
    /*) : ;;
    *) usage; die "command must be an absolute path: $command_path" ;;
esac
[ -f "$command_path" ] || die "command is not a regular file: $command_path"
[ -x "$command_path" ] || die "command is not executable: $command_path"

# ---- additional read-only binds (allowlisted build artifacts) -----------------
# Each --ro-bind path must be an absolute path to an existing, readable regular
# file. A directory or special file fails closed rather than being silently
# mounted into the sandbox. Each is bound read-only at its own absolute path so
# the command (or its dynamic loader) can open it verbatim.
extra_ro_binds=()
for path in "${ro_bind_paths[@]}"; do
    case "$path" in
        /*) : ;;
        *) usage; die "--ro-bind must be an absolute path: $path" ;;
    esac
    [ -f "$path" ] || die "--ro-bind is not a regular file: $path"
    [ -r "$path" ] || die "--ro-bind is not readable: $path"
    extra_ro_binds+=(--ro-bind "$path" "$path")
done

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

unit_name="${UNIT_PREFIX}${token}.service"

if [ "$socket_provided" -eq 0 ]; then
    socket_name="tokyo-${token}"
fi
validate_socket_name "$socket_name" \
    || die "invalid --socket (use [A-Za-z0-9_-], at most ${MAX_SOCKET_BYTES} bytes)"

# RuntimeMaxSec derives from the validated deadline; the external `timeout`
# deadline is the same window plus a short grace so timeout is only a backstop.
runtime_max_sec="${deadline_ms}ms"
timeout_ms=$(( deadline_ms + GRACE_MS ))
timeout_seconds=$(( (timeout_ms + 999) / 1000 ))

log "unit=${unit_name} runtime_dir=${runtime_dir} socket=${socket_name} deadline_ms=${deadline_ms} command=${command_path}"

# ---- sandbox -----------------------------------------------------------------
# --unshare-all is mandatory and never a *-try flag: it covers user/ipc/pid/
# net/cgroup/uts/mount namespaces and fails hard if any cannot be created.
# The environment is cleared and only safe variables are re-added, so no host
# display, X11, session-bus, DRM, or udmabuf state can leak through. Only the
# fresh runtime directory is bound (at /run/tokyo-runtime); /dev is a private
# device set with no /dev/dri or /dev/udmabuf, /proc is a private pidns view,
# and /tmp and /run are private tmpfs mounts. The command's own file is bound
# read-only at its original absolute path so it can be executed verbatim.
bwrap_args=(
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
    --ro-bind "$command_path" "$command_path"
    "${extra_ro_binds[@]}"
    --setenv PATH /usr/bin:/bin
    --setenv HOME /home/tokyo
    --setenv XDG_RUNTIME_DIR /run/tokyo-runtime
    --setenv WAYLAND_DISPLAY "$socket_name"
    --chdir /run/tokyo-runtime
    --
    "$command_path"
    "${command_args[@]}"
)

systemd_run_args=(
    systemd-run
    --user
    --wait
    --collect
    "--unit=${unit_name}"
    --property=LimitCORE=1
    --property=MemoryMax=32M
    --property=TasksMax=8
    --property=LimitNOFILE=64
    --property=LimitAS=128M
    "--property=RuntimeMaxSec=${runtime_max_sec}"
    --property=KillMode=control-group
    --property=NoNewPrivileges=yes
    --
)

# ---- launch ------------------------------------------------------------------
timeout --signal=TERM --kill-after="$TIMEOUT_KILL_AFTER" "${timeout_seconds}s" \
    "${systemd_run_args[@]}" "${bwrap_args[@]}"
status=$?

# The EXIT trap removes only the private runtime directory; the transient unit
# identity (never a bare PID) is collected by systemd-run --collect.
exit "$status"
