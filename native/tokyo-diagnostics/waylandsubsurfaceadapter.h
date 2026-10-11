#pragma once

#include <QPoint>
#include <QRect>
#include <QSize>
#include <QString>
#include <cstdint>

class QWindow;

namespace QtWaylandClient {
class QWaylandDisplay;
}

struct wl_surface;
struct wl_subsurface;
struct wl_subcompositor;
struct wl_compositor;
struct wl_buffer;
struct wl_display;

class WaylandSubsurfaceAdapter
{
public:
    WaylandSubsurfaceAdapter() = default;
    ~WaylandSubsurfaceAdapter();

    WaylandSubsurfaceAdapter(const WaylandSubsurfaceAdapter &) = delete;
    WaylandSubsurfaceAdapter &operator=(const WaylandSubsurfaceAdapter &) = delete;

    bool create(QWindow *target, const QRect &geometry, bool placeBelow, QString *error);
    void destroy();
    bool active() const { return m_children[0].surface != nullptr; }
    QString backend() const { return m_backend; }
    QString ordering() const { return m_ordering; }
    uint32_t surfaceId() const { return m_children[0].surfaceId; }
    uint32_t subsurfaceId() const { return m_children[0].subsurfaceId; }
    uint32_t secondarySurfaceId() const { return m_children[1].surfaceId; }
    uint32_t secondarySubsurfaceId() const { return m_children[1].subsurfaceId; }
    uint32_t lastDestroyedSurfaceId() const { return m_lastDestroyedSurfaceId; }
    uint32_t lastDestroyedSubsurfaceId() const { return m_lastDestroyedSubsurfaceId; }
    uint32_t lastDestroyedSecondarySurfaceId() const { return m_lastDestroyedSecondarySurfaceId; }
    uint32_t lastDestroyedSecondarySubsurfaceId() const { return m_lastDestroyedSecondarySubsurfaceId; }

private:
    struct Child {
        struct wl_surface *surface = nullptr;
        struct wl_subsurface *subsurface = nullptr;
        struct wl_buffer *buffer = nullptr;
        void *shmBuffer = nullptr;
        uint32_t surfaceId = 0;
        uint32_t subsurfaceId = 0;
    };

    bool createChild(QtWaylandClient::QWaylandDisplay *display,
                     struct wl_subcompositor *subcompositor,
                     struct wl_surface *targetSurface,
                     struct wl_compositor *compositor,
                     const QSize &size,
                     const QPoint &position,
                     uint32_t color,
                     Child *child,
                     QString *error);
    void destroyChild(Child *child);

    Child m_children[2];
    struct wl_display *m_display = nullptr;
    QString m_backend = QStringLiteral("none");
    QString m_ordering = QStringLiteral("not-requested");
    uint32_t m_lastDestroyedSurfaceId = 0;
    uint32_t m_lastDestroyedSubsurfaceId = 0;
    uint32_t m_lastDestroyedSecondarySurfaceId = 0;
    uint32_t m_lastDestroyedSecondarySubsurfaceId = 0;
};
