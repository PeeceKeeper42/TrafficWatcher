/**
 * @file StyledButton.qml
 * @brief Универсальная стилизованная кнопка.
 *
 * @property text            - текст кнопки
 * @property backgroundColor - цвет фона (по умолчанию Theme.colorSurfaceAlt)
 * @property textColor       - цвет текста (по умолчанию Theme.colorTextPrimary)
 * @property borderColor     - цвет рамки (по умолчанию Theme.colorBorder)
 * @property implicitWidth   - ширина (по умолчанию 130)
 * @property implicitHeight  - высота (по умолчанию 36)
 * @property enabled         - доступность
 *
 * @signal clicked()         - испускается при нажатии
 *
 * Биндинги: backgroundColor, textColor могут динамически меняться (например, для кнопки "Остановить").
 * Коннекты: MouseArea внутри.
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import TrafficLightUi 1.0

Button {
    id: control

    property color backgroundColor: Theme.colorSurfaceAlt
    property color textColor: Theme.colorTextPrimary
    property color borderColor: Theme.colorBorder

    implicitWidth: 130
    implicitHeight: 36

    contentItem: Text {
        text: control.text
        color: control.textColor
        font.family: Theme.fontFamily
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: control.enabled ? 1.0 : 0.5
    }

    background: Rectangle {
        radius: Theme.radiusSmall
        color: control.backgroundColor
        border.color: control.borderColor
        border.width: 1
        opacity: control.enabled ? 1.0 : 0.5
    }
}