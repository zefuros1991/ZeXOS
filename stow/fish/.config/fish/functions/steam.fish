function steam --wraps=/usr/bin/steam --description 'Launch Steam with a workaround for the libaudio.so/PulseAudio startup segfault (ValveSoftware/steam-for-linux #9204/#9289)'
    env PULSE_SERVER=/nonexistent/pulse-workaround.sock /usr/bin/steam $argv
end
