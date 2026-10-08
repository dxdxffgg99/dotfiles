export LIBVA_DRIVER_NAME=iHD
export VDPAU_DRIVER=va_gl

# niri-session re-runs itself through a login shell, which reads this file again,
# so the guard variable keeps that nested shell from launching niri-session recursively.
if [ -z "$DISPLAY" ] && [ -z "$NIRI_SESSION_STARTED" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export NIRI_SESSION_STARTED=1
    exec niri-session
fi


# Added by Toolbox App
export PATH="$PATH:/home/kr-dev/.local/share/JetBrains/Toolbox/scripts"

