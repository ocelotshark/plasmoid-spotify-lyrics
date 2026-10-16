import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

// Frosted glass: a live, blurred copy of the part of the desktop wallpaper
// behind this item, cut to `shape` (an invisible, layered item the same size
// as this one) with feathered edges. Works with any wallpaper plugin (image,
// slideshow, animated) because it samples the wallpaper item itself.
Item {
    id: glass

    property Item wallpaper: null
    property real strength: 0.6            // 0..1
    property real tint: 0.2                // 0..1, how strongly tintColor covers it
    property color tintColor: "black"
    property Item shape: null               // white where the glass should be
    property real feather: 0.5              // 0..1, softness of the shape's edges

    readonly property int blurRadius: Math.round(12 + 52 * strength)
    readonly property int pad: blurRadius + 4
    property rect sourceArea: Qt.rect(0, 0, 1, 1)

    visible: wallpaper !== null && width > 0 && height > 0

    // Where this item sits over the wallpaper, plus a margin so the blur
    // has real pixels to sample at the edges.
    function refresh() {
        if (!wallpaper) {
            return;
        }
        const p = glass.mapToItem(wallpaper, -pad, -pad);
        const area = Qt.rect(Math.round(p.x), Math.round(p.y), Math.round(width + 2 * pad), Math.round(height + 2 * pad));
        if (area.x !== sourceArea.x || area.y !== sourceArea.y || area.width !== sourceArea.width || area.height !== sourceArea.height) {
            sourceArea = area;
        }
    }

    onWidthChanged: refresh()
    onHeightChanged: refresh()
    onWallpaperChanged: {
        console.debug("[spotify-lyrics] wallpaper blur source:", wallpaper);
        refresh();
    }
    Component.onCompleted: refresh()

    // The widget can be dragged around the desktop; follow it.
    Timer {
        interval: 400
        repeat: true
        running: glass.visible
        onTriggered: glass.refresh()
    }

    // The shape, blurred, so its pieces melt together with soft edges.
    MultiEffect {
        id: softShape
        width: glass.width
        height: glass.height
        visible: false
        layer.enabled: true
        source: glass.shape
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: Math.round(8 + 56 * glass.feather)
    }

    Item {
        anchors.fill: parent
        layer.enabled: glass.shape !== null
        layer.effect: GE.OpacityMask {
            maskSource: softShape
        }

        ShaderEffectSource {
            id: snapshot
            x: -glass.pad
            y: -glass.pad
            width: glass.width + 2 * glass.pad
            height: glass.height + 2 * glass.pad
            sourceItem: glass.wallpaper
            sourceRect: glass.sourceArea
            live: true
            hideSource: false
            visible: false
        }

        MultiEffect {
            source: snapshot
            anchors.fill: snapshot
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1.0
            blurMax: glass.blurRadius
            blurMultiplier: 0.5
        }

        Rectangle {
            anchors.fill: parent
            color: glass.tintColor
            opacity: glass.tint
        }
    }
}
