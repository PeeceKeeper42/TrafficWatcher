import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import TrafficLight 1.0

ApplicationWindow {
    visible: true
    width: 600
    height: 400
    title: "Светофор"

    // Создаём экземпляр модели светофора
    TrafficLight {
        id: trafficLight
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20

        // Левая панель — настройки
        ColumnLayout {
            spacing: 15
            Layout.fillWidth: true

            GroupBox {
                title: "Длительность (мс)"
                Layout.fillWidth: true

                GridLayout {
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 8

                    Label { text: "Красный:" }
                    SpinBox {
                        from: 500; to: 10000; stepSize: 500
                        value: trafficLight.redDuration
                        onValueChanged: trafficLight.redDuration = value
                    }
                    Label { text: "Красный+жёлтый:" }
                    SpinBox {
                        from: 500; to: 5000; stepSize: 500
                        value: trafficLight.redYellowDuration
                        onValueChanged: trafficLight.redYellowDuration = value
                    }
                    Label { text: "Зелёный:" }
                    SpinBox {
                        from: 1000; to: 20000; stepSize: 500
                        value: trafficLight.greenDuration
                        onValueChanged: trafficLight.greenDuration = value
                    }
                    Label { text: "Жёлтый:" }
                    SpinBox {
                        from: 500; to: 5000; stepSize: 500
                        value: trafficLight.yellowDuration
                        onValueChanged: trafficLight.yellowDuration = value
                    }
                }
            }

            RowLayout {
                spacing: 10
                Button {
                    text: "Старт"
                    onClicked: trafficLight.start()
                }
                Button {
                    text: "Стоп"
                    onClicked: trafficLight.stop()
                }
                Button {
                    text: "Следующий"
                    onClicked: trafficLight.nextState()
                }
            }

            // Отображение текущего состояния (для отладки)
            Label {
                text: {
                    var state = trafficLight.currentState;
                    var stateName;
                    if (state === TrafficLight.None) stateName = "Выключен";
                    else if (state === TrafficLight.Red) stateName = "Красный";
                    else if (state === TrafficLight.RedYellow) stateName = "Красный+Жёлтый";
                    else if (state === TrafficLight.Green) stateName = "Зелёный";
                    else if (state === TrafficLight.Yellow) stateName = "Жёлтый";
                    else stateName = "Неизвестно";
                    return "Состояние: " + stateName;
                }
                Layout.alignment: Qt.AlignLeft
            }
            Label {
                text: "Запущен: " + (trafficLight.isRunning ? "Да" : "Нет")
                Layout.alignment: Qt.AlignLeft
            }
        }

        // Справа — компонент светофора
        TrafficLightView {
            controller: trafficLight
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: 120
            Layout.preferredHeight: 360
        }
    }
}