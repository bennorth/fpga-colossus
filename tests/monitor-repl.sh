#!/bin/bash

if [ $USER = "pi" ]; then
    cd ../rpi-client/
    exec sudo ./rpi-client
else
    cd ../src
    ulimit -v 6291456  # 6GB
    exec ./monitor-repl -tclbatch run_all_exit.tcl
fi
