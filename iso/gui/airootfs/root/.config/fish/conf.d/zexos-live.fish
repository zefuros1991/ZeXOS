# ZeXOS: start the live desktop with the installer on the first screen.
# "-l" tells niri-session we are already in a login shell. Without it,
# niri-session starts a new login shell, which runs this file again, and
# so on forever.
if status is-login; and test (tty) = /dev/tty1; and not set -q WAYLAND_DISPLAY
    # Hide niri-session's start-up chatter; niri's own log is in the journal.
    clear
    niri-session -l >/dev/null 2>&1
end
