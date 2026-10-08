import QtQuick
import qs

// Hairline slider: uppercase mono label, a 2px line that fills, mono percentage.
// `value` is 0..1; emits `moved(v)` while dragging.
Item {
    id: root

    property real value: 0
    property color fill: Theme.fg
    property string label: ""
    property string icon: ""      // kept for callers that still pass a glyph; used when no label is set
    property bool interactive: true
    signal moved(real v)
    signal iconClicked()

    implicitHeight: 30
    implicitWidth: 200

    Text {
        id: ico
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        text: root.label !== "" ? root.label : root.icon
        color: hoverIco.hovered && root.interactive ? Theme.fg : Theme.muted
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.8
        font.capitalization: Font.AllUppercase
        Behavior on color { ColorAnimation { duration: 300 } }

        HoverHandler { id: hoverIco; cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: root.interactive; onTapped: root.iconClicked() }
    }

    Rectangle {
        id: track
        anchors.left: ico.right
        anchors.right: pct.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 2
        color: Theme.hairline

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            color: root.fill
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }

    Text {
        id: pct
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100) + "%"
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: 11
    }

    MouseArea {
        anchors.fill: track
        anchors.topMargin: -12
        anchors.bottomMargin: -12
        enabled: root.interactive
        function emitAt(x) { root.moved(Math.max(0, Math.min(1, x / track.width))) }
        onPressed: mouse => emitAt(mouse.x)
        onPositionChanged: mouse => { if (pressed) emitAt(mouse.x) }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
