import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Particles
import Qt5Compat.GraphicalEffects as GE

// Animated border around the album art. Two instances are used: one behind
// the art (back: true) for halos that must not cover the cover, and one in
// front for everything else.
//
// Effects: solid, pulse, glow, breathe, gradient, rainbow, neon, heartbeat,
// colorcycle, shine, ripple, sparkle, progress, aurora, glitch, double
// Music visualizers: spectrum, waveline, eq, bassring, beatripple, sparks,
// levelglow, bloom
Item {
    id: frame

    property string effect: "none"
    property bool back: false
    property bool outer: true             // draw outside the art (true) or over its edge (false)
    property real radius: 8
    property real lineWidth: 3
    property real speed: 1                // 1 = normal, 2 = twice as fast
    property real intensity: 0.5          // 0..1
    property color color: "white"
    property color color2: "gray"
    property real progress: 0             // song progress 0..1, for "progress"

    // Music input (from AudioLevels).
    property bool reactive: false         // make the regular effects follow the music
    property var bars: []
    property real level: 0
    property real bass: 0
    property real beat: 0

    readonly property var visualizers: ["spectrum", "waveline", "eq", "bassring", "beatripple", "sparks", "levelglow", "bloom"]
    readonly property bool isVisualizer: visualizers.indexOf(effect) >= 0
    readonly property real k: 0.3 + intensity * 1.4
    readonly property real react: reactive && !isVisualizer ? Math.min(1, bass * 1.3 + beat * 0.3) : 0
    // Line width including the music's push.
    readonly property real lw: lineWidth * (1 + react * 1.5 * k)
    readonly property real size: Math.min(width, height)

    function dur(ms) {
        return Math.max(60, ms / Math.max(0.1, speed));
    }

    function shows(names) {
        return !back && names.indexOf(effect) >= 0;
    }

    // ---- shared animation state ---------------------------------------------

    property real phase: 0
    NumberAnimation on phase {
        from: 0
        to: 1
        loops: Animation.Infinite
        running: frame.visible && ["none", "solid", "progress", "spectrum", "waveline", "eq", "bassring", "sparks"].indexOf(frame.effect) < 0
        duration: {
            switch (frame.effect) {
            case "pulse": case "breathe": return frame.dur(2200);
            case "heartbeat": return frame.dur(1100);
            case "neon": return frame.dur(3000);
            case "shine": return frame.dur(3200);
            case "ripple": return frame.dur(2000);
            case "sparkle": return frame.dur(2400);
            case "colorcycle": return frame.dur(6000);
            case "glitch": return frame.dur(2500);
            default: return frame.dur(3500);
            }
        }
    }

    readonly property real wave: 0.5 - 0.5 * Math.cos(2 * Math.PI * phase)
    readonly property real heartbeat: {
        const p = phase;
        const thump = (c, w) => Math.max(0, 1 - Math.abs(p - c) / w);
        return Math.max(thump(0.08, 0.08), 0.7 * thump(0.28, 0.08));
    }
    readonly property real neonFlicker: (phase > 0.20 && phase < 0.23) || (phase > 0.27 && phase < 0.29) || (phase > 0.71 && phase < 0.73) ? 0.25 : 1
    readonly property color cycled: Qt.hsla(phase, 0.75, 0.6, 1)
    readonly property color levelColor: Qt.rgba(color.r + (color2.r - color.r) * level,
                                                color.g + (color2.g - color.g) * level,
                                                color.b + (color2.b - color.b) * level, 1)

    // Band value for position i of n around the outline, mirrored so the
    // shape is symmetric and lows sit at the start and end.
    function barAt(i, n) {
        if (!bars || bars.length === 0) {
            return 0;
        }
        const half = n / 2;
        const j = i < half ? i : n - 1 - i;
        return bars[Math.min(bars.length - 1, Math.floor(j / half * bars.length))];
    }

    // ---- outline geometry ------------------------------------------------------

    // Position on the art's rounded outline at fraction t (0..1, clockwise
    // from the top-left end of the top edge).
    function pointAt(t) {
        const r = Math.min(radius, width / 2, height / 2);
        const w = width - 2 * r;
        const h = height - 2 * r;
        const arc = Math.PI * r / 2;
        const total = 2 * w + 2 * h + 4 * arc;
        let d = ((t % 1) + 1) % 1 * total;
        const corner = (cx, cy, startAngle, dist) => {
            const a = startAngle + (dist / Math.max(arc, 0.0001)) * Math.PI / 2;
            return Qt.point(cx + r * Math.cos(a), cy + r * Math.sin(a));
        };
        if (d < w) return Qt.point(r + d, 0);
        d -= w;
        if (d < arc) return corner(width - r, r, -Math.PI / 2, d);
        d -= arc;
        if (d < h) return Qt.point(width, r + d);
        d -= h;
        if (d < arc) return corner(width - r, height - r, 0, d);
        d -= arc;
        if (d < w) return Qt.point(width - r - d, height);
        d -= w;
        if (d < arc) return corner(r, height - r, Math.PI / 2, d);
        d -= arc;
        if (d < h) return Qt.point(0, height - r - d);
        d -= h;
        return corner(r, r, Math.PI, d);
    }

    // n points around the outline with outward normals: [{x, y, nx, ny}].
    function samples(n) {
        const out = [];
        for (let i = 0; i < n; i++) {
            const t = (i + 0.5) / n;
            const p = pointAt(t);
            const a = pointAt(t - 0.002);
            const b = pointAt(t + 0.002);
            let tx = b.x - a.x, ty = b.y - a.y;
            const len = Math.max(0.0001, Math.sqrt(tx * tx + ty * ty));
            tx /= len;
            ty /= len;
            out.push({ x: p.x, y: p.y, nx: ty, ny: -tx });
        }
        return out;
    }

    readonly property var ring48: width > 0 && height > 0 ? samples(48) : []
    readonly property var ring120: width > 0 && height > 0 && effect === "waveline" ? samples(120) : []
    readonly property real dir: outer ? 1 : -1

    // ---- rings: everything drawn as a band along the edge ------------------

    // The band's box: just outside the art (outer) or just inside it.
    Item {
        id: ringBox
        anchors.fill: parent
        anchors.margins: frame.outer ? -frame.lw : 0
        readonly property real r: frame.radius + (frame.outer ? frame.lw : 0)

        Rectangle {
            id: ring
            visible: frame.shows(["solid", "pulse", "glow", "breathe", "neon", "heartbeat", "colorcycle", "glitch", "double", "bassring", "levelglow"])
            anchors.fill: parent
            anchors.margins: {
                if (frame.effect === "heartbeat") return -frame.heartbeat * 3 * frame.k * frame.dir;
                return 0;
            }
            radius: ringBox.r - anchors.margins
            color: "transparent"
            border.width: {
                switch (frame.effect) {
                case "pulse": return frame.lw * (0.6 + 0.8 * frame.wave);
                case "bassring": return frame.lineWidth * (1 + frame.bass * 4 * frame.k);
                default: return frame.lw;
                }
            }
            border.color: {
                switch (frame.effect) {
                case "colorcycle": return frame.cycled;
                case "levelglow": return frame.levelColor;
                default: return frame.color;
                }
            }
            opacity: {
                switch (frame.effect) {
                case "pulse": return 0.5 + 0.5 * frame.wave;
                case "neon": return frame.neonFlicker;
                case "levelglow": return 0.35 + 0.65 * frame.level;
                default: return 1;
                }
            }

            layer.enabled: visible && (["glow", "breathe", "neon", "heartbeat", "bassring", "levelglow"].indexOf(frame.effect) >= 0 || frame.react > 0)
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: ring.border.color
                shadowBlur: 1.0
                shadowScale: 1 + 0.04 * frame.k + (frame.effect === "levelglow" ? 0.08 * frame.level : 0)
                shadowOpacity: {
                    switch (frame.effect) {
                    case "breathe": return 0.25 + 0.75 * frame.wave;
                    case "heartbeat": return 0.4 + 0.6 * frame.heartbeat;
                    case "bassring": return Math.min(1, 0.2 + frame.bass);
                    case "levelglow": return Math.min(1, 0.2 + frame.level * 1.2);
                    case "solid": case "pulse": case "glitch": case "double": case "colorcycle":
                        return Math.min(1, frame.react);
                    default: return Math.min(1, 0.6 + 0.3 * frame.k + frame.react * 0.4);
                    }
                }
                brightness: frame.effect === "neon" ? 0.2 : 0
            }
        }

        // Second, thinner ring for "double", on the far side of the first.
        Rectangle {
            visible: frame.shows(["double"])
            anchors.fill: parent
            anchors.margins: -(frame.lw + 3 + 2 * frame.wave * frame.k) * frame.dir
            radius: Math.max(0, ringBox.r - anchors.margins)
            color: "transparent"
            border.width: Math.max(1, frame.lw / 2)
            border.color: frame.color2
            opacity: 0.4 + 0.6 * (1 - frame.wave)
        }

        // RGB-split copies for "glitch".
        Repeater {
            model: frame.shows(["glitch"]) ? 2 : 0

            Rectangle {
                required property int index
                readonly property bool active: (frame.phase > 0.10 && frame.phase < 0.16) || (frame.phase > 0.55 && frame.phase < 0.58) || frame.beat > 0.7
                anchors.fill: parent
                anchors.leftMargin: active ? (index === 0 ? -3 : 3) * frame.k : 0
                anchors.rightMargin: -anchors.leftMargin
                radius: ringBox.r
                color: "transparent"
                border.width: frame.lw
                border.color: index === 0 ? Qt.rgba(1, 0.1, 0.3, 0.8) : Qt.rgba(0.1, 0.9, 1, 0.8)
                visible: active
            }
        }

        // Gradient / rainbow: a conical gradient seen through a ring mask.
        Rectangle {
            id: ringMask
            anchors.fill: parent
            visible: false
            radius: ringBox.r
            color: "transparent"
            border.width: frame.lw
            border.color: "white"
            layer.enabled: true
        }

        GE.ConicalGradient {
            visible: frame.shows(["gradient", "rainbow"])
            anchors.fill: parent
            source: ringMask
            angle: 360 * frame.phase
            gradient: frame.effect === "rainbow" ? rainbowGradient : albumGradient
        }

        // Song progress around the outline.
        Item {
            anchors.fill: parent
            visible: frame.shows(["progress"])

            BorderOutline {
                lineWidth: frame.lw
                cornerRadius: ringBox.r
                strokeColor: Qt.rgba(frame.color.r, frame.color.g, frame.color.b, 0.25)
            }
            BorderOutline {
                lineWidth: frame.lw
                cornerRadius: ringBox.r
                strokeColor: frame.color
                trimEnd: Math.max(0.001, Math.min(1, frame.progress))
            }
        }
    }

    Gradient {
        id: albumGradient
        GradientStop { position: 0.0; color: frame.color }
        GradientStop { position: 0.5; color: frame.color2 }
        GradientStop { position: 1.0; color: frame.color }
    }

    Gradient {
        id: rainbowGradient
        GradientStop { position: 0.00; color: "#ff3b3b" }
        GradientStop { position: 0.17; color: "#ffb03b" }
        GradientStop { position: 0.33; color: "#f5ff3b" }
        GradientStop { position: 0.50; color: "#3bff7a" }
        GradientStop { position: 0.67; color: "#3bc4ff" }
        GradientStop { position: 0.83; color: "#a23bff" }
        GradientStop { position: 1.00; color: "#ff3b3b" }
    }

    // ---- shine: a diagonal light sweeping across the cover -------------------

    Item {
        id: shine
        anchors.fill: parent
        visible: frame.shows(["shine"])
        layer.enabled: visible
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: shine.width
                height: shine.height
                radius: frame.radius
            }
        }

        Rectangle {
            width: shine.width * 0.35
            height: shine.height * 2
            y: -shine.height / 2
            x: -width * 2 + (shine.width + width * 3) * Math.min(1, frame.phase * 1.6)
            rotation: 25
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, Math.min(0.85, 0.3 + 0.3 * frame.k + frame.react * 0.3)) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // ---- ripple: rings expanding outward (or closing in) ----------------------

    Repeater {
        model: frame.shows(["ripple"]) ? 3 : 0

        Rectangle {
            required property int index
            readonly property real p: (frame.phase + index / 3) % 1
            readonly property real reach: p * (14 + frame.react * 10) * frame.k * frame.dir
            anchors.centerIn: parent
            width: parent.width + 2 * reach
            height: parent.height + 2 * reach
            radius: Math.max(0, frame.radius + reach)
            color: "transparent"
            border.width: Math.max(1, frame.lw * (1 - p))
            border.color: frame.color
            opacity: 1 - p
        }
    }

    // ---- sparkle: little stars twinkling around the edge ---------------------

    Repeater {
        model: frame.shows(["sparkle"]) ? 10 : 0

        Text {
            required property int index
            readonly property real along: (index * 0.137 + 0.05) % 1
            readonly property real twinkle: Math.min(1, Math.max(0, Math.sin(2 * Math.PI * (frame.phase + index * 0.29))) + frame.beat * 0.6)
            readonly property point at: frame.pointAt(along)
            text: "✦"
            color: index % 2 ? frame.color : frame.color2
            font.pixelSize: Math.max(8, frame.lineWidth * 4 * (0.6 + frame.intensity))
            x: at.x - width / 2
            y: at.y - height / 2
            scale: 0.3 + twinkle
            opacity: twinkle
        }
    }

    // ---- aurora / bloom halo (back layer when outer, edge glow when inner) ----

    Item {
        id: haloBox
        anchors.fill: parent
        visible: (frame.outer ? frame.back : !frame.back) && (frame.effect === "aurora" || frame.effect === "bloom")
        // Inside the art, keep the glow within the rounded cover.
        layer.enabled: visible && !frame.outer
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: haloBox.width
                height: haloBox.height
                radius: frame.radius
            }
        }

        GE.ConicalGradient {
            id: halo
            anchors.fill: parent
            anchors.margins: frame.outer
                ? -(frame.effect === "bloom" ? 4 + frame.bass * 26 * frame.k : 10 * frame.k * (1 + frame.react))
                : 0
            angle: 360 * frame.phase
            opacity: frame.effect === "bloom" ? Math.min(1, 0.15 + frame.level * 1.3) : 1
            source: frame.outer ? null : innerGlowMask
            gradient: Gradient {
                GradientStop { position: 0.00; color: frame.color }
                GradientStop { position: 0.33; color: frame.color2 }
                GradientStop { position: 0.66; color: Qt.hsla((frame.phase + 0.5) % 1, 0.7, 0.6, 1) }
                GradientStop { position: 1.00; color: frame.color }
            }
            layer.enabled: haloBox.visible
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: Math.round(24 + 24 * frame.intensity)
                autoPaddingEnabled: frame.outer
            }
        }
    }

    // Inner variant: a soft band just inside the art's edge.
    Rectangle {
        id: innerGlowMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        radius: frame.radius
        color: "transparent"
        border.color: "white"
        border.width: frame.size * (frame.effect === "bloom" ? 0.03 + frame.bass * 0.07 * frame.k : 0.08 * frame.k)
    }

    // ---- visualizer: spectrum bars around the outline -----------------------

    Repeater {
        model: frame.shows(["spectrum"]) ? frame.ring48 : []

        Rectangle {
            required property var modelData
            required property int index
            readonly property real v: frame.barAt(index, frame.ring48.length)
            readonly property real angle: Math.atan2(modelData.ny * frame.dir, modelData.nx * frame.dir) * 180 / Math.PI
            readonly property real reach: frame.size * (frame.outer ? 0.16 : 0.12) * frame.k

            x: modelData.x + modelData.nx * frame.dir * 2
            y: modelData.y + modelData.ny * frame.dir * 2 - height / 2
            width: 2 + v * reach
            height: Math.max(1.5, frame.lineWidth)
            radius: height / 2
            transformOrigin: Item.Left
            rotation: angle
            antialiasing: true
            color: index % 2 ? frame.color : Qt.rgba(frame.color.r + (frame.color2.r - frame.color.r) * v,
                                                    frame.color.g + (frame.color2.g - frame.color.g) * v,
                                                    frame.color.b + (frame.color2.b - frame.color.b) * v, 1)
        }
    }

    // ---- visualizer: the outline itself bends with the spectrum -------------

    Shape {
        id: waveline
        anchors.fill: parent
        visible: frame.shows(["waveline"])
        preferredRendererType: Shape.CurveRenderer

        layer.enabled: visible
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: frame.color
            shadowBlur: 1.0
            shadowOpacity: Math.min(1, 0.3 + frame.level)
        }

        ShapePath {
            strokeColor: frame.color
            strokeWidth: frame.lineWidth
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            PathPolyline {
                path: {
                    const pts = frame.ring120;
                    const n = pts.length;
                    if (n === 0) {
                        return [];
                    }
                    const amp = frame.size * 0.12 * frame.k;
                    const out = [];
                    for (let i = 0; i <= n; i++) {
                        const s = pts[i % n];
                        // Average neighbours for a smoother line.
                        const v = (frame.barAt((i - 1 + n) % n, n) + 2 * frame.barAt(i % n, n) + frame.barAt((i + 1) % n, n)) / 4;
                        const off = (frame.lineWidth / 2 + v * amp) * frame.dir;
                        out.push(Qt.point(s.x + s.nx * off, s.y + s.ny * off));
                    }
                    return out;
                }
            }
        }
    }

    // ---- visualizer: classic equalizer bars along the bottom ----------------

    Row {
        visible: frame.shows(["eq"])
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: frame.outer ? undefined : parent.bottom
        anchors.bottomMargin: frame.size * 0.04
        anchors.top: frame.outer ? parent.bottom : undefined
        anchors.topMargin: 3
        spacing: Math.max(1, frame.width / 24 * 0.25)
        height: frame.size * 0.35 * frame.k

        Repeater {
            model: frame.shows(["eq"]) ? 20 : 0

            Rectangle {
                required property int index
                readonly property real v: frame.bars && frame.bars.length ? frame.bars[Math.min(frame.bars.length - 1, Math.floor(index / 20 * frame.bars.length * 0.8))] : 0
                width: (frame.width * 0.92 - 19 * parent.spacing) / 20
                height: Math.max(2, v * parent.height)
                y: frame.outer ? 0 : parent.height - height
                radius: Math.min(width / 2, 2)
                opacity: frame.outer ? 0.9 : 0.85
                color: Qt.rgba(frame.color.r + (frame.color2.r - frame.color.r) * index / 19,
                               frame.color.g + (frame.color2.g - frame.color.g) * index / 19,
                               frame.color.b + (frame.color2.b - frame.color.b) * index / 19, 1)
            }
        }
    }

    // ---- visualizer: ripples fired on each beat -----------------------------

    property var _ripples: []          // start times
    property double _now: 0

    onBeatChanged: {
        if (effect === "beatripple" && beat >= 0.999) {
            _ripples = _ripples.concat([Date.now()]).slice(-5);
        }
        if (effect === "sparks" && beat >= 0.999) {
            sparkEmitter.burst(Math.round(10 + 20 * intensity));
        }
    }

    Timer {
        interval: 16
        repeat: true
        running: frame.effect === "beatripple" && frame._ripples.length > 0
        onTriggered: {
            frame._now = Date.now();
            frame._ripples = frame._ripples.filter(t => frame._now - t < 900);
        }
    }

    Repeater {
        model: frame.shows(["beatripple"]) ? frame._ripples : []

        Rectangle {
            required property var modelData
            readonly property real p: Math.min(1, Math.max(0, (frame._now - modelData) / 900))
            readonly property real reach: (1 - Math.pow(1 - p, 3)) * frame.size * 0.18 * frame.k * frame.dir
            anchors.centerIn: parent
            width: frame.width + 2 * reach
            height: frame.height + 2 * reach
            radius: Math.max(0, frame.radius + reach)
            color: "transparent"
            border.width: Math.max(1, frame.lineWidth * 1.5 * (1 - p))
            border.color: frame.color
            opacity: 1 - p
        }
    }

    // A faint resting ring so beat ripples have something to grow from.
    Rectangle {
        visible: frame.shows(["beatripple", "sparks"])
        anchors.fill: parent
        anchors.margins: frame.outer ? -frame.lineWidth : 0
        radius: frame.radius + (frame.outer ? frame.lineWidth : 0)
        color: "transparent"
        border.width: Math.max(1, frame.lineWidth * (0.6 + frame.beat * 0.8))
        border.color: frame.color
        opacity: 0.35 + 0.65 * frame.beat
    }

    // ---- visualizer: sparks thrown off on each beat --------------------------

    ParticleSystem {
        id: sparks
        anchors.fill: parent
        running: frame.shows(["sparks"])
    }

    ImageParticle {
        system: sparks
        source: "qrc:///particleresources/glowdot.png"
        color: frame.color
        colorVariation: 0.25
        alpha: 0.9
        entryEffect: ImageParticle.Fade
    }

    Emitter {
        id: sparkEmitter
        system: sparks
        anchors.fill: parent
        anchors.margins: frame.outer ? -frame.lineWidth : frame.size * 0.04
        enabled: false
        lifeSpan: 700
        lifeSpanVariation: 250
        size: Math.max(7, frame.lineWidth * 4)
        sizeVariation: 4
        endSize: 1
        shape: EllipseShape { fill: false }
        velocity: TargetDirection {
            targetX: sparkEmitter.width / 2
            targetY: sparkEmitter.height / 2
            magnitude: -frame.size * 0.6 * frame.k * frame.dir
            magnitudeVariation: frame.size * 0.3
        }
    }
}
