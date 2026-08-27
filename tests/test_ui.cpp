/**
 * @file test_ui.cpp
 * @brief Интеграционный тест UI: загружает главное QML окно и проверяет работу TrafficLight.
 */

#include <QtTest>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include "TrafficLight.h"
#include "StateModel.h"

using namespace TrafficLight;

class TestUi : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void testInitialState();
    void testAddState();
    void cleanupTestCase();

private:
    QGuiApplication* m_app = nullptr;
    QQmlApplicationEngine* m_engine = nullptr;
    TrafficLight* m_trafficLight = nullptr;
};

void TestUi::initTestCase()
{
    Q_INIT_RESOURCE(resources);

    // Для QML нам нужен QGuiApplication
    int argc = 1;
    char* argv[] = { const_cast<char*>("test_ui") };
    m_app = new QGuiApplication(argc, argv);

    // Регистрируем типы (как в main.cpp)
    qmlRegisterUncreatableType<TrafficLightMode>(
        "TrafficLight", 1, 0, "TrafficLightMode",
        "TrafficLightMode is created by TrafficLightState");
    qmlRegisterType<TrafficLightState>("TrafficLight", 1, 0, "TrafficLightState");
    qmlRegisterType<StatesModel>("TrafficLight", 1, 0, "StatesModel");
    qmlRegisterType<TrafficLight>("TrafficLight", 1, 0, "TrafficLight");

    m_engine = new QQmlApplicationEngine();
    m_engine->addImportPath(QStringLiteral("qrc:/qml"));
    m_engine->load(QUrl(QStringLiteral("qrc:/qml/main.qml")));

    QVERIFY(!m_engine->rootObjects().isEmpty());

    // Находим TrafficLight внутри окна
    QObject* root = m_engine->rootObjects().first();
    m_trafficLight = root->findChild<TrafficLight*>("trafficLight");
    QVERIFY(m_trafficLight != nullptr);
}

void TestUi::testInitialState()
{
    // Проверяем начальное состояние
    QCOMPARE(m_trafficLight->states()->rowCount(), 1);
    QCOMPARE(m_trafficLight->currentIndex(), 0);
    QVERIFY(m_trafficLight->currentState() != nullptr);
    QVERIFY(!m_trafficLight->isRunning());
    QVERIFY(!m_trafficLight->blinkPhase());

    // Проверяем имя состояния
    TrafficLightState* state = m_trafficLight->currentState();
    QCOMPARE(state->name(), QString("Состояние 1"));

    // Проверяем, что все каналы Off
    QCOMPARE(state->redMode()->getMode(), TrafficLightMode::Off);
    QCOMPARE(state->yellowMode()->getMode(), TrafficLightMode::Off);
    QCOMPARE(state->greenMode()->getMode(), TrafficLightMode::Off);
}

void TestUi::testAddState()
{
    // Добавляем состояние
    m_trafficLight->states()->addState();
    QCOMPARE(m_trafficLight->states()->rowCount(), 2);
    QCOMPARE(m_trafficLight->currentIndex(), 1); // автоматом переключается на новое

    TrafficLightState* newState = m_trafficLight->currentState();
    QCOMPARE(newState->name(), QString("Состояние 2"));

    // Проверяем, что свойства каналов скопированы? Нет, они создаются с Off по умолчанию
    QCOMPARE(newState->redMode()->getMode(), TrafficLightMode::Off);
}

void TestUi::cleanupTestCase()
{
    delete m_engine;
    delete m_app;
}

QTEST_MAIN(TestUi)
#include "test_ui.moc"