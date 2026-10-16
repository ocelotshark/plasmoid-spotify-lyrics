import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_playerIdentity: playerIdentity.text
    property alias cfg_volumeStep: volumeStep.value

    Kirigami.FormLayout {
        TextField {
            id: playerIdentity
            Kirigami.FormData.label: "Player identity:"
            placeholderText: "Any player (prefer Spotify)"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        }

        SpinBox {
            id: volumeStep
            Kirigami.FormData.label: "Scroll volume step:"
            from: 1
            to: 20
            textFromValue: value => value + "%"
        }
    }
}
