// Qt-independent, CPU-only disposable Wayland compositor.
//
// This executable creates exactly one private server socket (supplied via
// --socket) and registers the five protocol globals required by the disposable
// compositor harness: wl_compositor, wl_shm (through libwayland's built-in
// shm implementation), wl_subcompositor, wl_output, and xdg_wm_base (via the
// generated stable xdg-shell server API). It implements enough request
// semantics for a Qt Wayland SHM client: surface creation and commit, shm
// pools/buffers, xdg surface/toplevel configure + ack, subsurface placement and
// ordering, frame callbacks, and buffer release. It never opens DRM, udmabuf,
// GPU devices, or a seat, and it never touches the active desktop or an
// inherited WAYLAND_DISPLAY.
//
// Composition is software-only: a committed toplevel scene is blitted into a
// bounded in-memory ARGB framebuffer and reduced to a bounded textual frame
// record (a 32-bit digest plus the ordered subsurface stack). That record is
// evidence that ordering variants produced distinguishable CPU framebuffer
// results; it is NOT a claim of visual ordering on a real display. The event
// loop runs until its bounded deadline or until the last client disconnects,
// then tears down deterministically.

#include <wayland-server-core.h>
#include <wayland-server-protocol.h>
#include <xdg-shell-server-protocol.h>
#include <ext-background-effect-v1-server-protocol.h>

#include <unistd.h>
#include <time.h>

#include <algorithm>
#include <array>
#include <cerrno>
#include <cctype>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

namespace {

constexpr int kDefaultDeadlineMs = 1000;
constexpr std::size_t kMaxSocketNameLength = 107;
constexpr std::size_t kMaxEvidenceEntries = 16;
constexpr uint32_t kMaxSubsurfaceCreationIndex = 1000000;
constexpr int kMaxCanvasDim = 2048;

// Advertised interface versions: conservative, widely supported subsets.
constexpr int kCompositorVersion = 4;
constexpr int kSubcompositorVersion = 1;
constexpr int kOutputVersion = 3;
constexpr int kXdgWmBaseVersion = 3;

constexpr int kOutputWidth = 800;
constexpr int kOutputHeight = 600;

struct Compositor;
struct Surface;
struct RegionData {
    std::vector<std::array<int32_t, 4>> rectangles;
};
struct Subsurface;
struct XdgSurface;
struct XdgToplevel;
struct BackgroundEffect;

struct Compositor {
    wl_display* display = nullptr;
    uint32_t next_serial = 1;
    uint64_t frame_counter = 0;
    uint32_t next_subsurface_creation_index = 1;
    uint32_t client_count = 0;
    bool ever_had_client = false;
    bool terminated = false;
    bool protocol_error = false;
    const char* exit_reason = "deadline";

    struct wl_listener client_created_listener = {};
};

Compositor* g_compositor = nullptr;

struct Surface {
    Surface()
    {
        wl_list_init(&pending_buffer_listener.link);
        wl_list_init(&current_buffer_listener.link);
    }

    wl_resource* resource = nullptr;

    // Pending (double-buffered) surface state.
    wl_resource* pending_buffer = nullptr;
    struct wl_listener pending_buffer_listener;
    bool has_pending_buffer = false;
    int32_t pending_dx = 0;
    int32_t pending_dy = 0;

    // Committed (current) surface state.
    wl_resource* current_buffer = nullptr;
    struct wl_listener current_buffer_listener;
    bool has_current_buffer = false;

    BackgroundEffect* background_effect = nullptr;
    std::vector<std::array<int32_t, 4>> pending_background_rectangles;
    std::vector<std::array<int32_t, 4>> current_background_rectangles;

    std::vector<wl_resource*> pending_frames;
    std::vector<wl_resource*> committed_frames;

    enum class Role { None, Toplevel, Subsurface, Popup };
    Role role = Role::None;
    XdgSurface* xdg = nullptr;
    Subsurface* subsurface = nullptr;

