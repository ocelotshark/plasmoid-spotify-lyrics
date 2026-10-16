import QtQuick
import QtQuick.LocalStorage

import "Lrc.js" as Lrc

// Finds lyrics for the current track.
//
// Set track/artist/album/duration; read lines/synced/status. Lookups go to
// lrclib.net first and, if that has no synced lyrics or is throttling us, to
// NetEase as a backup. Results are cached on disk, so a song only ever needs
// the network once. Failures are retried with growing delays, and once a
// server says "too many requests" nothing more is sent to it for a while.
Item {
    id: root

    // Inputs
    property string track: ""
    property string artist: ""
    property string album: ""
    property real duration: 0          // seconds, 0 when unknown
    property bool active: true
    property bool allowUnsynced: true
    property bool useBackupSource: true

    // Outputs
    property var lines: []
    property bool synced: false
    // idle | loading | synced | plain | instrumental | none | error
    property string status: "idle"

    readonly property string lrclib: "https://lrclib.net"
    readonly property string netease: "https://music.163.com"
    readonly property int requestTimeout: 10000
    readonly property var retryDelays: [15000, 30000, 60000, 120000, 300000]
    readonly property int requestGap: 800      // ms between requests in one lookup
    readonly property int memoryCacheLimit: 200
    readonly property int diskCacheLimit: 3000
    // How long non-synced results are trusted before looking again.
    readonly property real noneTtl: 24 * 3600 * 1000
    readonly property real partialTtl: 7 * 24 * 3600 * 1000

    property string _key: ""
    property real _lookupDuration: 0
    property int _generation: 0
    property int _attempt: 0
    property var _cache: ({})
    property var _cacheOrder: []
    property var _db: null
    // Per-host time (ms since epoch) before which we don't send requests.
    property var _blockedUntil: ({})

    onTrackChanged: debounce.restart()
    onArtistChanged: debounce.restart()
    onAlbumChanged: debounce.restart()
    onDurationChanged: debounce.restart()
    onActiveChanged: debounce.restart()
    onAllowUnsyncedChanged: reload()
    onUseBackupSourceChanged: reload()

    Component.onCompleted: _openDb()

    Timer {
        id: debounce
        // Players often publish title, artist and length in separate updates.
        interval: 400
        onTriggered: root._refresh(false)
    }

    Timer {
        id: retryTimer
        onTriggered: root._refresh(true)
    }

    // Drop the cached result for this track and look it up again.
    function reload() {
        if (_key) {
            delete _cache[_key];
            _dbDelete(_key);
        }
        _key = "";
        _attempt = 0;
        _blockedUntil = {};
        _refresh(false);
    }

    function clearCache() {
        _cache = {};
        _cacheOrder = [];
        _dbClear();
        reload();
    }

    function _keyFor(track, artist) {
        return Lrc.normalize(artist) + "|" + Lrc.normalize(track);
    }

    function _setResult(result) {
        lines = result.lines;
        synced = result.status === "synced";
        status = result.status;
    }

    function _refresh(isRetry) {
        if (!active || !track || !artist) {
            _generation++;
            retryTimer.stop();
            _key = "";
            _setResult({ status: "idle", lines: [] });
            return;
        }

        const key = _keyFor(track, artist);
        const durationNowKnown = _lookupDuration <= 0 && duration > 0;

        if (!isRetry && key === _key) {
            // Same song: only look again if the first attempt lacked the
            // duration and found nothing, since duration sharpens matching.
            if (!(durationNowKnown && (status === "none" || status === "plain"))) {
                return;
            }
        }

        if (key !== _key) {
            _attempt = 0;
            retryTimer.stop();
        }
        _key = key;

        let cached = _cache[key];
        if (!cached) {
            cached = _dbGet(key);
            if (cached) {
                _rememberInMemory(key, cached);
            }
        }
        if (cached && !(durationNowKnown && cached.status !== "synced")) {
            _setResult(cached);
            return;
        }

        const generation = ++_generation;
        const want = { track: track, artist: artist, album: album, duration: duration };
        _lookupDuration = duration;
        if (!isRetry || (status !== "synced" && status !== "plain")) {
            _setResult({ status: "loading", lines: [] });
        }

        _lookup(want).then(result => {
            if (generation !== _generation) {
                return;
            }
            const retriesLeft = _attempt < retryDelays.length;
            if (result.incomplete && result.status !== "synced" && (retriesLeft || result.status === "none")) {
                // Something failed along the way; show what we have but try again.
                _setResult(result.status === "none" ? { status: "error", lines: [] } : result);
                _scheduleRetry();
                return;
            }
            _attempt = 0;
            const clean = { status: result.status, lines: result.lines };
            _rememberInMemory(key, clean);
            _dbPut(key, clean);
            _setResult(clean);
            if (result.status !== "synced" && want.duration <= 0 && duration > 0) {
                // The length arrived while we were searching; it may help.
                Qt.callLater(_refresh, false);
            }
        }).catch(error => {
            if (generation !== _generation) {
                return;
            }
            console.warn("[spotify-lyrics] lookup failed:", error && error.message ? error.message : error);
            _setResult({ status: "error", lines: [] });
            _scheduleRetry();
        });
    }

    function _scheduleRetry() {
        let delay = retryDelays[Math.min(_attempt, retryDelays.length - 1)];
        // Never retry before a throttling server is willing to talk again.
        const waitForLrclib = (_blockedUntil[lrclib] || 0) - Date.now();
        delay = Math.max(delay, waitForLrclib);
        retryTimer.interval = delay;
        _attempt++;
        retryTimer.restart();
    }

    function _rememberInMemory(key, result) {
        if (!_cache[key]) {
            _cacheOrder.push(key);
        }
        _cache[key] = result;
        while (_cacheOrder.length > memoryCacheLimit) {
            delete _cache[_cacheOrder.shift()];
        }
    }

    // ---- disk cache --------------------------------------------------------

    function _openDb() {
        try {
            _db = LocalStorage.openDatabaseSync("SpotifyLyricsCache", "", "Lyrics cache for the Spotify Lyrics widget", 50000000);
            _db.transaction(tx => {
                tx.executeSql("CREATE TABLE IF NOT EXISTS lyrics (key TEXT PRIMARY KEY, status TEXT, data TEXT, saved INTEGER)");
            });
        } catch (e) {
            console.warn("[spotify-lyrics] disk cache unavailable:", e);
            _db = null;
        }
    }

    function _dbGet(key) {
        if (!_db) {
            return null;
        }
        let found = null;
        try {
            _db.readTransaction(tx => {
                const rows = tx.executeSql("SELECT status, data, saved FROM lyrics WHERE key = ?", [key]).rows;
                if (rows.length === 0) {
                    return;
                }
                const row = rows.item(0);
                const age = Date.now() - row.saved;
                if (row.status === "none" && age > noneTtl) {
                    return;
                }
                if ((row.status === "plain" || row.status === "instrumental") && age > partialTtl) {
                    return;
                }
                found = { status: row.status, lines: JSON.parse(row.data) };
            });
        } catch (e) {
            console.warn("[spotify-lyrics] cache read failed:", e);
        }
        return found;
    }

    function _dbPut(key, result) {
        if (!_db) {
            return;
        }
        try {
            _db.transaction(tx => {
                tx.executeSql("INSERT OR REPLACE INTO lyrics (key, status, data, saved) VALUES (?, ?, ?, ?)",
                              [key, result.status, JSON.stringify(result.lines), Date.now()]);
                tx.executeSql("DELETE FROM lyrics WHERE key IN (SELECT key FROM lyrics ORDER BY saved DESC LIMIT -1 OFFSET ?)",
                              [diskCacheLimit]);
            });
        } catch (e) {
            console.warn("[spotify-lyrics] cache write failed:", e);
        }
    }

    function _dbDelete(key) {
        if (_db) {
            try {
                _db.transaction(tx => tx.executeSql("DELETE FROM lyrics WHERE key = ?", [key]));
            } catch (e) {}
        }
    }

    function _dbClear() {
        if (_db) {
            try {
                _db.transaction(tx => tx.executeSql("DELETE FROM lyrics"));
            } catch (e) {}
        }
    }

    // ---- lookup --------------------------------------------------------------

    // Resolves with { status, lines, incomplete }; rejects only when every
    // source failed and nothing at all was found.
    function _lookup(want) {
        return _lookupLrclib(want).then(lr => {
            if (lr.result && lr.result.status === "synced") {
                return lr.result;
            }
            if (!useBackupSource) {
                return _finish(lr.result, lr.failed);
            }
            return _delay(lr.requests > 0 ? requestGap : 0)
                .then(() => _lookupNetease(want))
                .then(ne => {
                    if (ne.result) {
                        return ne.result;
                    }
                    return _finish(lr.result, lr.failed || ne.failed);
                });
        });
    }

    function _finish(result, failed) {
        if (!result) {
            if (failed) {
                throw { message: "lyrics sources unreachable or throttling" };
            }
            return { status: "none", lines: [], incomplete: false };
        }
        result.incomplete = failed;
        return result;
    }

    // Resolves with { result, failed, requests }.
    function _lookupLrclib(want) {
        const state = { candidates: {}, failed: false, requests: 0, rateLimited: false };
        const cleaned = Lrc.cleanTitle(want.track);
        const bare = Lrc.bareTitle(want.track);
        const mainArtist = Lrc.primaryArtist(want.artist);

        // Most to least specific; each step only runs if the earlier ones
        // found no acceptable synced lyrics. Searches hit lrclib's own
        // database, so they go before /api/get, which is rate limited harder.
        const steps = [];
        const searches = [];
        const addSearch = (t, a) => {
            const id = t + "|" + a;
            if (t && a && searches.indexOf(id) < 0) {
                searches.push(id);
                steps.push(() => _lrclibRequest("/api/search", { track_name: t, artist_name: a }, state));
            }
        };
        addSearch(want.track, want.artist);
        addSearch(cleaned, want.artist);
        if (want.duration > 0) {
            steps.push(() => {
                const params = { track_name: cleaned, artist_name: want.artist, duration: Math.round(want.duration) };
                if (want.album) {
                    params.album_name = want.album;
                }
                return _lrclibRequest("/api/get", params, state);
            });
        }
        addSearch(cleaned, mainArtist);
        addSearch(bare, mainArtist);
        steps.push(() => _lrclibRequest("/api/search", { q: bare + " " + mainArtist }, state));

        const runFrom = index => {
            const best = _best(state.candidates, want);
            // Once lrclib says "slow down", more requests only extend the ban.
            if ((best && best.status === "synced") || index >= steps.length || state.rateLimited || _isBlocked(lrclib)) {
                return {
                    result: best,
                    failed: state.failed || state.rateLimited || (state.requests === 0 && _isBlocked(lrclib)),
                    requests: state.requests
                };
            }
            const pause = state.requests > 0 ? _delay(requestGap) : Promise.resolve();
            return pause.then(() => steps[index]()).then(() => runFrom(index + 1));
        };
        return runFrom(0);
    }

    function _lrclibRequest(path, params, state) {
        state.requests++;
        return _get(lrclib, lrclib + path + "?" + _query(params), true).then(r => {
            if (r.failed) {
                state.failed = true;
            }
            if (r.busy) {
                state.rateLimited = true;
            }
            const records = !r.value ? [] : Array.isArray(r.value) ? r.value : [r.value];
            records.forEach(rec => {
                if (rec && rec.id !== undefined) {
                    state.candidates[rec.id] = rec;
                }
            });
        });
    }

    // NetEase Cloud Music has synced lyrics for a lot of mainstream music.
    // Resolves with { result (synced only, or null), failed }.
    function _lookupNetease(want) {
        if (_isBlocked(netease)) {
            return Promise.resolve({ result: null, failed: true });
        }
        const query = Lrc.bareTitle(want.track) + " " + Lrc.primaryArtist(want.artist);
        const url = netease + "/api/search/get?" + _query({ s: query, type: 1, limit: 10 });

        return _get(netease, url, false).then(r => {
            // NetEase answers throttled requests with 200 and an error code.
            if (!r.failed && (!r.value || (r.value.code !== undefined && r.value.code !== 200))) {
                console.warn("[spotify-lyrics] NetEase refused the search:", r.value ? r.value.code : "empty");
                r.failed = true;
                _block(netease, 60000);
            }
            const songs = r.value && r.value.result && r.value.result.songs ? r.value.result.songs : [];
            const ranked = songs.map(s => ({
                id: s.id,
                trackName: s.name,
                artistName: (s.artists || []).map(a => a.name).join(", "),
                albumName: s.album ? s.album.name : "",
                duration: s.duration ? s.duration / 1000 : 0
            })).map(c => ({ candidate: c, score: Lrc.score(c, want) }))
              .filter(c => Lrc.acceptable(c.score))
              .sort((a, b) => b.score.total - a.score.total)
              .slice(0, 2);

            const tryFrom = i => {
                if (i >= ranked.length) {
                    return { result: null, failed: r.failed };
                }
                const lyricUrl = netease + "/api/song/lyric?" + _query({ id: ranked[i].candidate.id, lv: 1 });
                return _delay(requestGap).then(() => _get(netease, lyricUrl, false)).then(lr => {
                    const text = lr.value && lr.value.lrc ? lr.value.lrc.lyric : "";
                    const parsed = Lrc.stripCredits(Lrc.parseSynced(text));
                    const timed = parsed.filter(l => l.time > 0).length;
                    if (timed >= 3) {
                        console.debug("[spotify-lyrics] using NetEase lyrics for", want.track);
                        return { result: { status: "synced", lines: parsed }, failed: false };
                    }
                    return tryFrom(i + 1);
                });
            };
            return tryFrom(0);
        });
    }

    function _best(candidates, want) {
        let bestSynced = null;
        let bestPlain = null;
        let bestInstrumental = null;

        for (const id in candidates) {
            const c = candidates[id];
            const s = Lrc.score(c, want);
            if (!Lrc.acceptable(s)) {
                continue;
            }
            if (c.syncedLyrics && (!bestSynced || s.total > bestSynced.score)) {
                bestSynced = { record: c, score: s.total };
            }
            if (c.plainLyrics && (!bestPlain || s.total > bestPlain.score)) {
                bestPlain = { record: c, score: s.total };
            }
            if (c.instrumental && (!bestInstrumental || s.total > bestInstrumental.score)) {
                bestInstrumental = { record: c, score: s.total };
            }
        }

        if (bestSynced) {
            const parsed = Lrc.parseSynced(bestSynced.record.syncedLyrics);
            if (parsed.length > 0) {
                return { status: "synced", lines: parsed };
            }
        }
        if (bestInstrumental && (!bestPlain || bestInstrumental.score >= bestPlain.score)) {
            return { status: "instrumental", lines: [] };
        }
        if (bestPlain && allowUnsynced) {
            return { status: "plain", lines: Lrc.parsePlain(bestPlain.record.plainLyrics) };
        }
        return null;
    }

    // ---- HTTP ----------------------------------------------------------------

    function _query(params) {
        return Object.keys(params)
            .map(k => encodeURIComponent(k) + "=" + encodeURIComponent(params[k]))
            .join("&");
    }

    function _isBlocked(host) {
        return (_blockedUntil[host] || 0) > Date.now();
    }

    function _block(host, ms) {
        const until = Date.now() + ms;
        if ((_blockedUntil[host] || 0) < until) {
            _blockedUntil[host] = until;
        }
    }

    function _delay(ms) {
        if (ms <= 0) {
            return Promise.resolve();
        }
        return new Promise(resolve => {
            const timer = Qt.createQmlObject("import QtQuick; Timer { repeat: false }", root, "delay");
            timer.interval = ms;
            timer.triggered.connect(() => {
                timer.destroy();
                resolve();
            });
            timer.start();
        });
    }

    // Resolves (never rejects) with { value, failed, busy }. 404 is a normal
    // "not found". 429/5xx put the host on a cool-down so later lookups don't
    // pile on; Retry-After is honoured when the server sends it.
    function _get(host, url, identify) {
        if (_isBlocked(host)) {
            return Promise.resolve({ value: null, failed: true, busy: true });
        }

        return new Promise(resolve => {
            const xhr = new XMLHttpRequest();
            let finished = false;
            const timer = Qt.createQmlObject("import QtQuick; Timer { repeat: false }", root, "requestTimeout");
            const finish = (value, failed, reason, busy) => {
                if (finished) {
                    return;
                }
                finished = true;
                timer.stop();
                timer.destroy();
                if (failed) {
                    console.warn("[spotify-lyrics]", reason, url);
                }
                resolve({ value: value, failed: failed, busy: !!busy });
            };

            timer.interval = requestTimeout;
            timer.triggered.connect(() => {
                finish(null, true, "timed out:");
                xhr.abort();
            });

            xhr.onreadystatechange = () => {
                if (xhr.readyState !== XMLHttpRequest.DONE) {
                    return;
                }
                if (xhr.status === 200) {
                    try {
                        finish(JSON.parse(xhr.responseText), false);
                    } catch (e) {
                        finish(null, true, "bad JSON from");
                    }
                } else if (xhr.status === 404) {
                    finish(null, false);
                } else {
                    const busy = xhr.status === 429 || (xhr.status >= 500 && xhr.status <= 504);
                    if (busy) {
                        const retryAfter = parseInt(xhr.getResponseHeader("Retry-After"), 10);
                        _block(host, retryAfter > 0 ? retryAfter * 1000 : 60000);
                    }
                    finish(null, true, "HTTP " + xhr.status + " from", busy);
                }
            };

            console.debug("[spotify-lyrics] GET", url);
            xhr.open("GET", url);
            if (identify) {
                xhr.setRequestHeader("Lrclib-Client", "plasmoid-spotify-lyrics (https://github.com/LabyStudio/plasmoid-spotify)");
            }
            xhr.send();
            timer.start();
        });
    }
}
