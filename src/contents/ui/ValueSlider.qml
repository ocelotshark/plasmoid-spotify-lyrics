import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Slider with its value shown next to it.
RowLayout {
    id: valueSlider

    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to
    property string suffix: "%"
    property bool signed: false

    Slider {
        id: slider
        stepSize: 1
        snapMode: Slider.SnapAlways
        Layout.preferredWidth: Kirigami.Units.gridUnit * 9
    }
    Label {
        text: (valueSlider.signed && slider.value > 0 ? "+" : "") + Math.round(slider.value) + valueSlider.suffix
        Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
    }
}
