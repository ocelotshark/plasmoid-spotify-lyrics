import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Color swatch that opens a color dialog. `color` is a "#rrggbb" string.
RowLayout {
    id: colorButton

    property string color: "#ffffff"
    property string dialogTitle: "Choose color"

    Rectangle {
        opacity: colorButton.enabled ? 1 : 0.4
        implicitWidth: Kirigami.Units.gridUnit * 2
        implicitHeight: Kirigami.Units.gridUnit
        radius: Kirigami.Units.cornerRadius
        color: colorButton.color
        border.color: Kirigami.Theme.textColor
        border.width: 1

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: dialog.open()
        }
    }
    Label {
        text: colorButton.color
        opacity: 0.7
    }
    ColorDialog {
        id: dialog
        title: colorButton.dialogTitle
        selectedColor: colorButton.color
        onAccepted: colorButton.color = selectedColor.toString()
    }
}
