#pragma once

#include <QObject>
#include <QTimer>
#include <QMap>

class TrafficLight : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int redDuration READ redDuration WRITE setRedDuration NOTIFY redDurationChanged)
    Q_PROPERTY(int redYellowDuration READ redYellowDuration WRITE setRedYellowDuration NOTIFY redYellowDurationChanged)
    Q_PROPERTY(int greenDuration READ greenDuration WRITE setGreenDuration NOTIFY greenDurationChanged)
    Q_PROPERTY(int yellowDuration READ yellowDuration WRITE setYellowDuration NOTIFY yellowDurationChanged)
    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)
    Q_PROPERTY(LightState currentState READ currentState NOTIFY stateChanged)

public:
    enum class LightState {
        None,
        Red,
        RedYellow,
        Green,
        Yellow
    };
    Q_ENUM(LightState)

    explicit TrafficLight(QObject *parent = nullptr);

    // Геттеры длительностей (в миллисекундах)
    int redDuration() const;
    int redYellowDuration() const;
    int greenDuration() const;
    int yellowDuration() const;

    // Сеттеры длительностей
    void setRedDuration(int ms);
    void setRedYellowDuration(int ms);
    void setGreenDuration(int ms);
    void setYellowDuration(int ms);

    bool isRunning() const;
    LightState currentState() const;

public slots:
    void start();
    void stop();
    void nextState();   // Принудительный переход к следующему состоянию

signals:
    void stateChanged(LightState newState);
    void redDurationChanged();
    void redYellowDurationChanged();
    void greenDurationChanged();
    void yellowDurationChanged();
    void isRunningChanged();

private slots:
    void onTimeout();

private:
    QTimer m_timer;
    LightState m_currentState = LightState::None;
    QMap<LightState, int> m_durations;
    bool m_isRunning = false;

    void setState(LightState state);
    void startTimerForCurrentState();
};