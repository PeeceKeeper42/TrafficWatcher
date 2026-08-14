/**
 * @file TrafficLightState.cpp
 * @brief Реализация классов TrafficLightMode и TrafficLightState.
 */

#include "TrafficLightState.h"
#include <QDebug>

namespace TrafficLight
{
    // --- TrafficLightMode ---

    TrafficLightMode::TrafficLightMode(const QString& name, int mode, int durationMs, QObject *parent)
    : QObject(parent)
    , m_name(name)
    , m_mode(mode)
    , m_durationMs(durationMs)
    { }

    int TrafficLightMode::getMode() const { return m_mode; }
    void TrafficLightMode::setMode(int mode)
    {
        if (m_mode != mode) {
            m_mode = mode;
            emit modeChanged();
        }
    }

    int TrafficLightMode::getDuration() const { return m_durationMs; }
    void TrafficLightMode::setDuration(int durationMs)
    {
        if (m_durationMs != durationMs) {
            m_durationMs = durationMs;
            emit durationChanged();
        }
    }

    QString TrafficLightMode::getName() const { return m_name; }
    void TrafficLightMode::setName(const QString &name)
    {
        if (m_name != name) {
            m_name = name;
            emit nameChanged();
        }
    }

    bool TrafficLightMode::isActive() const { return m_active; }
    void TrafficLightMode::setActive(bool active)
    {
        if (m_active != active) {
            m_active = active;
            emit activeChanged();
        }
    }

    // --- TrafficLightState ---

    TrafficLightState::TrafficLightState(QObject *parent)
    : QObject(parent)
    {
        m_redMode = new TrafficLightMode(tr("Красный свет"), TrafficLightMode::Off, 0, this);
        m_yellowMode = new TrafficLightMode(tr("Желтый свет"), TrafficLightMode::Off, 0, this);
        m_greenMode = new TrafficLightMode(tr("Зеленый свет"), TrafficLightMode::Off, 0, this);
    }

    TrafficLightState::~TrafficLightState()
    {
        if (m_redMode)   { m_redMode->deleteLater();   m_redMode = nullptr; }
        if (m_yellowMode){ m_yellowMode->deleteLater(); m_yellowMode = nullptr; }
        if (m_greenMode) { m_greenMode->deleteLater();  m_greenMode = nullptr; }
    }

    TrafficLightMode* TrafficLightState::redMode() const
    {
        if (m_redMode == nullptr) qCritical("Red light object requested but not initialized");
        return m_redMode;
    }

    TrafficLightMode* TrafficLightState::yellowMode() const
    {
        if (m_yellowMode == nullptr) qCritical("Yellow light object requested but not initialized");
        return m_yellowMode;
    }

    TrafficLightMode* TrafficLightState::greenMode() const
    {
        if (m_greenMode == nullptr) qCritical("Green light object requested but not initialized");
        return m_greenMode;
    }

    QString TrafficLightState::name() const { return m_name; }
    void TrafficLightState::setName(const QString &name)
    {
        if (m_name == name) return;
        m_name = name;
        emit nameChanged();
    }

} // namespace TrafficLight