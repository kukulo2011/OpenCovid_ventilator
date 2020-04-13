#!/bin/bash

if [ $# != 4 ] ; then
    base="`dirname $0`"
    dir="`realpath --relative-to=\"$base\" \"$base/../../firmware/Misc/example_measurements\"`"
    echo ""
    echo "Usage:  $0 security address port file"
    echo ""
    echo "This will open a socket to the display using nc to the"
    echo "given address and port.  It will send the security"
    echo "string first, then send the contents of the file.  See"
    echo "$dir for suitable files."
    echo ""
    echo "If you're running an emulator, you might need to do this:"
    echo "    adb forward tcp:7777 tcp:7777"
    echo "    See https://developer.android.com/studio/command-line/adb#forwardports"
    echo ""
    exit 1
fi

security=$1
addr=$2
port=$3
file=$4


(echo "$security" ; cat ../../firmware/Misc/example_measurements/breezy-example3.log; echo ""; echo "exit") | nc localhost 7777

