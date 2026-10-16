import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

// One lyric line. When it is the current line, the chosen effect is applied:
//
//   glow, shadow, grow, bounce, pulse, fade, slide, blur, neon, spread,
//   karaoke, typewriter, wave, rainbow, shimmer   (or "none")
Item {
    id: line

    property string text
    property bool current: false
    property string effect: "none"
    property real intensity: 0.5           // 0..1
    property real progress: 0              // 0..1 through the line's singing time
    property color color: "white"          // color for this line in its current state
    property color accentColor: "white"    // the current-line color (used by glow etc.)
    property font font
    property int horizontalAlignment: Text.AlignLeft

    readonly property string fx: current ? effect : "none"
    readonly property real k: 0.25 + intensity * 1.5     // effect strength, 0.25..1.75
    readonly property bool charMode: fx === "wave" || fx === "rainbow"
    readonly property bool loops: ["pulse", "neon", "wave", "rainbow", "shimmer"].indexOf(fx) >= 0

    // Activation animation (0 -> 1 when the line becomes current) and a
    // looping phase (0 -> 1, repeating) for continuous effects.
    property real anim: 1
    property real phase: 0

    onCurrentChanged: {
        if (current) {
            activation.restart();
        } else {
            activation.stop();
            anim = 1;
        }
    }

    NumberAnimation {
        id: activation
        target: line
        property: "anim"
        from: 0
        to: 1
        duration: line.effect === "bounce" ? 900 : line.effect === "fade" || line.effect === "blur" ? 700 : 450
        easing.type: line.effect === "bounce" ? Easing.OutElastic : Easing.OutCubic
        easing.amplitude: 1.2
        easing.period: 0.35
    }

    NumberAnimation on phase {
        from: 0
        to: 1
        loops: Animation.Infinite
        running: line.loops
        duration: line.fx === "pulse" ? 1400 : line.fx === "neon" ? 2600 : line.fx === "shimmer" ? 1800 : 2000
    }

    // Left edge of the laid-out text, for overlays that must sit on it.
    function startX(contentWidth) {
        if (horizontalAlignment === Text.AlignRight) {
            return width - contentWidth;
        }
        if (horizontalAlignment === Text.AlignHCenter) {
            return (width - contentWidth) / 2;
        }
        return 0;
    }

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    readonly property string typewriterText: {
        if (fx !== "typewriter") {
            return "";
        }
        const chars = Array.from(text);
        const shown = Math.ceil(chars.length * Math.min(1, progress * (1 + k)));
        return escapeHtml(chars.slice(0, shown).join(""))
            + "<font color=\"#00000000\">" + escapeHtml(chars.slice(shown).join("")) + "</font>";
    }

    readonly property real neonFlicker: {
        if (fx !== "neon") {
            return 1;
        }
        const p = phase;
        const off = (p > 0.10 && p < 0.125) || (p > 0.16 && p < 0.18) || (p > 0.63 && p < 0.65);
        return off ? 1 - 0.55 * Math.min(1, k) : 1;
    }

    Item {
        id: visual
        width: line.width
        height: line.height

        transformOrigin: line.horizontalAlignment === Text.AlignRight ? Item.Right
            : line.horizontalAlignment === Text.AlignHCenter ? Item.Center
            : Item.Left

        scale: {
            switch (line.fx) {
            case "grow": return 1 + 0.12 * line.k * line.anim;
            case "bounce": return 1 + 0.08 * line.k * line.anim;
            case "pulse": return 1 + 0.06 * line.k * (0.5 - 0.5 * Math.cos(2 * Math.PI * line.phase));
            default: return 1;
            }
        }
        opacity: line.fx === "fade" ? line.anim : line.neonFlicker
        x: {
            if (line.fx !== "slide") {
                return 0;
            }
            const direction = line.horizontalAlignment === Text.AlignRight ? 1 : -1;
            return direction * (1 - line.anim) * 40 * line.k;
        }

        Behavior on scale {
            enabled: line.fx === "grow" || line.fx === "none"
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        layer.enabled: ["glow", "shadow", "blur", "neon"].indexOf(line.fx) >= 0
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: line.fx === "glow" || line.fx === "neon" || line.fx === "shadow"
            shadowColor: line.fx === "shadow" ? Qt.rgba(0, 0, 0, 0.9) : line.accentColor
            shadowOpacity: line.fx === "shadow" ? 0.9 : Math.min(1, 0.55 + 0.3 * line.k)
            shadowBlur: line.fx === "shadow" ? 0.35 : Math.min(1, 0.45 + 0.3 * line.k)
            shadowHorizontalOffset: line.fx === "shadow" ? 2 * line.k : 0
            shadowVerticalOffset: line.fx === "shadow" ? 3 * line.k : 0
            shadowScale: line.fx === "neon" ? 1.04 : 1.0
            blurEnabled: line.fx === "blur"
            blur: line.fx === "blur" ? 1 - line.anim : 0
            blurMax: Math.round(16 + 24 * line.intensity)
            brightness: line.fx === "neon" ? 0.15 * line.neonFlicker : 0
        }

        // The ordinary text. Hidden only when drawn letter by letter.
        Text {
            id: label
            anchors.fill: parent
            visible: !line.charMode
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: line.horizontalAlignment
            elide: Text.ElideRight
            font.family: line.font.family
            font.pixelSize: line.font.pixelSize
            font.weight: line.font.weight
            font.letterSpacing: line.fx === "spread" ? line.font.pixelSize * 0.08 * line.k * line.anim : 0
            textFormat: line.fx === "typewriter" ? Text.StyledText : Text.PlainText
            text: line.fx === "typewriter" ? line.typewriterText : line.text
            color: line.fx === "karaoke"
                ? Qt.rgba(line.color.r, line.color.g, line.color.b, line.color.a * 0.4)
                : line.color

            Behavior on color {
                ColorAnimation { duration: 250 }
            }
        }

        // Karaoke: a full-color copy revealed left to right as the line is sung.
        Item {
            visible: line.fx === "karaoke"
            x: line.startX(label.contentWidth)
            width: label.contentWidth * Math.min(1, line.progress * (0.6 + 0.4 * line.k))
            height: parent.height
            clip: true

            Text {
                x: -parent.x
                width: line.width
                height: line.height
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: line.horizontalAlignment
                elide: Text.ElideRight
                font: line.font
                textFormat: Text.PlainText
                text: line.text
                color: line.color
            }
        }

        // Wave / rainbow: the line laid out one character at a time.
        Row {
            id: chars
            visible: line.charMode
            x: line.startX(width)
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: line.charMode ? Array.from(line.text) : []

                Text {
                    required property string modelData
                    required property int index

                    text: modelData === " " ? String.fromCharCode(160) : modelData
                    font: line.font
                    textFormat: Text.PlainText
                    y: line.fx === "wave"
                        ? Math.sin(2 * Math.PI * line.phase - index * 0.45) * line.font.pixelSize * 0.14 * line.k
                        : 0
                    color: line.fx === "rainbow"
                        ? Qt.hsla((line.phase + index * 0.04 * line.k) % 1, 0.8,
                                  Math.max(0.55, Math.min(0.75, line.color.hslLightness)), line.color.a)
                        : line.color
                }
            }
        }

        // Shimmer: a bright band sweeping across the letters.
        Item {
            id: shimmer
            anchors.fill: parent
            visible: line.fx === "shimmer"
            layer.enabled: visible
            layer.effect: GE.OpacityMask {
                maskSource: shimmerMask
            }

            Rectangle {
                width: Math.max(40, line.width * 0.3)
                height: parent.height
                x: -width + (line.width + 2 * width) * line.phase
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, Math.min(1, 0.45 + 0.35 * line.k)) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        Text {
            id: shimmerMask
            anchors.fill: parent
            visible: false
            layer.enabled: line.fx === "shimmer"
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: line.horizontalAlignment
            elide: Text.ElideRight
            font: line.font
            textFormat: Text.PlainText
            text: line.text
            color: "white"
        }
    }
}
