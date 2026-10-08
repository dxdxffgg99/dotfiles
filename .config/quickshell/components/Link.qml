import QtQuick
import qs

// Underlined text link in the reedge.xyz style: small uppercase mono label, hairline underline,
// grey -> bright on hover, and the arrow slides out a little.
Item {
    id: root

    property string label: ""
    property color tone: Theme.muted
    property bool arrow: false
    signal clicked()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight + 7

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.clicked() }

    Row {
        id: row
        spacing: hover.hovered ? 10 : 6
        Behavior on spacing { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        Text {
            text: root.label
            color: hover.hovered ? Theme.fg : root.tone
            font.family: Theme.font
            font.pixelSize: 11
            font.letterSpacing: 1.3
            font.capitalization: Font.AllUppercase
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Text {
            visible: root.arrow
            text: "→"
            color: hover.hovered ? Theme.fg : root.tone
            font.family: Theme.font
            font.pixelSize: 11
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: hover.hovered ? Theme.fg : root.tone
        opacity: hover.hovered ? 1 : 0.6
        Behavior on color { ColorAnimation { duration: 300 } }
    }
}
