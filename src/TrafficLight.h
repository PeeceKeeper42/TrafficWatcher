/**
 * @file TrafficLight.h
 * @brief Основной контроллер светофора.
 * @details Управляет списком состояний, текущим индексом, запуском/остановкой,
 *          таймерами и отображением каналов (красный, жёлтый, зелёный).
 * @author Разработчик
 * @date 2026
 */

#include "StateModel.h"
#include <QObject>
#include <QTimer>
#include <QVector>

#ifndef TRAFFICLIGHT_TRAFFICLIGHT_H
#define TRAFFICLIGHT_TRAFFICLIGHT_H

namespace TrafficLight
{
    /**
     * @class TrafficLight
     * @brief Контроллер светофора.
     *
     * @details Предоставляет QML-свойства:
     *          - states – модель состояний,
     *          - currentIndex – текущий выбранный индекс,
     *          - isRunning – флаг работы,
     *          - blinkPhase – фаза мигания (для анимации),
     *          - currentState – указатель на текущее состояние.
     *          Управляет последовательным переключением состояний и отсчётом времени каждого канала.
     */
    class TrafficLight : public QObject
    {
        Q_OBJECT
        Q_PROPERTY(StatesModel* states READ states CONSTANT)
        Q_PROPERTY(int currentIndex READ currentIndex WRITE setCurrentIndex NOTIFY currentIndexChanged)
        Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)
        Q_PROPERTY(bool blinkPhase READ blinkPhase NOTIFY blinkPhaseChanged)
        Q_PROPERTY(TrafficLightState* currentState READ currentState NOTIFY currentStateChanged)

    public:
        /**
         * @brief Конструктор.
         * @param parent Родительский QObject.
         * @details Инициализирует модель состояний, подключает сигналы и создаёт одно начальное состояние.
         */
        explicit TrafficLight(QObject *parent = nullptr);
        ~TrafficLight() override = default;

        // Геттеры для QML-свойств
        StatesModel* states() const;
        int currentIndex() const;
        void setCurrentIndex(int index);
        bool isRunning() const;
        bool blinkPhase() const;
        TrafficLightState* currentState() const;

    public slots:
        /**
         * @brief Запускает светофор (если есть состояния).
         * @details Устанавливает флаг isRunning, применяет текущее состояние и запускает таймеры.
         */
        void start();

        /**
         * @brief Останавливает светофор.
         * @details Останавливает все таймеры, выключает каналы, сбрасывает фазу мигания.
         */
        void stop();

        /**
         * @brief Переключает на следующее состояние (по кругу).
         * @details Работает только при isRunning.
         */
        void nextState();

        /**
         * @brief Принудительно применить состояние по индексу.
         * @param index Индекс состояния в модели.
         */
        void updateState(int index);

    signals:
        void currentIndexChanged();
        void isRunningChanged();
        void blinkPhaseChanged();
        void currentStateChanged();

    private slots:
        void onRowsInserted(const QModelIndex &parent, int first, int last);
        void onStateDataChanged();
        void onBlinkTimeout();           ///< Обновляет фазу мигания.
        void onRowsRemoved();            ///< Обрабатывает удаление состояния.
        void onUpdateTimer();            ///< Обновляет оставшееся время для каждого канала.

    private:
        // Модель данных
        StatesModel* m_states = nullptr;

        // Текущее состояние
        int m_currentIndex = -1;
        TrafficLightState* m_currentState = nullptr;

        // Флаги
        bool m_isRunning = false;
        bool m_blinkPhase = false;

        // Таймеры
        QTimer m_blinkTimer;       ///< Период 100 мс для мигания.
        QTimer m_updateTimer;      ///< Период 100 мс для отсчёта времени каналов.

        /**
         * @struct ChannelState
         * @brief Отслеживает состояние одного канала (цвета).
         */
        struct ChannelState {
            TrafficLightMode* mode = nullptr; ///< Указатель на объект режима.
            int remainingMs = 0;               ///< Оставшееся время в миллисекундах.
        };
        QVector<ChannelState> m_channelStates;

        // Приватные методы
        void applyState(int index);
        void updateCurrentState();
        void stopAllChannels();
    };

} // namespace TrafficLight

#endif // TRAFFICLIGHT_TRAFFICLIGHT_H