import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_transparentBackground: transparentBackground.checked
    property alias cfg_wallpaperBlur: wallpaperBlur.current
    property alias cfg_wallpaperBlurStrength: wallpaperBlurStrength.value
    property alias cfg_wallpaperBlurTint: wallpaperBlurTint.value
    property alias cfg_wallpaperBlurTintColor: wallpaperBlurTintColor.color
    property alias cfg_wallpaperBlurSoftness: wallpaperBlurSoftness.value
    property alias cfg_wallpaperBlurPadding: wallpaperBlurPadding.value

    property alias cfg_textShadowLyrics: textShadowLyrics.checked
    property alias cfg_textShadowTitle: textShadowTitle.checked
    property alias cfg_textShadowArtist: textShadowArtist.checked
    property alias cfg_textShadowColorMode: textShadowColorMode.current
    property alias cfg_textShadowColor: textShadowColor.color
    property alias cfg_textShadowOpacity: textShadowOpacity.value
    property alias cfg_textShadowBlur: textShadowBlur.value
    property alias cfg_textShadowDistance: textShadowDistance.value
    property alias cfg_textShadowAngle: textShadowAngle.value

    readonly property bool anyShadow: textShadowLyrics.checked || textShadowTitle.checked || textShadowArtist.checked

    Kirigami.FormLayout {
        CheckBox {
            id: transparentBackground
            Kirigami.FormData.label: "Background:"
            text: "Transparent on desktop"
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Blur behind text"
        }

        ChoiceBox {
            id: wallpaperBlur
            Kirigami.FormData.label: "Blur wallpaper behind:"
            model: [
                { text: "Nothing", value: "off" },
                { text: "Lyrics", value: "lyrics" },
                { text: "Lyrics, title and artist", value: "all" }
            ]
        }

        ValueSlider {
            id: wallpaperBlurStrength
            enabled: wallpaperBlur.current !== "off"
            Kirigami.FormData.label: "Blur strength:"
            from: 0
            to: 100
        }

        ValueSlider {
            id: wallpaperBlurTint
            enabled: wallpaperBlur.current !== "off"
            Kirigami.FormData.label: "Tint:"
            from: 0
            to: 100
        }

        ColorButton {
            id: wallpaperBlurTintColor
            enabled: wallpaperBlur.current !== "off"
            Kirigami.FormData.label: "Tint color:"
        }

        ValueSlider {
            id: wallpaperBlurSoftness
            enabled: wallpaperBlur.current !== "off"
            Kirigami.FormData.label: "Edge softness:"
            from: 0
            to: 100
        }

        ValueSlider {
            id: wallpaperBlurPadding
            enabled: wallpaperBlur.current !== "off"
            Kirigami.FormData.label: "Space around text:"
            from: 0
            to: 100
            suffix: " px"
        }

        Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "A soft shape hugs the visible lyrics and glides with them as they scroll. Only works on the desktop (panels have no wallpaper behind them)."
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Text shadow"
        }

        CheckBox {
            id: textShadowLyrics
            Kirigami.FormData.label: "Apply to:"
            text: "Lyrics"
        }
        CheckBox {
            id: textShadowTitle
            text: "Title"
        }
        CheckBox {
            id: textShadowArtist
            text: "Artist"
        }

        ChoiceBox {
            id: textShadowColorMode
            enabled: anyShadow
            Kirigami.FormData.label: "Color:"
            model: [
                { text: "Custom", value: "custom" },
                { text: "Dark album color", value: "album" }
            ]
        }

        ColorButton {
            id: textShadowColor
            visible: textShadowColorMode.current === "custom"
            enabled: anyShadow
            Kirigami.FormData.label: "Shadow color:"
        }

        ValueSlider {
            id: textShadowOpacity
            enabled: anyShadow
            Kirigami.FormData.label: "Opacity:"
            from: 0
            to: 100
        }

        ValueSlider {
            id: textShadowBlur
            enabled: anyShadow
            Kirigami.FormData.label: "Softness:"
            from: 0
            to: 100
        }

        ValueSlider {
            id: textShadowDistance
            enabled: anyShadow
            Kirigami.FormData.label: "Distance:"
            from: 0
            to: 30
            suffix: " px"
        }

        ValueSlider {
            id: textShadowAngle
            enabled: anyShadow
            Kirigami.FormData.label: "Direction:"
            from: 0
            to: 359
            suffix: "°"
        }
    }
}
