#!/bin/bash

if [ $# != 1 ] ; then
    echo ""
    echo "Usage:  $0 device"
    echo ""
    echo "This will send data to device (like /dev/rfcomm0) as fast as the"
    echo "device accepts it.  It's meant to be used with \"Test Input Port\" as"
    echo "a stress test."
    echo ""
    exit 1
fi

addr=$1
port=$2
yes "stress test" | nl | tee $1
