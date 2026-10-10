// Qt-independent, build-only public Wayland protocol server.
//
// This executable creates exactly one private server socket and registers the
// five protocol globals required for the future disposable-compositor harness:
// wl_compositor, wl_shm, wl_subcompositor, wl_output, and xdg_wm_base (via the
// generated stable xdg-shell server API). It advertises no request handlers and
// implements no compositor, client, CPU composition, visual ordering, or
// runtime containment. It is a build/structural unit only and must not be run
// until a separate containment authorization: it never launches a compositor or
// client, never opens DRM/devices, and never touches the active desktop or an
// inherited WAYLAND_DISPLAY. Its socket name and bounded deadline are validated
// the same way as the lifecycle sentinel, and setup errors fail closed with
// deterministic teardown of every registered global before the display is
// destroyed.

#include <wayland-server-core.h>
#include <wayland-server-protocol.h>
#include <xdg-shell-server-protocol.h>

#include <cerrno>
#include <cctype>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <string>
#include <string_view>
#include <unistd.h>

namespace {

constexpr int kDefaultDeadlineMs = 1000;
constexpr std::size_t kMaxSocketNameLength = 107;
constexpr std::size_t kGlobalCount = 5;

// Advertised interface versions. These are conservative, widely supported
// subsets of each protocol (never the bleeding-edge maximum), so a future
// client implementation has a stable negotiation surface to target.
constexpr int kCompositorVersion = 4;
constexpr int kShmVersion = 1;
constexpr int kSubcompositorVersion = 1;
constexpr int kOutputVersion = 3;
constexpr int kXdgWmBaseVersion = 3;

struct ProtocolServerState {
    wl_display* display = nullptr;
    bool terminated = false;
};

bool valid_socket_name(std::string_view name)
{
    if (name.empty() || name == "." || name == ".." || name.size() > kMaxSocketNameLength) {
        return false;
    }

    for (const unsigned char character : name) {
        if (!(std::isalnum(character) || character == '_' || character == '-')) {
            return false;
        }
    }
    return true;
}

bool parse_deadline(std::string_view value, int& deadline_ms)
{
    if (value.empty()) {
        return false;
    }

    for (const unsigned char character : value) {
        if (!std::isdigit(character)) {
            return false;
        }
    }

    errno = 0;
    char* end = nullptr;
    const std::string owned_value(value);
    const long parsed = std::strtol(owned_value.c_str(), &end, 10);
    if (errno != 0 || end == owned_value.c_str() || *end != '\0' || parsed < 1 || parsed > 60000) {
        return false;
    }

    deadline_ms = static_cast<int>(parsed);
    return true;
}

void print_usage(const char* program)
{
    std::cerr << "usage: " << program << " --socket NAME [--deadline-ms N]\n";
}

// Request handlers are intentionally empty: this server registers globals for
// discovery/connection testing only and implements no request semantics. A
// future client implementation must replace these with real handlers. The
// parameters are unnamed so the signatures match the generated/installed
// interface structs exactly without triggering unused-argument warnings.

void noop_destroy(struct wl_client*, struct wl_resource*) {}
void noop_release(struct wl_client*, struct wl_resource*) {}

void compositor_create_surface(struct wl_client*, struct wl_resource*, uint32_t) {}
void compositor_create_region(struct wl_client*, struct wl_resource*, uint32_t) {}

const struct wl_compositor_interface compositor_impl = {
    compositor_create_surface,
    compositor_create_region,
    noop_release,
};

void shm_create_pool(struct wl_client*, struct wl_resource*, uint32_t, int32_t, int32_t) {}

const struct wl_shm_interface shm_impl = {
    shm_create_pool,
    noop_release,
};

void subcompositor_get_subsurface(
    struct wl_client*, struct wl_resource*, uint32_t, struct wl_resource*, struct wl_resource*) {}

const struct wl_subcompositor_interface subcompositor_impl = {
    noop_destroy,
    subcompositor_get_subsurface,
};

const struct wl_output_interface output_impl = {
    noop_release,
};

void xdg_wm_base_create_positioner(struct wl_client*, struct wl_resource*, uint32_t) {}
void xdg_wm_base_get_xdg_surface(
    struct wl_client*, struct wl_resource*, uint32_t, struct wl_resource*) {}
void xdg_wm_base_pong(struct wl_client*, struct wl_resource*, uint32_t) {}

const struct xdg_wm_base_interface xdg_wm_base_impl = {
    noop_destroy,
    xdg_wm_base_create_positioner,
    xdg_wm_base_get_xdg_surface,
    xdg_wm_base_pong,
};

// Binds a client request to a resource that carries only the minimal no-op
// implementation. Every global shares this helper; it differs only in the
// interface and implementation pointers supplied by each bind entry point.
void bind_global(struct wl_client* client,
                 const struct wl_interface* interface,
                 const void* implementation,
                 void* data,
                 uint32_t version,
                 uint32_t id)
{
    struct wl_resource* resource =
        wl_resource_create(client, interface, static_cast<int>(version), id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(resource, implementation, data, nullptr);
}

void bind_compositor(struct wl_client* client, void* data, uint32_t version, uint32_t id)
{
    bind_global(client, &wl_compositor_interface, &compositor_impl, data, version, id);
}

void bind_shm(struct wl_client* client, void* data, uint32_t version, uint32_t id)
{
    bind_global(client, &wl_shm_interface, &shm_impl, data, version, id);
}

void bind_subcompositor(struct wl_client* client, void* data, uint32_t version, uint32_t id)
{
    bind_global(client, &wl_subcompositor_interface, &subcompositor_impl, data, version, id);
}

void bind_output(struct wl_client* client, void* data, uint32_t version, uint32_t id)
{
    bind_global(client, &wl_output_interface, &output_impl, data, version, id);
}

void bind_xdg_wm_base(struct wl_client* client, void* data, uint32_t version, uint32_t id)
{
    bind_global(client, &xdg_wm_base_interface, &xdg_wm_base_impl, data, version, id);
}

int timer_callback(void* data)
{
    auto* state = static_cast<ProtocolServerState*>(data);
    state->terminated = true;
    wl_display_terminate(state->display);
    return 0;
}

} // namespace

int main(int argc, char** argv)
{
    std::string socket_name;
    int deadline_ms = kDefaultDeadlineMs;

    for (int index = 1; index < argc; ++index) {
        const std::string_view argument(argv[index]);
        if (argument == "--socket" && index + 1 < argc) {
            socket_name = argv[++index];
        } else if (argument == "--deadline-ms" && index + 1 < argc) {
            if (!parse_deadline(argv[++index], deadline_ms)) {
                std::cerr << "invalid --deadline-ms (expected 1..60000)\n";
                return 2;
            }
        } else {
            print_usage(argv[0]);
            return 2;
        }
    }

    if (!valid_socket_name(socket_name)) {
        std::cerr << "invalid or missing --socket (use an alphanumeric, '_' or '-' name)\n";
        return 2;
    }

    wl_display* display = wl_display_create();
    if (!display) {
        std::cerr << "wl_display_create failed\n";
        return 1;
    }

    if (wl_display_add_socket(display, socket_name.c_str()) != 0) {
        std::cerr << "wl_display_add_socket failed\n";
        wl_display_destroy(display);
        return 1;
    }

    // Register the required globals. Registration order is fixed so teardown
    // can destroy them deterministically in reverse order. Any registration
    // failure fails closed: already-created globals are destroyed before the
    // display so no partial protocol surface survives.
    struct wl_global* globals[kGlobalCount] = {};
    std::size_t global_count = 0;

    auto register_global = [&](const struct wl_interface* interface,
                               int version,
                               wl_global_bind_func_t bind) -> bool {
        struct wl_global* global =
            wl_global_create(display, interface, version, nullptr, bind);
        if (!global) {
            return false;
        }
        globals[global_count++] = global;
        return true;
    };

    const bool registered =
        register_global(&wl_compositor_interface, kCompositorVersion, bind_compositor) &&
        register_global(&wl_shm_interface, kShmVersion, bind_shm) &&
        register_global(&wl_subcompositor_interface, kSubcompositorVersion, bind_subcompositor) &&
        register_global(&wl_output_interface, kOutputVersion, bind_output) &&
        register_global(&xdg_wm_base_interface, kXdgWmBaseVersion, bind_xdg_wm_base);

    if (!registered) {
        std::cerr << "wl_global_create failed\n";
        for (std::size_t index = global_count; index > 0; --index) {
            wl_global_destroy(globals[index - 1]);
        }
        wl_display_destroy(display);
        return 1;
    }

    ProtocolServerState state{display};
    wl_event_source* timer = wl_event_loop_add_timer(
        wl_display_get_event_loop(display), timer_callback, &state);
    if (!timer || wl_event_source_timer_update(timer, deadline_ms) != 0) {
        std::cerr << "timer setup failed\n";
        if (timer) {
            wl_event_source_remove(timer);
        }
        for (std::size_t index = global_count; index > 0; --index) {
            wl_global_destroy(globals[index - 1]);
        }
        wl_display_destroy(display);
        return 1;
    }

    std::cout << "TOKYO_WAYLAND_PROTOCOL_SERVER_READY"
              << " pid=" << static_cast<long long>(getpid())
              << " socket=" << socket_name
              << " deadline_ms=" << deadline_ms
              << " globals=wl_compositor,wl_shm,wl_subcompositor,wl_output,xdg_wm_base\n";
    std::cout.flush();

    int result = 0;
    while (!state.terminated) {
        if (wl_event_loop_dispatch(wl_display_get_event_loop(display), -1) < 0) {
            result = 1;
            break;
        }
    }

    // Deterministic teardown: globals first (reverse registration order), then
    // any remaining clients, then the display itself.
    for (std::size_t index = global_count; index > 0; --index) {
        wl_global_destroy(globals[index - 1]);
    }
    wl_display_destroy_clients(display);
    wl_display_destroy(display);
    return result;
}
