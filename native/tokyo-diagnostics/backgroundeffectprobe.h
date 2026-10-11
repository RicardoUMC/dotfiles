#pragma once

#include <QObject>
#include <QRect>
#include <QWindow>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class BackgroundEffectProbe : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QWindow *targetWindow READ targetWindow WRITE setTargetWindow NOTIFY targetWindowChanged)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(bool capabilityPresent READ capabilityPresent NOTIFY capabilityPresentChanged)
    Q_PROPERTY(bool blurCapability READ blurCapability NOTIFY capabilityPresentChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString sequencing READ sequencing NOTIFY sequencingChanged)
public:
    explicit BackgroundEffectProbe(QObject *parent = nullptr);
    ~BackgroundEffectProbe() override;

    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    QWindow *targetWindow() const { return m_targetWindow; }
    void setTargetWindow(QWindow *window);
    bool active() const { return m_effect != nullptr; }
    bool capabilityPresent() const { return m_capabilityPresent; }
    bool blurCapability() const { return m_blurCapability; }
    QString status() const { return m_status; }
    QString sequencing() const { return m_sequencing; }

public:
    void onManagerBound(struct ext_background_effect_manager_v1 *manager);

public slots:
    void tryStart();
    void onCapabilities(uint32_t flags);

signals:
    void enabledChanged();
    void targetWindowChanged();
    void activeChanged();
    void capabilityPresentChanged();
    void statusChanged();
    void sequencingChanged();

private:
    void stop();
    void scheduleRetry();
    void issueEffect();
    void setStatus(const QString &status);
    void setSequencing(const QString &sequencing);

    bool m_enabled = false;
    bool m_capabilityPresent = false;
    bool m_blurCapability = false;
    QWindow *m_targetWindow = nullptr;
    struct ext_background_effect_manager_v1 *m_manager = nullptr;
    struct ext_background_effect_surface_v1 *m_effect = nullptr;
    struct wl_display *m_display = nullptr;
    struct wl_compositor *m_compositor = nullptr;
    struct wl_surface *m_surface = nullptr;
    struct wl_region *m_region = nullptr;
    QTimer m_retryTimer;
    int m_retryAttempts = 0;
    bool m_capabilityKnown = false;
    QString m_status = QStringLiteral("disabled; no protocol request");
    QString m_sequencing = QStringLiteral("none");
};
