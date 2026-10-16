.pragma library

// Picks readable lyric colors from a Kirigami.ImageColors palette.

function channel(v) {
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

function luminance(c) {
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

function contrast(a, b) {
    const la = luminance(a);
    const lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

// Lightens (on dark backgrounds) or darkens (on light ones) until the color
// reaches the given contrast ratio, keeping its hue and saturation.
function readable(color, background, minRatio) {
    const hue = Math.max(0, color.hslHue);
    const saturation = color.hslSaturation;
    let lightness = color.hslLightness;
    const darkBackground = luminance(background) < 0.4;

    for (let i = 0; i < 30; i++) {
        const candidate = Qt.hsla(hue, saturation, lightness, 1);
        if (contrast(candidate, background) >= minRatio) {
            return candidate;
        }
        lightness = darkBackground ? Math.min(1, lightness + 0.035) : Math.max(0, lightness - 0.035);
    }
    return darkBackground ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1);
}

function hueDistance(a, b) {
    const d = Math.abs(Math.max(0, a.hslHue) - Math.max(0, b.hslHue));
    return Math.min(d, 1 - d);
}

// Returns { primary, secondary }: the most prominent colorful swatch and a
// second, visibly different one, both adjusted to read on `background`.
function fromPalette(palette, fallback, background) {
    background = Qt.lighter(background, 1.0);   // accept "#rrggbb" strings too
    fallback = Qt.lighter(fallback, 1.0);
    const entries = [];
    for (let i = 0; palette && i < palette.length; i++) {
        if (palette[i] && palette[i].color !== undefined) {
            entries.push(palette[i]);
        }
    }
    entries.sort((a, b) => b.ratio - a.ratio);

    const colorful = entries.filter(e => e.color.hslSaturation > 0.2);
    const ordered = colorful.concat(entries.filter(e => e.color.hslSaturation <= 0.2));

    const primary = ordered.length > 0 ? ordered[0].color : fallback;
    let secondary = primary;
    for (let i = 1; i < ordered.length; i++) {
        const c = ordered[i].color;
        if (hueDistance(c, primary) > 0.08 || Math.abs(c.hslLightness - primary.hslLightness) > 0.25) {
            secondary = c;
            break;
        }
    }

    return {
        primary: readable(primary, background, 4.5),
        secondary: readable(secondary, background, 3)
    };
}

// Applies a brightness shift (-100 = black, 0 = unchanged, +100 = white) and
// an opacity (0..100 %) to a color.
function tone(color, brightness, opacity) {
    const c = Qt.lighter(color, 1.0);
    const b = Math.max(-100, Math.min(100, brightness || 0)) / 100;
    const shift = v => b >= 0 ? v + (1 - v) * b : v * (1 + b);
    const alpha = c.a * Math.max(0, Math.min(100, opacity === undefined ? 100 : opacity)) / 100;
    return Qt.rgba(shift(c.r), shift(c.g), shift(c.b), alpha);
}
