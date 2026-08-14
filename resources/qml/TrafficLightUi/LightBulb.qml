/**
 * @file LightBulb.qml
 * @brief Отдельная лампа светофора: круг с обводкой, свечением и анимацией затухания.
 *
 * @property baseColor   – цвет лампы в включённом состоянии (красный/жёлтый/зелёный)
 * @property mode        – режим работы (Off/On/Blink), биндится к TrafficLightMode.mode
 * @property blinkPhase  – фаза мигания (true/false), биндится к TrafficLight.blinkPhase
 * @property isRunning   – запущен ли светофор, биндится к TrafficLight.isRunning
 * @property isActive    – активен ли канал (отсчитывает своё время), биндится к TrafficLightMode.active
 *
 * @readonly property lit – вычисляется на основе всех свойств; определяет, горит ли лампа сейчас
 * @readonly property activeColor – цвет лампы (либо baseColor, либо Theme.colorLampOff)
 *
 * Биндинги:
 *   - lit зависит от isRunning, mode, isActive, blinkPhase
 *   - activeColor зависит от lit
 *   - внешнее свечение (Rectangle с gradient) и сама лампа используют lit и activeColor
 * Коннекты: Behavior на opacity и color для анимации.
 */

import QtQuick 2.15
import TrafficLightUi 1.0
import TrafficLight 1.0

Item {
    id: bulb

    property color baseColor: Theme.colorLampOff
    property int mode: TrafficLightMode.Off
    property bool blinkPhase: false
    property bool isRunning: false
    property bool isActive: false

    readonly property bool lit: {
        if (!isRunning || mode === TrafficLightMode.Off || !isActive)
            return false
        if (mode === TrafficLightMode.On)
            return true
        if (mode === TrafficLightMode.Blink)
            return blinkPhase
        return false
    }

    readonly property color activeColor: lit ? baseColor : Theme.colorLampOff

    implicitWidth: 84
    implicitHeight: 84

    // Внешнее свечение
    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 26
        height: width
        radius: width / 2
        color: "transparent"
        opacity: bulb.lit ? 0.35 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        gradient: Gradient {
            GradientStop { position: 0.0; color: bulb.baseColor }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Сама лампа
    Rectangle {
        id: glass
        anchors.fill: parent
        radius: width / 2
        color: bulb.activeColor
        border.color: Theme.colorBorder
        border.width: 2

        Behavior on color { ColorAnimation { duration: 100 } }

        // Блик для "стеклянности"
        Rectangle {
            width: parent.width * 0.4
            height: parent.height * 0.25
            radius: height / 2
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.14
            anchors.horizontalCenter: parent.horizontalCenter
            color: "white"
            opacity: 0.18
        }
    }
}