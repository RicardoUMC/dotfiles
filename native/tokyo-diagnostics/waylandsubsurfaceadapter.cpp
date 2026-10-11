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

    const QSize childSize = bounded.size();
    const QPoint primaryPos = bounded.topLeft();
    QPoint secondaryPos = primaryPos + QPoint(childSize.width() / 2, childSize.height() / 2);
    secondaryPos.setX(qBound(0, secondaryPos.x(), qMax(0, target->size().width() - childSize.width())));
    secondaryPos.setY(qBound(0, secondaryPos.y(), qMax(0, target->size().height() - childSize.height())));

    m_display = application->display();

    // Create the secondary first so it starts topmost in the subcompositor's
    // creation order, then place the primary explicitly relative to the
    // secondary. That place request is the single source of truth for the
    // pair's stacking, so the compositor evidence reflects the selector.
    if (!createChild(display, registryState.subcompositor, targetInterface->surface(),
                     application->compositor(), childSize, secondaryPos,
                     qRgba(112, 225, 232, 255), // cyan, contrasting pair color
                     &m_children[1], error)
        || !createChild(display, registryState.subcompositor, targetInterface->surface(),
                        application->compositor(), childSize, primaryPos,
                        qRgba(220, 30, 180, 255), // magenta, existing probe color
                        &m_children[0], error)) {
        wl_subcompositor_destroy(registryState.subcompositor);
        destroy();
        return false;
    }
    wl_subcompositor_destroy(registryState.subcompositor);

    if (placeBelow) {
        wl_subsurface_place_below(m_children[0].subsurface, m_children[1].surface);
        m_ordering = QStringLiteral("primary-below-secondary");
    } else {
        wl_subsurface_place_above(m_children[0].subsurface, m_children[1].surface);
        m_ordering = QStringLiteral("primary-above-secondary");
    }

    wl_surface_commit(m_children[0].surface);
    wl_surface_commit(m_children[1].surface);
    wl_display_flush(m_display);

    m_backend = QStringLiteral("wayland-private-qt-adapter");
    qInfo().noquote() << QStringLiteral("[subsurface-native] active child pair primary wl_surface=%1 wl_subsurface=%2 secondary wl_surface=%3 wl_subsurface=%4 ordering=%5")
                             .arg(m_children[0].surfaceId).arg(m_children[0].subsurfaceId)
                             .arg(m_children[1].surfaceId).arg(m_children[1].subsurfaceId)
                             .arg(m_ordering);
    return true;
}

bool WaylandSubsurfaceAdapter::createChild(QtWaylandClient::QWaylandDisplay *display,
                                           struct wl_subcompositor *subcompositor,
                                           struct wl_surface *targetSurface,
                                           struct wl_compositor *compositor,
                                           const QSize &size,
                                           const QPoint &position,
                                           uint32_t color,
                                           Child *child,
                                           QString *error)
{
    child->surface = display->createSurface(nullptr);
    if (!child->surface) {
        if (error) *error = QStringLiteral("failed to create child wl_surface");
        return false;
    }

    child->subsurface = wl_subcompositor_get_subsurface(subcompositor, child->surface, targetSurface);
    if (!child->subsurface) {
        destroyChild(child);
        if (error) *error = QStringLiteral("failed to create wl_subsurface");
        return false;
    }

    auto *shm = new QWaylandShmBuffer(display, size, QImage::Format_ARGB32_Premultiplied);
    shm->image()->fill(color);
    child->shmBuffer = shm;
    child->buffer = shm->buffer();

    wl_subsurface_set_position(child->subsurface, position.x(), position.y());
    wl_subsurface_set_desync(child->subsurface);

    wl_surface_attach(child->surface, child->buffer, 0, 0);
    wl_surface_damage_buffer(child->surface, 0, 0, size.width(), size.height());
    wl_region *emptyRegion = wl_compositor_create_region(compositor);
    if (emptyRegion) {
        wl_surface_set_input_region(child->surface, emptyRegion);
        wl_region_destroy(emptyRegion);
    }

    child->surfaceId = wl_proxy_get_id(reinterpret_cast<wl_proxy *>(child->surface));
    child->subsurfaceId = wl_proxy_get_id(reinterpret_cast<wl_proxy *>(child->subsurface));
    return true;
}

void WaylandSubsurfaceAdapter::destroyChild(Child *child)
{
    if (child->subsurface) {
        wl_subsurface_destroy(child->subsurface);
        child->subsurface = nullptr;
        child->subsurfaceId = 0;
    }
    if (child->surface) {
        wl_surface_destroy(child->surface);
        child->surface = nullptr;
        child->surfaceId = 0;
    }
    child->buffer = nullptr;
    delete static_cast<QtWaylandClient::QWaylandShmBuffer *>(child->shmBuffer);
    child->shmBuffer = nullptr;
}

void WaylandSubsurfaceAdapter::destroy()
{
    // Capture teardown evidence before mutating so a replacement run can log
    // the previous pair's identities. Only overwrite when something is being
    // destroyed, matching the single-child behavior.
    if (m_children[0].surface) m_lastDestroyedSurfaceId = m_children[0].surfaceId;
    if (m_children[0].subsurface) m_lastDestroyedSubsurfaceId = m_children[0].subsurfaceId;
    if (m_children[1].surface) m_lastDestroyedSecondarySurfaceId = m_children[1].surfaceId;
    if (m_children[1].subsurface) m_lastDestroyedSecondarySubsurfaceId = m_children[1].subsurfaceId;

    // A child surface must not outlive its role as a subsurface. Destroy the
    // secondary role first (created first), then the primary, so neither
    // surface can be processed as a still-attached subsurface while a
    // replacement parent commit is queued.
    for (int i = 1; i >= 0; --i) {
        if (!m_children[i].subsurface)
            continue;
        qInfo().noquote() << QStringLiteral("[subsurface-native] destroy role first: wl_subsurface id=%1")
                                 .arg(m_children[i].subsurfaceId);
        wl_subsurface_destroy(m_children[i].subsurface);
        m_children[i].subsurface = nullptr;
        m_children[i].subsurfaceId = 0;
    }

    for (int i = 1; i >= 0; --i) {
        if (!m_children[i].surface)
            continue;
        qInfo().noquote() << QStringLiteral("[subsurface-native] destroy child surface second: wl_surface id=%1")
                                 .arg(m_children[i].surfaceId);
        wl_surface_destroy(m_children[i].surface);
        m_children[i].surface = nullptr;
        m_children[i].surfaceId = 0;
    }

    for (int i = 0; i < 2; ++i) {
        m_children[i].buffer = nullptr;
        delete static_cast<QtWaylandClient::QWaylandShmBuffer *>(m_children[i].shmBuffer);
        m_children[i].shmBuffer = nullptr;
    }

    m_display = nullptr;
    m_backend = QStringLiteral("none");
    m_ordering = QStringLiteral("not-requested");
}
