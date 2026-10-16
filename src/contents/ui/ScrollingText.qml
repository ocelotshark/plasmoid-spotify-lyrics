import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

// One line of text that, when it doesn't fit, either elides, wraps onto a
// second line, or slowly scrolls back and forth. Optionally carries an
// always-on effect:
//
//   glow, neon, pulse, breathe, float, shimmer, rainbow, gradient,
//   colorshift, outline, glitch   (or "none")
Item {
    id: root

    property alias text: label.text
    property alias font: label.font
    property color color: "white"
    property color color2: "gray"          // second color for gradient/colorshift/outline
    property int horizontalAlignment: Text.AlignLeft
    property string overflow: "elide"      // elide | wrap | scroll
    property string effect: "none"
    property real intensity: 0.5           // 0..1

    // Drop shadow (separate from the effect, so both can be on).
    property bool shadowEnabled: false
    property color shadowColor: "black"
    property real shadowBlur: 0.3          // 0..1
    property real shadowX: 2
    property real shadowY: 2

    // Horizontal scroll position, animated by the marquee.
    property real scrollX: 0

    readonly property bool overflowing: label.implicitWidth > width + 1
    // Width of the visible text and where it starts, for shapes drawn around it.
    readonly property real textWidth: Math.min(width, label.implicitWidth)
    readonly property real textStart: scrolling || horizontalAlignment === Text.AlignLeft ? 0
        : horizontalAlignment === Text.AlignRight ? width - textWidth
        : (width - textWidth) / 2
    readonly property bool scrolling: overflow === "scroll" && overflowing
    readonly property real k: 0.3 + intensity * 1.4
    readonly property bool gradientFill: effect === "rainbow" || effect === "gradient"
    // Room above and below so glows aren't cut off by the scrolling clip.
    readonly property real pad: Math.ceil(label.font.pixelSize * 0.6 + Math.max(Math.abs(shadowX), Math.abs(shadowY)))

    implicitHeight: label.implicitHeight

    property real phase: 0
    NumberAnimation on phase {
        from: 0
        to: 1
        loops: Animation.Infinite
        running: root.visible && ["pulse", "breathe", "float", "shimmer", "rainbow", "colorshift", "neon", "glitch"].indexOf(root.effect) >= 0
        duration: {
            switch (root.effect) {
            case "pulse": case "breathe": return 2200;
            case "float": return 3000;
            case "shimmer": return 2600;
            case "neon": case "glitch": return 3000;
            default: return 5000;
            }
        }
    }
    readonly property real wave: 0.5 - 0.5 * Math.cos(2 * Math.PI * phase)
    readonly property bool glitching: effect === "glitch" && ((phase > 0.12 && phase < 0.17) || (phase > 0.60 && phase < 0.62) || (phase > 0.66 && phase < 0.68))
    readonly property real flicker: effect === "neon" && ((phase > 0.30 && phase < 0.33) || (phase > 0.37 && phase < 0.39)) ? 0.35 : 1

    Item {
        id: viewport
        y: -root.pad
        width: root.width
        height: root.height + 2 * root.pad
        clip: root.scrolling

        // Padded host for the drop shadow, so shadows and glows inside it
        // have room and aren't cut at the text's edges.
        Item {
            id: shadowHost
            x: root.scrollX - root.pad
            y: root.effect === "float" ? (root.wave - 0.5) * root.font.pixelSize * 0.25 * root.k : 0
            width: label.width + 2 * root.pad
            height: label.height + 2 * root.pad

            layer.enabled: root.shadowEnabled
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                shadowEnabled: true
                shadowColor: root.shadowColor
                shadowBlur: root.shadowBlur
                shadowHorizontalOffset: root.shadowX
                shadowVerticalOffset: root.shadowY
            }

            Item {
                id: content
                x: root.pad
                y: root.pad
                width: label.width
                height: label.height
                opacity: root.effect === "breathe" ? 0.45 + 0.55 * (1 - root.wave * Math.min(1, root.k)) : root.flicker

                transformOrigin: root.horizontalAlignment === Text.AlignRight ? Item.Right
                    : root.horizontalAlignment === Text.AlignHCenter ? Item.Center
                    : Item.Left
                scale: root.effect === "pulse" ? 1 + 0.06 * root.k * root.wave : 1

                layer.enabled: root.effect === "glow" || root.effect === "neon"
                layer.effect: MultiEffect {
                    autoPaddingEnabled: true
                    shadowEnabled: true
                    shadowColor: root.color
                    shadowBlur: Math.min(1, 0.45 + 0.3 * root.k)
                    shadowOpacity: Math.min(1, 0.55 + 0.3 * root.k) * root.flicker
                    shadowScale: root.effect === "neon" ? 1.03 : 1
                    brightness: root.effect === "neon" ? 0.15 : 0
                }

                // RGB-split ghosts for "glitch".
                Repeater {
                    model: root.glitching ? 2 : 0
                    Text {
                        required property int index
                        x: (index === 0 ? -2 : 2) * root.k
                        width: label.width
                        text: label.text
                        font: label.font
                        textFormat: Text.PlainText
                        horizontalAlignment: label.horizontalAlignment
                        wrapMode: label.wrapMode
                        maximumLineCount: label.maximumLineCount
                        elide: label.elide
                        color: index === 0 ? Qt.rgba(1, 0.15, 0.35, 0.8) : Qt.rgba(0.1, 0.9, 1, 0.8)
                    }
                }

                Text {
                    id: label
                    visible: !root.gradientFill
                    width: root.scrolling ? implicitWidth : root.width
                    textFormat: Text.PlainText
                    horizontalAlignment: root.scrolling ? Text.AlignLeft : root.horizontalAlignment
                    wrapMode: root.overflow === "wrap" ? Text.Wrap : Text.NoWrap
                    maximumLineCount: root.overflow === "wrap" ? 2 : 1
                    elide: root.overflow === "scroll" ? Text.ElideNone : Text.ElideRight
                    color: root.effect === "colorshift"
                        ? Qt.rgba(root.color.r + (root.color2.r - root.color.r) * root.wave,
                                  root.color.g + (root.color2.g - root.color.g) * root.wave,
                                  root.color.b + (root.color2.b - root.color.b) * root.wave,
                                  root.color.a)
                        : root.color
                    style: root.effect === "outline" ? Text.Outline : Text.Normal
                    styleColor: root.color2

                    onTextChanged: {
                        marquee.stop();
                        root.scrollX = 0;
                        if (root.scrolling && root.visible) {
                            marquee.start();
                        }
                    }
                }

                // Rainbow / album gradient painted through the letters. The span is
                // twice the text width so the rainbow can slide without a seam.
                GE.LinearGradient {
                    visible: root.gradientFill
                    anchors.fill: label
                    source: label
                    start: Qt.point(root.effect === "rainbow" ? -root.phase * label.width : 0, 0)
                    end: Qt.point(root.effect === "rainbow" ? (2 - root.phase) * label.width : label.width, 0)
                    opacity: root.color.a
                    gradient: root.effect === "rainbow" ? rainbow : albumGradient
                }

                // Shimmer: a bright band sliding across the letters.
                Item {
                    id: shimmer
                    anchors.fill: label
                    visible: root.effect === "shimmer"
                    layer.enabled: visible
                    layer.effect: GE.OpacityMask {
                        maskSource: label
                    }

                    Rectangle {
                        width: Math.max(30, shimmer.width * 0.3)
                        height: shimmer.height
                        x: -width + (shimmer.width + 2 * width) * root.phase
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, Math.min(1, 0.4 + 0.35 * root.k)) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                }
            }
        }
    }

    Gradient {
        id: albumGradient
        GradientStop { position: 0.0; color: root.color }
        GradientStop { position: 1.0; color: root.color2 }
    }

    Gradient {
        id: rainbow
        GradientStop { position: 0.000; color: "#ff4d4d" }
        GradientStop { position: 0.083; color: "#ffb04d" }
        GradientStop { position: 0.166; color: "#f2ff4d" }
        GradientStop { position: 0.250; color: "#4dff88" }
        GradientStop { position: 0.333; color: "#4dc8ff" }
        GradientStop { position: 0.416; color: "#a64dff" }
        GradientStop { position: 0.500; color: "#ff4d4d" }
        GradientStop { position: 0.583; color: "#ffb04d" }
        GradientStop { position: 0.666; color: "#f2ff4d" }
        GradientStop { position: 0.750; color: "#4dff88" }
        GradientStop { position: 0.833; color: "#4dc8ff" }
        GradientStop { position: 0.916; color: "#a64dff" }
        GradientStop { position: 1.000; color: "#ff4d4d" }
    }

    SequentialAnimation {
        id: marquee
        running: root.scrolling && root.visible
        loops: Animation.Infinite
        onRunningChanged: if (!running) root.scrollX = 0

        PauseAnimation { duration: 2500 }
        NumberAnimation {
            target: root
            property: "scrollX"
            from: 0
            to: root.width - label.implicitWidth
            duration: Math.max(1, label.implicitWidth - root.width) * 30
            easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: 2000 }
        NumberAnimation {
            target: root
            property: "scrollX"
            to: 0
            duration: Math.max(1, label.implicitWidth - root.width) * 12
            easing.type: Easing.InOutSine
        }
    }
}