    // Subsurface stacking relative to this surface acting as a parent.
    std::vector<Subsurface*> below; // below parent, bottom -> top
    std::vector<Subsurface*> above; // above parent, bottom -> top
};

struct Subsurface {
    wl_resource* resource = nullptr;
    uint32_t creation_index = 0;
    Surface* surface = nullptr;
    Surface* parent = nullptr;
    int32_t x = 0;
    int32_t y = 0;
    bool sync = true;
    bool above_parent = true;
};

struct XdgSurface {
    wl_resource* resource = nullptr;
    Surface* surface = nullptr;
    XdgToplevel* toplevel = nullptr;
    bool configured = false;
};

struct XdgToplevel {
    wl_resource* resource = nullptr;
    XdgSurface* xdg = nullptr;
};

struct BackgroundEffect {
    wl_resource* resource = nullptr;
    Surface* surface = nullptr;
};

Surface* get_surface(wl_resource* resource)
{
    return resource ? static_cast<Surface*>(wl_resource_get_user_data(resource)) : nullptr;
}

Subsurface* get_sub(wl_resource* resource)
{
    return resource ? static_cast<Subsurface*>(wl_resource_get_user_data(resource)) : nullptr;
}

XdgSurface* get_xdg(wl_resource* resource)
{
    return resource ? static_cast<XdgSurface*>(wl_resource_get_user_data(resource)) : nullptr;
}

void emit(const std::string& line)
{
    std::cout << line << "\n";
    std::cout.flush();
}

std::string hex32(uint32_t value)
{
    char buffer[16];
    std::snprintf(buffer, sizeof(buffer), "%08x", value);
    return std::string(buffer);
}

uint32_t monotonic_ms()
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return static_cast<uint32_t>(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}

uint32_t fnv1a(const std::vector<uint32_t>& framebuffer)
{
    uint32_t hash = 2166136261u;
    for (const uint32_t pixel : framebuffer) {
        hash ^= pixel & 0xFFu;
        hash *= 16777619u;
        hash ^= (pixel >> 8) & 0xFFu;
        hash *= 16777619u;
        hash ^= (pixel >> 16) & 0xFFu;
        hash *= 16777619u;
        hash ^= (pixel >> 24) & 0xFFu;
        hash *= 16777619u;
    }
    return hash;
}

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

struct wl_resource* create_resource(struct wl_client* client,
                                    const struct wl_interface* interface,
                                    const void* implementation,
                                    int version,
                                    uint32_t id,
                                    void* data,
                                    wl_resource_destroy_func_t destroy)
{
    struct wl_resource* resource = wl_resource_create(client, interface, version, id);
    if (!resource) {
        wl_client_post_no_memory(client);
        return nullptr;
    }
    wl_resource_set_implementation(resource, implementation, data, destroy);
    return resource;
}

// ---- Client lifecycle -----------------------------------------------------

void client_destroyed(struct wl_listener* listener, void* data);

void client_created(struct wl_listener*, void* data)
{
    Compositor* compositor = g_compositor;
    compositor->client_count++;
    compositor->ever_had_client = true;

    // One fresh destroy listener per client so concurrent clients stay safe.
    struct wl_listener* listener = new struct wl_listener;
    listener->notify = client_destroyed;
    wl_client_add_destroy_listener(static_cast<wl_client*>(data), listener);
}

void client_destroyed(struct wl_listener* listener, void*)
{
    Compositor* compositor = g_compositor;
    wl_list_remove(&listener->link);
    delete listener;

    if (compositor->client_count > 0) {
        compositor->client_count--;
    }
    if (compositor->ever_had_client && compositor->client_count == 0 && !compositor->terminated) {
        compositor->terminated = true;
        compositor->exit_reason = compositor->protocol_error ? "protocol-error" : "client-disconnect";
        wl_display_terminate(compositor->display);
    }
}

// ---- Buffer lifetime tracking ---------------------------------------------

void surface_current_buffer_destroyed(struct wl_listener* listener, void*)
{
    Surface* surface = wl_container_of(listener, surface, current_buffer_listener);
    surface->current_buffer = nullptr;
    surface->has_current_buffer = false;
    wl_list_remove(&surface->current_buffer_listener.link);
    wl_list_init(&surface->current_buffer_listener.link);
}

void surface_pending_buffer_destroyed(struct wl_listener* listener, void*)
{
    Surface* surface = wl_container_of(listener, surface, pending_buffer_listener);
    surface->pending_buffer = nullptr;
    surface->has_pending_buffer = false;
    wl_list_remove(&surface->pending_buffer_listener.link);
    wl_list_init(&surface->pending_buffer_listener.link);
}

void surface_set_current_buffer(Surface* surface, wl_resource* buffer)
{
    if (!wl_list_empty(&surface->current_buffer_listener.link)) {
        wl_list_remove(&surface->current_buffer_listener.link);
        wl_list_init(&surface->current_buffer_listener.link);
    }
    surface->current_buffer = buffer;
    if (buffer) {
        surface->current_buffer_listener.notify = surface_current_buffer_destroyed;
        wl_resource_add_destroy_listener(buffer, &surface->current_buffer_listener);
    }
}

void surface_set_pending_buffer(Surface* surface, wl_resource* buffer)
{
    if (!wl_list_empty(&surface->pending_buffer_listener.link)) {
        wl_list_remove(&surface->pending_buffer_listener.link);
        wl_list_init(&surface->pending_buffer_listener.link);
    }
    surface->pending_buffer = buffer;
    if (buffer) {
        surface->pending_buffer_listener.notify = surface_pending_buffer_destroyed;
        wl_resource_add_destroy_listener(buffer, &surface->pending_buffer_listener);
    }
}

// ---- Software composition -------------------------------------------------

void draw_surface(Surface* surface,
                  std::vector<uint32_t>& framebuffer,
                  int framebuffer_width,
                  int framebuffer_height,
                  int offset_x,
                  int offset_y)
{
    if (!surface || !surface->has_current_buffer || !surface->current_buffer) {
        return;
    }
    wl_shm_buffer* shm = wl_shm_buffer_get(surface->current_buffer);
    if (!shm) {
        return;
    }

    wl_shm_buffer_begin_access(shm);
    const uint32_t format = wl_shm_buffer_get_format(shm);
    const int width = wl_shm_buffer_get_width(shm);
    const int height = wl_shm_buffer_get_height(shm);
    const int stride = wl_shm_buffer_get_stride(shm);
    const uint8_t* base = static_cast<const uint8_t*>(wl_shm_buffer_get_data(shm));
    if (!base) {
        wl_shm_buffer_end_access(shm);
        return;
    }

    for (int y = 0; y < height; ++y) {
        const int target_y = offset_y + y;
        if (target_y < 0 || target_y >= framebuffer_height) {
            continue;
        }
        const uint32_t* row =
            reinterpret_cast<const uint32_t*>(base + static_cast<std::size_t>(y) * stride);
        for (int x = 0; x < width; ++x) {
            const int target_x = offset_x + x;
            if (target_x < 0 || target_x >= framebuffer_width) {
                continue;
            }
            uint32_t pixel = row[x];
            if (format == WL_SHM_FORMAT_XRGB8888) {
                pixel |= 0xFF000000u; // XRGB8888 has no alpha; force opaque.
            }
            framebuffer[static_cast<std::size_t>(target_y) * framebuffer_width + target_x] = pixel;
        }
    }
    wl_shm_buffer_end_access(shm);
}

Surface* toplevel_root(Surface* surface)
{
    while (surface && surface->role == Surface::Role::Subsurface && surface->subsurface &&
           surface->subsurface->parent) {
        surface = surface->subsurface->parent;
    }
    return surface;
}

bool creates_subsurface_cycle(const Surface* surface, const Surface* parent)
{
    const Surface* cursor = parent;
    while (cursor && cursor->role == Surface::Role::Subsurface && cursor->subsurface &&
           cursor->subsurface->parent) {
        if (cursor == surface) {
            return true;
        }
        cursor = cursor->subsurface->parent;
    }
    return cursor == surface;
}

void composite_toplevel(Surface* root)
{
    if (!root->has_current_buffer || !root->current_buffer) {
        return;
    }
    wl_shm_buffer* root_shm = wl_shm_buffer_get(root->current_buffer);
    if (!root_shm) {
        return;
    }

    const int source_width = wl_shm_buffer_get_width(root_shm);
    const int source_height = wl_shm_buffer_get_height(root_shm);
    if (source_width <= 0 || source_height <= 0) {
        return;
    }

    const int width = std::min(source_width, kMaxCanvasDim);
    const int height = std::min(source_height, kMaxCanvasDim);
    const bool clamped = width < source_width || height < source_height;

    std::vector<uint32_t> framebuffer(static_cast<std::size_t>(width) * height, 0x00000000u);

    std::ostringstream order;
    std::size_t entries = 0;
    auto record = [&](const std::string& token) {
        if (entries >= kMaxEvidenceEntries) {
            return;
        }
        if (entries > 0) {
            order << ">";
        }
        order << token;
        ++entries;
    };

    for (Subsurface* sub : root->below) {
        if (!sub || !sub->surface) {
            continue;
        }
        draw_surface(sub->surface, framebuffer, width, height, sub->x, sub->y);
        record("sub:" + std::to_string(wl_resource_get_id(sub->surface->resource)) +
               ":child=" + std::to_string(sub->creation_index) + "@" + std::to_string(sub->x) +
               "," + std::to_string(sub->y) + "(below)");
    }
    draw_surface(root, framebuffer, width, height, 0, 0);
    record("parent");
    for (Subsurface* sub : root->above) {
        if (!sub || !sub->surface) {
            continue;
        }
        draw_surface(sub->surface, framebuffer, width, height, sub->x, sub->y);
        record("sub:" + std::to_string(wl_resource_get_id(sub->surface->resource)) +
               ":child=" + std::to_string(sub->creation_index) + "@" + std::to_string(sub->x) +
               "," + std::to_string(sub->y) + "(above)");
    }

    const std::size_t total_entries = root->below.size() + root->above.size() + 1;
    if (entries < total_entries) {
        order << ">...";
    }

    const uint32_t digest = fnv1a(framebuffer);
    ++g_compositor->frame_counter;

    emit("TOKYO_FRAME root=" + std::to_string(wl_resource_get_id(root->resource)) +
         " frame=" + std::to_string(g_compositor->frame_counter) + " size=" + std::to_string(width) +
         "x" + std::to_string(height) + " clamped=" + (clamped ? "1" : "0") +
         " order=" + order.str() + " digest=0x" + hex32(digest));
}

// ---- Subsurface placement -------------------------------------------------

void erase_sub(Surface* parent, Subsurface* sub)
{
    parent->below.erase(std::remove(parent->below.begin(), parent->below.end(), sub),
                        parent->below.end());
    parent->above.erase(std::remove(parent->above.begin(), parent->above.end(), sub),
                        parent->above.end());
}

const char* role_name(Surface::Role role)
{
    switch (role) {
    case Surface::Role::None:
        return "none";
    case Surface::Role::Toplevel:
        return "toplevel";
    case Surface::Role::Subsurface:
        return "subsurface";
    case Surface::Role::Popup:
        return "popup";
    }
    return "unknown";
}

void emit_role(Surface* surface)
{
    emit(std::string("TOKYO_STATE event=role surface=") +
         std::to_string(wl_resource_get_id(surface->resource)) + " role=" + role_name(surface->role));
}

void send_toplevel_configure(XdgSurface* xdg)
{
    const uint32_t serial = g_compositor->next_serial++;
    xdg->configured = true;

    wl_array states;
    wl_array_init(&states);
    xdg_toplevel_send_configure(xdg->toplevel->resource, 0, 0, &states);
    wl_array_release(&states);
    xdg_surface_send_configure(xdg->resource, serial);

    emit(std::string("TOKYO_STATE event=configure surface=") +
         std::to_string(wl_resource_get_id(xdg->surface->resource)) +
         " serial=" + std::to_string(serial) + " size=0x0");
}

void place_sub(wl_resource* resource, wl_resource* sibling, bool above)
{
    Subsurface* sub = get_sub(resource);
    if (!sub || !sub->parent) {
        return;
    }
    Surface* parent = sub->parent;

    erase_sub(parent, sub);

    if (sibling == parent->resource) {
        sub->above_parent = true;
        if (above) {
            parent->above.insert(parent->above.begin(), sub);
        } else {
            parent->below.push_back(sub);
            sub->above_parent = false;
        }
    } else {
        // wl_subsurface.place_above/below receives the sibling's wl_surface,
        // not the sibling's wl_subsurface resource. Resolve the surface first,
        // then use its role-owned subsurface and validate the shared parent.
        Surface* sibling_surface = get_surface(sibling);
        Subsurface* sibling_sub = sibling_surface ? sibling_surface->subsurface : nullptr;
        if (!sibling_sub || sibling_sub->parent != parent) {
            // Invalid reference: keep the surface above the parent.
            parent->above.insert(parent->above.begin(), sub);
            sub->above_parent = true;
        } else if (sibling_sub->above_parent) {
            auto it = std::find(parent->above.begin(), parent->above.end(), sibling_sub);
            if (above) {
                ++it;
            }
            parent->above.insert(it, sub);
            sub->above_parent = true;
        } else {
            auto it = std::find(parent->below.begin(), parent->below.end(), sibling_sub);
            if (above) {
                ++it;
            }
            parent->below.insert(it, sub);
            sub->above_parent = false;
        }
    }

    emit(std::string("TOKYO_STATE event=subsurface-place surface=") +
         std::to_string(wl_resource_get_id(sub->resource)) + " ref=" +
         (sibling == parent->resource
              ? std::string("parent")
              : "surface:" + std::to_string(wl_resource_get_id(sibling))) +
         " mode=" + (above ? "above" : "below"));
}

// ---- Resource teardown ----------------------------------------------------

void surface_resource_destroyed(struct wl_resource* resource)
{
    Surface* surface = get_surface(resource);
    if (!surface) {
        return;
    }

    // Detach the subsurface role from its parent, if any.
    if (surface->role == Surface::Role::Subsurface && surface->subsurface) {
        Subsurface* sub = surface->subsurface;
        if (sub->parent) {
            erase_sub(sub->parent, sub);
        }
        sub->surface = nullptr;
        surface->subsurface = nullptr;
    }

    // Detach the xdg surface and its role object before the wl_surface
    // storage disappears; client disconnect teardown does not guarantee role
    // resources are destroyed in dependency order.
    if (surface->xdg) {
        surface->xdg->surface = nullptr;
        if (surface->xdg->toplevel) {
            surface->xdg->toplevel->xdg = nullptr;
            surface->xdg->toplevel = nullptr;
        }
    }

    // Detach any child subsurfaces of this surface.
    for (Subsurface* sub : surface->below) {
        sub->parent = nullptr;
    }
    for (Subsurface* sub : surface->above) {
        sub->parent = nullptr;
    }
    surface->below.clear();
    surface->above.clear();

    // Stop listening to buffer destruction before the buffers are torn down.
    if (!wl_list_empty(&surface->current_buffer_listener.link)) {
        wl_list_remove(&surface->current_buffer_listener.link);
        wl_list_init(&surface->current_buffer_listener.link);
    }
    if (!wl_list_empty(&surface->pending_buffer_listener.link)) {
        wl_list_remove(&surface->pending_buffer_listener.link);
        wl_list_init(&surface->pending_buffer_listener.link);
    }

    delete surface;
}

void subsurface_resource_destroyed(struct wl_resource* resource)
{
    Subsurface* sub = get_sub(resource);
    if (!sub) {
        return;
    }
    if (sub->parent) {
        erase_sub(sub->parent, sub);
    }
    if (sub->surface) {
        sub->surface->subsurface = nullptr;
        if (sub->surface->role == Surface::Role::Subsurface) {
            sub->surface->role = Surface::Role::None;
        }
    }
    delete sub;
}

void xdg_surface_resource_destroyed(struct wl_resource* resource)
{
    XdgSurface* xdg = get_xdg(resource);
    if (!xdg) {
        return;
    }
    if (xdg->toplevel) {
        xdg->toplevel->xdg = nullptr;
        xdg->toplevel = nullptr;
    }
    if (xdg->surface) {
        xdg->surface->xdg = nullptr;
        if (xdg->surface->role == Surface::Role::Toplevel ||
            xdg->surface->role == Surface::Role::Popup) {
            xdg->surface->role = Surface::Role::None;
        }
    }
    delete xdg;
}

void xdg_toplevel_resource_destroyed(struct wl_resource* resource)
{
    XdgToplevel* toplevel = static_cast<XdgToplevel*>(wl_resource_get_user_data(resource));
    if (!toplevel) {
        return;
    }
    if (toplevel->xdg) {
        toplevel->xdg->toplevel = nullptr;
        if (toplevel->xdg->surface && toplevel->xdg->surface->role == Surface::Role::Toplevel) {
            toplevel->xdg->surface->role = Surface::Role::None;
        }
    }
    delete toplevel;
}

// ---- wl_surface -----------------------------------------------------------

void surface_destroy(struct wl_client*, struct wl_resource* resource)
{
    wl_resource_destroy(resource);
}

void surface_attach(struct wl_client*,
                    struct wl_resource* resource,
                    struct wl_resource* buffer,
                    int32_t x,
                    int32_t y)
{
    Surface* surface = get_surface(resource);
    if (!surface) {
        return;
    }
    surface_set_pending_buffer(surface, buffer);
    surface->has_pending_buffer = true;
    surface->pending_dx = x;
    surface->pending_dy = y;
}

void surface_damage(struct wl_client*, struct wl_resource*, int32_t, int32_t, int32_t, int32_t)
{
}

void surface_frame(struct wl_client* client, struct wl_resource* resource, uint32_t callback)
{
    Surface* surface = get_surface(resource);
    if (!surface) {
        return;
    }
    struct wl_resource* callback_resource =
        wl_resource_create(client, &wl_callback_interface, 1, callback);
    if (!callback_resource) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(callback_resource, nullptr, nullptr, nullptr);
    surface->pending_frames.push_back(callback_resource);
}

void surface_set_opaque_region(struct wl_client*, struct wl_resource*, struct wl_resource*)
{
}

void background_effect_destroyed(struct wl_resource* resource)
{
    auto* effect = static_cast<BackgroundEffect*>(wl_resource_get_user_data(resource));
    if (!effect)
        return;
    if (effect->surface && effect->surface->background_effect == effect) {
        effect->surface->background_effect = nullptr;
        effect->surface->pending_background_rectangles.clear();
        effect->surface->current_background_rectangles.clear();
    }
    delete effect;
}

void background_effect_destroy(struct wl_client*, struct wl_resource* resource)
{
    wl_resource_destroy(resource);
}

void background_effect_set_blur_region(struct wl_client*, struct wl_resource* resource,
                                       struct wl_resource* region)
{
    auto* effect = static_cast<BackgroundEffect*>(wl_resource_get_user_data(resource));
    if (!effect || !effect->surface)
        return;
    effect->surface->pending_background_rectangles.clear();
    if (region) {
        auto *data = static_cast<RegionData *>(wl_resource_get_user_data(region));
        if (data)
            effect->surface->pending_background_rectangles = data->rectangles;
    }
    emit(std::string("TOKYO_BACKGROUND_EFFECT event=set-region surface=") +
         std::to_string(wl_resource_get_id(effect->surface->resource)) +
         " region=" + (region ? "copied" : "none") +
         " rects=" + std::to_string(effect->surface->pending_background_rectangles.size()));
}

const struct ext_background_effect_surface_v1_interface background_effect_impl = {
    background_effect_destroy,
    background_effect_set_blur_region,
};

void background_effect_manager_destroy(struct wl_client*, struct wl_resource* resource)
{
    wl_resource_destroy(resource);
}

void background_effect_manager_get(struct wl_client* client, struct wl_resource* resource,
                                   uint32_t id, struct wl_resource* surface_resource)
{
    auto* surface = get_surface(surface_resource);
    if (!surface || surface->background_effect) {
        wl_resource_post_error(resource, EXT_BACKGROUND_EFFECT_MANAGER_V1_ERROR_BACKGROUND_EFFECT_EXISTS,
                               "surface already has a background effect");
        return;
    }
    auto* effect = new BackgroundEffect;
    effect->surface = surface;
    effect->resource = create_resource(client, &ext_background_effect_surface_v1_interface,
                                       &background_effect_impl, 1, id, effect,
                                       background_effect_destroyed);
    if (!effect->resource) {
        delete effect;
        return;
    }
    surface->background_effect = effect;
    emit(std::string("TOKYO_BACKGROUND_EFFECT event=created surface=") +
         std::to_string(wl_resource_get_id(surface_resource)));
}

const struct ext_background_effect_manager_v1_interface background_effect_manager_impl = {
    background_effect_manager_destroy,
    background_effect_manager_get,
};

void surface_set_input_region(struct wl_client*, struct wl_resource*, struct wl_resource*)
{
}

void surface_commit(struct wl_client*, struct wl_resource* resource)
{
    Surface* surface = get_surface(resource);
    if (!surface) {
        return;
    }

    // Release the previous committed buffer: its content was consumed by the
    // last synchronous composite.
    if (surface->has_current_buffer && surface->current_buffer) {
        wl_buffer_send_release(surface->current_buffer);
        emit(std::string("TOKYO_STATE event=release surface=") +
             std::to_string(wl_resource_get_id(resource)) +
             " buffer=" + std::to_string(wl_resource_get_id(surface->current_buffer)));
    }

    // Apply the pending buffer.
    if (surface->has_pending_buffer) {
        wl_resource* new_buffer = surface->pending_buffer;
        if (!wl_list_empty(&surface->pending_buffer_listener.link)) {
            wl_list_remove(&surface->pending_buffer_listener.link);
            wl_list_init(&surface->pending_buffer_listener.link);
        }
        surface->pending_buffer = nullptr;
        surface->has_pending_buffer = false;
        surface_set_current_buffer(surface, new_buffer);
        surface->has_current_buffer = (new_buffer != nullptr);
    }

    if (surface->background_effect) {
        surface->current_background_rectangles = surface->pending_background_rectangles;
        emit(std::string("TOKYO_BACKGROUND_EFFECT event=commit surface=") +
             std::to_string(wl_resource_get_id(resource)) +
             " region=" + (surface->current_background_rectangles.empty() ? "none" : "copied") +
             " rects=" + std::to_string(surface->current_background_rectangles.size()));
    }

    // Move frame callbacks into the committed set.
    surface->committed_frames = std::move(surface->pending_frames);
    surface->pending_frames.clear();

    // A toplevel's first commit (before any buffer) triggers the configure
    // sequence expected by xdg-shell clients.
    if (surface->role == Surface::Role::Toplevel && surface->xdg && surface->xdg->toplevel &&
        !surface->xdg->configured) {
        send_toplevel_configure(surface->xdg);
    }

    std::string buffer_desc = "none";
    if (surface->has_current_buffer && surface->current_buffer) {
        wl_shm_buffer* shm = wl_shm_buffer_get(surface->current_buffer);
        if (shm) {
            buffer_desc = std::to_string(wl_shm_buffer_get_width(shm)) + "x" +
                          std::to_string(wl_shm_buffer_get_height(shm));
        }
    }
    emit(std::string("TOKYO_STATE event=commit surface=") +
         std::to_string(wl_resource_get_id(resource)) + " role=" + role_name(surface->role) +
         " buffer=" + buffer_desc);

    // Composite the toplevel scene this surface belongs to (software evidence).
    Surface* root = toplevel_root(surface);
    if (root->role == Surface::Role::Toplevel) {
        composite_toplevel(root);
    }

    // Fire frame callbacks after the synchronous presentation.
    const uint32_t now = monotonic_ms();
    for (wl_resource* callback : surface->committed_frames) {
        wl_callback_send_done(callback, now);
        wl_resource_destroy(callback);
    }
    surface->committed_frames.clear();
}

void surface_set_buffer_transform(struct wl_client*, struct wl_resource*, int32_t)
{
}

void surface_set_buffer_scale(struct wl_client*, struct wl_resource*, int32_t)
{
}

void surface_damage_buffer(struct wl_client*,
                           struct wl_resource*,
                           int32_t,
                           int32_t,
                           int32_t,
                           int32_t)
{
}

void surface_offset(struct wl_client*, struct wl_resource*, int32_t, int32_t)
{
}

void surface_get_release(struct wl_client*, struct wl_resource*, uint32_t)
{
}

const struct wl_surface_interface surface_impl = {
    surface_destroy,           surface_attach,          surface_damage,
    surface_frame,             surface_set_opaque_region, surface_set_input_region,
    surface_commit,            surface_set_buffer_transform, surface_set_buffer_scale,
    surface_damage_buffer,     surface_offset,          surface_get_release,
};

// ---- wl_region ------------------------------------------------------------

void region_resource_destroyed(struct wl_resource* resource)
{
    delete static_cast<RegionData *>(wl_resource_get_user_data(resource));
}

void region_destroy(struct wl_client*, struct wl_resource* resource)
{
    wl_resource_destroy(resource);
}

void region_add(struct wl_client*, struct wl_resource* resource,
                int32_t x, int32_t y, int32_t width, int32_t height)
{
    auto *data = static_cast<RegionData *>(wl_resource_get_user_data(resource));
    if (data)
        data->rectangles.push_back({x, y, width, height});
}

void region_subtract(struct wl_client*, struct wl_resource* resource,
                     int32_t x, int32_t y, int32_t width, int32_t height)
{
    auto *data = static_cast<RegionData *>(wl_resource_get_user_data(resource));
    if (!data)
        return;
    data->rectangles.erase(std::remove_if(data->rectangles.begin(), data->rectangles.end(),
        [=](const auto &rect) {
            return rect[0] == x && rect[1] == y && rect[2] == width && rect[3] == height;
        }), data->rectangles.end());
}

const struct wl_region_interface region_impl = {
    region_destroy,
    region_add,
    region_subtract,
};

// ---- wl_compositor --------------------------------------------------------

void compositor_create_surface(struct wl_client* client, struct wl_resource* resource, uint32_t id)
{
    Surface* surface = new Surface;
    surface->resource = create_resource(client, &wl_surface_interface, &surface_impl,
                                        wl_resource_get_version(resource), id, surface,
                                        surface_resource_destroyed);
    if (!surface->resource) {
        delete surface;
    }
}

void compositor_create_region(struct wl_client* client, struct wl_resource* resource, uint32_t id)
{
    auto *data = new RegionData;
    if (!create_resource(client, &wl_region_interface, &region_impl, wl_resource_get_version(resource),
                         id, data, region_resource_destroyed))
        delete data;
}

void compositor_release(struct wl_client*, struct wl_resource*)
{
}

const struct wl_compositor_interface compositor_impl = {
    compositor_create_surface,
    compositor_create_region,
    compositor_release,
};

// ---- wl_subsurface --------------------------------------------------------

void subsurface_destroy(struct wl_client*, struct wl_resource* resource)
{
    wl_resource_destroy(resource);
}

void subsurface_set_position(struct wl_client*, struct wl_resource* resource, int32_t x, int32_t y)
{
    Subsurface* sub = get_sub(resource);
    if (!sub) {
        return;
    }
    sub->x = x;
    sub->y = y;
    emit(std::string("TOKYO_STATE event=subsurface-position surface=") +
         std::to_string(wl_resource_get_id(resource)) + " x=" + std::to_string(x) +
         " y=" + std::to_string(y));
}

void subsurface_place_above(struct wl_client*,
                            struct wl_resource* resource,
                            struct wl_resource* sibling)
{
    place_sub(resource, sibling, true);
}

void subsurface_place_below(struct wl_client*,
                            struct wl_resource* resource,
                            struct wl_resource* sibling)
{
    place_sub(resource, sibling, false);
}

void subsurface_set_sync(struct wl_client*, struct wl_resource* resource)
{
    Subsurface* sub = get_sub(resource);
    if (sub) {
        sub->sync = true;
    }
}

void subsurface_set_desync(struct wl_client*, struct wl_resource* resource)
{
    Subsurface* sub = get_sub(resource);
    if (sub) {
        sub->sync = false;
    }
}

const struct wl_subsurface_interface subsurface_impl = {
    subsurface_destroy,      subsurface_set_position, subsurface_place_above,
    subsurface_place_below,  subsurface_set_sync,     subsurface_set_desync,
};

// ---- wl_subcompositor -----------------------------------------------------

void subcompositor_destroy(struct wl_client*, struct wl_resource* resource)
{
    wl_resource_destroy(resource);
}

void subcompositor_get_subsurface(struct wl_client* client,
                                  struct wl_resource* resource,
                                  uint32_t id,
                                  struct wl_resource* surface_resource,
                                  struct wl_resource* parent_resource)
{
    Surface* surface = get_surface(surface_resource);
    Surface* parent = get_surface(parent_resource);
    if (!surface || !parent) {
        return;
    }
    if (surface->role != Surface::Role::None) {
        g_compositor->protocol_error = true;
        wl_resource_post_error(resource, WL_SUBCOMPOSITOR_ERROR_BAD_SURFACE,
                               "surface already has a role");
        return;
    }
    if (creates_subsurface_cycle(surface, parent)) {
        g_compositor->protocol_error = true;
        wl_resource_post_error(resource, WL_SUBCOMPOSITOR_ERROR_BAD_SURFACE,
                               "subsurface parent would create a cycle");
        return;
    }

