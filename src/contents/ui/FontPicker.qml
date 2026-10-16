import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Font family button + pixel size spin box.
RowLayout {
    id: picker

    property string family
    property alias size: sizeBox.value
    property string dialogTitle: "Choose font"

    Button {
        text: picker.family.length > 0 ? picker.family : "System default"
        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
        onClicked: dialog.open()
    }
    SpinBox {
        id: sizeBox
        from: 6
        to: 72
    }
    Label {
        text: "px"
    }
    Button {
        icon.name: "edit-undo"
        visible: picker.family.length > 0
        display: AbstractButton.IconOnly
        text: "Use system font"
        ToolTip.text: text
        ToolTip.visible: hovered
        onClicked: picker.family = ""
    }
    FontDialog {
        id: dialog
        title: picker.dialogTitle
        selectedFont: Qt.font({ family: picker.family || Kirigami.Theme.defaultFont.family, pixelSize: sizeBox.value })
        onAccepted: picker.family = selectedFont.family
    }
}
