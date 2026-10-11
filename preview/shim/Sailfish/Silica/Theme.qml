pragma Singleton
import QtQuick 2.6

// Values of a 540x960 Sailfish device at scale 1.0, dark ambience.
QtObject {
    readonly property real paddingSmall: 6
    readonly property real paddingMedium: 12
    readonly property real paddingLarge: 24
    readonly property real horizontalPageMargin: 24
    readonly property real itemSizeExtraSmall: 70
    readonly property real itemSizeSmall: 80
    readonly property real itemSizeMedium: 100
    readonly property real itemSizeLarge: 110
    readonly property real itemSizeExtraLarge: 135
    readonly property real itemSizeHuge: 180
    readonly property real iconSizeExtraSmall: 32
    readonly property real iconSizeSmall: 48
    readonly property real iconSizeMedium: 64
    readonly property real fontSizeTiny: 20
    readonly property real fontSizeExtraSmall: 24
    readonly property real fontSizeSmall: 28
    readonly property real fontSizeMedium: 32
    readonly property real fontSizeLarge: 40
    readonly property real fontSizeExtraLarge: 50
    readonly property real fontSizeHuge: 64
    readonly property color primaryColor: "#ffffff"
    readonly property color secondaryColor: "#b3ffffff"
    readonly property color highlightColor: "#72c8f7"
    readonly property color secondaryHighlightColor: "#4c9ac4"
    readonly property color highlightBackgroundColor: "#3a7da6"
    readonly property color highlightDimmerColor: "#0d2533"
    readonly property color overlayBackgroundColor: "#1a2128"
    readonly property color errorColor: "#ff4d4d"
    readonly property real highlightBackgroundOpacity: 0.3
    readonly property real opacityFaint: 0.2
    readonly property real opacityLow: 0.4
    readonly property real opacityHigh: 0.6
    readonly property real opacityOverlay: 0.8
    readonly property real pixelRatio: 1.0
    readonly property string fontFamily: "DejaVu Sans"
    readonly property string fontFamilyHeading: "DejaVu Sans"

    function rgba(c, alpha) {
        var col = Qt.darker(c, 1.0)
        return Qt.rgba(col.r, col.g, col.b, alpha)
    }
}
