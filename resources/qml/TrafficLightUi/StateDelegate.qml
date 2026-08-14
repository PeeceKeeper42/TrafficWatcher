/**
 * @file StateDelegate.qml
 * @brief Делегат для отображения состояния в списке.
 * @details Отображает имя состояния и мини-индикаторы каналов (цвет, режим, длительность).
 *          При клике испускает сигнал selected.
 * @property bool highlight - выделен ли элемент (текущий выбранный).
 * @signal selected() - испускается при нажатии на делегат.
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import TrafficLightUi 1.0
import TrafficLight 1.0

Rectangle {
    id: delegateRoot

    width: ListView.view ? ListView.view.width : 0
    height: 64
    radius: Theme.radiusSmall
    color: highlight ? Theme.colorAccentMuted : Theme.colorSurface
    border.color: highlight ? Theme.colorAccent : Theme.colorBorder
    border.width: highlight ? 2 : 1

    property bool highlight: false
    signal selected()

    readonly property TrafficLightState state: model.stateObject

    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMedium
        anchors.rightMargin: Theme.spacingMedium
        spacing: Theme.spacingMedium

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 120
            text: delegateRoot.state ? delegateRoot.state.name : qsTr("Состояние %1").arg(index + 1)
            color: Theme.colorTextPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
            font.bold: delegateRoot.highlight
            elide: Text.ElideRight
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSmall
            Repeater {
                model: [
                    { color: Theme.colorRed,   mode: delegateRoot.state ? delegateRoot.state.redMode : null },
                    { color: Theme.colorYellow, mode: delegateRoot.state ? delegateRoot.state.yellowMode : null },
                    { color: Theme.colorGreen,  mode: delegateRoot.state ? delegateRoot.state.greenMode : null }
                ]
                StateDelegateIndicator {
                    lampColor: modelData.color
                    target: modelData.mode
                }
            }
        }
    }

    // MouseArea только для клика
    MouseArea {
        id: clickArea
        anchors.fill: parent
        onClicked: delegateRoot.selected()
    }
}