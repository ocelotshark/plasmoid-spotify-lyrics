.pragma library

// Pure helpers for parsing LRC lyrics and fuzzy-matching track metadata.
// Kept free of QML imports so they can be tested outside of Plasma.

// Parses synced LRC text into [{ time: seconds, text }] sorted by time.
// Handles [mm:ss], [mm:ss.x], [mm:ss.xx], [mm:ss.xxx], [mm:ss:xx],
// several timestamps on one line, enhanced-LRC word tags and [offset:±ms].
function parseSynced(text) {
    if (!text) {
        return [];
    }

    const stamp = /^\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]/;
    const lines = String(text).split(/\r?\n/);
    const out = [];
    let offset = 0;

    for (let i = 0; i < lines.length; i++) {
        let rest = lines[i].trim();

        const offsetTag = rest.match(/^\[offset:\s*([+-]?\d+)\s*\]$/i);
        if (offsetTag) {
            offset = parseInt(offsetTag[1], 10) / 1000;
            continue;
        }

        const times = [];
        let m;
        while ((m = stamp.exec(rest)) !== null) {
            const fraction = m[3] ? parseInt(m[3], 10) / Math.pow(10, m[3].length) : 0;
            times.push(parseInt(m[1], 10) * 60 + parseInt(m[2], 10) + fraction);
            rest = rest.slice(m[0].length);
        }
        if (times.length === 0) {
            continue;
        }

        const lineText = rest.replace(/<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>/g, "").trim();
        for (let t = 0; t < times.length; t++) {
            out.push({ time: Math.max(0, times[t] - offset), text: lineText, order: out.length });
        }
    }

    out.sort((a, b) => a.time - b.time || a.order - b.order);
    return out.map(l => ({ time: l.time, text: l.text }));
}

// Parses unsynced lyrics into [{ time: -1, text }], dropping leading/trailing blanks.
function parsePlain(text) {
    if (!text) {
        return [];
    }
    const lines = String(text).split(/\r?\n/).map(l => l.trim());
    while (lines.length > 0 && lines[0] === "") lines.shift();
    while (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();
    return lines.map(l => ({ time: -1, text: l }));
}

// Index of the last line whose time is <= position (seconds), or -1.
function lineIndexAt(lines, position) {
    let lo = 0;
    let hi = lines.length - 1;
    let found = -1;
    while (lo <= hi) {
        const mid = (lo + hi) >> 1;
        if (lines[mid].time <= position) {
            found = mid;
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }
    return found;
}

function stripDiacritics(s) {
    try {
        return s.normalize("NFKD").replace(/[\u0300-\u036f]/g, "");
    } catch (e) {
        return s;
    }
}

// Lowercase, accent-free, punctuation-free form used for comparisons.
function normalize(s) {
    if (!s) {
        return "";
    }
    return stripDiacritics(String(s).toLowerCase())
        .replace(/&/g, " and ")
        .replace(/[’'`´]/g, "")
        .replace(/[\s!-\/:-@\[-`{-~\u00a1-\u00bf\u2000-\u206f\u3000-\u303f\uff01-\uff0f]+/g, " ")
        .trim();
}

const versionWords = "remaster|remastered|live|version|edit|mix|remix|mono|stereo|deluxe|bonus|acoustic|demo|"
    + "from|feat|ft|featuring|with|edition|single|explicit|clean|original|extended|radio|anniversary|re-recorded|"
    + "taylor's|sped up|slowed|reverb";

// Removes " - Remastered 2011", "(feat. X)", "[Live]" and similar decorations.
function cleanTitle(s) {
    if (!s) {
        return "";
    }
    let t = String(s);
    const words = new RegExp("\\b(" + versionWords + ")\\b", "i");

    // Parenthesised / bracketed groups that look like version info.
    t = t.replace(/\s*[(\[]([^()\[\]]*)[)\]]/g, (whole, inner) => words.test(inner) ? "" : whole);
    // " - Something Remastered" style suffixes.
    t = t.replace(/\s+[-–—]\s+(.*)$/, (whole, tail) => words.test(tail) ? "" : whole);
    // Bare "feat. X" without brackets.
    t = t.replace(/\s+(feat\.?|ft\.?|featuring)\s+.*$/i, "");
    return t.trim() || String(s).trim();
}

// Drops every bracketed group and dash suffix: last-resort search title.
function bareTitle(s) {
    const t = String(s || "")
        .replace(/\s*[(\[][^()\[\]]*[)\]]/g, "")
        .replace(/\s+[-–—]\s+.*$/, "")
        .trim();
    return t || cleanTitle(s);
}

// First credited artist: "A, B & C feat. D" -> "A".
function primaryArtist(s) {
    if (!s) {
        return "";
    }
    const first = String(s).split(/\s*(?:,|;|\/|\s&\s|\sx\s|\bfeat\.?\s|\bft\.?\s|\bfeaturing\s|\bwith\s)\s*/i)[0];
    return (first || String(s)).trim();
}

function tokenOverlap(a, b) {
    const ta = a.split(" ").filter(Boolean);
    const tb = b.split(" ").filter(Boolean);
    if (ta.length === 0 || tb.length === 0) {
        return 0;
    }
    const setB = {};
    tb.forEach(t => setB[t] = true);
    const shared = ta.filter(t => setB[t]).length;
    return shared / Math.max(ta.length, tb.length);
}

function similarity(a, b) {
    if (!a || !b) {
        return 0;
    }
    if (a === b) {
        return 1;
    }
    if (a.indexOf(b) >= 0 || b.indexOf(a) >= 0) {
        return 0.8;
    }
    return tokenOverlap(a, b) * 0.7;
}

// Scores an lrclib record against what the player reports.
// Returns { total, title, artist, duration }.
function score(candidate, want) {
    const title = similarity(normalize(cleanTitle(candidate.trackName || candidate.name)), normalize(cleanTitle(want.track)));
    const fullArtist = similarity(normalize(candidate.artistName), normalize(want.artist));
    const mainArtist = similarity(normalize(primaryArtist(candidate.artistName)), normalize(primaryArtist(want.artist)));
    const artist = Math.max(fullArtist, mainArtist * 0.9);

    let duration = 0;
    if (want.duration > 0 && candidate.duration > 0) {
        const diff = Math.abs(candidate.duration - want.duration);
        duration = diff <= 2 ? 1 : diff <= 5 ? 0.6 : diff <= 10 ? 0.1 : diff <= 20 ? -0.5 : -1.5;
    }

    const album = want.album && normalize(candidate.albumName) === normalize(want.album) ? 1 : 0;
    return {
        total: title * 40 + artist * 30 + duration * 30 + album * 5,
        title: title,
        artist: artist,
        duration: duration
    };
}

function acceptable(s) {
    return s.title >= 0.5 && s.artist >= 0.5 && s.duration > -0.5 && s.total >= 50;
}

// Drops the credit lines NetEase puts at the top of its LRC files
// ("作词 : Someone", "Producer : Someone", ...).
function stripCredits(lines) {
    const credit = /^(作词|作曲|编曲|制作人?|混音|母带|和声|录音|监制|出品|吉他|贝斯|鼓|弦乐|lyricist|lyrics|composer|composed|producer|produced|arranger|arranged|written|mixed|mastered|engineer)[^:：]{0,20}[:：]/i;
    const spacedColon = /^[^:：]{1,30}\s[:：]\s\S/;
    return lines.filter((line, i) => !(i < 12 && (credit.test(line.text) || spacedColon.test(line.text))));
}
