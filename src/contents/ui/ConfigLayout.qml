import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_lyricsPosition: lyricsPosition.current
    property alias cfg_lyricsWidth: lyricsWidth.value
    property alias cfg_lyricsGap: lyricsGap.value
    property alias cfg_infoPosition: infoPosition.current
    property alias cfg_infoWidth: infoWidth.value
    property alias cfg_infoGap: infoGap.value
    property alias cfg_infoAlignment: infoAlignment.current
    property alias cfg_infoVerticalAlignment: infoVerticalAlignment.current
    property alias cfg_infoOverflow: infoOverflow.current

    Kirigami.FormLayout {
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Lyrics"
        }

        ChoiceBox {
            id: lyricsPosition
            Kirigami.FormData.label: "Position:"
            model: [
                { text: "Left of album art", value: "left" },
                { text: "Right of album art", value: "right" }
            ]
        }

        RowLayout {
            Kirigami.FormData.label: "Width:"
            SpinBox { id: lyricsWidth; from: 60; to: 3000; stepSize: 10 }
            Label { text: "px" }
        }

        ValueSlider {
            id: lyricsGap
            Kirigami.FormData.label: "Distance from art:"
            from: 0
            to: 300
            suffix: " px"
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Title and artist"
        }

        ChoiceBox {
            id: infoPosition
            Kirigami.FormData.label: "Position:"
            model: [
                { text: "Opposite side from lyrics", value: "opposite" },
                { text: "Left of album art", value: "left" },
                { text: "Right of album art", value: "right" }
            ]
        }

        RowLayout {
            Kirigami.FormData.label: "Width:"
            SpinBox { id: infoWidth; from: 40; to: 1000; stepSize: 10 }
            Label { text: "px" }
        }

        ValueSlider {
            id: infoGap
            Kirigami.FormData.label: "Distance from art:"
            from: 0
            to: 300
            suffix: " px"
        }

        ChoiceBox {
            id: infoAlignment
            Kirigami.FormData.label: "Text alignment:"
            model: [
                { text: "Toward album art", value: "auto" },
                { text: "Left", value: "left" },
                { text: "Center", value: "center" },
                { text: "Right", value: "right" }
            ]
        }

        ChoiceBox {
            id: infoVerticalAlignment
            Kirigami.FormData.label: "Vertical position:"
            model: [
                { text: "Middle of album art", value: "center" },
                { text: "Top of album art", value: "top" },
                { text: "Bottom of album art", value: "bottom" }
            ]
        }

        ChoiceBox {
            id: infoOverflow
            Kirigami.FormData.label: "Long titles:"
            model: [
                { text: "Scroll", value: "scroll" },
                { text: "Wrap onto two lines", value: "wrap" },
                { text: "Cut off with …", value: "elide" }
            ]
        }

        Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Widths stay reserved even when a song has no lyrics, so the album art never moves."
        }
    }
}
