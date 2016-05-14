#!/bin/bash

case "$1" in
    monitor)
        exec entr ./$0 refresh "$2"
        ;;
    refresh)
        active_wid=$(xdotool getactivewindow)
        xdotool search --name "$2" \
            windowactivate \
            --sync \
            key --clearmodifiers "ctrl+r"
        xdotool windowactivate $active_wid
        ;;
    *)
        echo "specify monitor or refresh"
esac
