import QtQuick
import QtQuick.Controls

// Combo box bound to a string config value via `current`.
ComboBox {
    property string current

    implicitContentWidthPolicy: ComboBox.WidestText
    textRole: "text"
    valueRole: "value"
    onCurrentChanged: currentIndex = Math.max(0, indexOfValue(current))
    onModelChanged: currentIndex = Math.max(0, indexOfValue(current))
    Component.onCompleted: currentIndex = Math.max(0, indexOfValue(current))
    onActivated: current = currentValue
}
