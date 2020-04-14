#!/bin/bash

if [ $# != 2 ] ; then
    echo ""
    echo "Usage:  $0 address port"
    echo ""
    echo "This will open a socket to the Android device using nc to the"
    echo "given address and port.  It will send data as fast as the device"
    echo "accepts it.  It's meant to be used with \"Test Input Port\" as a"
    echo "stress test."
    echo ""
    echo "If you're running an emulator, you might need to do this:"
    echo "    adb forward tcp:7777 tcp:7777"
    echo "    See https://developer.android.com/studio/command-line/adb#forwardports"
    echo ""
    exit 1
fi

addr=$1
port=$2
yes "stress test" | nl | nc $addr $port
