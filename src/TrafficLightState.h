/**
 * @file TrafficLightState.h
 * @brief Определения классов TrafficLightMode и TrafficLightState.
 * @details TrafficLightMode – режим отдельного канала (цвета): Off, On, Blink,
 *          с длительностью и активностью.
 *          TrafficLightState – набор из трёх каналов (красный, жёлтый, зелёный)
 *          и имя состояния.
 */

#include <QObject>

#ifndef TRAFFICLIGHT_TRAFFICLIGHTSTATE_H
#define TRAFFICLIGHT_TRAFFICLIGHTSTATE_H

namespace TrafficLight
{
    /**
     * @class TrafficLightMode
     * @brief Режим одного канала светофора.
     *
     * @details Хранит режим (Off/On/Blink), длительность в мс, имя и флаг активности.
     *          Все свойства имеют сигналы об изменении для биндингов в QML.
     */
    class TrafficLightMode : public QObject
    {
        Q_OBJECT
        Q_PROPERTY(int mode READ getMode WRITE setMode NOTIFY modeChanged)
        Q_PROPERTY(int duration READ getDuration WRITE setDuration NOTIFY durationChanged)
        Q_PROPERTY(QString name READ getName WRITE setName NOTIFY nameChanged)
        Q_PROPERTY(bool active READ isActive WRITE setActive NOTIFY activeChanged)

    public:
        /**
         * @enum Mode
         * @brief Возможные режимы работы канала.
         */
        enum Mode
        {
            Off = 0,   ///< Выключен
            On = 1,    ///< Включён постоянно
            Blink = 2  ///< Мигает с периодом 100 мс (фаза управляется внешним таймером)
        };
        Q_ENUM(Mode)

        /**
         * @brief Конструктор.
         * @param name Название канала (например, "Красный свет").
         * @param mode Начальный режим (по умолчанию Off).
         * @param durationMs Длительность в миллисекундах (по умолчанию 1000).
         * @param parent Родительский QObject.
         */
        explicit TrafficLightMode(
            const QString& name = tr("Знак светофора (цветной)"),
            int mode = Off,
            int durationMs = 1000,
            QObject *parent = nullptr);

        // Геттеры/сеттеры
        int getMode() const;
        void setMode(int mode);

        int getDuration() const;
        void setDuration(int ms);

        void setName(const QString &name);
        QString getName() const;

        bool isActive() const;
        void setActive(bool active);

    signals:
        void modeChanged();
        void nameChanged();
        void durationChanged();
        void activeChanged();

    private:
        int m_mode = Off;
        int m_durationMs = 1000;
        QString m_name = tr("Знак светофора (цветной)");
        bool m_active = false;
    };

    /**
     * @class TrafficLightState
     * @brief Состояние светофора, состоящее из трёх каналов.
     *
     * @details Содержит указатели на красный, жёлтый и зелёный каналы,
     *          а также пользовательское имя состояния.
     */
    class TrafficLightState : public QObject
    {
        Q_OBJECT
        Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
        Q_PROPERTY(TrafficLightMode* redMode READ redMode CONSTANT)
        Q_PROPERTY(TrafficLightMode* yellowMode READ yellowMode CONSTANT)
        Q_PROPERTY(TrafficLightMode* greenMode READ greenMode CONSTANT)

    public:
        /**
         * @brief Конструктор. Создаёт три канала с именем по умолчанию.
         * @param parent Родительский QObject.
         */
        explicit TrafficLightState(QObject *parent = nullptr);
        virtual ~TrafficLightState();

        // Доступ к каналам
        Q_INVOKABLE TrafficLightMode* redMode() const;
        Q_INVOKABLE TrafficLightMode* yellowMode() const;
        Q_INVOKABLE TrafficLightMode* greenMode() const;

        // Имя состояния
        QString name() const;
        void setName(const QString &name);

    signals:
        void nameChanged();

    private:
        TrafficLightMode* m_redMode;
        TrafficLightMode* m_yellowMode;
        TrafficLightMode* m_greenMode;
        QString m_name;
    };

} // namespace TrafficLight

#endif //TRAFFICLIGHT_TRAFFICLIGHTSTATE_H