import QtQuick

// The shape the wallpaper blur is cut to: a rounded pill behind every
// visible lyric line (bigger for the current line), plus optional pills for
// the title and artist. Used blurred as a mask, the pills melt into one soft
// shape. It follows the lyrics' scroll animation and line changes, so the
// shape glides and morphs as the song moves on.
Item {
    id: blob

    property LyricsView view: null           // the lyrics being shown
    property real originX: 0                 // where the view's top-left sits in this item
    property real originY: 0
    property real padX: 16
    property real padY: 6
    property var extraRects: []              // [{x, y, w, h}] in this item's coordinates

    function startX(textWidth) {
        if (!view) {
            return 0;
        }
        if (view.horizontalAlignment === Text.AlignRight) {
            return view.width - textWidth;
        }
        if (view.horizontalAlignment === Text.AlignHCenter) {
            return (view.width - textWidth) / 2;
        }
        return 0;
    }

    Repeater {
        model: blob.view ? blob.view.lines : []

        Rectangle {
            required property var modelData
            required property int index

            TextMetrics {
                id: metrics
                font: blob.view.font
                text: modelData.text
            }

            readonly property bool current: index === blob.view.currentIndex
            readonly property real grow: current ? 1.4 : 1
            readonly property real textWidth: Math.min(blob.view.width, metrics.advanceWidth)

            // Fade out toward the edges of the lyrics area, like the text itself.
            readonly property real centerY: y + height / 2 - blob.originY
            readonly property real edgeFade: Math.max(0, Math.min(1,
                Math.min(centerY, blob.view.height - centerY) / blob.view.lineHeight + 0.5))

            visible: modelData.text.length > 0 && edgeFade > 0
            width: textWidth + 2 * blob.padX * grow
            height: blob.view.lineHeight + 2 * blob.padY * grow
            x: blob.originX + blob.startX(textWidth) - blob.padX * grow
            y: blob.originY + blob.view.scrollY + (index + 0.5) * blob.view.lineHeight - height / 2
            radius: height / 2
            color: "white"
            opacity: (current ? 1 : 0.8) * edgeFade

            Behavior on width {
                NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
            }
        }
    }

    Repeater {
        model: blob.extraRects

        Rectangle {
            required property var modelData
            x: modelData.x - blob.padX
            y: modelData.y - blob.padY
            width: modelData.w + 2 * blob.padX
            height: modelData.h + 2 * blob.padY
            radius: height / 2
            color: "white"
        }
    }
}
