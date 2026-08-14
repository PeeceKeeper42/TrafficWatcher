/**
 * @file main.qml
 * @brief Главное окно приложения.
 * @details Содержит контроллер TrafficLight, список состояний, редактор и визуализацию светофора.
 *          Управляет взаимодействием между моделью, представлением и контроллером.
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import TrafficLight 1.0
import TrafficLightUi 1.0

ApplicationWindow {
    id: window
    visible: true
    width: 1080
    height: 780
    minimumWidth: 760
    minimumHeight: 780
    title: qsTr("Светофор")
    color: Theme.colorBackground

    TrafficLight { id: trafficLight }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingLarge
        spacing: Theme.spacingLarge

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacingMedium

            // Панель управления
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                StyledButton {
                    text: trafficLight.isRunning ? qsTr("Остановить") : qsTr("Запустить")
                    backgroundColor: trafficLight.isRunning ? Theme.colorDanger : Theme.colorAccent
                    textColor: "white"
                    borderColor: "transparent"
                    onClicked: trafficLight.isRunning ? trafficLight.stop() : trafficLight.start()
                }

                StyledButton {
                    text: qsTr("Добавить состояние")
                    onClicked: trafficLight.states.addState()
                }

                StyledButton {
                    text: qsTr("Удалить выбранное")
                    enabled: trafficLight.currentIndex >= 0
                    onClicked: trafficLight.states.removeState(trafficLight.currentIndex)
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: qsTr("Текущее: %1").arg(trafficLight.currentState ? trafficLight.currentState.name : qsTr("нет"))
                    color: Theme.colorTextSecondary
                    font.family: Theme.fontFamily
                }
            }

            // Список состояний
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height * 0.55
                radius: Theme.radiusMedium
                color: Theme.colorSurface
                border.color: Theme.colorBorder
                border.width: 1

                ListView {
                    id: listView
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSmall
                    spacing: Theme.spacingTiny
                    clip: true
                    model: trafficLight.states
                    currentIndex: trafficLight.currentIndex

                    delegate: StateDelegate {
                        highlight: trafficLight.currentIndex === index
                        onSelected: trafficLight.currentIndex = index
                    }

                    ScrollBar.vertical: ScrollBar { }

                    Label {
                        anchors.centerIn: parent
                        visible: listView.count === 0
                        text: qsTr("Состояний пока нет.\nНажмите «Добавить состояние»")
                        color: Theme.colorTextSecondary
                        font.family: Theme.fontFamily
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Редактор состояния
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMedium
                color: Theme.colorSurface
                border.color: Theme.colorBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMedium
                    spacing: Theme.spacingSmall

                    Label {
                        text: qsTr("Редактор состояния")
                        color: Theme.colorTextPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeTitle
                        font.bold: true
                    }

                    StateEditor {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        stateObject: trafficLight.currentState
                    }
                }
            }
        }

        // Светофор
        Rectangle {
            Layout.preferredWidth: window.width / 5
            Layout.fillHeight: true
            Layout.minimumWidth: 140
            radius: Theme.radiusMedium
            color: Theme.colorSurface
            border.color: Theme.colorBorder
            border.width: 1

            TrafficLightDisplay {
                anchors.fill: parent
                anchors.margins: Theme.spacingSmall
                controller: trafficLight
            }
        }
    }
}