#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "TrafficLight.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    qmlRegisterType<TrafficLight>("TrafficLight", 1, 0, "TrafficLight");
    // или можно зарегистрировать как контекстное свойство:
    // TrafficLight trafficLight;
    // engine.rootContext()->setContextProperty("trafficLight", &trafficLight);

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}