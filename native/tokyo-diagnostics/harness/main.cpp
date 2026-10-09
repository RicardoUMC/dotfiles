#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include <QStringList>
#include <cstdlib>

namespace {

bool affirmativeEnvironmentValue(const QByteArray &value)
{
    const QByteArray normalized = value.trimmed().toLower();
    return normalized == "1" || normalized == "true" || normalized == "yes" || normalized == "on";
}

}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    const QStringList arguments = QCoreApplication::arguments();
    const bool nativeProbeOptIn = affirmativeEnvironmentValue(qgetenv("TOKYO_DIAGNOSTICS_ENABLE_SUBSURFACE"))
        || arguments.contains(QStringLiteral("--enable-subsurface-probe"));
    const bool lifecycleExercise = arguments.contains(QStringLiteral("--exercise-subsurface-lifecycle"));
    bool placeBelow = true;
    const QString requestedOrder = qEnvironmentVariable("TOKYO_DIAGNOSTICS_SUBSURFACE_ORDER").trimmed().toLower();
    if (requestedOrder == QStringLiteral("above"))
        placeBelow = false;
    for (const QString &argument : arguments) {
        if (argument == QStringLiteral("--subsurface-order=above"))
            placeBelow = false;
        else if (argument == QStringLiteral("--subsurface-order=below"))
            placeBelow = true;
    }

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("nativeProbeOptIn"), nativeProbeOptIn);
    engine.rootContext()->setContextProperty(QStringLiteral("nativeProbeLifecycleExercise"), lifecycleExercise);
    engine.rootContext()->setContextProperty(QStringLiteral("nativeProbePlaceBelow"), placeBelow);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(EXIT_FAILURE); },
                     Qt::QueuedConnection);
    engine.loadFromModule(QStringLiteral("Tokyo.Diagnostics.Harness"), QStringLiteral("Main"));

    if (engine.rootObjects().isEmpty()) {
        return EXIT_FAILURE;
    }

    qInfo().noquote() << QStringLiteral("Tokyo.Diagnostics harness loaded");
    if (lifecycleExercise)
        qInfo().noquote() << QStringLiteral("Subsurface lifecycle exercise enabled; bounded timers will update, disable, and quit");
    return app.exec();
}