    if (g_compositor->next_subsurface_creation_index > kMaxSubsurfaceCreationIndex) {
        wl_client_post_no_memory(client);
        return;
    }

    Subsurface* sub = new Subsurface;
    sub->creation_index = g_compositor->next_subsurface_creation_index++;
    sub->resource = create_resource(client, &wl_subsurface_interface, &subsurface_impl,
                                    wl_resource_get_version(resource), id, sub,
                                    subsurface_resource_destroyed);
    if (!sub->resource) {
        delete sub;
        return;
    }
    sub->surface = surface;
    sub->parent = parent;

    surface->role = Surface::Role::Subsurface;
    surface->subsurface = sub;
    parent->above.push_back(sub); // new subsurface starts topmost (above parent)
    sub->above_parent = true;

    emit_role(surface);
    emit(std::string("TOKYO_STATE event=subsurface surface=") +
         std::to_string(wl_resource_get_id(surface_resource)) +
         " parent=" + std::to_string(wl_resource_get_id(parent_resource)) +
         " x=" + std::to_string(sub->x) + " y=" + std::to_string(sub->y) + " mode=above");
}

const struct wl_subcompositor_interface subcompositor_impl = {
    subcompositor_destroy,
    subcompositor_get_subsurface,
};

// ---- wl_output ------------------------------------------------------------

void output_release(struct wl_client*, struct wl_resource* resource)
{
    wl_resource_destroy(resource);
}

const struct wl_output_interface output_impl = {
    output_release,
};

// ---- xdg_positioner -------------------------------------------------------

void positioner_destroy(struct wl_client*, struct wl_resource* resource)
{
    wl_resource_destroy(resource);
}

void positioner_set_size(struct wl_client*, struct wl_resource*, int32_t, int32_t)
{
}
void positioner_set_anchor_rect(struct wl_client*,
                                struct wl_resource*,
                                int32_t,
                                int32_t,
                                int32_t,
                                int32_t)
{
}
void positioner_set_anchor(struct wl_client*, struct wl_resource*, uint32_t)
{
}
void positioner_set_gravity(struct wl_client*, struct wl_resource*, uint32_t)
{
}
void positioner_set_constraint_adjustment(struct wl_client*, struct wl_resource*, uint32_t)
{
}
void positioner_set_offset(struct wl_client*, struct wl_resource*, int32_t, int32_t)
{
}
void positioner_set_reactive(struct wl_client*, struct wl_resource*)
{
}
void positioner_set_parent_size(struct wl_client*, struct wl_resource*, int32_t, int32_t)
{
}
void positioner_set_parent_configure(struct wl_client*, struct wl_resource*, uint32_t)
{
}

const struct xdg_positioner_interface positioner_impl = {
    positioner_destroy,
    positioner_set_size,
    positioner_set_anchor_rect,
    positioner_set_anchor,
    positioner_set_gravity,
    positioner_set_constraint_adjustment,
    positioner_set_offset,
    positioner_set_reactive,
    positioner_set_parent_size,
    positioner_set_parent_configure,
};

// ---- xdg_toplevel ---------------------------------------------------------

void xdg_toplevel_destroy(struct wl_client*, struct wl_resource* resource)
{
    wl_resource_destroy(resource);
}

void xdg_toplevel_set_parent(struct wl_client*, struct wl_resource*, struct wl_resource*)
{
}
void xdg_toplevel_set_title(struct wl_client*, struct wl_resource*, const char*)
{
}
void xdg_toplevel_set_app_id(struct wl_client*, struct wl_resource*, const char*)
{
}
void xdg_toplevel_show_window_menu(struct wl_client*,
                                   struct wl_resource*,
                                   struct wl_resource*,
                                   uint32_t,
                                   int32_t,
                                   int32_t)
{
}
void xdg_toplevel_move(struct wl_client*, struct wl_resource*, struct wl_resource*, uint32_t)
{
}
void xdg_toplevel_resize(struct wl_client*,
                         struct wl_resource*,
                         struct wl_resource*,
                         uint32_t,
                         uint32_t)
{
}
void xdg_toplevel_set_max_size(struct wl_client*, struct wl_resource*, int32_t, int32_t)
{
}
void xdg_toplevel_set_min_size(struct wl_client*, struct wl_resource*, int32_t, int32_t)
{
}
void xdg_toplevel_set_maximized(struct wl_client*, struct wl_resource*)
{
}
void xdg_toplevel_unset_maximized(struct wl_client*, struct wl_resource*)
{
}
void xdg_toplevel_set_fullscreen(struct wl_client*, struct wl_resource*, struct wl_resource*)
{
}
void xdg_toplevel_unset_fullscreen(struct wl_client*, struct wl_resource*)
{
}
void xdg_toplevel_set_minimized(struct wl_client*, struct wl_resource*)
{
}

const struct xdg_toplevel_interface xdg_toplevel_impl = {
    xdg_toplevel_destroy,
    xdg_toplevel_set_parent,
    xdg_toplevel_set_title,
    xdg_toplevel_set_app_id,
    xdg_toplevel_show_window_menu,
    xdg_toplevel_move,
    xdg_toplevel_resize,
    xdg_toplevel_set_max_size,
    xdg_toplevel_set_min_size,
    xdg_toplevel_set_maximized,
    xdg_toplevel_unset_maximized,
    xdg_toplevel_set_fullscreen,
    xdg_toplevel_unset_fullscreen,
    xdg_toplevel_set_minimized,
};

// ---- xdg_popup ------------------------------------------------------------

void popup_destroy(struct wl_client*, struct wl_resource* resource)
{
    wl_resource_destroy(resource);
}
void popup_grab(struct wl_client*, struct wl_resource*, struct wl_resource*, uint32_t)
{
}
void popup_reposition(struct wl_client*, struct wl_resource*, struct wl_resource*, uint32_t)
{
}

const struct xdg_popup_interface popup_impl = {
    popup_destroy,
    popup_grab,
    popup_reposition,
};

// ---- xdg_surface ----------------------------------------------------------

void xdg_surface_destroy(struct wl_client*, struct wl_resource* resource)
{
    XdgSurface* xdg = get_xdg(resource);
    if (xdg && xdg->toplevel) {
        wl_resource_post_error(resource, XDG_SURFACE_ERROR_DEFUNCT_ROLE_OBJECT,
                               "destroy the toplevel role first");
        return;
    }
    wl_resource_destroy(resource);
}

void xdg_surface_get_toplevel(struct wl_client* client, struct wl_resource* resource, uint32_t id)
{
    XdgSurface* xdg = get_xdg(resource);
    if (!xdg || !xdg->surface) {
        return;
    }
    if (xdg->toplevel) {
        wl_resource_post_error(resource, XDG_SURFACE_ERROR_ALREADY_CONSTRUCTED,
                               "toplevel already constructed");
        return;
    }

    XdgToplevel* toplevel = new XdgToplevel;
    toplevel->resource = create_resource(client, &xdg_toplevel_interface, &xdg_toplevel_impl,
                                         wl_resource_get_version(resource), id, toplevel,
                                         xdg_toplevel_resource_destroyed);
    if (!toplevel->resource) {
        delete toplevel;
        return;
    }
    toplevel->xdg = xdg;
    xdg->toplevel = toplevel;
    xdg->surface->role = Surface::Role::Toplevel;
    emit_role(xdg->surface);
}

void xdg_surface_get_popup(struct wl_client* client,
                           struct wl_resource* resource,
                           uint32_t id,
                           struct wl_resource*,
                           struct wl_resource*)
{
    XdgSurface* xdg = get_xdg(resource);
    if (!xdg || !xdg->surface) {
        return;
    }
    if (xdg->toplevel || xdg->surface->role != Surface::Role::None) {
        wl_resource_post_error(resource, XDG_SURFACE_ERROR_ALREADY_CONSTRUCTED,
                               "surface already has a role");
        return;
    }
    create_resource(client, &xdg_popup_interface, &popup_impl, wl_resource_get_version(resource),
                    id, nullptr, nullptr);
    xdg->surface->role = Surface::Role::Popup;
}

void xdg_surface_set_window_geometry(struct wl_client*,
                                     struct wl_resource*,
                                     int32_t,
                                     int32_t,
                                     int32_t,
                                     int32_t)
{
}

void xdg_surface_ack_configure(struct wl_client*, struct wl_resource* resource, uint32_t serial)
{
    XdgSurface* xdg = get_xdg(resource);
    if (!xdg || !xdg->surface) {
        return;
    }
    emit(std::string("TOKYO_STATE event=ack-configure surface=") +
         std::to_string(wl_resource_get_id(xdg->surface->resource)) +
         " serial=" + std::to_string(serial));
}

const struct xdg_surface_interface xdg_surface_impl = {
    xdg_surface_destroy,
    xdg_surface_get_toplevel,
    xdg_surface_get_popup,
    xdg_surface_set_window_geometry,
    xdg_surface_ack_configure,
};

// ---- xdg_wm_base ----------------------------------------------------------

void xdg_wm_base_destroy(struct wl_client*, struct wl_resource* resource)
{
    wl_resource_destroy(resource);
}

void xdg_wm_base_create_positioner(struct wl_client* client,
                                   struct wl_resource* resource,
                                   uint32_t id)
{
    create_resource(client, &xdg_positioner_interface, &positioner_impl,
                    wl_resource_get_version(resource), id, nullptr, nullptr);
}

void xdg_wm_base_get_xdg_surface(struct wl_client* client,
                                 struct wl_resource* resource,
                                 uint32_t id,
                                 struct wl_resource* surface_resource)
{
    Surface* surface = get_surface(surface_resource);
    if (!surface) {
        wl_resource_post_error(resource, XDG_WM_BASE_ERROR_ROLE, "invalid surface");
        return;
    }
    if (surface->role != Surface::Role::None) {
        wl_resource_post_error(resource, XDG_WM_BASE_ERROR_ROLE, "surface already has a role");
        return;
    }

