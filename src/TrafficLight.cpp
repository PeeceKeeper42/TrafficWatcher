#include "TrafficLight.h"
#include <QDebug>

TrafficLight::TrafficLight(QObject *parent)
    : QObject(parent)
{
    // Значения по умолчанию (в миллисекундах)
    m_durations[LightState::Red]        = 3000;
    m_durations[LightState::RedYellow]  = 1000;
    m_durations[LightState::Green]      = 4000;
    m_durations[LightState::Yellow]     = 2000;
    // Для None длительность не нужна

    connect(&m_timer, &QTimer::timeout, this, &TrafficLight::onTimeout);
}

int TrafficLight::redDuration() const
{
    return m_durations.value(LightState::Red, 3000);
}

int TrafficLight::redYellowDuration() const
{
    return m_durations.value(LightState::RedYellow, 1000);
}

int TrafficLight::greenDuration() const
{
    return m_durations.value(LightState::Green, 4000);
}

int TrafficLight::yellowDuration() const
{
    return m_durations.value(LightState::Yellow, 2000);
}

void TrafficLight::setRedDuration(int ms)
{
    if (ms != redDuration()) {
        m_durations[LightState::Red] = ms;
        emit redDurationChanged();
        // Если сейчас горит красный, перезапускаем таймер с новым значением
        if (m_isRunning && m_currentState == LightState::Red) {
            startTimerForCurrentState();
        }
    }
}

void TrafficLight::setRedYellowDuration(int ms)
{
    if (ms != redYellowDuration()) {
        m_durations[LightState::RedYellow] = ms;
        emit redYellowDurationChanged();
        if (m_isRunning && m_currentState == LightState::RedYellow) {
            startTimerForCurrentState();
        }
    }
}

void TrafficLight::setGreenDuration(int ms)
{
    if (ms != greenDuration()) {
        m_durations[LightState::Green] = ms;
        emit greenDurationChanged();
        if (m_isRunning && m_currentState == LightState::Green) {
            startTimerForCurrentState();
        }
    }
}

void TrafficLight::setYellowDuration(int ms)
{
    if (ms != yellowDuration()) {
        m_durations[LightState::Yellow] = ms;
        emit yellowDurationChanged();
        if (m_isRunning && m_currentState == LightState::Yellow) {
            startTimerForCurrentState();
        }
    }
}

bool TrafficLight::isRunning() const
{
    return m_isRunning;
}

TrafficLight::LightState TrafficLight::currentState() const
{
    return m_currentState;
}

void TrafficLight::start()
{
    if (m_isRunning)
        return;

    m_isRunning = true;
    emit isRunningChanged();

    setState(LightState::Red);
    startTimerForCurrentState();
}

void TrafficLight::stop()
{
    if (!m_isRunning)
        return;

    m_timer.stop();
    m_isRunning = false;
    emit isRunningChanged();

    setState(LightState::None);
}

void TrafficLight::nextState()
{
    if (!m_isRunning) {
        // Если не запущен, можно ничего не делать или включить
        return;
    }

    // Определяем следующее состояние по порядку
    LightState next;
    switch (m_currentState) {
    case LightState::Red:
        next = LightState::RedYellow;
        break;
    case LightState::RedYellow:
        next = LightState::Green;
        break;
    case LightState::Green:
        next = LightState::Yellow;
        break;
    case LightState::Yellow:
        next = LightState::Red;
        break;
    default:
        next = LightState::Red;
        break;
    }

    setState(next);
    startTimerForCurrentState();
}

void TrafficLight::onTimeout()
{
    if (m_isRunning) {
        nextState();
    }
}

void TrafficLight::setState(LightState state)
{
    if (m_currentState != state) {
        m_currentState = state;
        emit stateChanged(state);
    }
}

void TrafficLight::startTimerForCurrentState()
{
    if (m_currentState == LightState::None) {
        m_timer.stop();
        return;
    }

    int duration = m_durations.value(m_currentState, 3000);
    if (duration <= 0) {
        // Если длительность нулевая, переходим сразу на следующее состояние
        // Но лучше предотвратить зацикливание — просто пропускаем
        if (m_isRunning) {
            // Можно запланировать немедленный переход, но для простоты остановим таймер
            m_timer.stop();
            // И вызовем nextState() через 0 мс, чтобы не зациклиться
            QTimer::singleShot(0, this, &TrafficLight::nextState);
        }
        return;
    }

    m_timer.start(duration);
}