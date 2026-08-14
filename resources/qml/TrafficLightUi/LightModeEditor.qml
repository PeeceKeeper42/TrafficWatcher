/**
 * @file LightModeEditor.qml
 * @brief Редактор одного канала (цвета) светофора.
 *
 * @property target      - указатель на TrafficLightMode (редактируемый канал)
 * @property accentColor - цвет названия (красный/жёлтый/зелёный)
 * @property titleText   - текст названия
 *
 * Биндинги:
 *   - ComboBox.currentIndex ↔ target.mode
 *   - SpinBox.value ↔ target.duration
 *   - enabled зависит от наличия target и выбранного режима
 * Коннекты:
 *   - onActivated → запись mode в target
 *   - onValueModified → запись duration в target
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import TrafficLight 1.0
import TrafficLightUi 1.0

GroupBox {
    id: root

    property TrafficLightMode target: null
    property color accentColor: Theme.colorAccent
    property string titleText: ""

    readonly property bool hasTarget: target !== null
    readonly property var modeValues: [TrafficLightMode.Off, TrafficLightMode.On, TrafficLightMode.Blink]

    background: Rectangle {
        radius: Theme.radiusSmall
        color: Theme.colorSurfaceAlt
        border.color: Theme.colorBorder
        border.width: 1
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingTiny
        spacing: Theme.spacingTiny

        Label {
            text: root.titleText
            color: root.accentColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
            font.bold: true
            Layout.preferredWidth: 80
            Layout.alignment: Qt.AlignVCenter
        }

        Label {
            text: qsTr("Режим:")
            color: Theme.colorTextSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            Layout.preferredWidth: 55
            Layout.alignment: Qt.AlignVCenter
        }

        StyledComboBox {
            id: modeCombo
            Layout.preferredWidth: 140
            Layout.alignment: Qt.AlignVCenter
            enabled: root.hasTarget
            model: [qsTr("Выкл"), qsTr("Вкл"), qsTr("Мигает")]
            currentIndex: root.hasTarget ? root.modeValues.indexOf(root.target.mode) : 0

            onActivated: {
                if (root.hasTarget)
                    root.target.mode = root.modeValues[currentIndex]
            }
        }

        Label {
            text: qsTr("Длительность:")
            color: Theme.colorTextSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            Layout.preferredWidth: 90
            Layout.alignment: Qt.AlignVCenter
        }

        StyledSpinBox {
            id: durationSpin
            Layout.preferredWidth: 140
            Layout.alignment: Qt.AlignVCenter
            from: 0
            to: 60000
            stepSize: 500
            enabled: root.hasTarget && modeCombo.currentIndex !== 0
            value: root.hasTarget ? root.target.duration : 0
            textFromValue: function(value) { return (value / 1000).toFixed(1) + " s" }
            valueFromText: function(text) { return Math.round(parseFloat(text) * 1000) }

            onValueModified: {
                if (root.hasTarget)
                    root.target.duration = value
            }
        }

        Item { Layout.fillWidth: true }
    }
}