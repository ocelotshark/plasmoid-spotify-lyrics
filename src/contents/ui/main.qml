import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

import "Colors.js" as Colors

PlasmoidItem {
    id: widget

    readonly property var cfg: Plasmoid.configuration
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
        || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool lyricsOnRight: cfg.lyricsPosition === "right"
    readonly property bool showInfo: cfg.showTitle || cfg.showArtist
    // "opposite" puts title/artist on the other side of the art from the lyrics.
    readonly property bool infoOnLeft: cfg.infoPosition === "left"
        || (cfg.infoPosition !== "right" && lyricsOnRight)

    readonly property int infoAlignment: {
        switch (cfg.infoAlignment) {
        case "left": return Text.AlignLeft;
        case "center": return Text.AlignHCenter;
        case "right": return Text.AlignRight;
        default: return infoOnLeft ? Text.AlignRight : Text.AlignLeft;   // toward the art
        }
    }

    // Lyric colors taken from the album art (when that mode is on).
    property var albumColors: null
    readonly property bool useAlbumColors: cfg.lyricsColorMode === "album" && albumColors !== null

    readonly property real artRadius: artwork.width * cfg.artCornerRadius / 100
    property real songProgress: 0

    // theme | custom | album
    function pickColor(mode, custom, fromAlbum) {
        if (mode === "album" && albumColors) {
            return fromAlbum;
        }
        return mode === "custom" ? custom : Kirigami.Theme.textColor;
    }

    readonly property color borderColor: cfg.artBorderColorMode === "album" && albumColors ? albumColors.primary
        : cfg.artBorderColorMode === "custom" ? cfg.artBorderColor
        : Kirigami.Theme.highlightColor
    readonly property color borderColor2: cfg.artBorderColorMode === "album" && albumColors ? albumColors.secondary
        : cfg.artBorderColorMode === "custom" ? cfg.artBorderColor2
        : Qt.lighter(borderColor, 1.5)

    readonly property color textShadowColor: Colors.tone(
        cfg.textShadowColorMode === "album" && albumColors ? albumColors.secondary : cfg.textShadowColor,
        cfg.textShadowColorMode === "album" ? -60 : 0,
        cfg.textShadowOpacity)
    readonly property real textShadowX: cfg.textShadowDistance * Math.cos(cfg.textShadowAngle * Math.PI / 180)
    readonly property real textShadowY: cfg.textShadowDistance * Math.sin(cfg.textShadowAngle * Math.PI / 180)

    Plasmoid.status: player.ready ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
    Plasmoid.backgroundHints: cfg.transparentBackground
        ? PlasmaCore.Types.NoBackground
        : PlasmaCore.Types.DefaultBackground

    Layout.preferredWidth: row.implicitWidth
    Layout.preferredHeight: inPanel ? row.implicitHeight : Kirigami.Units.gridUnit * 5
    Layout.minimumHeight: inPanel ? -1 : Kirigami.Units.gridUnit * 2

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Reload Lyrics"
            icon.name: "view-refresh"
            enabled: player.ready
            onTriggered: lyrics.reload()
        },
        PlasmaCore.Action {
            text: "Lyrics on Right Side"
            icon.name: "view-split-left-right"
            checkable: true
            checked: widget.lyricsOnRight
            onTriggered: cfg.lyricsPosition = checked ? "right" : "left"
        }
    ]

    // Round icon button used by the hover controls.
    component ControlButton: Item {
        id: button
        property alias iconName: icon.source
        signal clicked()

        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: implicitWidth
        opacity: enabled ? 1 : 0.35

        Kirigami.Icon {
            id: icon
            anchors.fill: parent
            isMask: true
            color: "white"
            scale: buttonArea.pressed ? 0.88 : buttonArea.containsMouse ? 1.12 : 1
            Behavior on scale {
                NumberAnimation { duration: 100 }
            }
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    Player {
        id: player
        identity: cfg.playerIdentity
    }

    LyricsSource {
        id: lyrics
        active: cfg.showLyrics && player.ready
        allowUnsynced: cfg.showUnsyncedLyrics
        useBackupSource: cfg.useBackupSource
        track: player.track
        artist: player.artist
        album: player.album
        duration: player.length / 1e6
    }

    // Live audio spectrum for music-reactive borders and visualizers. The
    // helper (contents/code/audio.py, which runs cava) is started on demand
    // and quits by itself once nothing asks it for data.
    readonly property bool wantsAudio: cfg.showAlbumCover && cfg.artBorderEffect !== "none"
        && (cfg.artBorderReactive || ["spectrum", "waveline", "eq", "bassring", "beatripple", "sparks", "levelglow", "bloom"].indexOf(cfg.artBorderEffect) >= 0)

    AudioLevels {
        id: audio
        active: widget.wantsAudio && player.playing
        onLaunchRequested: {
            const script = decodeURIComponent(Qt.resolvedUrl("../code/audio.py").toString().replace(/^file:\/\//, ""));
            launcher.connectSource("setsid -f python3 -I '" + script.replace(/'/g, "'\\''") + "' --port " + port + " >/dev/null 2>&1");
        }
    }

    Plasma5Support.DataSource {
        id: launcher
        engine: "executable"
        onNewData: source => disconnectSource(source)
    }

    Kirigami.ImageColors {
        id: imageColors
        source: shownArt
        onPaletteChanged: widget.updateAlbumColors()
    }

    Connections {
        target: Kirigami.Theme
        function onTextColorChanged() { widget.updateAlbumColors(); }
    }

    function updateAlbumColors() {
        if (shownArt.source.toString() === artwork.fallback || !imageColors.palette || imageColors.palette.length === 0) {
            albumColors = null;
            return;
        }
        // What the lyrics sit on is unknown (often the wallpaper when the
        // background is transparent), so assume the opposite of the theme's
        // text color, which is readable there by design.
        const t = Kirigami.Theme.textColor;
        const lightText = 0.2126 * t.r + 0.7152 * t.g + 0.0722 * t.b > 0.5;
        const backdrop = lightText ? "#1b1e20" : "#eff0f1";
        albumColors = Colors.fromPalette(imageColors.palette, imageColors.dominant, backdrop);
        console.debug("[spotify-lyrics] album colors", albumColors.primary, albumColors.secondary, "from", imageColors.palette.length, "swatches");
    }

    // Frosted wallpaper in a soft shape around the text (desktop only). The
    // glass extends past the widget so the feathered edges aren't cut off.
    WallpaperBlur {
        id: glass
        z: -2
        readonly property int margin: 72
        x: -margin
        y: -margin
        width: widget.width + 2 * margin
        height: widget.height + 2 * margin
        wallpaper: cfg.wallpaperBlur !== "off" && Plasmoid.containment ? Plasmoid.containment.wallpaperGraphicsObject : null
        strength: cfg.wallpaperBlurStrength / 100
        tint: cfg.wallpaperBlurTint / 100
        tintColor: cfg.wallpaperBlurTintColor
        feather: cfg.wallpaperBlurSoftness / 100
        shape: blobShape
    }

    LyricsBlob {
        id: blobShape
        visible: false
        layer.enabled: glass.visible
        width: glass.width
        height: glass.height
        view: cfg.showLyrics ? lyricsView : null
        originX: lyricsView.parent.x + lyricsView.x + glass.margin
        originY: lyricsView.parent.y + lyricsView.y + glass.margin
        padX: cfg.wallpaperBlurPadding
        padY: cfg.wallpaperBlurPadding * 0.4
        extraRects: cfg.wallpaperBlur === "all" ? widget.infoRects : []
    }

    // Title/artist text boxes in glass coordinates, for the blur shape.
    property var infoRects: []
    Timer {
        interval: 500
        repeat: true
        triggeredOnStart: true
        running: glass.visible && cfg.wallpaperBlur === "all"
        onTriggered: {
            const rects = [];
            [title, artistLabel].forEach(t => {
                if (t.visible && t.text.length > 0) {
                    const p = t.mapToItem(widget, t.textStart, 0);
                    rects.push({ x: p.x + glass.margin, y: p.y + glass.margin, w: t.textWidth, h: t.height });
                }
            });
            widget.infoRects = rects;
        }
    }

    // Sits behind everything so the hover buttons get their own clicks.
    MouseArea {
        z: -1
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        cursorShape: player.canRaise ? Qt.PointingHandCursor : Qt.ArrowCursor

        property int wheelDelta: 0

        onClicked: mouse => {
            switch (mouse.button) {
            case Qt.MiddleButton:
                player.togglePlayback();
                break;
            case Qt.LeftButton:
                player.raise();
                break;
            case Qt.BackButton:
                player.previous();
                break;
            case Qt.ForwardButton:
                player.next();
                break;
            }
        }

        // Accumulate so high-resolution touchpads don't jump the volume.
        onWheel: wheel => {
            wheelDelta += wheel.angleDelta.y;
            while (Math.abs(wheelDelta) >= 120) {
                const step = wheelDelta > 0 ? 1 : -1;
                player.changeVolume(step * cfg.volumeStep / 100, true);
                wheelDelta -= step * 120;
            }
        }
    }

    // Fixed slots: [lyrics][info][art][info][lyrics]. The lyrics and info
    // items are moved into whichever slot their setting picks. Slot widths
    // don't depend on the song, so the artwork never moves.
    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 0   // distances from the art are per-column settings

        Item {
            id: lyricsLeftSlot
            visible: cfg.showLyrics && !widget.lyricsOnRight
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: cfg.lyricsWidth + cfg.lyricsGap
            Layout.minimumWidth: Kirigami.Units.gridUnit * 3 + cfg.lyricsGap
        }

        Item {
            id: infoLeftSlot
            visible: widget.showInfo && widget.infoOnLeft
            Layout.fillHeight: true
            Layout.preferredWidth: (cfg.showLyrics ? cfg.infoWidth : info.implicitWidth) + cfg.infoGap
            Layout.maximumWidth: cfg.showLyrics ? cfg.infoWidth + cfg.infoGap : Number.POSITIVE_INFINITY
            Layout.fillWidth: !cfg.showLyrics
        }

        /* Album artwork */
        Item {
            id: artwork
            visible: cfg.showAlbumCover
            Layout.preferredWidth: row.height
            Layout.preferredHeight: row.height
            Layout.fillWidth: false

            readonly property string fallback: Qt.resolvedUrl("../assets/icon.svg").toString()
            readonly property string wanted: {
                let url = player.artUrl;
                if (url.startsWith("https://") && !cfg.fetchAlbumCoverHttps) {
                    url = "http://" + url.slice(8);
                }
                return url || fallback;
            }

            HoverHandler {
                id: artHover
            }

            ArtBorder {
                anchors.fill: parent
                back: true
                visible: cfg.artBorderEffect === "aurora" || cfg.artBorderEffect === "bloom"
                effect: cfg.artBorderEffect
                radius: widget.artRadius
                lineWidth: cfg.artBorderWidth
                speed: cfg.artBorderSpeed / 100
                intensity: cfg.artBorderIntensity / 100
                color: widget.borderColor
                color2: widget.borderColor2
                outer: cfg.artBorderPlacement !== "inner"
                reactive: cfg.artBorderReactive
                bars: audio.bars
                level: audio.level
                bass: audio.bass
                beat: audio.beat
            }

            // The previous cover stays up until the new one has loaded.
            Image {
                id: shownArt
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: artwork.fallback
                onStatusChanged: if (status === Image.Ready) imageColors.update()

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: shownArt.width
                        height: shownArt.height
                        radius: widget.artRadius
                    }
                }
            }

            ArtBorder {
                anchors.fill: parent
                visible: cfg.artBorderEffect !== "none"
                effect: cfg.artBorderEffect
                radius: widget.artRadius
                lineWidth: cfg.artBorderWidth
                speed: cfg.artBorderSpeed / 100
                intensity: cfg.artBorderIntensity / 100
                color: widget.borderColor
                color2: widget.borderColor2
                progress: widget.songProgress
                outer: cfg.artBorderPlacement !== "inner"
                reactive: cfg.artBorderReactive
                bars: audio.bars
                level: audio.level
                bass: audio.bass
                beat: audio.beat
            }

            Image {
                id: loadingArt
                visible: false
                asynchronous: true
                source: artwork.wanted
                onStatusChanged: {
                    if (status === Image.Ready) {
                        shownArt.source = source;
                        artTimeout.stop();
                    } else if (status === Image.Error) {
                        console.warn("[spotify-lyrics] could not load artwork", source);
                        shownArt.source = artwork.fallback;
                        artTimeout.stop();
                    }
                }
                onSourceChanged: artTimeout.restart()
            }

            Timer {
                id: artTimeout
                interval: 8000
                onTriggered: {
                    if (loadingArt.status !== Image.Ready) {
                        shownArt.source = artwork.fallback;
                    }
                }
            }

            /* Progress bar */
            Rectangle {
                visible: cfg.showProgressBar && player.ready && player.length > 0
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 2
                height: 3
                radius: 1
                color: "#80282828"

                Rectangle {
                    id: progressFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 1
                    color: "#1db954"
                    width: 0
                }
            }

            Timer {
                interval: 1000
                repeat: true
                triggeredOnStart: true
                running: player.ready && artwork.visible
                onTriggered: {
                    const fraction = player.length > 0 ? Math.min(1, player.position() / player.length) : 0;
                    progressFill.width = fraction * progressFill.parent.width;
                    widget.songProgress = fraction;
                }
            }

            /* Playback controls on hover */
            Item {
                id: controls
                anchors.fill: parent
                opacity: cfg.showHoverControls && player.ready && artHover.hovered ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: Kirigami.Units.shortDuration }
                }

                readonly property bool compact: width < Kirigami.Units.gridUnit * 3

                Rectangle {
                    anchors.fill: parent
                    radius: widget.artRadius
                    color: Qt.rgba(0, 0, 0, 0.55)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Math.round(controls.width * 0.03)

                    ControlButton {
                        visible: !controls.compact
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(controls.width * 0.24)
                        height: width
                        iconName: "media-skip-backward"
                        enabled: player.canGoPrevious
                        onClicked: player.previous()
                    }
                    ControlButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(controls.width * (controls.compact ? 0.6 : 0.32))
                        height: width
                        iconName: player.playing ? "media-playback-pause" : "media-playback-start"
                        enabled: player.canControl
                        onClicked: player.togglePlayback()
                    }
                    ControlButton {
                        visible: !controls.compact
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(controls.width * 0.24)
                        height: width
                        iconName: "media-skip-forward"
                        enabled: player.canGoNext
                        onClicked: player.next()
                    }
                }
            }
        }

        Item {
            id: infoRightSlot
            visible: widget.showInfo && !widget.infoOnLeft
            Layout.fillHeight: true
            Layout.preferredWidth: infoLeftSlot.Layout.preferredWidth
            Layout.maximumWidth: infoLeftSlot.Layout.maximumWidth
            Layout.fillWidth: !cfg.showLyrics
        }

        Item {
            id: lyricsRightSlot
            visible: cfg.showLyrics && widget.lyricsOnRight
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: cfg.lyricsWidth + cfg.lyricsGap
            Layout.minimumWidth: Kirigami.Units.gridUnit * 3 + cfg.lyricsGap
        }
    }

    LyricsView {
        id: lyricsView
        parent: widget.lyricsOnRight ? lyricsRightSlot : lyricsLeftSlot
        anchors.fill: parent
        anchors.leftMargin: widget.lyricsOnRight ? cfg.lyricsGap : 0
        anchors.rightMargin: widget.lyricsOnRight ? 0 : cfg.lyricsGap

        shadowEnabled: cfg.textShadowLyrics
        shadowColor: widget.textShadowColor
        shadowBlur: cfg.textShadowBlur / 100
        shadowX: widget.textShadowX
        shadowY: widget.textShadowY

        lines: lyrics.lines
        synced: lyrics.synced
        message: cfg.showLyricsStatus && lyrics.status === "loading" ? "Searching for lyrics…" : ""
        positionSource: player.position
        length: player.length
        playing: player.playing
        offsetSeconds: cfg.lyricsOffsetMs / 1000

        horizontalAlignment: {
            if (cfg.lyricsAlignment === "center" || (!cfg.showAlbumCover && !widget.showInfo)) {
                return Text.AlignHCenter;
            }
            return widget.lyricsOnRight ? Text.AlignLeft : Text.AlignRight;
        }
        highlightCurrent: cfg.highlightCurrentLine
        effect: cfg.lyricsEffect
        effectIntensity: cfg.lyricsEffectIntensity / 100
        currentLineShift: cfg.currentLineOffset
        readonly property color baseColor: widget.useAlbumColors ? widget.albumColors.primary
            : cfg.lyricsColorMode === "custom" ? cfg.lyricsTextColor
            : Kirigami.Theme.textColor
        readonly property color baseDimColor: cfg.lyricsInactiveColorMode === "custom" ? cfg.lyricsInactiveColor
            : widget.useAlbumColors ? widget.albumColors.secondary
            : baseColor
        textColor: Colors.tone(baseColor, cfg.lyricsBrightness, cfg.lyricsOpacity)
        dimColor: Colors.tone(baseDimColor, cfg.lyricsBrightness, cfg.lyricsOpacity * cfg.lyricsInactiveOpacity / 100)
        font.family: cfg.lyricsFontFamily || Kirigami.Theme.defaultFont.family
        font.pixelSize: cfg.lyricsFontSize
    }

    /* Song information */
    Item {
        id: info
        parent: widget.infoOnLeft ? infoLeftSlot : infoRightSlot
        anchors.fill: parent
        anchors.leftMargin: widget.infoOnLeft ? 0 : cfg.infoGap
        anchors.rightMargin: widget.infoOnLeft ? cfg.infoGap : 0
        implicitWidth: Math.max(title.implicitWidth, artistLabel.implicitWidth)

        // Text boxes have empty space above capital letters and below the
        // baseline; measure it so "top"/"bottom" line the letters up with the
        // edges of the album art rather than the invisible box.
        FontMetrics {
            id: topMetrics
            font: cfg.showTitle ? title.font : artistLabel.font
        }
        FontMetrics {
            id: bottomMetrics
            font: artistLabel.visible ? artistLabel.font : title.font
        }

        ColumnLayout {
            id: infoColumn
            anchors.left: parent.left
            anchors.right: parent.right
            y: {
                switch (cfg.infoVerticalAlignment) {
                case "top":
                    return -Math.max(0, topMetrics.ascent + topMetrics.tightBoundingRect("H").y);
                case "bottom":
                    return parent.height - height + bottomMetrics.descent;
                default:
                    return Math.round((parent.height - height) / 2);
                }
            }
            spacing: 0

            ScrollingText {
                id: title
                Layout.fillWidth: true
                visible: cfg.showTitle
                overflow: cfg.infoOverflow
                horizontalAlignment: widget.infoAlignment
                color: Colors.tone(widget.pickColor(cfg.titleColorMode, cfg.titleTextColor, widget.albumColors ? widget.albumColors.primary : "white"),
                                   cfg.titleBrightness, cfg.titleOpacity)
                color2: widget.albumColors ? widget.albumColors.secondary : Qt.lighter(color, 1.6)
                effect: cfg.titleEffect
                intensity: cfg.infoEffectIntensity / 100
                shadowEnabled: cfg.textShadowTitle
                shadowColor: widget.textShadowColor
                shadowBlur: cfg.textShadowBlur / 100
                shadowX: widget.textShadowX
                shadowY: widget.textShadowY
                font.pixelSize: cfg.titleFontSize
                font.family: cfg.titleFontFamily || Kirigami.Theme.defaultFont.family
                font.weight: Font.Bold
                text: player.ready ? (player.track || player.playerName || "No song playing") : "Spotify"
            }

            ScrollingText {
                id: artistLabel
                Layout.fillWidth: true
                visible: cfg.showArtist && text.length > 0
                overflow: cfg.infoOverflow
                horizontalAlignment: widget.infoAlignment
                color: Colors.tone(widget.pickColor(cfg.artistColorMode, cfg.artistTextColor, widget.albumColors ? widget.albumColors.secondary : "white"),
                                   cfg.artistBrightness, cfg.artistOpacity)
                color2: widget.albumColors ? widget.albumColors.primary : Qt.lighter(color, 1.6)
                effect: cfg.artistEffect
                intensity: cfg.infoEffectIntensity / 100
                shadowEnabled: cfg.textShadowArtist
                shadowColor: widget.textShadowColor
                shadowBlur: cfg.textShadowBlur / 100
                shadowX: widget.textShadowX
                shadowY: widget.textShadowY
                font.pixelSize: cfg.artistFontSize
                font.family: cfg.artistFontFamily || Kirigami.Theme.defaultFont.family
                text: player.ready ? player.artist : "No song playing"
            }
        }
    }
}
