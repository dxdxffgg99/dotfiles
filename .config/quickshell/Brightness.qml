pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real value: 1        // 0..1
    property bool fromSet: false
    signal changed()

    function set(v) {
        const pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100);
        setProc.command = ["brightnessctl", "-q", "set", pct + "%"];
        fromSet = true;
        setProc.running = true;
    }

    function step(deltaPct) {
        set(root.value + deltaPct / 100);
    }

    Process {
        id: setProc
        onExited: readProc.running = true
    }

    Process {
        id: readProc
        command: ["brightnessctl", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // name,class,current,percent%,max
                const f = text.trim().split(",");
                if (f.length < 5) return;
                const v = parseInt(f[3]) / 100;
                root.value = v;
                if (root.fromSet) {
                    root.fromSet = false;
                    root.changed();
                }
            }
        }
    }
}
