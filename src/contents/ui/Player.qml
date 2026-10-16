import QtQuick
import org.kde.plasma.private.mpris as Mpris

// Tracks one MPRIS player (Spotify by default) and exposes its metadata plus
// a smoothly extrapolated playback position.
Item {
    id: root

    // Empty = follow whatever player Plasma considers active, preferring Spotify.
    property string identity: "Spotify"

    readonly property string wantedIdentity: (identity || "").trim()
    readonly property bool acceptAnyPlayer: wantedIdentity.length === 0

    readonly property var player: mpris2Model.currentPlayer
    readonly property bool ready: !!player && (acceptAnyPlayer || player.identity === wantedIdentity)

    readonly property string playerName: ready ? clean(player.identity) : ""
    readonly property string track: ready ? clean(player.track) : ""
    readonly property string artist: ready ? clean(player.artist) : ""
    readonly property string album: ready ? clean(player.album) : ""
    readonly property string artUrl: ready && player.artUrl ? String(player.artUrl) : ""
    readonly property real length: ready ? player.length : 0          // microseconds
    readonly property real reportedPosition: ready ? player.position : 0
    readonly property bool playing: ready && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool canRaise: ready && player.canRaise
    readonly property bool canGoNext: ready && player.canGoNext
    readonly property bool canGoPrevious: ready && player.canGoPrevious
    readonly property bool canControl: ready && player.canControl

    property double _anchorTime: Date.now()
    property real _anchorPosition: 0

    Mpris.Mpris2Model {
        id: mpris2Model

        readonly property int containerRole: Qt.UserRole + 1

        // Row 0 is Plasma's "automatic" multiplexer, which borrows the name of
        // whichever player is active. Prefer the real player entry, so we stay
        // on Spotify even when a browser starts playing something.
        function selectPlayer() {
            let match = -1;
            for (let i = 0; i < mpris2Model.rowCount(); i++) {
                const p = mpris2Model.data(mpris2Model.index(i, 0), containerRole);
                if (!p || !p.identity) {
                    continue;
                }
                const wanted = root.acceptAnyPlayer
                    ? String(p.identity).toLowerCase() === "spotify"
                    : p.identity === root.wantedIdentity;
                if (wanted && (match < 0 || i > 0)) {
                    match = i;
                }
            }
            if (match < 0 && root.acceptAnyPlayer) {
                match = 0;   // let the multiplexer follow whatever is playing
            }
            if (match >= 0 && match < mpris2Model.rowCount() && currentIndex !== match) {
                currentIndex = match;
            }
        }

        onRowsInserted: Qt.callLater(selectPlayer)
        onRowsRemoved: Qt.callLater(selectPlayer)
        onDataChanged: if (!root.ready) Qt.callLater(selectPlayer)
        Component.onCompleted: selectPlayer()
    }

    // A player's identity arrives over D-Bus a moment after it appears in the
    // model, so a single check at insertion can miss it. Keep looking until
    // we're attached.
    Timer {
        interval: 1000
        repeat: true
        running: !root.ready
        triggeredOnStart: true
        onTriggered: mpris2Model.selectPlayer()
    }

    onWantedIdentityChanged: mpris2Model.selectPlayer()

    // Re-anchor extrapolation whenever the player tells us something new.
    onReportedPositionChanged: _reanchor(reportedPosition)
    onPlayingChanged: _reanchor(reportedPosition)
    onTrackChanged: _reanchor(reportedPosition)
    onReadyChanged: _reanchor(reportedPosition)

    // Plasma only refreshes MPRIS Position on demand; poll it so lyrics do
    // not drift and seeks made in Spotify are picked up.
    Timer {
        interval: 2000
        repeat: true
        running: root.playing
        onTriggered: root.player.updatePosition()
    }

    function _reanchor(position) {
        _anchorPosition = position;
        _anchorTime = Date.now();
    }

    // Current position in microseconds, extrapolated between MPRIS updates.
    function position() {
        if (!ready) {
            return 0;
        }
        let pos = _anchorPosition;
        if (playing) {
            pos += (Date.now() - _anchorTime) * 1000;
        }
        if (length > 0) {
            pos = Math.min(pos, length);
        }
        return Math.max(0, pos);
    }

    function raise() {
        if (ready) player.Raise();
    }

    function togglePlayback() {
        if (ready) player.PlayPause();
    }

    function next() {
        if (ready) player.Next();
    }

    function previous() {
        if (ready) player.Previous();
    }

    function changeVolume(delta, showOSD) {
        if (ready) player.changeVolume(delta, showOSD);
    }

    // Players sometimes pad metadata with invisible characters or send a
    // placeholder such as "-" for a missing value; reduce those to "".
    function clean(value) {
        if (value === undefined || value === null) {
            return "";
        }
        if (Array.isArray(value)) {
            return value.map(clean).filter(Boolean).join(", ");
        }
        let text = "";
        for (const ch of String(value)) {
            text += isInvisible(ch.codePointAt(0)) ? " " : ch;
        }
        text = text.replace(/\s+/g, " ").trim();
        // Keep it only if something other than ASCII punctuation is left.
        return /[^\s!-\/:-@\[-`{-~]/.test(text) ? text : "";
    }

    // Control characters, soft hyphens, zero-width and direction marks.
    function isInvisible(c) {
        return c < 0x20
            || (c >= 0x7f && c <= 0x9f)
            || c === 0xad || c === 0x34f || c === 0x61c || c === 0x180e || c === 0xfeff
            || (c >= 0x200b && c <= 0x200f)
            || (c >= 0x2028 && c <= 0x202e)
            || (c >= 0x2060 && c <= 0x206f);
    }
}
