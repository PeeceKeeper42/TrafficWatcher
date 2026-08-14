/**
 * @file StateModel.h
 * @brief Модель списка состояний светофора (наследует QAbstractListModel).
 * @details Хранит список объектов TrafficLightState и предоставляет их в QML
 *          через роль StateObjectRole.
 */

#include "TrafficLightState.h"
#include <QAbstractListModel>

#ifndef TRAFFICLIGHT_STATEMODEL_H
#define TRAFFICLIGHT_STATEMODEL_H

namespace TrafficLight
{
    /**
     * @brief Роли модели списка состояний.
     */
    enum StatesModelRoles
    {
        StateObjectRole = Qt::UserRole + 1, ///< Роль, возвращающая указатель на TrafficLightState.
    };

    /**
     * @class StatesModel
     * @brief Модель списка состояний светофора.
     *
     * @details Модель управляет списком объектов TrafficLightState.
     *          Единственная роль StateObjectRole возвращает указатель на состояние,
     *          а QML уже читает его свойства напрямую.
     *          Биндинги обновляются автоматически благодаря сигналам свойств.
     */
    class StatesModel : public QAbstractListModel
    {
        Q_OBJECT

    public:
        /**
         * @brief Конструктор.
         * @param parent Родительский QObject.
         */
        explicit StatesModel(QObject *parent = nullptr);
        ~StatesModel() override;

        // --- Интерфейс QAbstractListModel ---
        int rowCount(const QModelIndex &parent = QModelIndex()) const override;
        QVariant data(const QModelIndex &index, int role) const override;
        QHash<int, QByteArray> roleNames() const override;

        /**
         * @brief Добавляет новое состояние в конец списка.
         * @details Имя состояния устанавливается как "Состояние N".
         *          Модель генерирует сигнал rowsInserted.
         */
        Q_INVOKABLE void addState();

        /**
         * @brief Удаляет состояние по индексу.
         * @param index Индекс удаляемого элемента.
         * @details Модель генерирует сигнал rowsRemoved.
         */
        Q_INVOKABLE void removeState(int index);

        /**
         * @brief Возвращает указатель на состояние по индексу.
         * @param index Индекс состояния.
         * @return Указатель на TrafficLightState, либо nullptr если индекс невалидный.
         */
        Q_INVOKABLE TrafficLightState* getState(int index) const;

        /**
         * @brief Перемещает состояние с одного индекса на другой.
         * @param from Исходный индекс.
         * @param to   Целевой индекс.
         * @return true, если перемещение выполнено.
         */
        Q_INVOKABLE bool moveState(int from, int to);

    private:
        QList<TrafficLightState*> m_states; ///< Список состояний (владелец).
    };

} // namespace TrafficLight

#endif //TRAFFICLIGHT_STATEMODEL_H