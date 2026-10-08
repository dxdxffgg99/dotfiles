import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs
import qs.components

// Drops down from the top edge (hover the edge strip, or `qs ipc call shell dashboard` / Super+D).
// Look: reedge.xyz — near-black, hairline rules between columns, uppercase mono eyebrows, text links.
Scope {
    id: root

    // Thin invisible strip at the top-centre of the screen that opens the dashboard on hover.
    PanelWindow {
        anchors.top: true
        implicitWidth: 420
        implicitHeight: 3
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "qs-dashboard-edge"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                if (!Drawers.dashboard) {
                    Drawers.closeAll();
                    Drawers.dashboard = true;
                }
            }
        }
    }

    PanelWindow {
        id: win
        anchors.top: true
        margins.top: 10
        implicitWidth: 760
        implicitHeight: card.height
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: Drawers.dashboard || card.y > -card.height
        WlrLayershell.namespace: "qs-dashboard"

        onVisibleChanged: Stats.active = visible

        readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
        readonly property var sink: Pipewire.defaultAudioSink
        readonly property var bat: UPower.displayDevice

        PwObjectTracker { objects: [win.sink] }

        // Closes shortly after the mouse leaves. If it was opened by keybind and never hovered,
        // the idle timer closes it instead, so it can't get stuck open.
        property bool hoveredOnce: false

        Timer {
            id: leaveTimer
            interval: 350
            onTriggered: Drawers.dashboard = false
        }
        Timer {
            id: idleTimer
            interval: 5000
            running: Drawers.dashboard && !win.hoveredOnce
            onTriggered: Drawers.dashboard = false
        }
        Connections {
            target: Drawers
            function onDashboardChanged() { if (Drawers.dashboard) win.hoveredOnce = false }
        }

        component Eyebrow: Text {
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 10
            font.letterSpacing: 2.2
            font.capitalization: Font.AllUppercase
        }

        Card {
            id: card
            width: parent.width
            height: content.implicitHeight + Theme.pad * 2
            y: Drawers.dashboard ? 0 : -height - 20
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) { win.hoveredOnce = true; leaveTimer.stop() }
                    else leaveTimer.restart()
                }
            }

            RowLayout {
                id: content
                anchors.fill: parent
                anchors.margins: Theme.pad
                spacing: 24

                // ── time ────────────────────────────────────────
                ColumnLayout {
                    Layout.preferredWidth: 170
                    Layout.alignment: Qt.AlignTop
                    spacing: 6

                    SystemClock { id: clock; precision: SystemClock.Seconds }

                    Eyebrow { text: "Time" }
                    Text {
                        Layout.topMargin: 6
                        text: Qt.formatTime(clock.date, "HH:mm")
                        color: Theme.fg
                        font.family: Theme.display
                        font.pixelSize: 46
                    }
                    Text {
                        text: Qt.locale("ko_KR").toString(clock.date, "M월 d일 dddd")
                        color: Theme.fgSoft
                        font.family: Theme.fontKr
                        font.pixelSize: 13
                    }

                    Item { Layout.preferredHeight: 14 }

                    Eyebrow {
                        visible: win.bat && win.bat.isLaptopBattery
                        text: "Battery"
                    }
                    Text {
                        visible: win.bat && win.bat.isLaptopBattery
                        readonly property bool charging: win.bat && win.bat.state === UPowerDeviceState.Charging
                        readonly property real p: win.bat ? win.bat.percentage : 0
                        text: Math.round(p * 100) + "%" + (charging ? "  ↑ charging" : "")
                        color: p < 0.2 && !charging ? Theme.crit : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 13
                    }
                    Eyebrow { Layout.topMargin: 6; text: "Network" }
                    Text {
                        text: Stats.network || "offline"
                        color: Stats.network ? Theme.fg : Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        Layout.maximumWidth: 170
                    }
                }

                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.hairline }

                // ── now playing ─────────────────────────────────
                ColumnLayout {
                    Layout.preferredWidth: 190
                    Layout.alignment: Qt.AlignTop
                    spacing: 8

                    Eyebrow { text: "Now playing" }

                    Rectangle {
                        Layout.topMargin: 6
                        implicitWidth: 120
                        implicitHeight: 120
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.hairline
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: win.player ? win.player.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "—"
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 24
                            visible: !win.player || !win.player.trackArtUrl
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        text: win.player ? (win.player.trackTitle || "Unknown") : "재생 중인 미디어 없음"
                        color: win.player ? Theme.fg : Theme.muted
                        font.family: Theme.fontKr
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: win.player ? win.player.trackArtist : ""
                        color: Theme.muted
                        font.family: Theme.fontKr
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        Layout.topMargin: 6
                        spacing: 16
                        enabled: win.player !== null
                        opacity: enabled ? 1 : 0.4

                        Link { label: "Prev"; onClicked: if (win.player) win.player.previous() }
                        Link {
                            label: win.player && win.player.isPlaying ? "Pause" : "Play"
                            tone: Theme.fg
                            onClicked: if (win.player) win.player.togglePlaying()
                        }
                        Link { label: "Next"; onClicked: if (win.player) win.player.next() }
                    }
                }

                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.hairline }

                // ── system ──────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 8

                    Eyebrow { text: "System" }

                    Slider {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        label: win.sink && win.sink.audio && win.sink.audio.muted ? "Muted" : "Volume"
                        fill: Theme.accent
                        value: win.sink && win.sink.audio ? win.sink.audio.volume : 0
                        onMoved: v => { if (win.sink && win.sink.audio) win.sink.audio.volume = v }
                        onIconClicked: { if (win.sink && win.sink.audio) win.sink.audio.muted = !win.sink.audio.muted }
                    }
                    Slider {
                        Layout.fillWidth: true
                        label: "Bright"
                        fill: Theme.warn
                        value: Brightness.value
                        onMoved: v => Brightness.set(v)
                    }
                    Slider {
                        Layout.fillWidth: true
                        label: "CPU"
                        fill: Theme.accent2
                        value: Stats.cpu
                        interactive: false
                    }
                    Slider {
                        Layout.fillWidth: true
                        label: "Mem"
                        fill: Theme.crit
                        value: Stats.mem
                        interactive: false
                    }

                    // ── power profile (tlp-pd via UPower's PowerProfiles API) ──
                    Eyebrow { Layout.topMargin: 10; text: "Power" }
                    RowLayout {
                        spacing: 22

                        Repeater {
                            model: [
                                { label: "Saver", profile: PowerProfile.PowerSaver },
                                { label: "Balanced", profile: PowerProfile.Balanced },
                                { label: "Performance", profile: PowerProfile.Performance }
                            ]
                            delegate: Link {
                                required property var modelData
                                readonly property bool active: PowerProfiles.profile === modelData.profile
                                readonly property bool available: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile

                                label: (active ? "● " : "") + modelData.label
                                tone: active ? Theme.fg : Theme.muted
                                opacity: available ? 1 : 0.35
                                onClicked: if (available) PowerProfiles.profile = modelData.profile
                            }
                        }
                    }
                }
            }
        }
    }
}
