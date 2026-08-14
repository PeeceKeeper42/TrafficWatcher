/**
 * @file StateEditor.qml
 * @brief Редактор выбранного состояния: имя + три цветных канала.
 *
 * @property stateObject – указатель на TrafficLightState (редактируемое состояние)
 *
 * @readonly property hasState – true, если состояние существует
 *
 * Биндинги:
 *   - TextField.text ↔ stateObject.name (двусторонняя связь через onEditingFinished)
 *   - каждый LightModeEditor получает соответствующий канал (redMode, yellowMode, greenMode)
 *   - видимость подсказки зависит от hasState
 * Коннекты:
 *   - onEditingFinished – запись имени в модель
 *   - LightModeEditor сам обновляет mode и duration
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import TrafficLight 1.0
import TrafficLightUi 1.0

ColumnLayout {
    id: editor

    property TrafficLightState stateObject: null
    readonly property bool hasState: stateObject !== null

    spacing: Theme.spacingTiny

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingTiny

        Label {
            text: qsTr("Имя состояния:")
            color: Theme.colorTextSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
        }
        TextField {
            id: nameField
            Layout.fillWidth: true
            enabled: editor.hasState
            placeholderText: editor.hasState ? "" : qsTr("Нет выбранного состояния")
            text: editor.hasState ? editor.stateObject.name : ""
            color: Theme.colorTextPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            implicitHeight: 26

            background: Rectangle {
                radius: Theme.radiusSmall
                color: Theme.colorSurfaceAlt
                border.color: nameField.activeFocus ? Theme.colorAccent : Theme.colorBorder
                border.width: 1
            }

            onEditingFinished: {
                if (editor.hasState && text !== editor.stateObject.name)
                    editor.stateObject.name = text
            }
        }
    }

    LightModeEditor {
        Layout.fillWidth: true
        titleText: qsTr("Красный")
        accentColor: Theme.colorRed
        target: editor.hasState ? editor.stateObject.redMode : null
    }

    LightModeEditor {
        Layout.fillWidth: true
        titleText: qsTr("Жёлтый")
        accentColor: Theme.colorYellow
        target: editor.hasState ? editor.stateObject.yellowMode : null
    }

    LightModeEditor {
        Layout.fillWidth: true
        titleText: qsTr("Зелёный")
        accentColor: Theme.colorGreen
        target: editor.hasState ? editor.stateObject.greenMode : null
    }

    Label {
        Layout.fillWidth: true
        visible: !editor.hasState
        text: qsTr("Добавьте состояние или выберите его в списке, чтобы редактировать")
        color: Theme.colorTextSecondary
        font.family: Theme.fontFamily
        font.italic: true
        wrapMode: Text.WordWrap
    }
}