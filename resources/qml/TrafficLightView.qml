import QtQuick 2.15
import TrafficLight 1.0

Item {
    id: root
    property TrafficLight controller

    // Размеры кругов
    readonly property int lightSize: 60
    readonly property int spacing: 12

    width: lightSize + 20
    height: lightSize * 3 + spacing * 2 + 20

    // Рамка светофора
    Rectangle {
        anchors.fill: parent
        color: "#2c2c2c"
        radius: 10
        border.color: "#555"
        border.width: 2
    }

    Column {
        anchors.centerIn: parent
        spacing: root.spacing

        // Красный
        Rectangle {
            width: root.lightSize
            height: root.lightSize
            radius: root.lightSize / 2
            color: (controller.currentState === TrafficLight.Red ||
                    controller.currentState === TrafficLight.RedYellow) ? "#ff3b30" : "#444"
            border.color: "#888"
            border.width: 1
            // Лёгкое свечение при включении
            layer.enabled: true
            layer.effect: GlowEffect {
                color: parent.color
                strength: 0.5
                visible: parent.color !== "#444"
            }
        }

        // Жёлтый
        Rectangle {
            width: root.lightSize
            height: root.lightSize
            radius: root.lightSize / 2
            color: (controller.currentState === TrafficLight.RedYellow ||
                    controller.currentState === TrafficLight.Yellow) ? "#ffcc00" : "#444"
            border.color: "#888"
            border.width: 1
            layer.enabled: true
            layer.effect: GlowEffect {
                color: parent.color
                strength: 0.5
                visible: parent.color !== "#444"
            }
        }

        // Зелёный
        Rectangle {
            width: root.lightSize
            height: root.lightSize
            radius: root.lightSize / 2
            color: (controller.currentState === TrafficLight.Green) ? "#34c759" : "#444"
            border.color: "#888"
            border.width: 1
            layer.enabled: true
            layer.effect: GlowEffect {
                color: parent.color
                strength: 0.5
                visible: parent.color !== "#444"
            }
        }
    }

    // Компонент эффекта свечения (можно вынести в отдельный файл, но здесь для простоты)
    component GlowEffect : Item {
        property color color
        property real strength: 0.5
        visible: false
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: parent.radius
            border.color: parent.color
            border.width: 3
            opacity: parent.strength
            visible: parent.visible
        }
    }
}