    XdgSurface* xdg = new XdgSurface;
    xdg->resource = create_resource(client, &xdg_surface_interface, &xdg_surface_impl,
                                    wl_resource_get_version(resource), id, xdg,
                                    xdg_surface_resource_destroyed);
    if (!xdg->resource) {
        delete xdg;
        return;
    }
    xdg->surface = surface;
    surface->xdg = xdg;
}

void xdg_wm_base_pong(struct wl_client*, struct wl_resource*, uint32_t)
{
}

const struct xdg_wm_base_interface xdg_wm_base_impl = {
    xdg_wm_base_destroy,
    xdg_wm_base_create_positioner,
    xdg_wm_base_get_xdg_surface,
    xdg_wm_base_pong,
};

// ---- Global bind entry points ---------------------------------------------

void bind_compositor(struct wl_client* client, void*, uint32_t version, uint32_t id)
{
    create_resource(client, &wl_compositor_interface, &compositor_impl,
                    static_cast<int>(version), id, nullptr, nullptr);
}

void bind_subcompositor(struct wl_client* client, void*, uint32_t version, uint32_t id)
{
    create_resource(client, &wl_subcompositor_interface, &subcompositor_impl,
                    static_cast<int>(version), id, nullptr, nullptr);
}

void bind_output(struct wl_client* client, void*, uint32_t version, uint32_t id)
{
    struct wl_resource* resource = create_resource(client, &wl_output_interface, &output_impl,
                                                   static_cast<int>(version), id, nullptr, nullptr);
    if (!resource) {
        return;
    }
    wl_output_send_geometry(resource, 0, 0, 0, 0, WL_OUTPUT_SUBPIXEL_UNKNOWN, "tokyo",
                            "cpu-output", WL_OUTPUT_TRANSFORM_NORMAL);
    wl_output_send_mode(resource, WL_OUTPUT_MODE_CURRENT | WL_OUTPUT_MODE_PREFERRED, kOutputWidth,
                        kOutputHeight, 60000);
    if (version >= WL_OUTPUT_SCALE_SINCE_VERSION) {
        wl_output_send_scale(resource, 1);
    }
    if (version >= WL_OUTPUT_DONE_SINCE_VERSION) {
        wl_output_send_done(resource);
    }
}

void bind_xdg_wm_base(struct wl_client* client, void*, uint32_t version, uint32_t id)
{
    create_resource(client, &xdg_wm_base_interface, &xdg_wm_base_impl,
                    static_cast<int>(version), id, nullptr, nullptr);
}

void bind_background_effect_manager(struct wl_client* client, void*, uint32_t version, uint32_t id)
{
    auto* resource = create_resource(client, &ext_background_effect_manager_v1_interface,
                                     &background_effect_manager_impl,
                                     static_cast<int>(version), id, nullptr, nullptr);
    if (resource)
        // Advertise protocol capability for request sequencing only. This fixture
        // performs no blur or GPU work; the bit is not visual evidence.
        ext_background_effect_manager_v1_send_capabilities(
            resource, EXT_BACKGROUND_EFFECT_MANAGER_V1_CAPABILITY_BLUR);
}

// ---- Bounded event loop ---------------------------------------------------

int timer_callback(void* data)
{
    Compositor* compositor = static_cast<Compositor*>(data);
    compositor->terminated = true;
    compositor->exit_reason = "deadline";
    wl_display_terminate(compositor->display);
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

    // Register wl_shm through libwayland's built-in implementation and publish
    // the formats a Qt SHM client uses. This keeps pool/buffer mmap and resize
    // semantics out of this file.
    if (wl_display_init_shm(display) != 0) {
        std::cerr << "wl_display_init_shm failed\n";
        wl_display_destroy(display);
        return 1;
    }
    wl_display_add_shm_format(display, WL_SHM_FORMAT_ARGB8888);
    wl_display_add_shm_format(display, WL_SHM_FORMAT_XRGB8888);

    Compositor compositor;
    compositor.display = display;
    g_compositor = &compositor;

    struct wl_global* globals[5] = {};
    std::size_t global_count = 0;
    auto register_global = [&](const struct wl_interface* interface,
                               int version,
                               wl_global_bind_func_t bind) -> bool {
        struct wl_global* global = wl_global_create(display, interface, version, nullptr, bind);
        if (!global) {
            return false;
        }
        globals[global_count++] = global;
        return true;
    };

    const bool registered =
        register_global(&wl_compositor_interface, kCompositorVersion, bind_compositor) &&
        register_global(&wl_subcompositor_interface, kSubcompositorVersion, bind_subcompositor) &&
        register_global(&wl_output_interface, kOutputVersion, bind_output) &&
        register_global(&xdg_wm_base_interface, kXdgWmBaseVersion, bind_xdg_wm_base) &&
        register_global(&ext_background_effect_manager_v1_interface, 1, bind_background_effect_manager);

    if (!registered) {
        std::cerr << "wl_global_create failed\n";
        for (std::size_t index = global_count; index > 0; --index) {
            wl_global_destroy(globals[index - 1]);
        }
        g_compositor = nullptr;
        wl_display_destroy(display);
        return 1;
    }

    wl_list_init(&compositor.client_created_listener.link);
    compositor.client_created_listener.notify = client_created;
    wl_display_add_client_created_listener(display, &compositor.client_created_listener);

    struct wl_event_source* timer = wl_event_loop_add_timer(
        wl_display_get_event_loop(display), timer_callback, &compositor);
    if (!timer || wl_event_source_timer_update(timer, deadline_ms) != 0) {
        std::cerr << "timer setup failed\n";
        if (timer) {
            wl_event_source_remove(timer);
        }
        wl_list_remove(&compositor.client_created_listener.link);
        wl_list_init(&compositor.client_created_listener.link);
        for (std::size_t index = global_count; index > 0; --index) {
            wl_global_destroy(globals[index - 1]);
        }
        g_compositor = nullptr;
        wl_display_destroy(display);
        return 1;
    }

    {
        std::ostringstream ready;
        ready << "TOKYO_WAYLAND_COMPOSITOR_READY"
              << " pid=" << static_cast<long long>(getpid()) << " socket=" << socket_name
              << " deadline_ms=" << deadline_ms
              << " globals=wl_compositor,wl_shm,wl_subcompositor,wl_output,xdg_wm_base"
              << " output=" << kOutputWidth << "x" << kOutputHeight
              << " formats=ARGB8888,XRGB8888";
        emit(ready.str());
    }

    int result = 0;
    while (!compositor.terminated) {
        if (wl_event_loop_dispatch(wl_display_get_event_loop(display), -1) < 0) {
            result = 1;
            compositor.exit_reason = "error";
            break;
        }
        if (!compositor.terminated) {
            wl_display_flush_clients(display);
        }
    }

    emit(std::string("TOKYO_WAYLAND_COMPOSITOR_EXIT reason=") + compositor.exit_reason +
         " frames=" + std::to_string(compositor.frame_counter) +
         " clients=" + std::to_string(compositor.client_count));

    // Deterministic teardown: stop the timer, detach the display listener,
    // destroy clients (freeing every resource struct), then globals in reverse
    // registration order, then the display (which also frees the shm global).
    if (timer) {
        wl_event_source_remove(timer);
    }
    wl_list_remove(&compositor.client_created_listener.link);
    wl_list_init(&compositor.client_created_listener.link);
    wl_display_destroy_clients(display);
    for (std::size_t index = global_count; index > 0; --index) {
        wl_global_destroy(globals[index - 1]);
    }
    g_compositor = nullptr;
    wl_display_destroy(display);
    if (compositor.protocol_error) {
        result = 1;
    }
    return result;
}
