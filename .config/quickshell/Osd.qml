import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs
import qs.components

// Volume / brightness pill at the bottom centre. Reacts to the actual values changing, so
// it also fires for pavucontrol, media keys from other tools, etc.
Scope {
    id: root

    property string icon: ""
    property real value: 0
    property color fill: Theme.accent
    property bool armed: false      // ignore the initial values reported at startup

    readonly property var sink: Pipewire.defaultAudioSink

    PwObjectTracker { objects: [root.sink] }

    Timer { interval: 1500; running: true; onTriggered: root.armed = true }
    Timer { id: hideTimer; interval: 1400; onTriggered: win.shown = false }

    function show(icon, value, fill) {
        if (!armed) return;
        root.icon = icon;
        root.value = value;
        root.fill = fill;
        win.shown = true;
        hideTimer.restart();
    }

    function showVolume() {
        const a = root.sink ? root.sink.audio : null;
        if (!a) return;
        show(a.muted ? "Muted" : "Volume", a.muted ? 0 : a.volume, Theme.accent);
    }

    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() { root.showVolume() }
        function onMutedChanged() { root.showVolume() }
    }

    Connections {
        target: Brightness
        function onChanged() { root.show("Bright", Brightness.value, Theme.warn) }
    }

    PanelWindow {
        id: win
        property bool shown: false

        anchors.bottom: true
        margins.bottom: 48
        implicitWidth: 340
        implicitHeight: 52
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: shown || pill.opacity > 0
        mask: Region {}   // never steals clicks
        WlrLayershell.namespace: "qs-osd"

        Card {
            id: pill
            anchors.fill: parent
            opacity: win.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            Slider {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                label: root.icon
                fill: root.fill
                value: root.value
            }
        }
    }
}
