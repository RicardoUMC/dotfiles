// Minimal protocol-level negative regression client for the disposable compositor.
// Each invocation intentionally sends one invalid wl_subcompositor request. A
// protocol error (and therefore a nonzero client exit) is the expected result.

#include <wayland-client-core.h>
#include <wayland-client-protocol.h>

#include <cstring>
#include <iostream>
#include <string>
#include <string_view>

namespace {

struct Globals {
    wl_compositor* compositor = nullptr;
    wl_subcompositor* subcompositor = nullptr;
};

void global(void* data, wl_registry* registry, uint32_t name, const char* interface, uint32_t version)
{
    auto* globals = static_cast<Globals*>(data);
    if (std::strcmp(interface, wl_compositor_interface.name) == 0) {
        globals->compositor = static_cast<wl_compositor*>(wl_registry_bind(
            registry, name, &wl_compositor_interface, version < 1 ? version : 1));
    } else if (std::strcmp(interface, wl_subcompositor_interface.name) == 0) {
        globals->subcompositor = static_cast<wl_subcompositor*>(wl_registry_bind(
            registry, name, &wl_subcompositor_interface, version < 1 ? version : 1));
    }
}

void global_remove(void*, wl_registry*, uint32_t) {}

const wl_registry_listener registry_listener = { global, global_remove };

int reject_self_parent(wl_display* display, Globals* globals)
{
    wl_surface* surface = wl_compositor_create_surface(globals->compositor);
    wl_subsurface* request = wl_subcompositor_get_subsurface(
        globals->subcompositor, surface, surface);
    if (!request) {
        wl_surface_destroy(surface);
        return 1;
    }
    wl_display_flush(display);
    const int roundtrip = wl_display_roundtrip(display);
    const int error = wl_display_get_error(display);
    std::cerr << "TOKYO_CYCLE_PROBE case=self-parent roundtrip=" << roundtrip
              << " display_error=" << error << "\n";
    // The server must reject the request. Do not treat a clean roundtrip as a
    // pass: that would allow a regression to silently become positive.
    return (roundtrip < 0 && error != 0) ? 9 : 1;
}

int reject_ancestor_cycle(wl_display* display, Globals* globals)
{
    wl_surface* first = wl_compositor_create_surface(globals->compositor);
    wl_surface* second = wl_compositor_create_surface(globals->compositor);
    if (!first || !second) {
        return 1;
    }

    // first -> second is valid; second -> first would close the ancestor cycle.
    wl_subsurface* first_role = wl_subcompositor_get_subsurface(
        globals->subcompositor, first, second);
    if (!first_role || wl_display_roundtrip(display) < 0) {
        return 1;
    }
    wl_subsurface* second_role = wl_subcompositor_get_subsurface(
        globals->subcompositor, second, first);
    if (!second_role) {
        return 1;
    }
    wl_display_flush(display);
    const int roundtrip = wl_display_roundtrip(display);
    const int error = wl_display_get_error(display);
    std::cerr << "TOKYO_CYCLE_PROBE case=ancestor-cycle roundtrip=" << roundtrip
              << " display_error=" << error << "\n";
    return (roundtrip < 0 && error != 0) ? 9 : 1;
}

} // namespace

int main(int argc, char** argv)
{
    if (argc != 3 || std::string_view(argv[1]) != "--case" ||
        (std::string_view(argv[2]) != "self" && std::string_view(argv[2]) != "cycle")) {
        std::cerr << "usage: " << argv[0] << " --case self|cycle\n";
        return 2;
    }

    wl_display* display = wl_display_connect(nullptr);
    if (!display) {
        std::cerr << "TOKYO_CYCLE_PROBE connect failed\n";
        return 1;
    }
    Globals globals;
    wl_registry* registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, &globals);
    if (wl_display_roundtrip(display) < 0 || !globals.compositor || !globals.subcompositor) {
        wl_display_disconnect(display);
        return 1;
    }

    const int result = std::string_view(argv[2]) == "self"
        ? reject_self_parent(display, &globals)
        : reject_ancestor_cycle(display, &globals);
    wl_display_disconnect(display);
    return result;
}
