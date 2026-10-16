import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showAlbumCover: showAlbumCover.checked
    property alias cfg_artCornerRadius: artCornerRadius.value
    property alias cfg_showProgressBar: showProgressBar.checked
    property alias cfg_showHoverControls: showHoverControls.checked
    property alias cfg_artBorderEffect: artBorderEffect.current
    property alias cfg_artBorderPlacement: artBorderPlacement.current
    property alias cfg_artBorderReactive: artBorderReactive.checked
    property alias cfg_artBorderWidth: artBorderWidth.value
    property alias cfg_artBorderSpeed: artBorderSpeed.value
    property alias cfg_artBorderIntensity: artBorderIntensity.value
    property alias cfg_artBorderColorMode: artBorderColorMode.current
    property alias cfg_artBorderColor: artBorderColor.color
    property alias cfg_artBorderColor2: artBorderColor2.color
    property alias cfg_fetchAlbumCoverHttps: fetchAlbumCoverHttps.checked

    Kirigami.FormLayout {
        CheckBox {
            id: showAlbumCover
            Kirigami.FormData.label: "Album art:"
            text: "Show album art"
        }

        ValueSlider {
            id: artCornerRadius
            enabled: showAlbumCover.checked
            Kirigami.FormData.label: "Corner rounding:"
            from: 0
            to: 50
        }

        CheckBox {
            id: showProgressBar
            enabled: showAlbumCover.checked
            Kirigami.FormData.label: "Overlays:"
            text: "Song progress bar"
        }

        CheckBox {
            id: showHoverControls
            enabled: showAlbumCover.checked
            text: "Playback controls on hover"
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Border"
        }

        ChoiceBox {
            id: artBorderEffect
            enabled: showAlbumCover.checked
            Kirigami.FormData.label: "Effect:"
            model: [
                { text: "None", value: "none" },
                { text: "Solid", value: "solid" },
                { text: "Pulse", value: "pulse" },
                { text: "Glow", value: "glow" },
                { text: "Breathing glow", value: "breathe" },
                { text: "Rotating gradient", value: "gradient" },
                { text: "Rainbow", value: "rainbow" },
                { text: "Neon flicker", value: "neon" },
                { text: "Heartbeat", value: "heartbeat" },
                { text: "Color cycle", value: "colorcycle" },
                { text: "Shine sweep", value: "shine" },
                { text: "Ripple", value: "ripple" },
                { text: "Sparkle", value: "sparkle" },
                { text: "Song progress ring", value: "progress" },
                { text: "Aurora halo", value: "aurora" },
                { text: "Glitch", value: "glitch" },
                { text: "Double ring", value: "double" },
                { text: "Music: spectrum bars", value: "spectrum" },
                { text: "Music: wave outline", value: "waveline" },
                { text: "Music: equalizer", value: "eq" },
                { text: "Music: bass ring", value: "bassring" },
                { text: "Music: beat ripples", value: "beatripple" },
                { text: "Music: beat sparks", value: "sparks" },
                { text: "Music: loudness glow", value: "levelglow" },
                { text: "Music: bass bloom", value: "bloom" }
            ]
        }

        ChoiceBox {
            id: artBorderPlacement
            enabled: showAlbumCover.checked && artBorderEffect.current !== "none"
                && ["shine", "sparkle"].indexOf(artBorderEffect.current) < 0
            Kirigami.FormData.label: "Placement:"
            model: [
                { text: "Outside the art", value: "outer" },
                { text: "Inside the art's edge", value: "inner" }
            ]
        }

        CheckBox {
            id: artBorderReactive
            readonly property bool isVisualizer: artBorderEffect.current.length > 0
                && ["spectrum", "waveline", "eq", "bassring", "beatripple", "sparks", "levelglow", "bloom"].indexOf(artBorderEffect.current) >= 0
            enabled: showAlbumCover.checked && artBorderEffect.current !== "none" && !isVisualizer
            Kirigami.FormData.label: "Music:"
            text: isVisualizer ? "Always follows the music" : "React to the music playing"
        }

        Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Music effects listen to your system's audio output through cava, which must be installed (it is)."
        }

        ValueSlider {
            id: artBorderWidth
            enabled: showAlbumCover.checked && artBorderEffect.current !== "none"
            Kirigami.FormData.label: "Thickness:"
            from: 1
            to: 16
            suffix: " px"
        }

        ValueSlider {
            id: artBorderSpeed
            enabled: showAlbumCover.checked && artBorderEffect.current !== "none"
            Kirigami.FormData.label: "Speed:"
            from: 10
            to: 400
        }

        ValueSlider {
            id: artBorderIntensity
            enabled: showAlbumCover.checked && artBorderEffect.current !== "none"
            Kirigami.FormData.label: "Intensity:"
            from: 0
            to: 100
        }

        ChoiceBox {
            id: artBorderColorMode
            enabled: showAlbumCover.checked && artBorderEffect.current !== "none"
            Kirigami.FormData.label: "Colors:"
            model: [
                { text: "From album art", value: "album" },
                { text: "Theme accent", value: "theme" },
                { text: "Custom", value: "custom" }
            ]
        }

        ColorButton {
            id: artBorderColor
            visible: artBorderColorMode.current === "custom"
            Kirigami.FormData.label: "Main color:"
        }

        ColorButton {
            id: artBorderColor2
            visible: artBorderColorMode.current === "custom"
            Kirigami.FormData.label: "Second color:"
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: fetchAlbumCoverHttps
            enabled: showAlbumCover.checked
            Kirigami.FormData.label: "Loading:"
            text: "Load over HTTPS (may fail on some setups)"
        }
    }
}
