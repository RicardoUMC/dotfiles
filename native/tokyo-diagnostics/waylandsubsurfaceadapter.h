#pragma once

#include <QRect>
#include <QString>

class QWindow;

class WaylandSubsurfaceAdapter
{
public:
    WaylandSubsurfaceAdapter() = default;
    ~WaylandSubsurfaceAdapter();

    WaylandSubsurfaceAdapter(const WaylandSubsurfaceAdapter &) = delete;
    WaylandSubsurfaceAdapter &operator=(const WaylandSubsurfaceAdapter &) = delete;

    bool create(QWindow *target, const QRect &geometry, bool placeBelow, QString *error);
    void destroy();
    bool active() const { return m_surface != nullptr; }
    QString backend() const { return m_backend; }
    QString ordering() const { return m_ordering; }
    uint32_t surfaceId() const { return m_surfaceId; }
    uint32_t subsurfaceId() const { return m_subsurfaceId; }
    uint32_t lastDestroyedSurfaceId() const { return m_lastDestroyedSurfaceId; }
    uint32_t lastDestroyedSubsurfaceId() const { return m_lastDestroyedSubsurfaceId; }

private:
    struct wl_surface *m_surface = nullptr;
    struct wl_subsurface *m_subsurface = nullptr;
    struct wl_buffer *m_buffer = nullptr;
    struct wl_display *m_display = nullptr;
    void *m_shmBuffer = nullptr;
    QString m_backend = QStringLiteral("none");
    QString m_ordering = QStringLiteral("not-requested");
    uint32_t m_surfaceId = 0;
    uint32_t m_subsurfaceId = 0;
    uint32_t m_lastDestroyedSurfaceId = 0;
    uint32_t m_lastDestroyedSubsurfaceId = 0;
};
