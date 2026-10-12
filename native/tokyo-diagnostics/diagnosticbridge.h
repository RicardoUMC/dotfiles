#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

class DiagnosticBridge : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString buildIdentity READ buildIdentity CONSTANT)
    Q_PROPERTY(QString moduleVersion READ moduleVersion CONSTANT)
    Q_PROPERTY(QString status READ status CONSTANT)
    Q_PROPERTY(bool passive READ passive CONSTANT)
    Q_PROPERTY(bool surfaceCreationSupported READ surfaceCreationSupported CONSTANT)
    Q_PROPERTY(QString capabilityState READ capabilityState CONSTANT)

public:
    explicit DiagnosticBridge(QObject *parent = nullptr);

    QString buildIdentity() const;
    QString moduleVersion() const;
    QString status() const;
    bool passive() const;
    bool surfaceCreationSupported() const;
    QString capabilityState() const;

    Q_INVOKABLE QString diagnosticSummary() const;
};
