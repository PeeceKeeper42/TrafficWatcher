/**
* @file StateModel.cpp
 * @brief Реализация модели списка состояний.
 */

#include "StateModel.h"

namespace TrafficLight
{
    StatesModel::StatesModel(QObject *parent)
        : QAbstractListModel(parent)
    { }

    StatesModel::~StatesModel()
    {
        qDeleteAll(m_states);
        m_states.clear();
    }

    int StatesModel::rowCount(const QModelIndex &parent) const
    {
        Q_UNUSED(parent)
        return m_states.size();
    }

    QVariant StatesModel::data(const QModelIndex &index, int role) const
    {
        if (!index.isValid() || index.row() < 0 || index.row() >= m_states.size())
            return QVariant();

        if (role != StateObjectRole)
            return QVariant();

        return QVariant::fromValue(m_states[index.row()]);
    }

    QHash<int, QByteArray> StatesModel::roleNames() const
    {
        QHash<int, QByteArray> roles;
        roles[StateObjectRole] = "stateObject";
        return roles;
    }

    void StatesModel::addState()
    {
        beginInsertRows(QModelIndex(), m_states.size(), m_states.size());

        auto *state = new TrafficLightState(this);
        state->setName(QString("Состояние %1").arg(m_states.size() + 1));
        m_states.append(state);

        endInsertRows();
    }

    void StatesModel::removeState(int index)
    {
        if (index < 0 || index >= m_states.size())
            return;

        beginRemoveRows(QModelIndex(), index, index);
        delete m_states.takeAt(index);
        endRemoveRows();
    }

    TrafficLightState* StatesModel::getState(int index) const
    {
        if (index < 0 || index >= m_states.size())
            return nullptr;

        return m_states[index];
    }

    bool StatesModel::moveState(int from, int to)
    {
        if (from < 0 || from >= m_states.size() || to < 0 || to >= m_states.size() || from == to)
            return false;

        beginMoveRows(QModelIndex(), from, from, QModelIndex(), (to > from) ? to + 1 : to);
        m_states.move(from, to);
        endMoveRows();

        return true;
    }

} // namespace TrafficLight