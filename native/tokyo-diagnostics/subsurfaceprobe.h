#pragma once

#include <QObject>
#include <QPointer>
#include <QRect>
#include <QString>
#include <QTimer>
#include <QtQml/qqmlregistration.h>
#include <QWindow>


class WaylandSubsurfaceAdapter;

class SubsurfaceProbe : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool placeBelow READ placeBelow WRITE setPlaceBelow NOTIFY placeBelowChanged)
    Q_PROPERTY(QWindow *targetWindow READ targetWindow WRITE setTargetWindow NOTIFY targetWindowChanged)
    Q_PROPERTY(QRect geometry READ geometry WRITE setGeometry NOTIFY geometryChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(bool active READ active NOTIFY stateChanged)
    Q_PROPERTY(QString backend READ backend NOTIFY stateChanged)
    Q_PROPERTY(QString ordering READ ordering NOTIFY stateChanged)
    Q_PROPERTY(uint surfaceId READ surfaceId NOTIFY stateChanged)
    Q_PROPERTY(uint subsurfaceId READ subsurfaceId NOTIFY stateChanged)
    Q_PROPERTY(uint lastDestroyedSurfaceId READ lastDestroyedSurfaceId NOTIFY stateChanged)
    Q_PROPERTY(uint lastDestroyedSubsurfaceId READ lastDestroyedSubsurfaceId NOTIFY stateChanged)

public:
    explicit SubsurfaceProbe(QObject *parent = nullptr);
    ~SubsurfaceProbe() override;

    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    bool placeBelow() const { return m_placeBelow; }
    void setPlaceBelow(bool placeBelow);
    QWindow *targetWindow() const { return m_targetWindow; }
    void setTargetWindow(QWindow *window);
    QRect geometry() const { return m_geometry; }
    void setGeometry(const QRect &geometry);
    QString status() const { return m_status; }
    bool active() const;
    QString backend() const;
    QString ordering() const;
    uint surfaceId() const;
    uint subsurfaceId() const;
    uint lastDestroyedSurfaceId() const;
    uint lastDestroyedSubsurfaceId() const;

signals:
    void enabledChanged();
    void placeBelowChanged();
    void targetWindowChanged();
    void geometryChanged();
    void stateChanged();

private:
    static constexpr int kRetryDelayMs = 50;
    static constexpr int kMaxRetries = 20;

    void sync();
    void attemptCreate();
    void scheduleRetry();
    void setStatus(const QString &status);

    bool m_enabled = false;
    bool m_placeBelow = true;
    QPointer<QWindow> m_targetWindow;
    QRect m_geometry = QRect(12, 12, 180, 72);
    QString m_status = QStringLiteral("disabled; no surface");
    WaylandSubsurfaceAdapter *m_adapter = nullptr;
    QTimer m_retryTimer;
    int m_retryCount = 0;
};
