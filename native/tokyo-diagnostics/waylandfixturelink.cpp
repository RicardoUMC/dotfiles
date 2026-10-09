#include <wayland-server-core.h>
#include <wayland-server-protocol.h>
#include <xdg-shell-server-protocol.h>

// Build/link-only fixture for the public libwayland server API. The function
// takes no action and is never called by this project.
extern "C" const wl_interface *tokyo_wayland_fixture_link_check()
{
    static const wl_interface *const required_interfaces[] = {
        &wl_compositor_interface,
        &wl_shm_interface,
        &wl_subcompositor_interface,
        &wl_output_interface,
        &xdg_wm_base_interface,
    };
    return required_interfaces[0];
}
