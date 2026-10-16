import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showTitle: showTitle.checked
    property alias cfg_titleFontSize: titleFont.size
    property alias cfg_titleFontFamily: titleFont.family
    property alias cfg_titleColorMode: titleColorMode.current
    property alias cfg_titleTextColor: titleColor.color
    property alias cfg_titleBrightness: titleTone.brightness
    property alias cfg_titleOpacity: titleTone.opacityPercent
    property alias cfg_titleEffect: titleEffect.current
    property alias cfg_showArtist: showArtist.checked
    property alias cfg_artistFontSize: artistFont.size
    property alias cfg_artistFontFamily: artistFont.family
    property alias cfg_artistColorMode: artistColorMode.current
    property alias cfg_artistTextColor: artistColor.color
    property alias cfg_artistBrightness: artistTone.brightness
    property alias cfg_artistOpacity: artistTone.opacityPercent
    property alias cfg_artistEffect: artistEffect.current
    property alias cfg_infoEffectIntensity: infoEffectIntensity.value

    Kirigami.FormLayout {
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Title"
        }

        CheckBox {
            id: showTitle
            Kirigami.FormData.label: "Title:"
            text: "Show title"
        }

        FontPicker {
            id: titleFont
            enabled: showTitle.checked
            Kirigami.FormData.label: "Font:"
            dialogTitle: "Choose title font"
        }

        ChoiceBox {
            id: titleColorMode
            enabled: showTitle.checked
            Kirigami.FormData.label: "Color:"
            model: [
                { text: "Theme text color", value: "theme" },
                { text: "From album art", value: "album" },
                { text: "Custom", value: "custom" }
            ]
        }

        ColorButton {
            id: titleColor
            visible: titleColorMode.current === "custom"
            enabled: showTitle.checked
            Kirigami.FormData.label: "Custom color:"
        }

        TonePicker {
            id: titleTone
            enabled: showTitle.checked
            Kirigami.FormData.label: "Text:"
        }

        ChoiceBox {
            id: titleEffect
            enabled: showTitle.checked
            Kirigami.FormData.label: "Effect:"
            model: [
                { text: "None", value: "none" },
                { text: "Glow", value: "glow" },
                { text: "Neon flicker", value: "neon" },
                { text: "Pulse", value: "pulse" },
                { text: "Breathe", value: "breathe" },
                { text: "Float", value: "float" },
                { text: "Shimmer", value: "shimmer" },
                { text: "Rainbow", value: "rainbow" },
                { text: "Album color gradient", value: "gradient" },
                { text: "Color shift", value: "colorshift" },
                { text: "Outline", value: "outline" },
                { text: "Glitch", value: "glitch" }
            ]
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Artist"
        }

        CheckBox {
            id: showArtist
            Kirigami.FormData.label: "Artist:"
            text: "Show artist"
        }

        FontPicker {
            id: artistFont
            enabled: showArtist.checked
            Kirigami.FormData.label: "Font:"
            dialogTitle: "Choose artist font"
        }

        ChoiceBox {
            id: artistColorMode
            enabled: showArtist.checked
            Kirigami.FormData.label: "Color:"
            model: [
                { text: "Theme text color", value: "theme" },
                { text: "From album art", value: "album" },
                { text: "Custom", value: "custom" }
            ]
        }

        ColorButton {
            id: artistColor
            visible: artistColorMode.current === "custom"
            enabled: showArtist.checked
            Kirigami.FormData.label: "Custom color:"
        }

        TonePicker {
            id: artistTone
            enabled: showArtist.checked
            Kirigami.FormData.label: "Text:"
        }

        ChoiceBox {
            id: artistEffect
            enabled: showArtist.checked
            Kirigami.FormData.label: "Effect:"
            model: [
                { text: "None", value: "none" },
                { text: "Glow", value: "glow" },
                { text: "Neon flicker", value: "neon" },
                { text: "Pulse", value: "pulse" },
                { text: "Breathe", value: "breathe" },
                { text: "Float", value: "float" },
                { text: "Shimmer", value: "shimmer" },
                { text: "Rainbow", value: "rainbow" },
                { text: "Album color gradient", value: "gradient" },
                { text: "Color shift", value: "colorshift" },
                { text: "Outline", value: "outline" },
                { text: "Glitch", value: "glitch" }
            ]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        ValueSlider {
            id: infoEffectIntensity
            enabled: titleEffect.current !== "none" || artistEffect.current !== "none"
            Kirigami.FormData.label: "Effect intensity:"
            from: 0
            to: 100
        }

        Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Album colors: the title uses the cover's main color and the artist its second color."
        }
    }
}
