import QtQuick
import QtQuick.Shapes

// The album art's rounded outline as a stroked path, so effects can trim it
// (comets, progress) or dash it (marching ants, orbiting dots) along the
// real shape.
Shape {
    id: outline

    property real lineWidth: 3
    property real cornerRadius: 8
    property color defaultColor: "white"
    property color strokeColor: defaultColor
    property real strokeWidth: lineWidth
    property real trimStart: 0
    property real trimEnd: 1
    property real trimOffset: 0
    property bool dashed: false
    property var dashes: [2, 2]
    property real dashOffset: 0
    property int cap: ShapePath.RoundCap

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: outline.strokeColor
        strokeWidth: outline.strokeWidth
        fillColor: "transparent"
        capStyle: outline.cap
        strokeStyle: outline.dashed ? ShapePath.DashLine : ShapePath.SolidLine
        dashPattern: outline.dashes
        dashOffset: outline.dashOffset
        trim.start: outline.trimStart
        trim.end: outline.trimEnd
        trim.offset: outline.trimOffset

        PathRectangle {
            x: outline.lineWidth / 2
            y: outline.lineWidth / 2
            width: outline.width - outline.lineWidth
            height: outline.height - outline.lineWidth
            radius: Math.max(0, outline.cornerRadius - outline.lineWidth / 2)
        }
    }
}
