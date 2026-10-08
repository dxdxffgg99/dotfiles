pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU / memory / wifi SSID, polled only while something asks for it (Dashboard sets `active`).
Singleton {
    id: root

    property bool active: false
    property real cpu: 0
    property real mem: 0
    property string network: ""

    property var _last: null

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            netProc.running = true;
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root._last) {
                const dt = total - root._last.total;
                const di = idle - root._last.idle;
                if (dt > 0) root.cpu = 1 - di / dt;
            }
            root._last = { idle: idle, total: total };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const total = parseInt(t.match(/MemTotal:\s+(\d+)/)[1]);
            const avail = parseInt(t.match(/MemAvailable:\s+(\d+)/)[1]);
            root.mem = 1 - avail / total;
        }
    }

    Process {
        id: netProc
        // NetworkManager isn't running here, so ask the wireless stack directly.
        command: ["sh", "-c", "for d in $(iw dev | awk '/Interface/{print $2}'); do iw dev $d link | sed -n 's/^[[:space:]]*SSID: //p'; done | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.network = text.trim()
        }
    }
}
