#include "diagnosticbridge.h"

#include <QtQml/qqml.h>

#ifndef TOKYO_DIAGNOSTICS_VERSION
#define TOKYO_DIAGNOSTICS_VERSION "unknown"
#endif

DiagnosticBridge::DiagnosticBridge(QObject *parent)
    : QObject(parent)
{
}

QString DiagnosticBridge::buildIdentity() const
{
    return QStringLiteral("tokyo-diagnostics/%1").arg(QStringLiteral(TOKYO_DIAGNOSTICS_VERSION));
}

QString DiagnosticBridge::moduleVersion() const
{
    return QStringLiteral("1.0");
}

QString DiagnosticBridge::status() const
{
    return QStringLiteral("passive scaffold; no live shell connection");
}

bool DiagnosticBridge::passive() const
{
    return true;
}

bool DiagnosticBridge::surfaceCreationSupported() const
{
    return false;
}

QString DiagnosticBridge::capabilityState() const
{
    return QStringLiteral("diagnostics-only; subsurface and blur unavailable");
}

QString DiagnosticBridge::diagnosticSummary() const
{
    return QStringLiteral("No-op diagnostic: the bridge performs no compositor or shell operations.");
}
