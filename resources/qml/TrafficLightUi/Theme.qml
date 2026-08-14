/**
 * @file Theme.qml
 * @brief Синглтон с настройками темы оформления.
 * @details Единая точка правды для цветов, отступов, радиусов и шрифтов.
 *          Доступен во всех QML-файлах как `Theme.colorBackground`, `Theme.spacingMedium` и т.д.
 *          Все свойства только для чтения.
 */

pragma Singleton
import QtQuick 2.15

QtObject {
    readonly property color colorBackground:      "#1B1E27"
    readonly property color colorSurface:         "#242836"
    readonly property color colorSurfaceAlt:      "#2C3142"
    readonly property color colorBorder:          "#3A3F52"
    readonly property color colorTextPrimary:     "#F2F3F7"
    readonly property color colorTextSecondary:   "#9AA0B4"
    readonly property color colorAccent:          "#4C8DFF"
    readonly property color colorAccentMuted:     "#31456E"
    readonly property color colorDanger:          "#E5484D"
    readonly property color colorDangerMuted:     "#3A2529"

    readonly property color colorRed:             "#E5484D"
    readonly property color colorYellow:          "#F5A623"
    readonly property color colorGreen:           "#3DD68C"
    readonly property color colorLampOff:         "#3A3F4C"

    readonly property int radiusSmall:  6
    readonly property int radiusMedium: 10
    readonly property int radiusLarge:  18

    readonly property int spacingTiny:   4
    readonly property int spacingSmall:  8
    readonly property int spacingMedium: 16
    readonly property int spacingLarge:  24

    readonly property string fontFamily: "Segoe UI"
    readonly property int fontSizeSmall:  12
    readonly property int fontSizeBody:   14
    readonly property int fontSizeTitle:  18
}
