/**
 * @file test_trafficlightstate.cpp
 * @brief Модульный тест для класса TrafficLightState.
 */

#include <QtTest>
#include "TrafficLightState.h"

using namespace TrafficLight;

class TestTrafficLightState : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void testName();
    void testModes();
    void testDuration();
    void testSignals();
    void cleanupTestCase();

private:
    TrafficLightState* m_state = nullptr;
};

void TestTrafficLightState::initTestCase()
{
    m_state = new TrafficLightState(this);
    QVERIFY(m_state != nullptr);
}

void TestTrafficLightState::testName()
{
    QSignalSpy spy(m_state, &TrafficLightState::nameChanged);

    m_state->setName("Test State");
    QCOMPARE(m_state->name(), QString("Test State"));
    QCOMPARE(spy.count(), 1);

    // Установка того же имени не должна генерировать сигнал
    m_state->setName("Test State");
    QCOMPARE(spy.count(), 1);
}

void TestTrafficLightState::testModes()
{
    TrafficLightMode* red = m_state->redMode();
    TrafficLightMode* yellow = m_state->yellowMode();
    TrafficLightMode* green = m_state->greenMode();

    QVERIFY(red != nullptr);
    QVERIFY(yellow != nullptr);
    QVERIFY(green != nullptr);

    // Проверяем начальное состояние (Off)
    QCOMPARE(red->getMode(), TrafficLightMode::Off);
    QCOMPARE(yellow->getMode(), TrafficLightMode::Off);
    QCOMPARE(green->getMode(), TrafficLightMode::Off);

    // Устанавливаем режимы
    red->setMode(TrafficLightMode::On);
    yellow->setMode(TrafficLightMode::Blink);
    green->setMode(TrafficLightMode::On);

    QCOMPARE(red->getMode(), TrafficLightMode::On);
    QCOMPARE(yellow->getMode(), TrafficLightMode::Blink);
    QCOMPARE(green->getMode(), TrafficLightMode::On);
}

void TestTrafficLightState::testDuration()
{
    TrafficLightMode* red = m_state->redMode();
    red->setDuration(2000);
    QCOMPARE(red->getDuration(), 2000);

    // Проверяем изменение через сигнал
    QSignalSpy spy(red, &TrafficLightMode::durationChanged);
    red->setDuration(1500);
    QCOMPARE(red->getDuration(), 1500);
    QCOMPARE(spy.count(), 1);
}

void TestTrafficLightState::testSignals()
{
    // Проверяем сигналы изменения имени
    QSignalSpy nameSpy(m_state, &TrafficLightState::nameChanged);
    m_state->setName("Another Name");
    QCOMPARE(nameSpy.count(), 1);

    // Проверяем сигналы режима
    TrafficLightMode* green = m_state->greenMode();
    QSignalSpy modeSpy(green, &TrafficLightMode::modeChanged);
    green->setMode(TrafficLightMode::Blink);
    QCOMPARE(modeSpy.count(), 1);

    // Проверяем сигналы длительности
    QSignalSpy durationSpy(green, &TrafficLightMode::durationChanged);
    green->setDuration(3000);
    QCOMPARE(durationSpy.count(), 1);

    // Проверяем сигнал активности
    QSignalSpy activeSpy(green, &TrafficLightMode::activeChanged);
    green->setActive(true);
    QCOMPARE(activeSpy.count(), 1);
}

void TestTrafficLightState::cleanupTestCase()
{
    delete m_state;
    m_state = nullptr;
}

QTEST_MAIN(TestTrafficLightState)
#include "test_trafficlightstate.moc"