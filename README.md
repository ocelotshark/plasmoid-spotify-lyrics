# Spotify Lyrics for KDE Plasma 6

A desktop/panel widget that shows what's playing in Spotify with **synced lyrics** beside the album art, plus
lots of ways to style it.

By Wesley Berthelot. Inspired by [plasmoid-spotify](https://github.com/LabyStudio/plasmoid-spotify) by
LabyStudio.

## Features

### Lyrics
- Synced lyrics from [lrclib.net](https://lrclib.net), with [NetEase](https://music.163.com) as a backup source
  (optional).
- Matching handles remasters, "feat."/"with" credits and multiple artists, and scores results against the song's
  length so the wrong song isn't picked.
- Lyrics are cached on disk, so a song only needs the network once. If a server is busy, the widget backs off
  and retries quietly. Right-click → **Reload Lyrics** forces a new lookup.
- Falls back to unsynced lyrics (scrolled with the song) and recognises instrumentals. If nothing is found, the
  lyrics area simply stays blank.
- 15 effects for the current line: glow, drop shadow, grow, bounce, pulse, fade, slide, blur, neon, letter
  spread, karaoke fill, typewriter, wave, rainbow and shimmer.
- Colors: theme, custom or picked from the album art, with brightness/opacity controls and a separate color for
  the other lines.

### Layout
- Lyrics on the left or right of the album art. Title/artist opposite the lyrics or on either side.
- The album art never moves: the lyric and title columns keep their width even when a song has no lyrics.
- Adjustable distance from the art, text alignment, top/middle/bottom alignment for the title and artist, and
  scroll/wrap/cut-off for long titles.

### Title and artist
- Theme, custom or album colors, brightness and opacity.
- Always-on effects: glow, neon, pulse, breathe, float, shimmer, rainbow, album-color gradient, color shift,
  outline and glitch.

### Album art
- Corner rounding from square to circle; hover over the art for previous / play-pause / next.
- Animated borders: solid, pulse, glow, breathing glow, rotating gradient, rainbow, neon, heartbeat, color
  cycle, shine sweep, ripple, sparkle, song progress ring, aurora halo, glitch and double ring. They can sit
  outside the art or over its edge, and can react to the music.
- Music visualizers: spectrum bars, wave outline, equalizer, bass ring, beat ripples, beat sparks, loudness glow
  and bass bloom.

### Background
- Transparent background on the desktop.
- A soft blur of the wallpaper that hugs the visible lyrics (optionally the title and artist) and glides with
  them as they scroll.
- Drop shadow for the lyrics, title and artist.

### Controls
- Left-click opens Spotify, middle-click plays/pauses, scroll changes the volume, and the mouse back/forward
  buttons skip tracks.

## Requirements

- KDE Plasma 6.
- Spotify (or set another player under **Advanced → Player identity**).
- Optional, for the music-reactive effects: [cava](https://github.com/karlstav/cava) and Python 3
  (`sudo pacman -S cava`, `sudo apt install cava`, `sudo dnf install cava`). The widget runs a small helper
  (`contents/code/audio.py`) that reads your system's audio output through cava. It only runs while a music
  effect is on and something is playing, and quits by itself afterwards.

## Install

**From Plasma:** right-click the desktop → **Add Widgets…** → **Get New Widgets…** → **Download New Plasma
Widgets**, then search for "Spotify Lyrics".

**From a release:** download the `.plasmoid` file from the
[releases page](../../releases) and run:

```bash
kpackagetool6 -t Plasma/Applet -i spotify-lyrics-2.0.0.plasmoid
```

**From source:**

```bash
git clone https://github.com/ocelotshark/plasmoid-spotify-lyrics.git
cd plasmoid-spotify-lyrics
kpackagetool6 -t Plasma/Applet -i src
```

To update an existing install, use `-u` instead of `-i`. If the widget doesn't appear in **Add Widgets…**, restart
Plasma:

```bash
systemctl --user restart plasma-plasmashell
```

## Building the package

```bash
bsdtar --format zip -cf spotify-lyrics-2.0.0.plasmoid -C src .
```

## Credits

- Inspired by [LabyStudio/plasmoid-spotify](https://github.com/LabyStudio/plasmoid-spotify).
- Lyrics: [lrclib.net](https://lrclib.net) and NetEase Cloud Music.
- Audio spectrum: [cava](https://github.com/karlstav/cava).

## License

[MIT](LICENSE) © 2026 Wesley Berthelot
