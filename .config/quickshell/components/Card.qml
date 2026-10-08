import QtQuick
import qs

// Flat near-black surface with a hairline border: the shared look of every drawer (reedge.xyz style).
Rectangle {
    color: Qt.alpha(Theme.inset, 0.97)
    radius: 0
    border.width: 1
    border.color: Theme.hairline
}
