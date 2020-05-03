#!/bin/bash

if [ $# != 1 ] ; then
    base="`dirname $0`"
    dir="`realpath --relative-to=\"$base\" \"$base/../../firmware/Misc/example_measurements\"`"
    echo ""
    echo "Usage:  $0 file"
    echo ""
    echo "This will send file to /dev/rfcomm0.  See"
    echo "$dir for suitable files."
    echo ""
    exit 1
fi

file=$1


echo "meter-data:on" > /dev/rfcomm0
cat $file > /dev/rfcomm0
echo "reset-time" > /dev/rfcomm0

