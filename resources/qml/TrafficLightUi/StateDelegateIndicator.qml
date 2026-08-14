/**
 * @file StateDelegateIndicator.qml
 * @brief Маленький чип внутри строки списка состояний: цвет + режим + длительность.
 *
 * @property lampColor – цвет индикатора (красный/жёлтый/зелёный)
 * @property target    – указатель на TrafficLightMode (источник данных)
 *
 * @readonly property mode       – текущий режим (Off/On/Blink), берётся из target
 * @readonly property durationMs – длительность в мс, берётся из target
 *
 * Биндинги:
 *   - цвет фона зависит от mode
 *   - вертикальная полоса слева показывает lampColor, если режим не Off
 *   - текст отображает длительность и символ молнии для режима Blink
 * Коннекты: (нет внешних, только внутренние вычисления)
 */

import QtQuick 2.15
import TrafficLightUi 1.0
import TrafficLight 1.0

Rectangle {
    id: chip
    width: 44
    height: 30
    radius: Theme.radiusSmall
    border.width: 1
    border.color: Theme.colorBorder

    property color lampColor: Theme.colorLampOff
    property TrafficLightMode target: null

    readonly property int mode: target ? target.mode : TrafficLightMode.Off
    readonly property int durationMs: target ? target.duration : 0

    color: mode === TrafficLightMode.Off ? Theme.colorSurfaceAlt : Qt.darker(lampColor, 2.4)

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 4
        width: 4
        radius: 2
        color: chip.mode === TrafficLightMode.Off ? Theme.colorLampOff : chip.lampColor
    }

    Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 3
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.colorTextPrimary
        text: {
            if (chip.mode === TrafficLightMode.Off) return qsTr("—")
            var seconds = (chip.durationMs / 1000).toFixed(1)
            return chip.mode === TrafficLightMode.Blink ? seconds + "s ↯" : seconds + "s"
        }
    }
}