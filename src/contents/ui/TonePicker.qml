import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Brightness and opacity for one kind of text.
ColumnLayout {
    property alias brightness: brightnessSlider.value
    property alias opacityPercent: opacitySlider.value

    spacing: 0

    RowLayout {
        Label {
            text: "Brightness"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 4.5
        }
        ValueSlider {
            id: brightnessSlider
            from: -100
            to: 100
            signed: true
        }
    }
    RowLayout {
        Label {
            text: "Opacity"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 4.5
        }
        ValueSlider {
            id: opacitySlider
            from: 0
            to: 100
        }
    }
}
