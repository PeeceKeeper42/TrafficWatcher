/**
* @file main.cpp
 * @brief Точка входа в приложение "Светофор".
 * @details Инициализирует QGuiApplication, регистрирует C++ типы для QML
 *          и загружает главный QML-файл.
 *
 * @author Churkin Vladimir
 * @date 14.08.2026
 */

#include <QGuiApplication>
#include <QQmlApplicationEngine>

#include "TrafficLight.h"

#include <windows.h>

int main(int argc, char *argv[])
{
#ifdef Q_OS_WIN
    SetConsoleOutputCP(CP_UTF8);
#endif

    QGuiApplication app(argc, argv);

    // Регистрация типов для QML
    qmlRegisterUncreatableType<TrafficLight::TrafficLightMode>(
        "TrafficLight", 1, 0, "TrafficLightMode",
        "TrafficLightMode is created by TrafficLightState");

    qmlRegisterType<TrafficLight::TrafficLightState>(
        "TrafficLight", 1, 0, "TrafficLightState");

    qmlRegisterType<TrafficLight::StatesModel>(
        "TrafficLight", 1, 0, "StatesModel");

    qmlRegisterType<TrafficLight::TrafficLight>(
        "TrafficLight", 1, 0, "TrafficLight");

    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral("qrc:/qml"));
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}