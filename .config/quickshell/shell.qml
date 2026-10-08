//@ pragma UseQApplication
import Quickshell

// No always-on bar: everything below is a drawer that appears on edge hover, keybind or event.
ShellRoot {
    Ipc {}
    Dashboard {}
    Launcher {}
    Osd {}
    Session {}
}
