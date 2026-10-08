pragma Singleton
import QtQuick
import Quickshell

// Which drawer is open. The keybind-facing IPC surface lives in Ipc.qml.
Singleton {
    id: root

    property bool dashboard: false
    property bool launcher: false
    property bool power: false

    // True when opened by keybind: stays open until toggled/Escape instead of closing on mouse leave.
    property bool pinned: false

    function closeAll() {
        dashboard = false;
        launcher = false;
        power = false;
        pinned = false;
    }

    function toggle(name) {
        const wasOpen = root[name];
        closeAll();
        if (wasOpen) {
            root[name] = false;
        } else {
            root[name] = true;
            pinned = true;
        }
    }
}
