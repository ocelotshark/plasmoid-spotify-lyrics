import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_showLyrics: showLyrics.checked
    property alias cfg_useBackupSource: useBackupSource.checked
    property alias cfg_showUnsyncedLyrics: showUnsyncedLyrics.checked
    property alias cfg_showLyricsStatus: showLyricsStatus.checked
    property alias cfg_highlightCurrentLine: highlightCurrentLine.checked
    property alias cfg_lyricsEffect: lyricsEffect.current
    property alias cfg_lyricsEffectIntensity: lyricsEffectIntensity.value
    property alias cfg_lyricsAlignment: lyricsAlignment.current
    property alias cfg_currentLineOffset: currentLineOffset.value
    property alias cfg_lyricsOffsetMs: lyricsOffsetMs.value
    property alias cfg_lyricsFontSize: lyricsFont.size
    property alias cfg_lyricsFontFamily: lyricsFont.family
    property alias cfg_lyricsColorMode: lyricsColorMode.current
    property alias cfg_lyricsTextColor: lyricsColor.color
    property alias cfg_lyricsBrightness: lyricsTone.brightness
    property alias cfg_lyricsOpacity: lyricsTone.opacityPercent
    property alias cfg_lyricsInactiveOpacity: lyricsInactiveOpacity.value
    property alias cfg_lyricsInactiveColorMode: lyricsInactiveColorMode.current
    property alias cfg_lyricsInactiveColor: lyricsInactiveColor.color

    Kirigami.FormLayout {

        CheckBox {
            id: showLyrics
            Kirigami.FormData.label: "Lyrics:"
            text: "Show lyrics"
        }
        CheckBox {
            id: useBackupSource
            enabled: showLyrics.checked
            text: "Use NetEase as a backup lyrics source"
        }
        CheckBox {
            id: showUnsyncedLyrics
            enabled: showLyrics.checked
            text: "Fall back to unsynced lyrics"
        }
        CheckBox {
            id: showLyricsStatus
            enabled: showLyrics.checked
            text: "Show \"Searching for lyrics…\" while looking"
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Current line"
        }

        CheckBox {
            id: highlightCurrentLine
            enabled: showLyrics.checked
            Kirigami.FormData.label: "Highlight:"
            text: "Dim the other lines"
        }

        ChoiceBox {
            id: lyricsEffect
            enabled: showLyrics.checked
            Kirigami.FormData.label: "Effect:"
            model: [
                { text: "None", value: "none" },
                { text: "Glow", value: "glow" },
                { text: "Drop shadow", value: "shadow" },
                { text: "Grow", value: "grow" },
                { text: "Bounce in", value: "bounce" },
                { text: "Pulse", value: "pulse" },
                { text: "Fade in", value: "fade" },
                { text: "Slide in", value: "slide" },
                { text: "Blur in", value: "blur" },
                { text: "Neon flicker", value: "neon" },
                { text: "Letter spread", value: "spread" },
                { text: "Karaoke fill", value: "karaoke" },
                { text: "Typewriter", value: "typewriter" },
                { text: "Wave", value: "wave" },
                { text: "Rainbow", value: "rainbow" },
                { text: "Shimmer", value: "shimmer" }
            ]
        }

        ValueSlider {
            id: lyricsEffectIntensity
            enabled: showLyrics.checked && lyricsEffect.current !== "none"
            Kirigami.FormData.label: "Effect intensity:"
            from: 0
            to: 100
        }

        SpinBox {
            id: currentLineOffset
            enabled: showLyrics.checked
            Kirigami.FormData.label: "Position:"
            from: -5
            to: 5
            ToolTip.text: "+1 moves the current line one line toward the top"
            ToolTip.visible: hovered
        }

        RowLayout {
            enabled: showLyrics.checked
            Kirigami.FormData.label: "Timing adjustment:"
            SpinBox { id: lyricsOffsetMs; from: -10000; to: 10000; stepSize: 100 }
            Label { text: "ms (positive = earlier)" }
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Text"
        }

        ChoiceBox {
            id: lyricsAlignment
            enabled: showLyrics.checked
            Kirigami.FormData.label: "Alignment:"
            model: [
                { text: "Toward album art", value: "auto" },
                { text: "Centered", value: "center" }
            ]
        }

        FontPicker {
            id: lyricsFont
            enabled: showLyrics.checked
            Kirigami.FormData.label: "Font:"
            dialogTitle: "Choose lyrics font"
        }

        ChoiceBox {
            id: lyricsColorMode
            enabled: showLyrics.checked
            Kirigami.FormData.label: "Color:"
            model: [
                { text: "Theme text color", value: "theme" },
                { text: "From album art", value: "album" },
                { text: "Custom", value: "custom" }
            ]
        }

        ColorButton {
            id: lyricsColor
            visible: lyricsColorMode.current === "custom"
            enabled: showLyrics.checked
            Kirigami.FormData.label: "Custom color:"
        }

        TonePicker {
            id: lyricsTone
            enabled: showLyrics.checked
            Kirigami.FormData.label: "Lyrics text:"
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Other lines"
        }

        ChoiceBox {
            id: lyricsInactiveColorMode
            enabled: showLyrics.checked
            Kirigami.FormData.label: "Color:"
            model: [
                { text: "Same as lyrics (album: second color)", value: "auto" },
                { text: "Custom", value: "custom" }
            ]
        }

        ColorButton {
            id: lyricsInactiveColor
            visible: lyricsInactiveColorMode.current === "custom"
            enabled: showLyrics.checked
            Kirigami.FormData.label: "Custom color:"
        }

        ValueSlider {
            id: lyricsInactiveOpacity
            enabled: showLyrics.checked
            Kirigami.FormData.label: "Opacity:"
            from: 0
            to: 100
        }
    }
}
