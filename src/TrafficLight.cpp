/**
 * @file TrafficLight.cpp
 * @brief Реализация контроллера светофора.
 */

#include "TrafficLight.h"
#include <QDebug>

namespace TrafficLight
{
    TrafficLight::TrafficLight(QObject *parent)
        : QObject(parent)
    {
        m_states = new StatesModel(this);

        connect(m_states, &StatesModel::dataChanged,
                this, &TrafficLight::onStateDataChanged);
        connect(m_states, &StatesModel::rowsRemoved,
                this, &TrafficLight::onRowsRemoved);
        connect(m_states, &StatesModel::modelReset,
                this, &TrafficLight::onRowsRemoved);
        connect(m_states, &StatesModel::rowsInserted,
                this, &TrafficLight::onRowsInserted);

        connect(&m_blinkTimer, &QTimer::timeout,
                this, &TrafficLight::onBlinkTimeout);
        connect(&m_updateTimer, &QTimer::timeout,
                this, &TrafficLight::onUpdateTimer);

        // Начальное состояние
        m_states->addState();
        setCurrentIndex(0);
    }

    StatesModel* TrafficLight::states() const { return m_states; }
    int TrafficLight::currentIndex() const { return m_currentIndex; }
    bool TrafficLight::isRunning() const { return m_isRunning; }
    bool TrafficLight::blinkPhase() const { return m_blinkPhase; }
    TrafficLightState* TrafficLight::currentState() const { return m_currentState; }

    void TrafficLight::setCurrentIndex(int index)
    {
        if (m_currentIndex == index)
            return;

        if (index < -1 || index >= m_states->rowCount())
            return;

        m_currentIndex = index;
        emit currentIndexChanged();

        updateCurrentState();

        if (m_isRunning)
        {
            applyState(m_currentIndex);
        }
    }

    void TrafficLight::start()
    {
        if (m_isRunning)
            return;

        if (m_states->rowCount() == 0)
        {
            qWarning() << "No states available to start";
            return;
        }

        m_isRunning = true;
        emit isRunningChanged();

        if (m_currentIndex < 0 || m_currentIndex >= m_states->rowCount())
        {
            setCurrentIndex(0);
        }
        else
        {
            applyState(m_currentIndex);
        }
    }

    void TrafficLight::stop()
    {
        if (!m_isRunning) return;

        m_blinkTimer.stop();
        m_updateTimer.stop();
        stopAllChannels();

        m_isRunning = false;
        m_blinkPhase = false;

        emit isRunningChanged();
        emit blinkPhaseChanged();
    }

    void TrafficLight::nextState()
    {
        if (!m_isRunning || m_states->rowCount() == 0)
            return;

        int nextIndex = (m_currentIndex + 1) % m_states->rowCount();
        setCurrentIndex(nextIndex);
    }

    void TrafficLight::updateState(int index)
    {
        if (index >= 0 && index < m_states->rowCount())
            applyState(index);
    }

    void TrafficLight::onRowsInserted(const QModelIndex &parent, int first, int last)
    {
        Q_UNUSED(parent);
        Q_UNUSED(first);
        setCurrentIndex(last);
    }

    void TrafficLight::onStateDataChanged()
    {
        if (m_isRunning && m_currentIndex >= 0)
            applyState(m_currentIndex);
    }

    void TrafficLight::onBlinkTimeout()
    {
        m_blinkPhase = !m_blinkPhase;
        emit blinkPhaseChanged();
    }

    void TrafficLight::onRowsRemoved()
    {
        const int rowCount = m_states->rowCount();

        TrafficLightState* oldState = m_currentState;

        if (rowCount == 0)
        {
            m_blinkTimer.stop();
            m_updateTimer.stop();
            m_channelStates.clear();

            if (m_isRunning)
            {
                m_isRunning = false;
                emit isRunningChanged();
            }

            m_currentIndex = -1;
            emit currentIndexChanged();
            updateCurrentState();
            return;
        }

        if (m_currentIndex >= rowCount)
        {
            m_currentIndex = rowCount - 1;
            emit currentIndexChanged();
        }

        updateCurrentState();

        if (m_currentState != oldState)
        {
            m_channelStates.clear();

            if (m_isRunning)
            {
                if (m_currentState)
                    applyState(m_currentIndex);
                else
                    stop();
            }
        }
    }

    void TrafficLight::onUpdateTimer()
    {
        if (!m_isRunning)
            return;

        bool allFinished = true;

        for (auto &ch : m_channelStates)
        {
            if (!ch.mode)
                continue;

            if (!ch.mode->isActive())
                continue;

            ch.remainingMs -= 100;
            if (ch.remainingMs <= 0)
            {
                ch.mode->setActive(false);
                ch.remainingMs = 0;
            }
            else
            {
                allFinished = false;
            }
        }

        if (allFinished)
        {
            m_updateTimer.stop();
            nextState();
        }
    }

    void TrafficLight::applyState(int index)
    {
        if (index < 0 || index >= m_states->rowCount())
        {
            m_blinkTimer.stop();
            m_updateTimer.stop();

            stopAllChannels();
            return;
        }

        m_currentIndex = index;
        updateCurrentState();

        TrafficLightState* state = m_states->getState(index);
        if (!state)
            return;

        m_updateTimer.stop();
        m_blinkTimer.stop();

        m_channelStates.clear();
        auto addChannel = [&](TrafficLightMode* mode)
        {
            if (!mode)
                return;

            bool active = (mode->getMode() != TrafficLightMode::Off);
            mode->setActive(active);

            ChannelState ch;
            ch.mode = mode;
            ch.remainingMs = active ? mode->getDuration() : 0;

            m_channelStates.append(ch);
        };

        addChannel(state->redMode());
        addChannel(state->yellowMode());
        addChannel(state->greenMode());

        if (m_isRunning)
            m_updateTimer.start(100);

        bool hasBlink = false;
        if (state->redMode()->getMode() == TrafficLightMode::Blink) hasBlink = true;
        if (state->yellowMode()->getMode() == TrafficLightMode::Blink) hasBlink = true;
        if (state->greenMode()->getMode() == TrafficLightMode::Blink) hasBlink = true;

        if (hasBlink && m_isRunning)
        {
            m_blinkTimer.start(100);
        }
        else
        {
            m_blinkTimer.stop();
            m_blinkPhase = false;
            emit blinkPhaseChanged();
        }
    }

    void TrafficLight::updateCurrentState()
    {
        TrafficLightState* newState =
            (m_currentIndex >= 0 && m_currentIndex < m_states->rowCount())
                ? m_states->getState(m_currentIndex)
                : nullptr;

        if (m_currentState != newState)
        {
            m_currentState = newState;
            emit currentStateChanged();
        }
    }

    void TrafficLight::stopAllChannels()
    {
        for (auto &ch : m_channelStates)
        {
            if (ch.mode)
                ch.mode->setActive(false);
        }

        m_channelStates.clear();
    }

} // namespace TrafficLight