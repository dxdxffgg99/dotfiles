pragma Singleton
import QtQuick
import Quickshell

// GitHub Dark Colorblind (Primer tokens). Positive = blue, negative = orange, so nothing relies on red/green.
Singleton {
    readonly property color bg: "#f20d1117"        // bgColor-default
    readonly property color bgAlt: "#ff21262d"     // controls / tracks
    readonly property color surface: "#ff151b23"   // bgColor-muted
    readonly property color hover: "#ff262c36"     // control-bgColor-hover
    readonly property color inset: "#ff010409"     // bgColor-inset
    readonly property color border: "#803d444d"    // borderColor-default
    readonly property color hairline: "#ff30363d"
    readonly property color fg: "#f0f6fc"          // fgColor-default
    readonly property color fgSoft: "#c9d1d9"
    readonly property color muted: "#9198a1"       // fgColor-muted
    readonly property color accent: "#58a6ff"      // fgColor-success / accent (blue)
    readonly property color accent2: "#39c5cf"     // teal
    readonly property color purple: "#bc8cff"
    readonly property color warn: "#d29922"        // fgColor-attention
    readonly property color crit: "#f0883e"        // fgColor-danger (orange in the colorblind theme)

    readonly property int radius: 0
    readonly property int pad: 22
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string fontKr: "Noto Sans Mono CJK KR"
    readonly property string display: "The Jamsil 6 ExtraBold"   // headings (reedge-style), installed in ~/.local/share/fonts
}
