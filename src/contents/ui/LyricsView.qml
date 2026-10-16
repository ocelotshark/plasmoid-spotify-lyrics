import QtQuick
import QtQuick.Effects

import "Lrc.js" as Lrc

// Scrolling lyrics column. Every line has the same fixed height, so the
// scroll offset is exact arithmetic instead of font-metric guesswork.
Item {
    id: root
    clip: true

    property var lines: []
    property bool synced: true
    property string message: ""            // shown when there are no lines

    property var positionSource: null      // function() -> microseconds
    property real length: 0                // microseconds
    property bool playing: false
    property real offsetSeconds: 0         // user sync adjustment

    property int horizontalAlignment: Text.AlignRight
    property bool highlightCurrent: true
    property int currentLineShift: 0       // +n moves the current line up n lines
    property color textColor: "white"
    property color dimColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.45)
    property font font
    readonly property real lineHeight: Math.ceil(root.font.pixelSize * 1.45)

    property string effect: "none"         // current-line effect, see LyricLine.qml
    property real effectIntensity: 0.5     // 0..1

    // Drop shadow under the text. Applied to the scrolling column (not this
    // clipping item), so only the visible lines are shown.
    property bool shadowEnabled: false
    property color shadowColor: "black"
    property real shadowBlur: 0.3
    property real shadowX: 2
    property real shadowY: 2

    // Scroll position of the lines, for things that follow them (the blur shape).
    readonly property alias scrollY: column.y

    property int currentIndex: -1
    property real lineProgress: 0          // 0..1 through the current line
    property real plainProgress: 0         // 0..1, for unsynced lyrics
    property bool _animate: false

    onLinesChanged: _jump()
    onHeightChanged: _jump()
    onLineHeightChanged: _jump()
    onCurrentLineShiftChanged: _jump()
    Component.onCompleted: {
        _completed = true;
        _jump();
    }

    // Change handlers can fire while the item is still being constructed
    // (e.g. inside a delegate), before the JS environment is usable.
    property bool _completed: false

    function _jump() {
        if (!_completed) {
            return;
        }
        _animate = false;
        tick();
        column.y = targetY();
        Qt.callLater(() => _animate = true);
    }

    function tick() {
        if (!positionSource || lines.length === 0) {
            currentIndex = -1;
            plainProgress = 0;
            return;
        }
        const seconds = positionSource() / 1e6;
        if (synced) {
            // Lead slightly so the scroll lands as the line starts.
            const t = seconds + offsetSeconds + 0.15;
            currentIndex = Lrc.lineIndexAt(lines, t);
            lineProgress = _progressAt(currentIndex, t);
        } else {
            currentIndex = -1;
            plainProgress = length > 0 ? Math.min(1, seconds / (length / 1e6)) : 0;
        }
    }

    // How far through line `i` the song is. A line is assumed to be sung in
    // about the time its text takes, so a long gap before the next line
    // doesn't make karaoke/typewriter effects crawl.
    function _progressAt(i, t) {
        if (i < 0 || i >= lines.length) {
            return 0;
        }
        const start = lines[i].time;
        const next = i + 1 < lines.length ? lines[i + 1].time : start + 6;
        const sung = Math.min(Math.max(0.5, next - start), Array.from(lines[i].text).length * 0.085 + 1.0);
        return Math.max(0, Math.min(1, (t - start) / sung));
    }

    function targetY() {
        let focus;
        if (lines.length === 0) {
            focus = 0;
        } else if (synced) {
            focus = currentIndex + 0.5 + currentLineShift;
        } else {
            // Unsynced: drift through the text in step with the song.
            focus = plainProgress * lines.length;
        }
        return root.height / 2 - focus * lineHeight;
    }

    Timer {
        // Karaoke and typewriter need smooth progress; others can tick slower.
        interval: !root.synced ? 500 : (root.effect === "karaoke" || root.effect === "typewriter") ? 33 : 100
        repeat: true
        running: root.visible && root.lines.length > 0
        onTriggered: {
            root.tick();
            root._animate = true;
            column.y = root.targetY();
        }
    }

    Column {
        id: column
        width: root.width

        layer.enabled: root.shadowEnabled
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: root.shadowColor
            shadowBlur: root.shadowBlur
            shadowHorizontalOffset: root.shadowX
            shadowVerticalOffset: root.shadowY
        }

        Behavior on y {
            enabled: root._animate
            NumberAnimation {
                duration: root.synced ? 450 : 900
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: root.lines

            LyricLine {
                required property var modelData
                required property int index

                readonly property bool isCurrent: index === root.currentIndex

                width: column.width
                height: root.lineHeight
                text: modelData.text.length > 0 ? modelData.text : (root.synced ? "♪" : "")
                current: isCurrent && root.synced
                effect: root.effect
                intensity: root.effectIntensity
                progress: isCurrent ? root.lineProgress : 0
                horizontalAlignment: root.horizontalAlignment
                font: root.font
                accentColor: root.textColor
                color: !root.synced || !root.highlightCurrent || isCurrent ? root.textColor : root.dimColor
            }
        }
    }

    Text {
        anchors.fill: parent
        visible: root.lines.length === 0 && root.message.length > 0
        text: root.message
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: root.horizontalAlignment
        elide: Text.ElideRight
        textFormat: Text.PlainText
        font: root.font
        color: root.dimColor
    }
}
