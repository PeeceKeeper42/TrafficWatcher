/**
 * @file TrafficLightDisplay.qml
 * @brief Визуальное представление корпуса светофора.
 *
 * @property controller – указатель на TrafficLight (источник данных)
 *
 * Биндинги:
 *   - каждая лампа получает mode, isActive, blinkPhase, isRunning из controller
 *   - размеры корпуса адаптируются к родителю
 */

import QtQuick 2.15
import TrafficLightUi 1.0
import TrafficLight 1.0

Item {
    id: root
    property TrafficLight controller: null

    Rectangle {
        id: housing
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.7, 140)
        height: Math.min(parent.height * 0.9, 380)
        radius: Theme.radiusLarge
        color: "#14161E"
        border.color: Theme.colorBorder
        border.width: 2

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.5
            radius: parent.radius
            color: "white"
            opacity: 0.02
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingMedium

            Repeater {
                model: [
                    { color: Theme.colorRed,   mode: controller && controller.currentState ? controller.currentState.redMode : null },
                    { color: Theme.colorYellow, mode: controller && controller.currentState ? controller.currentState.yellowMode : null },
                    { color: Theme.colorGreen,  mode: controller && controller.currentState ? controller.currentState.greenMode : null }
                ]

                LightBulb {
                    anchors.horizontalCenter: parent.horizontalCenter
                    baseColor: modelData.color
                    mode: modelData.mode ? modelData.mode.mode : TrafficLightMode.Off
                    isActive: modelData.mode ? modelData.mode.active : false
                    blinkPhase: controller ? controller.blinkPhase : false
                    isRunning: controller ? controller.isRunning : false
                }
            }
        }
    }
}