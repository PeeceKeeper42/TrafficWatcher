/**
 * @file StyledComboBox.qml
 * @brief Стилизованный выпадающий список для тёмной темы.
 *
 * @property model          - модель строк для отображения
 * @property currentIndex   - индекс выбранного элемента (биндится к TrafficLightMode.mode)
 * @property enabled        - доступность контрола
 *
 * @signal activated(int index) - испускается при выборе элемента
 *
 * Биндинги: currentIndex привязан к свойству mode целевого объекта (через родителя).
 * Коннекты: внутренние обработчики для отрисовки индикатора.
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import TrafficLightUi 1.0

ComboBox {
    id: control

    implicitHeight: 26

    indicator: Item { } // Пустой элемент, ничего не рисуем

    // Настройка фона всплывающего списка
    popup.background: Rectangle {
        color: Theme.colorSurface
        border.color: Theme.colorBorder
        border.width: 1
        radius: Theme.radiusSmall
    }

    // Основной фон
    background: Rectangle {
        implicitWidth: 140
        implicitHeight: 26
        radius: Theme.radiusSmall
        color: control.enabled ? Theme.colorSurface : Theme.colorSurfaceAlt
        border.color: control.activeFocus ? Theme.colorAccent : Theme.colorBorder
        border.width: 1
    }

    // Отображаемый текст
    contentItem: Text {
        leftPadding: 8
        rightPadding: 8
        text: control.displayText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: control.enabled ? Theme.colorTextPrimary : Theme.colorTextSecondary
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // Кастомный делегат для пунктов списка
    delegate: ItemDelegate {
        width: control.width
        height: 26
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            text: modelData
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: highlighted ? Theme.colorTextPrimary : Theme.colorTextSecondary
            verticalAlignment: Text.AlignVCenter
            leftPadding: 8
        }

        background: Rectangle {
            color: highlighted ? Theme.colorAccentMuted : Theme.colorSurface
            radius: 0
        }
    }
}