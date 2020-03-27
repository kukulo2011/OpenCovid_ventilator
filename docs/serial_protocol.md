# Breezy Serial Protocol
To communicate between the 8-bit ventilator controller and the Android
app, we use a 9600 baud serial connection over the USB port.  The Android
app does not control the ventilator, because manipulating a touchscreen while
wearing gloves is not suitable.  For this reason, it's a one-directional
protocol:  The controller just continuously sends updates.

The protocol is a simple text-based protocol, with one data sample per line.
Output from the controller looks like this:
```
breezy,1,1234,270.3,3.5,87.3,-1
breezy,1,1254,170.3,3.6,77.3,-1
breezy,1,1275,70.3,4.2,67.3,-1
etc.
TODO:  Fill in a real capture from the device, with 
       the correct number of samples.
```
It's a simple CSV (comma-separated values) text line, terminated by
a carriage-return/line-feed.  Integers are represented as decimal
strings, and floating-point numbers as ASCII strings in decimal or
scientific notation, in the format requried by
https://api.flutter.dev/flutter/dart-core/double/parse.html.

The fields are as follows:

|   Field Name  |  Type  | Value |  Comment  |
|---------------|--------|-------|-----------|
| `protocol_name` | String | "breezy" | Allows extensibility to other devices. |
| `protocol_version` | integer | 1 | Allows extensibility to future versions |
| `time` | integer | 0-65535 | The time the sample was taken, in milliseconds.  The time value wraps when it overflows. |
| `value1` | float |  ???  |  ???  |
| `value2` | float |  ???  |  ???  |
| `value3` | float |  ???  |  ???  |
| `checksum` | int |  0-65535 or -1 | A value of -1 means "no checksum" |

The time value wraps.  For example, if samples arrive every 20ms, 
the sample at time 65532 would be followed by a sample at time 16.  Note
that if a few samples are missed, the time will remain synchronized.  This
would not be true if only time deltas were sent.

The checksum is calculated over the ASCII character values starting
at the first character of `protocol_name` and ending with the comma
before `checksum`. That final comma _is_ included in the checksum
calculation. 

___TODO:  Decide if this algorithm is OK.  If a different one is already
available/implemented on the controller, that would probably be better.___
The CRC algorithm is CRC-16-CCITT, as specified
by [The CRC Wikipedia Page](https://en.wikipedia.org/wiki/Cyclic_redundancy_check).  Sample C code to calculate this can be found at
http://srecord.sourceforge.net/crc16-ccitt.html.

