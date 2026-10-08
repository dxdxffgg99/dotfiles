import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

// Power menu: `qs ipc call shell session` (Super+X). Hairline grid like the product cells on reedge.xyz.
Scope {
    PanelWindow {
        id: win
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        implicitWidth: 640
        implicitHeight: 190
        visible: Drawers.power || card.opacity > 0
        WlrLayershell.namespace: "qs-session"
        WlrLayershell.keyboardFocus: Drawers.power ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        readonly property var actions: [
            { label: "Lock", hint: "L", key: Qt.Key_L, cmd: ["sh", "-c", "BRV=$(brightnessctl get) && brightnessctl set 75% && hyprlock; brightnessctl set $BRV"] },
            { label: "Logout", hint: "E", key: Qt.Key_E, cmd: ["loginctl", "terminate-user", Quickshell.env("USER")] },
            { label: "Sleep", hint: "S", key: Qt.Key_S, cmd: ["systemctl", "suspend"] },
            { label: "Reboot", hint: "R", key: Qt.Key_R, cmd: ["systemctl", "reboot"] },
            { label: "Shutdown", hint: "P", key: Qt.Key_P, cmd: ["systemctl", "poweroff"] }
        ]

        function run(a) {
            Drawers.closeAll();
            Quickshell.execDetached(a.cmd);
        }

        Card {
            id: card
            anchors.fill: parent
            opacity: Drawers.power ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            focus: true
            Keys.onEscapePressed: Drawers.closeAll()
            Keys.onPressed: event => {
                for (const a of win.actions) {
                    if (event.key === a.key) { win.run(a); return; }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 14

                Text {
                    text: "Session"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                    font.letterSpacing: 2.2
                    font.capitalization: Font.AllUppercase
                }

                // 1px gaps over a hairline background = hairline grid
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.hairline
                    border.width: 1
                    border.color: Theme.hairline

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 1
                        spacing: 1

                        Repeater {
                            model: win.actions
                            delegate: Rectangle {
                                id: cell
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: hover.hovered ? Theme.surface : Theme.inset
                                Behavior on color { ColorAnimation { duration: 300 } }

                                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: win.run(cell.modelData) }

                                Text {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 14
                                    text: "0" + (cell.index + 1)
                                    color: Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                    font.letterSpacing: 1
                                }
                                Text {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 14
                                    text: cell.modelData.label
                                    color: hover.hovered ? (cell.modelData.label === "Shutdown" ? Theme.crit : Theme.fg) : Theme.muted
                                    font.family: Theme.display
                                    font.pixelSize: 15
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 14
                                    text: cell.modelData.hint
                                    color: Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                    font.letterSpacing: 1.4
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
