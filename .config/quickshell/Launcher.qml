import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// Shortcut launcher: lists ~/.local/short and runs the chosen entry with `setsid -f` (Super+Space).
// Same behaviour the old `ls ~/.local/short | rofi -dmenu | xargs setsid -f` bind had.
Scope {
    PanelWindow {
        id: win
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        implicitWidth: 560
        implicitHeight: 62 + Math.max(1, Math.min(results.length, 9)) * 48 + 2
        visible: Drawers.launcher || card.opacity > 0
        WlrLayershell.namespace: "qs-launcher"
        WlrLayershell.keyboardFocus: Drawers.launcher ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible && Drawers.launcher) { input.text = ""; list.currentIndex = 0; list.positionViewAtBeginning(); input.forceActiveFocus(); lister.running = true }

        readonly property string shortDir: Quickshell.env("HOME") + "/.local/short"
        property var names: []

        // re-read the folder every time the launcher opens, so new shortcuts show up immediately
        Process {
            id: lister
            command: ["ls", "-1", "--", win.shortDir]
            stdout: StdioCollector {
                onStreamFinished: win.names = text.split("\n").filter(n => n !== "")
            }
        }

        readonly property var results: {
            const q = input.text.trim().toLowerCase();
            if (q === "") return names;
            const starts = names.filter(n => n.toLowerCase().startsWith(q));
            const has = names.filter(n => !n.toLowerCase().startsWith(q) && n.toLowerCase().includes(q));
            return starts.concat(has);
        }

        function launch(name) {
            if (!name) return;
            Drawers.closeAll();
            Quickshell.execDetached(["setsid", "-f", shortDir + "/" + name]);
        }

        Card {
            id: card
            anchors.fill: parent
            opacity: Drawers.launcher ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // prompt line
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 62

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        spacing: 12

                        Text {
                            text: "›"
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: 18
                        }
                        TextInput {
                            id: input
                            Layout.fillWidth: true
                            color: Theme.fg
                            font.family: Theme.fontKr
                            font.pixelSize: 16
                            selectionColor: "#1f6feb"
                            clip: true
                            focus: true
                            onTextChanged: list.currentIndex = 0

                            Keys.onEscapePressed: Drawers.closeAll()
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            Keys.onUpPressed: list.decrementCurrentIndex()
                            Keys.onTabPressed: list.incrementCurrentIndex()
                            Keys.onReturnPressed: win.launch(win.results[list.currentIndex])
                            Keys.onEnterPressed: win.launch(win.results[list.currentIndex])

                            Text {
                                visible: input.text === "" && !input.preeditText
                                text: "검색"
                                color: Theme.muted
                                font: input.font
                            }
                        }
                        Text {
                            text: "Esc"
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 10
                            font.letterSpacing: 1.6
                            font.capitalization: Font.AllUppercase
                        }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.hairline }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: win.results
                    currentIndex: 0
                    highlightMoveDuration: 0
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool lit: ListView.isCurrentItem || hover.hovered

                        width: list.width
                        height: 48
                        color: lit ? Theme.surface : "transparent"
                        Behavior on color { ColorAnimation { duration: 250 } }

                        HoverHandler { id: hover }
                        TapHandler { onTapped: win.launch(row.modelData) }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 24
                            anchors.rightMargin: 24
                            spacing: 14

                            Text {
                                text: row.index < 9 ? "0" + (row.index + 1) : String(row.index + 1)
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 10
                                font.letterSpacing: 1
                                Layout.preferredWidth: 18
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData
                                color: row.lit ? Theme.fg : Theme.fgSoft
                                font.family: Theme.fontKr
                                font.pixelSize: 14
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 250 } }
                            }
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.hairline; opacity: 0.6 }
                    }
                }
            }
        }
    }
}
