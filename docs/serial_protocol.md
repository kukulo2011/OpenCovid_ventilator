# Breezy Serial Protocol
To communicate between the 8-bit ventilator controller and the Android
app, we use a 115200 baud serial connection over the USB port.  The Android
app does not control the ventilator, because manipulating a touchscreen while
wearing gloves is not suitable.  For this reason, it's a one-directional
protocol:  The controller just continuously sends updates.

The protocol is a text-based protocol, with one data sample per line.
Output from the controller looks like this:
```
breezy,1,44741, 0.00,21.13,66.33,  0.0, 0, 0, 0,  0, 0.00, 0.0, 0.0, 0.0,  0,  0,25370
breezy,1,44795, 0.00,21.83,73.67,  0.0, 0, 0, 0,  0, 0.00, 0.0, 0.0, 0.0,  0,  0,26647
breezy,1,44850, 0.00,23.30,81.33,  0.0, 0, 0, 0,  0, 0.00, 0.0, 0.0, 0.0,  0,  0, 3793
breezy,1,44905, 0.00,23.47,89.00,  0.0, 0, 0, 0,  0, 0.00, 0.0, 0.0, 0.0,  0,  0,42439
breezy,1,44959, 0.00,22.10,96.33,  0.0, 0, 0, 0,  0, 0.00, 0.0, 0.0, 0.0,  0,  0, 3932
etc.
```
It's a simple CSV (comma-separated values) text line, terminated by
a carriage-return/line-feed.  Integers are represented as decimal
strings, and floating-point numbers as ASCII strings in decimal or
scientific notation, in the format requried by
https://api.flutter.dev/flutter/dart-core/double/parse.html.

The fields are as follows:

|   Field Name  |  Type  | Expected Range |  Comment  |
|---------------|--------|-------|-----------|
| `protocol_name` | String | "breezy" | Allows extensibility to other devices. |
| `protocol_version` | integer | 1 | Allows extensibility to future versions |
| `time` | integer | 0-65535 | The time the sample was taken, in milliseconds.  The time value wraps when it overflows. |
| `cmH2O` | float |  -99 to 99  |  Actual pressure (to be plotted)  |
| `l/min` | float |  -999 to 999  |  Actual flow (to be plotted) |
| `ml` | float |  0 to 9999  |  Actual volume (to be plotted) |
| `Ppeak (cmH2O)` | formatted float | ##.# |  Peak pressure  |
| `Pmean (cmH2O)` | formatted float | ##.# |  Mean pressure  |
| `PEEP (cmH2O)` | formatted float | ##.# |  Positive end-expiratory pressure  |
| `RR` | formatted float | ##.# |  Respiratory rate (b/min)  |
| `O2 (%)` | formatted float |  ### (0-100) |  Oxygen concentration  |
| `Ti (s)` | formatted float |  ##.## |  Inspiration time  |
| `I:E` | formatted float | ##.# |  Inspiration : Expiration ratio, print as 1:???  |
| `MVi (l/min)` | formatted float | ##.# |  Mean volume inspiration  |
| `MVe (l/min)` | formatted float | ##.# |  Mean volume expiration  |
| `VTi (ml)` | formatted float | #### |  Volume tidal inspiration  |
| `VTe (ml)` | formatted float | #### |  Volume tidal expiration  |
| `checksum` | int |  0-65535 or -1 | A value of -1 means "no checksum" |
| `line end` | String | "\r\n" | End of message |

The time value wraps.  For example, if samples arrive every 20ms, 
the sample at time 65532 would be followed by a sample at time 16.  Note
that if a few samples are missed, the time will remain synchronized.  This
would not be true if only time deltas were sent.

The expected range is the set of expected values.  For the line graph, 
actual values can go outside of this range, but if
they do, the line graph will clamp the value and color it
red.  For formatted float values, whitespace will be displayed.
Values longer than the given format string might have formatting
issues.

The checksum is calculated over the ASCII character values starting
at the first character of `protocol_name` and ending with the comma
before `checksum`. That final comma _is_ included in the checksum
calculation. 

The CRC algorithm is CRC-16-CCITT, as specified
by [The CRC Wikipedia Page](https://en.wikipedia.org/wiki/Cyclic_redundancy_check).  Sample C code to calculate this can be found at
http://srecord.sourceforge.net/crc16-ccitt.html.

Lines beginning with "#" will be treated as comments:  They will
be discarded without logging a parse error.

A line that consists entirely of the string `reset-time` will reset
the time calculation.  The next sample after this line will be displayed
at a time 40 ms after the last sample, regardless of the time value.
This can be useful e.g. for playing back captured data on a loop,
for demo purposes.
