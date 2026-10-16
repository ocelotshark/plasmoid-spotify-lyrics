import QtQuick

// Live audio spectrum from the helper in contents/code/audio.py (which runs
// cava). While `active`, polls it ~30 times a second; if it isn't running,
// asks for it to be started via launchRequested().
Item {
    id: root

    property bool active: false
    property int port: 47615

    property var bars: []          // 0..1 per band, low to high frequency
    property real level: 0         // overall loudness 0..1
    property real bass: 0          // low-frequency energy 0..1
    property real beat: 0          // 1 right after a beat, decaying to 0
    property bool available: false

    signal launchRequested()

    property real _avgBass: 0
    property double _lastBeat: 0
    property double _lastLaunch: 0
    property bool _inFlight: false

    Timer {
        interval: 33
        repeat: true
        running: root.active
        onTriggered: root._poll()
    }

    // When stopped (paused, effects off), let everything fall back to rest.
    Timer {
        interval: 33
        repeat: true
        running: !root.active && (root.level > 0.002 || root.beat > 0.002)
        onTriggered: {
            root.bars = root.bars.map(v => v * 0.8);
            root.level *= 0.8;
            root.bass *= 0.8;
            root.beat *= 0.8;
        }
    }

    function _poll() {
        if (_inFlight) {
            return;
        }
        _inFlight = true;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            _inFlight = false;
            if (xhr.status === 200) {
                available = true;
                _apply(xhr.responseText);
            } else {
                available = false;
                _maybeLaunch();
            }
        };
        xhr.open("GET", "http://127.0.0.1:" + port + "/bars");
        xhr.send();
    }

    function _maybeLaunch() {
        const now = Date.now();
        if (now - _lastLaunch > 5000) {
            _lastLaunch = now;
            launchRequested();
        }
    }

    function _apply(text) {
        const values = text.split(";").map(v => Math.min(1, Math.max(0, parseInt(v, 10) / 1000 || 0)));
        if (values.length === 0) {
            return;
        }
        bars = values;

        let sum = 0;
        values.forEach(v => sum += v);
        level = level * 0.4 + (sum / values.length) * 0.6;

        const lows = Math.max(1, Math.round(values.length / 8));
        let low = 0;
        for (let i = 0; i < lows; i++) {
            low += values[i];
        }
        low /= lows;
        bass = bass * 0.3 + low * 0.7;

        // A beat: bass jumps well above its recent average.
        const now = Date.now();
        _avgBass = _avgBass * 0.92 + low * 0.08;
        if (low > 0.25 && low > _avgBass * 1.35 && now - _lastBeat > 180) {
            _lastBeat = now;
            beat = 1;
        } else {
            beat *= 0.85;
        }
    }
}
