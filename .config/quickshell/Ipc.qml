import Quickshell
import Quickshell.Io

// niri keybinds drive the shell through this:
//   qs ipc call shell dashboard|launcher|session|close
//   qs ipc call shell brightness up|down
Scope {
    IpcHandler {
        target: "shell"

        function dashboard(): void { Drawers.toggle("dashboard") }
        function launcher(): void { Drawers.toggle("launcher") }
        function session(): void { Drawers.toggle("power") }
        function close(): void { Drawers.closeAll() }
        function brightness(dir: string): void { Brightness.step(dir === "up" ? 5 : -5) }
    }
}
