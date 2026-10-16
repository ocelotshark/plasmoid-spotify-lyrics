import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "Layout"
        icon: "view-split-left-right"
        source: "ConfigLayout.qml"
    }
    ConfigCategory {
        name: "Lyrics"
        icon: "view-media-lyrics"
        source: "ConfigLyrics.qml"
    }
    ConfigCategory {
        name: "Title & Artist"
        icon: "format-text-bold"
        source: "ConfigTrack.qml"
    }
    ConfigCategory {
        name: "Album Art"
        icon: "view-media-album-cover"
        source: "ConfigArt.qml"
    }
    ConfigCategory {
        name: "Background & Shadow"
        icon: "preferences-desktop-wallpaper"
        source: "ConfigBackground.qml"
    }
    ConfigCategory {
        name: "Advanced"
        icon: "preferences-other"
        source: "ConfigAdvanced.qml"
    }
}
