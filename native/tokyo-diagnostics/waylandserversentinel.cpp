#include <wayland-server-core.h>
#include <wayland-server-protocol.h>

// This symbol is intentionally inert: it only references a server-side API
// object so the target must compile against the installed headers and link
// through the pkg-config-provided wayland-server dependency. It never calls a
// Wayland function or creates a display, socket, global, or other runtime state.
extern "C" const wl_interface *tokyo_wayland_server_api_sentinel()
{
    return &wl_display_interface;
}
