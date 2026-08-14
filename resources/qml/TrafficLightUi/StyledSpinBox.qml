/**
 * @file StyledSpinBox.qml
 * @brief Стилизованный счётчик для тёмной темы.
 *
 * @property from           - минимальное значение (мс)
 * @property to             - максимальное значение (мс)
 * @property stepSize       - шаг изменения (мс)
 * @property value          - текущее значение (биндится к TrafficLightMode.duration)
 * @property enabled        - доступность контрола
 * @property textFromValue  - функция форматирования отображаемого текста
 * @property valueFromText  - функция парсинга текста в значение
 *
 * @signal valueModified()  - испускается при изменении значения (запись в модель)
 *
 * Биндинги: value привязан к duration целевого объекта.
 * Коннекты: внутренние обработчики для кнопок и редактирования текста.
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import TrafficLightUi 1.0

SpinBox {
    id: control

    implicitHeight: 26
    editable: true

    // Фон
    background: Rectangle {
        implicitWidth: 140
        implicitHeight: 26
        radius: Theme.radiusSmall
        color: control.enabled ? Theme.colorSurface : Theme.colorSurfaceAlt
        border.color: control.activeFocus ? Theme.colorAccent : Theme.colorBorder
        border.width: 1
    }

    // Редактируемый текст
    contentItem: TextInput {
        z: 2
        text: control.textFromValue(control.value, control.locale)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: control.enabled ? Theme.colorTextPrimary : Theme.colorTextSecondary
        selectionColor: Theme.colorAccentMuted
        selectedTextColor: Theme.colorTextPrimary
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        onTextEdited: {
            var newVal = control.valueFromText(text, control.locale)
            if (newVal !== undefined)
                control.value = newVal
        }
    }

    // Кнопка "вверх"
    up.indicator: Rectangle {
        x: parent.width - width
        y: 0
        width: 26
        height: parent.height / 2
        color: control.up.pressed ? Theme.colorAccentMuted : Theme.colorSurfaceAlt
        border.color: Theme.colorBorder
        border.width: 1
        radius: 0
        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 4
            color: control.enabled ? Theme.colorTextSecondary : Theme.colorTextSecondary
            opacity: 0.7
            radius: 1
        }
    }

    // Кнопка "вниз"
    down.indicator: Rectangle {
        x: parent.width - width
        y: parent.height / 2
        width: 26
        height: parent.height / 2
        color: control.down.pressed ? Theme.colorAccentMuted : Theme.colorSurfaceAlt
        border.color: Theme.colorBorder
        border.width: 1
        radius: 0
        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 4
            color: control.enabled ? Theme.colorTextSecondary : Theme.colorTextSecondary
            opacity: 0.7
            radius: 1
        }
    }
}