#include "backgroundeffectprobe.h"

#include <QGuiApplication>
#include <cstdio>
#include <QWindow>
#include <QtCore/qnativeinterface.h>
#include <QtWaylandClient/private/qwaylanddisplay_p.h>
#include <QtWaylandClient/private/qwaylandintegration_p.h>
#include <QtWaylandClient/private/qwaylandwindow_p.h>
#include "ext-background-effect-v1-client-protocol.h"

namespace {
using QtWaylandClient::QWaylandIntegration;

struct RegistryState {
    ext_background_effect_manager_v1 *manager = nullptr;
    BackgroundEffectProbe *probe = nullptr;
};

void capabilities(void *data, ext_background_effect_manager_v1 *, uint32_t flags)
{
    auto *probe = static_cast<BackgroundEffectProbe *>(data);
    std::fprintf(stderr, "TOKYO_BACKGROUND_EFFECT_CLIENT capabilities=%u\n", flags);
    std::fflush(stderr);
    probe->onCapabilities(flags);
}

const ext_background_effect_manager_v1_listener managerListener = {capabilities};

void registryGlobal(void *data, wl_registry *registry, uint32_t id, const QString &name, uint32_t version)
{
    auto *state = static_cast<RegistryState *>(data);
    if (name == QStringLiteral("ext_background_effect_manager_v1") && !state->manager)
        state->manager = static_cast<ext_background_effect_manager_v1 *>(wl_registry_bind(
            registry, id, &ext_background_effect_manager_v1_interface, qMin(version, 1u)));
        if (state->manager && state->probe) {
            state->probe->onManagerBound(state->manager);
            ext_background_effect_manager_v1_add_listener(state->manager, &managerListener, state->probe);
        }
}

}

BackgroundEffectProbe::BackgroundEffectProbe(QObject *parent) : QObject(parent)
{
    m_retryTimer.setSingleShot(true);
    m_retryTimer.setInterval(50);
    connect(&m_retryTimer, &QTimer::timeout, this, &BackgroundEffectProbe::tryStart);
}

BackgroundEffectProbe::~BackgroundEffectProbe()
{
    stop();
}

void BackgroundEffectProbe::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    m_enabled = enabled;
    emit enabledChanged();
    if (m_enabled)
        tryStart();
    else
        stop();
}

void BackgroundEffectProbe::setTargetWindow(QWindow *window)
{
    if (m_targetWindow == window)
        return;
    if (m_targetWindow)
        disconnect(m_targetWindow, nullptr, this, nullptr);
    m_targetWindow = window;
    emit targetWindowChanged();
    if (m_targetWindow) {
        connect(m_targetWindow, &QWindow::visibilityChanged, this, &BackgroundEffectProbe::tryStart);
        connect(m_targetWindow, &QWindow::visibleChanged, this, &BackgroundEffectProbe::tryStart);
        connect(m_targetWindow, &QWindow::screenChanged, this, &BackgroundEffectProbe::tryStart);
        connect(m_targetWindow, &QObject::destroyed, this, [this] { m_targetWindow = nullptr; stop(); });
    }
    if (m_enabled)
        tryStart();
}

void BackgroundEffectProbe::setStatus(const QString &status)
{
    if (m_status == status)
        return;
    m_status = status;
    emit statusChanged();
}

void BackgroundEffectProbe::setSequencing(const QString &sequencing)
{
    if (m_sequencing == sequencing)
        return;
    m_sequencing = sequencing;
    emit sequencingChanged();
}

void BackgroundEffectProbe::onManagerBound(ext_background_effect_manager_v1 *manager)
{
    m_manager = manager;
}

void BackgroundEffectProbe::onCapabilities(uint32_t flags)
{
    std::fprintf(stderr, "TOKYO_BACKGROUND_EFFECT_CLIENT onCapabilities=%u\n", flags);
    std::fflush(stderr);
    qInfo().noquote() << QStringLiteral("[background-effect-native] capabilities flags=%1").arg(flags);
    const bool wasPresent = m_capabilityPresent;
    m_capabilityPresent = true;
    m_blurCapability = (flags & EXT_BACKGROUND_EFFECT_MANAGER_V1_CAPABILITY_BLUR) != 0;
    m_capabilityKnown = true;
    if (!wasPresent)
        emit capabilityPresentChanged();
    if (!m_blurCapability) {
        setStatus(QStringLiteral("fail-closed; compositor did not advertise blur capability"));
        return;
    }
    issueEffect();
}

