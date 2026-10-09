#include "waylandsubsurfaceadapter.h"

#include <QGuiApplication>
#include <QDebug>
#include <QWindow>
#include <QtCore/qnativeinterface.h>
#include <QtGui/qguiapplication_platform.h>
#include <QtWaylandClient/private/qwaylanddisplay_p.h>
#include <QtWaylandClient/private/qwaylandintegration_p.h>
#include <QtWaylandClient/private/qwaylandshmbackingstore_p.h>
#include <QtWaylandClient/private/qwaylandwindow_p.h>
#include <QtWaylandClient/private/wayland-wayland-client-protocol.h>

namespace {
using QtWaylandClient::QWaylandDisplay;
using QtWaylandClient::QWaylandIntegration;
using QtWaylandClient::QWaylandShmBuffer;

struct RegistryState {
    wl_subcompositor *subcompositor = nullptr;
};

void registryGlobal(void *data, wl_registry *registry, uint32_t id, const QString &interfaceName, uint32_t)
{
    auto *state = static_cast<RegistryState *>(data);
    if (interfaceName == QStringLiteral("wl_subcompositor") && !state->subcompositor)
        state->subcompositor = static_cast<wl_subcompositor *>(wl_registry_bind(
            registry, id, &wl_subcompositor_interface, 1));
}
}

WaylandSubsurfaceAdapter::~WaylandSubsurfaceAdapter()
{
    destroy();
}

bool WaylandSubsurfaceAdapter::create(QWindow *target, const QRect &geometry, bool placeBelow, QString *error)
{
    destroy();
    m_backend = QStringLiteral("none");
    m_ordering = QStringLiteral("not-requested");

    if (!target) {
        if (error) *error = QStringLiteral("target window is null");
        return false;
    }

    auto *application = qobject_cast<QGuiApplication *>(QGuiApplication::instance())
        ? qobject_cast<QGuiApplication *>(QGuiApplication::instance())->nativeInterface<QNativeInterface::QWaylandApplication>()
        : nullptr;
    auto *targetInterface = target->nativeInterface<QNativeInterface::Private::QWaylandWindow>();
    if (!application || !targetInterface || !targetInterface->surface()) {
        if (error) *error = QStringLiteral("target is not a realized Wayland QWindow");
        return false;
    }

    auto *integration = QWaylandIntegration::instance();
    auto *display = integration ? integration->display() : nullptr;
    if (!display || !display->shm() || !display->hasRegistryGlobal(QStringLiteral("wl_subcompositor"))) {
        if (error) *error = QStringLiteral("Wayland wl_subcompositor/wl_shm capability unavailable");
        return false;
    }

    RegistryState registryState;
    display->addRegistryListener(registryGlobal, &registryState);
    display->forceRoundTrip();
    display->removeListener(registryGlobal, &registryState);
    if (!registryState.subcompositor) {
        if (error) *error = QStringLiteral("failed to bind wl_subcompositor");
        return false;
    }

    const QRect bounded = geometry.intersected(QRect(QPoint(0, 0), target->size()));
    if (bounded.isEmpty()) {
        wl_subcompositor_destroy(registryState.subcompositor);
        if (error) *error = QStringLiteral("probe geometry is empty or outside target window");
        return false;
    }

    m_display = application->display();
    m_surface = display->createSurface(nullptr);
    if (!m_surface) {
        wl_subcompositor_destroy(registryState.subcompositor);
        if (error) *error = QStringLiteral("failed to create child wl_surface");
        return false;
    }

    m_subsurface = wl_subcompositor_get_subsurface(registryState.subcompositor, m_surface,
                                                    targetInterface->surface());
    wl_subcompositor_destroy(registryState.subcompositor);
    if (!m_subsurface) {
        destroy();
        if (error) *error = QStringLiteral("failed to create wl_subsurface");
        return false;
    }

    auto *shm = new QWaylandShmBuffer(display, bounded.size(), QImage::Format_ARGB32_Premultiplied);
    shm->image()->fill(qRgba(220, 30, 180, 255));
    m_shmBuffer = shm;
    m_buffer = shm->buffer();

    wl_subsurface_set_position(m_subsurface, bounded.x(), bounded.y());
    if (placeBelow) {
        wl_subsurface_place_below(m_subsurface, targetInterface->surface());
        m_ordering = QStringLiteral("place-below-parent-requested");
    } else {
        wl_subsurface_place_above(m_subsurface, targetInterface->surface());
        m_ordering = QStringLiteral("place-above-parent-requested");
    }
    wl_subsurface_set_desync(m_subsurface);

    wl_surface_attach(m_surface, m_buffer, 0, 0);
    wl_surface_damage_buffer(m_surface, 0, 0, bounded.width(), bounded.height());
    wl_region *emptyRegion = wl_compositor_create_region(application->compositor());
    if (emptyRegion) {
        wl_surface_set_input_region(m_surface, emptyRegion);
        wl_region_destroy(emptyRegion);
    }
    wl_surface_commit(m_surface);
    wl_display_flush(m_display);
    m_surfaceId = wl_proxy_get_id(reinterpret_cast<wl_proxy *>(m_surface));
    m_subsurfaceId = wl_proxy_get_id(reinterpret_cast<wl_proxy *>(m_subsurface));
    m_backend = QStringLiteral("wayland-private-qt-adapter");
    qInfo().noquote() << QStringLiteral("[subsurface-native] active child surface id=%1 subsurface role id=%2")
                             .arg(m_surfaceId).arg(m_subsurfaceId);
    return true;
}

void WaylandSubsurfaceAdapter::destroy()
{
    // A child surface must not outlive its role as a subsurface.  Destroy the
    // role object first so the compositor cannot process the surface as a
    // still-attached subsurface while a replacement parent commit is queued.
    if (m_subsurface) {
        m_lastDestroyedSubsurfaceId = m_subsurfaceId;
        qInfo().noquote() << QStringLiteral("[subsurface-native] destroy role first: wl_subsurface id=%1")
                                 .arg(m_lastDestroyedSubsurfaceId);
        wl_subsurface_destroy(m_subsurface);
        m_subsurface = nullptr;
        m_subsurfaceId = 0;
    }

    if (m_surface) {
        m_lastDestroyedSurfaceId = m_surfaceId;
        qInfo().noquote() << QStringLiteral("[subsurface-native] destroy child surface second: wl_surface id=%1")
                                 .arg(m_lastDestroyedSurfaceId);
        wl_surface_destroy(m_surface);
        m_surface = nullptr;
        m_surfaceId = 0;
    }

    m_buffer = nullptr;
    delete static_cast<QtWaylandClient::QWaylandShmBuffer *>(m_shmBuffer);
    m_shmBuffer = nullptr;
    m_display = nullptr;
    m_backend = QStringLiteral("none");
    m_ordering = QStringLiteral("not-requested");
}
