#include "subsurfaceprobe.h"
#include "waylandsubsurfaceadapter.h"

#include <QGuiApplication>
#include <QWindow>

SubsurfaceProbe::SubsurfaceProbe(QObject *parent)
    : QObject(parent), m_adapter(new WaylandSubsurfaceAdapter)
{
    m_retryTimer.setSingleShot(true);
    m_retryTimer.setInterval(kRetryDelayMs);
    connect(&m_retryTimer, &QTimer::timeout, this, &SubsurfaceProbe::attemptCreate);
}

SubsurfaceProbe::~SubsurfaceProbe()
{
    delete m_adapter;
}

void SubsurfaceProbe::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    m_enabled = enabled;
    if (!m_enabled) {
        m_retryTimer.stop();
        m_retryCount = 0;
        m_adapter->destroy();
    }
    emit enabledChanged();
    sync();
}

void SubsurfaceProbe::setPlaceBelow(bool placeBelow)
{
    if (m_placeBelow == placeBelow)
        return;
    m_placeBelow = placeBelow;
    if (m_adapter->active()) {
        m_adapter->destroy();
        m_retryCount = 0;
    }
    emit placeBelowChanged();
    sync();
}

void SubsurfaceProbe::setTargetWindow(QWindow *window)
{
    if (m_targetWindow == window)
        return;
    m_retryTimer.stop();
    m_retryCount = 0;
    m_adapter->destroy();
    if (m_targetWindow)
        disconnect(m_targetWindow, nullptr, this, nullptr);
    m_targetWindow = window;
    if (m_targetWindow) {
        connect(m_targetWindow, &QWindow::visibleChanged, this, &SubsurfaceProbe::sync);
        connect(m_targetWindow, &QWindow::visibilityChanged, this, &SubsurfaceProbe::sync);
        connect(m_targetWindow, &QWindow::windowStateChanged, this, &SubsurfaceProbe::sync);
        connect(m_targetWindow, &QObject::destroyed, this, [this] {
            m_retryTimer.stop();
            m_retryCount = 0;
            m_targetWindow = nullptr;
            m_adapter->destroy();
            sync();
            emit targetWindowChanged();
        });
    }
    emit targetWindowChanged();
    sync();
}

void SubsurfaceProbe::setGeometry(const QRect &geometry)
{
    if (m_geometry == geometry)
        return;
    m_geometry = geometry;
    if (m_adapter->active()) {
        m_adapter->destroy();
        m_retryCount = 0;
    }
    emit geometryChanged();
    sync();
}

bool SubsurfaceProbe::active() const
{
    return m_adapter->active();
}

QString SubsurfaceProbe::backend() const
{
    return m_adapter->backend();
}

QString SubsurfaceProbe::ordering() const
{
    return m_adapter->ordering();
}

uint SubsurfaceProbe::surfaceId() const
{
    return m_adapter->surfaceId();
}

uint SubsurfaceProbe::subsurfaceId() const
{
    return m_adapter->subsurfaceId();
}

uint SubsurfaceProbe::lastDestroyedSurfaceId() const
{
    return m_adapter->lastDestroyedSurfaceId();
}

uint SubsurfaceProbe::lastDestroyedSubsurfaceId() const
{
    return m_adapter->lastDestroyedSubsurfaceId();
}

void SubsurfaceProbe::setStatus(const QString &status)
{
    if (m_status == status)
        return;
    m_status = status;
    emit stateChanged();
}

void SubsurfaceProbe::sync()
{
    if (!m_enabled) {
        m_retryTimer.stop();
        m_retryCount = 0;
        m_adapter->destroy();
        setStatus(QStringLiteral("disabled; no surface"));
        emit stateChanged();
        return;
    }
    if (!m_targetWindow) {
        m_retryTimer.stop();
        m_retryCount = 0;
        m_adapter->destroy();
        setStatus(QStringLiteral("enabled; target window unavailable; no surface"));
        emit stateChanged();
        return;
    }
    if (m_adapter->active()) {
        if (QGuiApplication::platformName() == QStringLiteral("wayland")
            && m_targetWindow->isVisible() && m_targetWindow->isExposed()) {
            return;
        }
        m_adapter->destroy();
        m_retryCount = 0;
    }
    attemptCreate();
}

void SubsurfaceProbe::attemptCreate()
{
    if (!m_enabled || !m_targetWindow || m_adapter->active())
        return;

    if (QGuiApplication::platformName() != QStringLiteral("wayland")) {
        m_retryTimer.stop();
        setStatus(QStringLiteral("closed; non-Wayland target; no surface"));
        emit stateChanged();
        return;
    }

    if (!m_targetWindow->isVisible() || !m_targetWindow->isExposed()) {
        setStatus(QStringLiteral("enabled; waiting for visible/exposed target surface; no surface"));
        emit stateChanged();
        scheduleRetry();
        return;
    }

    QString error;
    if (!m_adapter->create(m_targetWindow, m_geometry, m_placeBelow, &error)) {
        setStatus(QStringLiteral("enabled; target surface not ready; retrying; no surface"));
        emit stateChanged();
        scheduleRetry();
        return;
    }
    m_retryTimer.stop();
    m_retryCount = 0;
    setStatus(m_placeBelow
        ? QStringLiteral("active; synthetic magenta child placed below target")
        : QStringLiteral("active; synthetic magenta child placed above target"));
    emit stateChanged();
}

void SubsurfaceProbe::scheduleRetry()
{
    if (!m_enabled || !m_targetWindow || m_adapter->active() || m_retryTimer.isActive())
        return;
    if (m_retryCount >= kMaxRetries) {
        setStatus(QStringLiteral("closed; target surface did not become ready; no surface"));
        emit stateChanged();
        return;
    }
    ++m_retryCount;
    m_retryTimer.start();
}