void BackgroundEffectProbe::scheduleRetry()
{
    if (!m_enabled || m_effect || m_retryTimer.isActive())
        return;
    if (m_retryAttempts++ >= 40) {
        setStatus(QStringLiteral("fail-closed; Wayland surface readiness deadline expired"));
        return;
    }
    m_retryTimer.start();
}

void BackgroundEffectProbe::tryStart()
{
    if (!m_enabled || m_effect || !m_targetWindow || m_manager)
        return;

    auto *application = qobject_cast<QGuiApplication *>(QGuiApplication::instance());
    auto *waylandApplication = application ? application->nativeInterface<QNativeInterface::QWaylandApplication>() : nullptr;
    auto *window = m_targetWindow->nativeInterface<QNativeInterface::Private::QWaylandWindow>();
    auto *integration = QWaylandIntegration::instance();
    auto *display = integration ? integration->display() : nullptr;
    if (!waylandApplication || !window || !window->surface() || !display) {
        setStatus(QStringLiteral("waiting; target Wayland surface is not ready"));
        scheduleRetry();
        return;
    }

    m_display = waylandApplication->display();
    m_compositor = waylandApplication->compositor();
    m_surface = window->surface();

    RegistryState state;
    state.probe = this;
    display->addRegistryListener(registryGlobal, &state);
    m_manager = state.manager;
    display->forceRoundTrip();
    display->removeListener(registryGlobal, &state);
    if (!state.manager) {
        setStatus(QStringLiteral("fail-closed; ext-background-effect-v1 absent"));
        return;
    }

    wl_display_dispatch_pending(m_display);
    if (!m_capabilityKnown)
        setStatus(QStringLiteral("waiting; ext-background-effect-v1 capability event"));
}

void BackgroundEffectProbe::issueEffect()
{
    std::fprintf(stderr, "TOKYO_BACKGROUND_EFFECT_CLIENT issue manager=%d surface=%d known=%d blur=%d\n",
                 m_manager != nullptr, m_surface != nullptr, m_capabilityKnown, m_blurCapability);
    std::fflush(stderr);
    qInfo().noquote() << QStringLiteral("[background-effect-native] issue manager=%1 surface=%2 known=%3 blur=%4")
                             .arg(m_manager != nullptr).arg(m_surface != nullptr)
                             .arg(m_capabilityKnown).arg(m_blurCapability);
    if (!m_manager || !m_surface || !m_capabilityKnown || !m_blurCapability)
        return;
    m_effect = ext_background_effect_manager_v1_get_background_effect(m_manager, m_surface);
    if (!m_effect) {
        setStatus(QStringLiteral("fail-closed; manager rejected effect object"));
        stop();
        return;
    }

    m_region = wl_compositor_create_region(m_compositor);
    if (!m_region) {
        setStatus(QStringLiteral("fail-closed; region creation failed"));
        stop();
        return;
    }
    wl_region_add(m_region, 0, 0, qBound(1, m_targetWindow->width(), 2048), qBound(1, m_targetWindow->height(), 2048));
    ext_background_effect_surface_v1_set_blur_region(m_effect, m_region);
    wl_region_destroy(m_region);
    m_region = nullptr;
    wl_surface_commit(m_surface);
    setSequencing(QStringLiteral("set-region -> surface.commit"));

    ext_background_effect_surface_v1_set_blur_region(m_effect, nullptr);
    wl_surface_commit(m_surface);
    setSequencing(QStringLiteral("set-region -> surface.commit; clear-region -> surface.commit"));
    wl_display_flush(m_display);
    setStatus(QStringLiteral("protocol accepted; bounded region set/clear committed; visual blur unverified"));
    emit activeChanged();
}

void BackgroundEffectProbe::stop()
{
    m_retryTimer.stop();
    m_retryAttempts = 0;
    m_capabilityKnown = false;
    const bool wasActive = m_effect != nullptr;
    if (m_region) {
        wl_region_destroy(m_region);
        m_region = nullptr;
    }
    if (m_effect) {
        ext_background_effect_surface_v1_destroy(m_effect);
        m_effect = nullptr;
    }
    if (m_manager) {
        ext_background_effect_manager_v1_destroy(m_manager);
        m_manager = nullptr;
    }
    if (m_display)
        wl_display_flush(m_display);
    m_display = nullptr;
    m_compositor = nullptr;
    m_surface = nullptr;
    if (wasActive)
        emit activeChanged();
    m_capabilityPresent = false;
    m_blurCapability = false;
    if (!m_enabled)
        setStatus(QStringLiteral("disabled; no protocol request"));
}
